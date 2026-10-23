package repository

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"tetanggo-backend/internal/domain/entity"
)

type PostgresCashbookRepository struct {
	db *sql.DB
}

func NewPostgresCashbookRepository(db *sql.DB) *PostgresCashbookRepository {
	return &PostgresCashbookRepository{db: db}
}

func (r *PostgresCashbookRepository) GetSummary(ctx context.Context) (*entity.CashbookSummary, error) {
	summary := &entity.CashbookSummary{
		MonthlySummary: make([]entity.MonthlyCashFlow, 0),
	}

	totalsQuery := `
		SELECT 
			COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0) AS total_income,
			COALESCE(SUM(amount) FILTER (WHERE type = 'expense'), 0) AS total_expense
		FROM cash_transactions;
	`
	err := r.db.QueryRowContext(ctx, totalsQuery).Scan(&summary.TotalIncome, &summary.TotalExpense)
	if err != nil {
		return nil, fmt.Errorf("failed to get totals: %w", err)
	}

	summary.CurrentBalance = summary.TotalIncome - summary.TotalExpense

	monthlyQuery := `
		WITH months AS (
			SELECT TO_CHAR(date_trunc('month', CURRENT_DATE - (n || ' month')::interval), 'YYYY-MM') AS month_str
			FROM generate_series(5, 0, -1) n
		)
		SELECT 
			m.month_str,
			COALESCE(SUM(CASE WHEN c.type = 'income' THEN c.amount ELSE 0 END), 0) AS income,
			COALESCE(SUM(CASE WHEN c.type = 'expense' THEN c.amount ELSE 0 END), 0) AS expense
		FROM months m
		LEFT JOIN cash_transactions c ON TO_CHAR(c.transaction_date, 'YYYY-MM') = m.month_str
		GROUP BY m.month_str
		ORDER BY m.month_str ASC;
	`
	rows, err := r.db.QueryContext(ctx, monthlyQuery)
	if err != nil {
		return nil, fmt.Errorf("failed to get monthly summary: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var item entity.MonthlyCashFlow
		if err := rows.Scan(&item.Month, &item.Income, &item.Expense); err != nil {
			return nil, fmt.Errorf("failed to scan monthly item: %w", err)
		}
		summary.MonthlySummary = append(summary.MonthlySummary, item)
	}

	return summary, nil
}

func (r *PostgresCashbookRepository) GetTransactions(ctx context.Context, filter entity.CashTransactionsFilter) (*entity.CashTransactionsResult, error) {
	// Resolve period, start date, and end date
	var startDate string
	var endDate string
	var periodStr string

	if filter.Period != "" {
		parts := strings.Split(filter.Period, "-")
		if len(parts) == 2 {
			y, _ := strconv.Atoi(parts[0])
			m, _ := strconv.Atoi(parts[1])
			if y > 0 && m >= 1 && m <= 12 {
				firstDay := time.Date(y, time.Month(m), 1, 0, 0, 0, 0, time.Local)
				lastDay := firstDay.AddDate(0, 1, -1)
				startDate = firstDay.Format("2006-01-02")
				endDate = lastDay.Format("2006-01-02")
				periodStr = firstDay.Format("2006-01")
			}
		}
	}

	if startDate == "" && filter.Year > 0 && filter.Month >= 1 && filter.Month <= 12 {
		firstDay := time.Date(filter.Year, time.Month(filter.Month), 1, 0, 0, 0, 0, time.Local)
		lastDay := firstDay.AddDate(0, 1, -1)
		startDate = firstDay.Format("2006-01-02")
		endDate = lastDay.Format("2006-01-02")
		periodStr = firstDay.Format("2006-01")
	}

	if startDate == "" && filter.StartDate != "" && filter.EndDate != "" {
		startDate = filter.StartDate
		endDate = filter.EndDate
		if len(startDate) >= 7 {
			periodStr = startDate[:7]
		}
	}

	if startDate == "" {
		now := time.Now()
		firstDay := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.Local)
		lastDay := firstDay.AddDate(0, 1, -1)
		startDate = firstDay.Format("2006-01-02")
		endDate = lastDay.Format("2006-01-02")
		periodStr = firstDay.Format("2006-01")
	}

	// 1. Authoritative previous balance (transactions before startDate)
	var previousBalance float64
	prevQuery := `
		SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount WHEN type = 'expense' THEN -amount ELSE 0 END), 0)
		FROM cash_transactions
		WHERE transaction_date < $1;
	`
	err := r.db.QueryRowContext(ctx, prevQuery, startDate).Scan(&previousBalance)
	if err != nil {
		return nil, fmt.Errorf("failed calculating previous balance: %w", err)
	}

	// 2. Authoritative period income and expense (all transactions in the period)
	var periodIncome, periodExpense float64
	periodTotalsQuery := `
		SELECT
			COALESCE(SUM(amount) FILTER (WHERE type = 'income'), 0) AS period_income,
			COALESCE(SUM(amount) FILTER (WHERE type = 'expense'), 0) AS period_expense
		FROM cash_transactions
		WHERE transaction_date >= $1 AND transaction_date <= $2;
	`
	err = r.db.QueryRowContext(ctx, periodTotalsQuery, startDate, endDate).Scan(&periodIncome, &periodExpense)
	if err != nil {
		return nil, fmt.Errorf("failed calculating period totals: %w", err)
	}

	endingBalance := previousBalance + periodIncome - periodExpense

	// 3. Transactions query with date range and optional category/type
	whereClauses := []string{
		"ct.transaction_date >= $1",
		"ct.transaction_date <= $2",
	}
	args := []interface{}{startDate, endDate}
	argIdx := 3

	if filter.Type != "" && filter.Type != "all" {
		whereClauses = append(whereClauses, fmt.Sprintf("ct.type = $%d", argIdx))
		args = append(args, filter.Type)
		argIdx++
	}

	if filter.Category != "" && filter.Category != "all" {
		whereClauses = append(whereClauses, fmt.Sprintf("ct.category = $%d", argIdx))
		args = append(args, filter.Category)
		argIdx++
	}

	whereSQL := strings.Join(whereClauses, " AND ")
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM cash_transactions ct WHERE %s", whereSQL)
	var total int
	err = r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, fmt.Errorf("failed counting transactions: %w", err)
	}

	limit := filter.Limit
	if limit <= 0 {
		limit = 20
	}
	page := filter.Page
	if page <= 0 {
		page = 1
	}
	offset := (page - 1) * limit

	query := fmt.Sprintf(`
		SELECT 
			ct.id, ct.type, ct.category, ct.amount, 
			TO_CHAR(ct.transaction_date, 'YYYY-MM-DD') AS transaction_date,
			ct.description, ct.proof_image_url, ct.bill_id, ct.created_by,
			COALESCE(u.name, 'Admin RT') AS creator_name,
			ct.created_at
		FROM cash_transactions ct
		LEFT JOIN users u ON ct.created_by = u.id
		WHERE %s
		ORDER BY ct.transaction_date DESC, ct.id DESC
		LIMIT $%d OFFSET $%d;
	`, whereSQL, argIdx, argIdx+1)

	argsWithPaging := append(args, limit, offset)
	rows, err := r.db.QueryContext(ctx, query, argsWithPaging...)
	if err != nil {
		return nil, fmt.Errorf("failed querying cash transactions: %w", err)
	}
	defer rows.Close()

	transactions := make([]entity.CashTransaction, 0)
	for rows.Next() {
		var tx entity.CashTransaction
		err := rows.Scan(
			&tx.ID,
			&tx.Type,
			&tx.Category,
			&tx.Amount,
			&tx.TransactionDate,
			&tx.Description,
			&tx.ProofImageURL,
			&tx.BillID,
			&tx.CreatedBy,
			&tx.CreatorName,
			&tx.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed scanning cash transaction: %w", err)
		}
		transactions = append(transactions, tx)
	}

	return &entity.CashTransactionsResult{
		Transactions:    transactions,
		Total:           total,
		Page:            page,
		Limit:           limit,
		Period:          periodStr,
		StartDate:       startDate,
		EndDate:         endDate,
		PreviousBalance: previousBalance,
		PeriodIncome:    periodIncome,
		PeriodExpense:   periodExpense,
		EndingBalance:   endingBalance,
	}, nil
}

func (r *PostgresCashbookRepository) GetTransactionByID(ctx context.Context, id int64) (*entity.CashTransaction, error) {
	query := `
		SELECT 
			ct.id, ct.type, ct.category, ct.amount, 
			TO_CHAR(ct.transaction_date, 'YYYY-MM-DD') AS transaction_date,
			ct.description, ct.proof_image_url, ct.bill_id, ct.created_by,
			COALESCE(u.name, 'Admin RT') AS creator_name,
			ct.created_at
		FROM cash_transactions ct
		LEFT JOIN users u ON ct.created_by = u.id
		WHERE ct.id = $1;
	`
	var tx entity.CashTransaction
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&tx.ID,
		&tx.Type,
		&tx.Category,
		&tx.Amount,
		&tx.TransactionDate,
		&tx.Description,
		&tx.ProofImageURL,
		&tx.BillID,
		&tx.CreatedBy,
		&tx.CreatorName,
		&tx.CreatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed to get transaction by id: %w", err)
	}
	return &tx, nil
}

func (r *PostgresCashbookRepository) CreateTransaction(ctx context.Context, tx *entity.CashTransaction) error {
	query := `
		INSERT INTO cash_transactions (type, category, amount, transaction_date, description, proof_image_url, bill_id, created_by, created_at)
		VALUES ($1, $2, $3, $4::date, $5, $6, $7, $8, NOW())
		RETURNING id, created_at;
	`
	return r.db.QueryRowContext(
		ctx,
		query,
		tx.Type,
		tx.Category,
		tx.Amount,
		tx.TransactionDate,
		tx.Description,
		tx.ProofImageURL,
		tx.BillID,
		tx.CreatedBy,
	).Scan(&tx.ID, &tx.CreatedAt)
}

func (r *PostgresCashbookRepository) DeleteManualTransaction(ctx context.Context, id int64) error {
	var billID sql.NullInt64
	var proofImageURL sql.NullString

	checkQuery := `SELECT bill_id, proof_image_url FROM cash_transactions WHERE id = $1;`
	err := r.db.QueryRowContext(ctx, checkQuery, id).Scan(&billID, &proofImageURL)
	if err != nil {
		if err == sql.ErrNoRows {
			return fmt.Errorf("transaksi kas tidak ditemukan")
		}
		return fmt.Errorf("gagal memeriksa transaksi: %w", err)
	}

	if billID.Valid {
		return fmt.Errorf("transaksi otomatis dari iuran tidak dapat dihapus manual")
	}

	deleteQuery := `DELETE FROM cash_transactions WHERE id = $1;`
	_, err = r.db.ExecContext(ctx, deleteQuery, id)
	if err != nil {
		return fmt.Errorf("gagal menghapus transaksi kas: %w", err)
	}

	// Clean up image file if exists
	if proofImageURL.Valid && proofImageURL.String != "" {
		relPath := strings.TrimPrefix(proofImageURL.String, "/")
		_ = os.Remove(filepath.Clean(relPath))
	}

	return nil
}
