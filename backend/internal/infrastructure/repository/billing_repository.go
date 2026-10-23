package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"
	"tetanggo-backend/internal/domain/entity"
)

type PostgresBillingRepository struct {
	db *sql.DB
}

func NewPostgresBillingRepository(db *sql.DB) *PostgresBillingRepository {
	return &PostgresBillingRepository{db: db}
}

func (r *PostgresBillingRepository) GetPaymentSettings(ctx context.Context) (*entity.PaymentSetting, error) {
	query := `
		SELECT id, bank_name, account_number, account_holder, monthly_fee, created_at, updated_at
		FROM payment_settings
		ORDER BY id ASC
		LIMIT 1;
	`
	var s entity.PaymentSetting
	err := r.db.QueryRowContext(ctx, query).Scan(
		&s.ID,
		&s.BankName,
		&s.AccountNumber,
		&s.AccountHolder,
		&s.MonthlyFee,
		&s.CreatedAt,
		&s.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		// Insert default setting
		insertQuery := `
			INSERT INTO payment_settings (bank_name, account_number, account_holder, monthly_fee)
			VALUES ('BCA', '8830192831', 'Kas RT 05 RW 01', 100000.00)
			RETURNING id, bank_name, account_number, account_holder, monthly_fee, created_at, updated_at;
		`
		err = r.db.QueryRowContext(ctx, insertQuery).Scan(
			&s.ID,
			&s.BankName,
			&s.AccountNumber,
			&s.AccountHolder,
			&s.MonthlyFee,
			&s.CreatedAt,
			&s.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to initialize default payment settings: %w", err)
		}
		return &s, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get payment settings: %w", err)
	}
	return &s, nil
}

func (r *PostgresBillingRepository) UpdatePaymentSettings(ctx context.Context, s *entity.PaymentSetting) error {
	query := `
		UPDATE payment_settings
		SET bank_name = $1, account_number = $2, account_holder = $3, monthly_fee = $4, updated_at = CURRENT_TIMESTAMP
		WHERE id = (SELECT id FROM payment_settings ORDER BY id ASC LIMIT 1);
	`
	res, err := r.db.ExecContext(ctx, query, s.BankName, s.AccountNumber, s.AccountHolder, s.MonthlyFee)
	if err != nil {
		return fmt.Errorf("failed to update payment settings: %w", err)
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		insertQuery := `
			INSERT INTO payment_settings (bank_name, account_number, account_holder, monthly_fee)
			VALUES ($1, $2, $3, $4);
		`
		_, err = r.db.ExecContext(ctx, insertQuery, s.BankName, s.AccountNumber, s.AccountHolder, s.MonthlyFee)
		if err != nil {
			return fmt.Errorf("failed to insert payment settings: %w", err)
		}
	}
	return nil
}

func (r *PostgresBillingRepository) CountPaidOrPendingBillsByPeriod(ctx context.Context, period string) (int, error) {
	var paidCount int
	err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*) 
		FROM bills 
		WHERE billing_period = $1 
		  AND status IN ('paid', 'pending_verification')
	`, period).Scan(&paidCount)
	if err != nil {
		return 0, fmt.Errorf("failed to count paid or pending bills: %w", err)
	}
	return paidCount, nil
}

func (r *PostgresBillingRepository) CountTotalBillsByPeriod(ctx context.Context, period string) (int, error) {
	var total int
	err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*) 
		FROM bills 
		WHERE billing_period = $1
	`, period).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("failed to count total bills for period: %w", err)
	}
	return total, nil
}

func (r *PostgresBillingRepository) CountAnyPaymentsByPeriod(ctx context.Context, period string) (int, error) {
	var count int
	// Checks if any resident has initiated/made a payment for this period (pending, paid, or rejected)
	// or if any bill has status != unpaid
	err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(DISTINCT b.id)
		FROM bills b
		LEFT JOIN payments p ON p.bill_id = b.id
		WHERE b.billing_period = $1
		  AND (p.id IS NOT NULL OR b.status IN ('paid', 'pending_verification', 'rejected'))
	`, period).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("failed to count any payments for period: %w", err)
	}
	return count, nil
}

func (r *PostgresBillingRepository) GetDistinctPaymentAmountsByPeriod(ctx context.Context, period string) ([]float64, error) {
	query := `
		SELECT DISTINCT COALESCE(p.amount_paid, b.amount)
		FROM bills b
		LEFT JOIN payments p ON p.bill_id = b.id
		WHERE b.billing_period = $1
		  AND (p.id IS NOT NULL OR b.status IN ('paid', 'pending_verification', 'rejected'))
		ORDER BY 1 ASC;
	`
	rows, err := r.db.QueryContext(ctx, query, period)
	if err != nil {
		return nil, fmt.Errorf("failed to query payment amounts: %w", err)
	}
	defer rows.Close()

	var amounts []float64
	for rows.Next() {
		var amt float64
		if err := rows.Scan(&amt); err != nil {
			return nil, fmt.Errorf("failed to scan payment amount: %w", err)
		}
		amounts = append(amounts, amt)
	}
	return amounts, nil
}

func (r *PostgresBillingRepository) GenerateMonthlyBills(ctx context.Context, period string, amount float64) (int64, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// 1. Update existing unpaid bills if amount changed, provided they have no payment records
	updateQuery := `
		UPDATE bills
		SET amount = CAST($2 AS NUMERIC), updated_at = CURRENT_TIMESTAMP
		WHERE billing_period = CAST($1 AS VARCHAR)
		  AND status = 'unpaid'
		  AND NOT EXISTS (
		      SELECT 1 FROM payments p WHERE p.bill_id = bills.id
		  );
	`
	resUpdate, err := tx.ExecContext(ctx, updateQuery, period, amount)
	if err != nil {
		return 0, fmt.Errorf("failed to update existing unpaid bills: %w", err)
	}
	updatedRows, _ := resUpdate.RowsAffected()

	// 2. Insert bills for houses without bills yet
	insertQuery := `
		INSERT INTO bills (house_id, billing_period, amount, status)
		SELECT h.id, CAST($1 AS VARCHAR), CAST($2 AS NUMERIC), 'unpaid'
		FROM houses h
		WHERE h.status IN ('milik', 'kontrak')
		  AND NOT EXISTS (
		      SELECT 1 FROM bills b WHERE b.house_id = h.id AND b.billing_period = CAST($1 AS VARCHAR)
		  );
	`
	resInsert, err := tx.ExecContext(ctx, insertQuery, period, amount)
	if err != nil {
		return 0, fmt.Errorf("failed to generate monthly bills: %w", err)
	}
	insertedRows, _ := resInsert.RowsAffected()

	if err := tx.Commit(); err != nil {
		return 0, fmt.Errorf("failed to commit bill generation: %w", err)
	}

	totalAffected := insertedRows + updatedRows
	return totalAffected, nil
}

func (r *PostgresBillingRepository) GenerateIndividualBill(ctx context.Context, houseID int64, period string, amount float64) (*entity.Bill, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// 1. Verify house exists and is eligible
	var houseStatus string
	err = tx.QueryRowContext(ctx, "SELECT status FROM houses WHERE id = $1", houseID).Scan(&houseStatus)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, errors.New("unit rumah tidak ditemukan")
		}
		return nil, fmt.Errorf("failed to query house: %w", err)
	}
	if houseStatus != "milik" && houseStatus != "kontrak" {
		return nil, fmt.Errorf("unit rumah tidak memenuhi syarat untuk tagihan iuran (status: %s)", houseStatus)
	}

	// 2. Insert with ON CONFLICT DO NOTHING to prevent race conditions & duplicate bills
	query := `
		INSERT INTO bills (house_id, billing_period, amount, status)
		VALUES ($1, $2, $3, 'unpaid')
		ON CONFLICT (house_id, billing_period) DO NOTHING
		RETURNING id, house_id, billing_period, amount, status, created_at, updated_at;
	`
	var bill entity.Bill
	err = tx.QueryRowContext(ctx, query, houseID, period, amount).Scan(
		&bill.ID,
		&bill.HouseID,
		&bill.BillingPeriod,
		&bill.Amount,
		&bill.Status,
		&bill.CreatedAt,
		&bill.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, fmt.Errorf("unit rumah ini sudah memiliki tagihan untuk periode %s", period)
		}
		return nil, fmt.Errorf("failed to generate individual bill: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit individual bill: %w", err)
	}

	return &bill, nil
}

func (r *PostgresBillingRepository) GetBillsByHouseID(ctx context.Context, houseID int64) ([]entity.Bill, error) {
	query := `
		SELECT 
			b.id, b.house_id, b.billing_period, b.amount, b.status, b.created_at, b.updated_at,
			h.id, h.block, h.house_number, h.status,
			p.id, p.amount_paid, p.payment_method, p.proof_image_url, p.sender_bank, p.sender_name, p.notes, p.rejection_reason, p.verified_at, p.created_at
		FROM bills b
		INNER JOIN houses h ON h.id = b.house_id
		LEFT JOIN LATERAL (
			SELECT id, amount_paid, COALESCE(payment_method, 'TRANSFER') AS payment_method, proof_image_url, sender_bank, sender_name, notes, rejection_reason, verified_at, created_at
			FROM payments
			WHERE payments.bill_id = b.id
			ORDER BY id DESC
			LIMIT 1
		) p ON true
		WHERE b.house_id = $1
		ORDER BY b.billing_period DESC;
	`
	rows, err := r.db.QueryContext(ctx, query, houseID)
	if err != nil {
		return nil, fmt.Errorf("failed to get bills for house %d: %w", houseID, err)
	}
	defer rows.Close()

	var bills []entity.Bill
	for rows.Next() {
		var b entity.Bill
		var h entity.House
		var pID sql.NullInt64
		var pAmountPaid sql.NullFloat64
		var pPaymentMethod sql.NullString
		var pProofURL sql.NullString
		var pSenderBank sql.NullString
		var pSenderName sql.NullString
		var pNotes sql.NullString
		var pRejectionReason sql.NullString
		var pVerifiedAt sql.NullTime
		var pCreatedAt sql.NullTime

		err := rows.Scan(
			&b.ID,
			&b.HouseID,
			&b.BillingPeriod,
			&b.Amount,
			&b.Status,
			&b.CreatedAt,
			&b.UpdatedAt,
			&h.ID,
			&h.Block,
			&h.HouseNumber,
			&h.Status,
			&pID,
			&pAmountPaid,
			&pPaymentMethod,
			&pProofURL,
			&pSenderBank,
			&pSenderName,
			&pNotes,
			&pRejectionReason,
			&pVerifiedAt,
			&pCreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan bill: %w", err)
		}

		b.House = &h

		if pID.Valid {
			p := &entity.Payment{
				ID:            pID.Int64,
				BillID:        b.ID,
				AmountPaid:    pAmountPaid.Float64,
				PaymentMethod: pPaymentMethod.String,
				ProofImageURL: pProofURL.String,
			}
			if pSenderBank.Valid {
				p.SenderBank = &pSenderBank.String
			}
			if pSenderName.Valid {
				p.SenderName = &pSenderName.String
			}
			if pNotes.Valid {
				p.Notes = &pNotes.String
			}
			if pRejectionReason.Valid {
				p.RejectionReason = &pRejectionReason.String
			}
			if pVerifiedAt.Valid {
				p.VerifiedAt = &pVerifiedAt.Time
			}
			if pCreatedAt.Valid {
				p.CreatedAt = pCreatedAt.Time
			}
			b.Payment = p
		}

		bills = append(bills, b)
	}

	return bills, nil
}

func (r *PostgresBillingRepository) GetBillsByHouseIDAndPeriod(ctx context.Context, houseID int64, period string) ([]entity.Bill, error) {
	query := `
		SELECT 
			b.id, b.house_id, b.billing_period, b.amount, b.status, b.created_at, b.updated_at,
			h.id, h.block, h.house_number, h.status,
			p.id, p.amount_paid, p.payment_method, p.proof_image_url, p.sender_bank, p.sender_name, p.notes, p.rejection_reason, p.verified_at, p.created_at
		FROM bills b
		INNER JOIN houses h ON h.id = b.house_id
		LEFT JOIN LATERAL (
			SELECT id, amount_paid, COALESCE(payment_method, 'TRANSFER') AS payment_method, proof_image_url, sender_bank, sender_name, notes, rejection_reason, verified_at, created_at
			FROM payments
			WHERE payments.bill_id = b.id
			ORDER BY id DESC
			LIMIT 1
		) p ON true
		WHERE b.house_id = $1 AND b.billing_period = $2
		ORDER BY b.billing_period DESC;
	`
	rows, err := r.db.QueryContext(ctx, query, houseID, period)
	if err != nil {
		return nil, fmt.Errorf("failed to get bills for house %d and period %s: %w", houseID, period, err)
	}
	defer rows.Close()

	var bills []entity.Bill
	for rows.Next() {
		var b entity.Bill
		var h entity.House
		var pID sql.NullInt64
		var pAmountPaid sql.NullFloat64
		var pPaymentMethod sql.NullString
		var pProofURL sql.NullString
		var pSenderBank sql.NullString
		var pSenderName sql.NullString
		var pNotes sql.NullString
		var pRejectionReason sql.NullString
		var pVerifiedAt sql.NullTime
		var pCreatedAt sql.NullTime

		err := rows.Scan(
			&b.ID,
			&b.HouseID,
			&b.BillingPeriod,
			&b.Amount,
			&b.Status,
			&b.CreatedAt,
			&b.UpdatedAt,
			&h.ID,
			&h.Block,
			&h.HouseNumber,
			&h.Status,
			&pID,
			&pAmountPaid,
			&pPaymentMethod,
			&pProofURL,
			&pSenderBank,
			&pSenderName,
			&pNotes,
			&pRejectionReason,
			&pVerifiedAt,
			&pCreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan bill: %w", err)
		}

		b.House = &h

		if pID.Valid {
			p := &entity.Payment{
				ID:            pID.Int64,
				BillID:        b.ID,
				AmountPaid:    pAmountPaid.Float64,
				PaymentMethod: pPaymentMethod.String,
				ProofImageURL: pProofURL.String,
			}
			if pSenderBank.Valid {
				p.SenderBank = &pSenderBank.String
			}
			if pSenderName.Valid {
				p.SenderName = &pSenderName.String
			}
			if pNotes.Valid {
				p.Notes = &pNotes.String
			}
			if pRejectionReason.Valid {
				p.RejectionReason = &pRejectionReason.String
			}
			if pVerifiedAt.Valid {
				p.VerifiedAt = &pVerifiedAt.Time
			}
			if pCreatedAt.Valid {
				p.CreatedAt = pCreatedAt.Time
			}
			b.Payment = p
		}

		bills = append(bills, b)
	}

	if bills == nil {
		bills = []entity.Bill{}
	}

	return bills, nil
}

func (r *PostgresBillingRepository) GetBillByHouseAndPeriod(ctx context.Context, houseID int64, period string) (*entity.Bill, error) {
	bills, err := r.GetBillsByHouseIDAndPeriod(ctx, houseID, period)
	if err != nil {
		return nil, err
	}
	if len(bills) == 0 {
		return nil, nil
	}
	return &bills[0], nil
}

func (r *PostgresBillingRepository) CreateBill(ctx context.Context, bill *entity.Bill) error {
	query := `
		INSERT INTO bills (house_id, billing_period, amount, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, NOW(), NOW())
		RETURNING id, created_at, updated_at;
	`
	return r.db.QueryRowContext(ctx, query, bill.HouseID, bill.BillingPeriod, bill.Amount, bill.Status).
		Scan(&bill.ID, &bill.CreatedAt, &bill.UpdatedAt)
}

func (r *PostgresBillingRepository) GetBillByID(ctx context.Context, billID int64) (*entity.Bill, error) {
	query := `
		SELECT 
			b.id, b.house_id, b.billing_period, b.amount, b.status, b.created_at, b.updated_at,
			h.block, h.house_number, h.status,
			p.id, p.user_id, p.amount_paid, p.payment_method, p.proof_image_url, p.sender_bank, p.sender_name, 
			p.notes, p.rejection_reason, p.verified_by, u_admin.name, p.verified_at, p.created_at
		FROM bills b
		JOIN houses h ON h.id = b.house_id
		LEFT JOIN LATERAL (
			SELECT id, user_id, amount_paid, COALESCE(payment_method, 'TRANSFER') AS payment_method, proof_image_url, sender_bank, sender_name, notes, rejection_reason, verified_by, verified_at, created_at
			FROM payments
			WHERE payments.bill_id = b.id
			ORDER BY id DESC
			LIMIT 1
		) p ON true
		LEFT JOIN users u_admin ON u_admin.id = p.verified_by
		WHERE b.id = $1;
	`
	var b entity.Bill
	var h entity.House
	var pID sql.NullInt64
	var pUserID sql.NullInt64
	var pAmountPaid sql.NullFloat64
	var pPaymentMethod sql.NullString
	var pProofURL sql.NullString
	var pSenderBank sql.NullString
	var pSenderName sql.NullString
	var pNotes sql.NullString
	var pRejectionReason sql.NullString
	var pVerifiedBy sql.NullInt64
	var pVerifiedByName sql.NullString
	var pVerifiedAt sql.NullTime
	var pCreatedAt sql.NullTime

	err := r.db.QueryRowContext(ctx, query, billID).Scan(
		&b.ID,
		&b.HouseID,
		&b.BillingPeriod,
		&b.Amount,
		&b.Status,
		&b.CreatedAt,
		&b.UpdatedAt,
		&h.Block,
		&h.HouseNumber,
		&h.Status,
		&pID,
		&pUserID,
		&pAmountPaid,
		&pPaymentMethod,
		&pProofURL,
		&pSenderBank,
		&pSenderName,
		&pNotes,
		&pRejectionReason,
		&pVerifiedBy,
		&pVerifiedByName,
		&pVerifiedAt,
		&pCreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("bill with id %d not found", billID)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get bill by id: %w", err)
	}

	h.ID = b.HouseID
	b.House = &h

	if pID.Valid {
		p := &entity.Payment{
			ID:            pID.Int64,
			BillID:        b.ID,
			AmountPaid:    pAmountPaid.Float64,
			PaymentMethod: pPaymentMethod.String,
			ProofImageURL: pProofURL.String,
		}
		if pUserID.Valid {
			p.UserID = &pUserID.Int64
		}
		if pSenderBank.Valid {
			p.SenderBank = &pSenderBank.String
		}
		if pSenderName.Valid {
			p.SenderName = &pSenderName.String
		}
		if pNotes.Valid {
			p.Notes = &pNotes.String
		}
		if pRejectionReason.Valid {
			p.RejectionReason = &pRejectionReason.String
		}
		if pVerifiedBy.Valid {
			p.VerifiedBy = &pVerifiedBy.Int64
		}
		if pVerifiedByName.Valid {
			p.VerifiedByName = &pVerifiedByName.String
		}
		if pVerifiedAt.Valid {
			p.VerifiedAt = &pVerifiedAt.Time
		}
		if pCreatedAt.Valid {
			p.CreatedAt = pCreatedAt.Time
		}
		b.Payment = p
	}

	return &b, nil
}

func (r *PostgresBillingRepository) CreatePayment(ctx context.Context, p *entity.Payment) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Row locking: Lock bill row to serialize concurrent payment attempts on the same bill
	var currentStatus string
	checkQuery := `SELECT status FROM bills WHERE id = $1 FOR UPDATE;`
	err = tx.QueryRowContext(ctx, checkQuery, p.BillID).Scan(&currentStatus)
	if err != nil {
		return fmt.Errorf("failed to lock bill: %w", err)
	}

	if currentStatus == "paid" {
		return errors.New("Pembayaran untuk periode iuran ini sudah tercatat lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan.")
	}
	if currentStatus == "pending_verification" {
		return errors.New("Pembayaran untuk periode ini sedang menunggu verifikasi pengurus")
	}

	if p.PaymentMethod == "" {
		p.PaymentMethod = string(entity.PaymentMethodTransfer)
	}

	var proofURL sql.NullString
	if p.ProofImageURL != "" {
		proofURL = sql.NullString{String: p.ProofImageURL, Valid: true}
	}

	insertPaymentQuery := `
		INSERT INTO payments (bill_id, user_id, payment_method, sender_bank, sender_name, amount_paid, proof_image_url, notes, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, CURRENT_TIMESTAMP)
		RETURNING id, created_at;
	`
	err = tx.QueryRowContext(
		ctx,
		insertPaymentQuery,
		p.BillID,
		p.UserID,
		p.PaymentMethod,
		p.SenderBank,
		p.SenderName,
		p.AmountPaid,
		proofURL,
		p.Notes,
	).Scan(&p.ID, &p.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert payment: %w", err)
	}

	updateBillQuery := `
		UPDATE bills
		SET status = 'pending_verification', updated_at = CURRENT_TIMESTAMP
		WHERE id = $1;
	`
	_, err = tx.ExecContext(ctx, updateBillQuery, p.BillID)
	if err != nil {
		return fmt.Errorf("failed to update bill status: %w", err)
	}

	return tx.Commit()
}

func (r *PostgresBillingRepository) UpdateBillStatus(ctx context.Context, billID int64, status string) error {
	query := `UPDATE bills SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2;`
	_, err := r.db.ExecContext(ctx, query, status, billID)
	return err
}

func (r *PostgresBillingRepository) VerifyPayment(ctx context.Context, billID int64, action string, rejectionReason *string, verifiedBy int64) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Row locking: Lock bill row to ensure atomic status transition
	var currentStatus string
	checkQuery := `SELECT status FROM bills WHERE id = $1 FOR UPDATE;`
	err = tx.QueryRowContext(ctx, checkQuery, billID).Scan(&currentStatus)
	if err != nil {
		return fmt.Errorf("failed to lock bill for verification: %w", err)
	}

	if currentStatus == "paid" {
		return errors.New("Pembayaran untuk periode iuran ini sudah tercatat lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan.")
	}
	if currentStatus != "pending_verification" {
		return fmt.Errorf("tagihan tidak dalam antrean verifikasi (status saat ini: %s)", currentStatus)
	}

	now := time.Now()
	newStatus := "paid"
	if action == "reject" {
		newStatus = "rejected"
	}

	updateBillQuery := `
		UPDATE bills
		SET status = $1, updated_at = CURRENT_TIMESTAMP
		WHERE id = $2;
	`
	_, err = tx.ExecContext(ctx, updateBillQuery, newStatus, billID)
	if err != nil {
		return fmt.Errorf("failed to update bill status on verify: %w", err)
	}

	if action == "reject" {
		updatePaymentQuery := `
			UPDATE payments
			SET verified_by = $1, verified_at = $2, rejection_reason = $3
			WHERE id = (SELECT id FROM payments WHERE bill_id = $4 ORDER BY id DESC LIMIT 1);
		`
		_, err = tx.ExecContext(ctx, updatePaymentQuery, verifiedBy, now, rejectionReason, billID)
		if err != nil {
			return fmt.Errorf("failed to update payment verification details: %w", err)
		}
	} else {
		updatePaymentQuery := `
			UPDATE payments
			SET verified_by = $1, verified_at = $2, rejection_reason = NULL
			WHERE id = (SELECT id FROM payments WHERE bill_id = $3 ORDER BY id DESC LIMIT 1);
		`
		_, err = tx.ExecContext(ctx, updatePaymentQuery, verifiedBy, now, billID)
		if err != nil {
			return fmt.Errorf("failed to update payment verification details: %w", err)
		}

		// Sprint 3: Automasi Sinkronisasi Iuran ke Buku Kas (HANYA saat APPROVE)
		insertCashQuery := `
			INSERT INTO cash_transactions (type, category, amount, transaction_date, description, bill_id, created_by, created_at)
			SELECT 
				'income', 
				'iuran', 
				b.amount, 
				CURRENT_DATE, 
				CASE 
					WHEN COALESCE(p.payment_method, 'TRANSFER') = 'CASH' 
					THEN 'Iuran IPL (Tunai) Blok ' || h.block || ' No. ' || h.house_number || ' (' || b.billing_period || ')'
					ELSE 'Iuran IPL Blok ' || h.block || ' No. ' || h.house_number || ' (' || b.billing_period || ')'
				END,
				b.id, 
				$1, 
				NOW()
			FROM bills b
			JOIN houses h ON b.house_id = h.id
			LEFT JOIN LATERAL (
				SELECT payment_method FROM payments WHERE payments.bill_id = b.id ORDER BY id DESC LIMIT 1
			) p ON true
			WHERE b.id = $2
			  AND NOT EXISTS (SELECT 1 FROM cash_transactions ct WHERE ct.bill_id = b.id);
		`
		_, err = tx.ExecContext(ctx, insertCashQuery, verifiedBy, billID)
		if err != nil {
			return fmt.Errorf("failed to record cashbook transaction on approve: %w", err)
		}
	}

	return tx.Commit()
}

func (r *PostgresBillingRepository) GetPendingPayments(ctx context.Context) ([]entity.PendingPaymentItem, error) {
	query := `
		SELECT 
			b.id AS bill_id,
			p.id AS payment_id,
			h.id AS house_id,
			h.block,
			h.house_number,
			COALESCE(CASE WHEN u.salutation IS NOT NULL AND u.salutation != '' THEN u.salutation || ' ' || u.name ELSE u.name END, 'Penghuni') AS resident_name,
			COALESCE(u.phone, '') AS resident_phone,
			b.billing_period,
			b.amount AS bill_amount,
			p.amount_paid,
			COALESCE(p.payment_method, 'TRANSFER') AS payment_method,
			COALESCE(p.sender_bank, '') AS sender_bank,
			COALESCE(p.sender_name, '') AS sender_name,
			COALESCE(p.proof_image_url, '') AS proof_image_url,
			COALESCE(p.notes, '') AS notes,
			p.created_at
		FROM bills b
		JOIN houses h ON h.id = b.house_id
		JOIN LATERAL (
			SELECT id, user_id, amount_paid, payment_method, sender_bank, sender_name, proof_image_url, notes, created_at
			FROM payments
			WHERE payments.bill_id = b.id
			ORDER BY id DESC
			LIMIT 1
		) p ON true
		LEFT JOIN users u ON u.id = p.user_id
		WHERE b.status = 'pending_verification'
		ORDER BY p.created_at ASC;
	`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query pending payments: %w", err)
	}
	defer rows.Close()

	var list []entity.PendingPaymentItem
	for rows.Next() {
		var item entity.PendingPaymentItem
		err := rows.Scan(
			&item.BillID,
			&item.PaymentID,
			&item.HouseID,
			&item.HouseBlock,
			&item.HouseNumber,
			&item.ResidentName,
			&item.ResidentPhone,
			&item.BillingPeriod,
			&item.BillAmount,
			&item.AmountPaid,
			&item.PaymentMethod,
			&item.SenderBank,
			&item.SenderName,
			&item.ProofImageURL,
			&item.Notes,
			&item.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan pending payment item: %w", err)
		}
		list = append(list, item)
	}

	return list, nil
}

func (r *PostgresBillingRepository) GetBillingSummary(ctx context.Context, period string, block string) (*entity.BillingSummaryResponse, error) {
	// Base query for houses
	baseQuery := `
		SELECT 
			h.id, h.block, h.house_number,
			COALESCE(CASE WHEN head.salutation IS NOT NULL AND head.salutation != '' THEN head.salutation || ' ' || head.name ELSE head.name END, 'Belum Terdaftar') AS resident_name,
			COALESCE(head.phone, '-') AS resident_phone,
			COALESCE(b.status, 'unpaid') AS bill_status,
			b.id AS bill_id,
			COALESCE(b.amount, (SELECT COALESCE(monthly_fee, 0) FROM payment_settings ORDER BY id ASC LIMIT 1), 0) AS bill_amount,
			p.verified_at AS paid_at,
			p.proof_image_url,
			p.payment_method
		FROM houses h
		LEFT JOIN LATERAL (
			SELECT u.salutation, u.name, u.phone
			FROM users u
			WHERE u.house_id = h.id AND u.status = 'active'
			ORDER BY u.id ASC
			LIMIT 1
		) head ON true
		LEFT JOIN bills b ON b.house_id = h.id AND b.billing_period = $1
		LEFT JOIN LATERAL (
			SELECT verified_at, proof_image_url, payment_method
			FROM payments
			WHERE payments.bill_id = b.id
			ORDER BY id DESC
			LIMIT 1
		) p ON true
		WHERE h.status IN ('milik', 'kontrak')
	`

	var rows *sql.Rows
	var err error
	if block != "" && block != "all" {
		baseQuery += " AND h.block = $2 ORDER BY h.block ASC, h.house_number ASC;"
		rows, err = r.db.QueryContext(ctx, baseQuery, period, block)
	} else {
		baseQuery += " ORDER BY h.block ASC, h.house_number ASC;"
		rows, err = r.db.QueryContext(ctx, baseQuery, period)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get billing summary: %w", err)
	}
	defer rows.Close()

	summary := &entity.BillingSummaryResponse{
		Period:            period,
		Block:             block,
		IsPeriodGenerated: false,
		TotalHouses:       0,
		PaidHouses:        0,
		UnpaidHouses:      0,
		TotalPaidHouses:   0,
		TotalUnpaidHouses: 0,
		TotalPaidAmount:   0,
		TotalUnpaidAmount: 0,
		HouseBills:        make([]entity.HouseBillStatus, 0),
		Items:             make([]entity.HouseBillStatus, 0),
	}

	for rows.Next() {
		var item entity.HouseBillStatus
		var bID sql.NullInt64
		var pPaidAt sql.NullTime
		var pProofURL sql.NullString
		var pPaymentMethod sql.NullString

		err := rows.Scan(
			&item.HouseID,
			&item.Block,
			&item.HouseNumber,
			&item.ResidentName,
			&item.ResidentPhone,
			&item.Status,
			&bID,
			&item.Amount,
			&pPaidAt,
			&pProofURL,
			&pPaymentMethod,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan house bill status: %w", err)
		}

		if bID.Valid {
			item.BillID = &bID.Int64
			summary.IsPeriodGenerated = true
		} else {
			item.Status = "no_bill"
		}
		if pPaidAt.Valid {
			item.PaidAt = &pPaidAt.Time
		}
		if pProofURL.Valid {
			item.ProofImageURL = &pProofURL.String
		}
		if pPaymentMethod.Valid {
			item.PaymentMethod = &pPaymentMethod.String
		}

		summary.TotalHouses++
		if item.Status == "paid" {
			summary.PaidHouses++
			summary.TotalPaidAmount += item.Amount
		} else {
			summary.UnpaidHouses++
			summary.TotalUnpaidAmount += item.Amount
		}

		summary.HouseBills = append(summary.HouseBills, item)
	}

	summary.Items = summary.HouseBills
	summary.TotalPaidHouses = summary.PaidHouses
	summary.TotalUnpaidHouses = summary.UnpaidHouses

	return summary, nil
}

func (r *PostgresBillingRepository) RecordDirectCashPayment(
	ctx context.Context,
	billID int64,
	adminID int64,
	residentUserID *int64,
	amount float64,
	paymentDate time.Time,
	notes *string,
) (*entity.Payment, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	// 1. Lock bill row FOR UPDATE to strictly serialize concurrent operations
	var currentStatus string
	var billAmount float64
	var billingPeriod string
	var houseBlock, houseNumber string

	checkQuery := `
		SELECT b.status, b.amount, b.billing_period, h.block, h.house_number
		FROM bills b
		JOIN houses h ON b.house_id = h.id
		WHERE b.id = $1
		FOR UPDATE OF b;
	`
	err = tx.QueryRowContext(ctx, checkQuery, billID).Scan(&currentStatus, &billAmount, &billingPeriod, &houseBlock, &houseNumber)
	if err == sql.ErrNoRows {
		return nil, errors.New("tagihan tidak ditemukan")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to lock bill: %w", err)
	}

	// 2. Authoritative check
	if currentStatus == "paid" {
		return nil, errors.New("Pembayaran untuk periode iuran ini sudah tercatat lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan.")
	}
	if currentStatus == "pending_verification" {
		return nil, errors.New("Pembayaran untuk periode iuran ini sedang dalam antrean verifikasi. Selesaikan verifikasi terlebih dahulu sebelum mencatat pembayaran tunai.")
	}
	if amount <= 0 {
		amount = billAmount
	}
	if amount != billAmount {
		return nil, fmt.Errorf("nominal pembayaran tidak sesuai dengan tagihan (Rp %.0f)", billAmount)
	}

	if paymentDate.IsZero() {
		paymentDate = time.Now()
	}

	// 3. Insert payment record (immediately approved, payment_method = CASH)
	insertPaymentQuery := `
		INSERT INTO payments (bill_id, user_id, payment_method, amount_paid, notes, verified_by, verified_at, created_at)
		VALUES ($1, $2, 'CASH', $3, $4, $5, $6, $6)
		RETURNING id, created_at;
	`
	var p entity.Payment
	p.BillID = billID
	p.UserID = residentUserID
	p.PaymentMethod = string(entity.PaymentMethodCash)
	p.AmountPaid = amount
	p.Notes = notes
	p.VerifiedBy = &adminID
	p.VerifiedAt = &paymentDate

	err = tx.QueryRowContext(
		ctx,
		insertPaymentQuery,
		billID,
		residentUserID,
		amount,
		notes,
		adminID,
		paymentDate,
	).Scan(&p.ID, &p.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to record cash payment: %w", err)
	}

	// 4. Update bill status to paid
	updateBillQuery := `
		UPDATE bills
		SET status = 'paid', updated_at = CURRENT_TIMESTAMP
		WHERE id = $1;
	`
	_, err = tx.ExecContext(ctx, updateBillQuery, billID)
	if err != nil {
		return nil, fmt.Errorf("failed to update bill status: %w", err)
	}

	// 5. Record cash ledger entry (income, atomic, idempotent)
	cashDesc := fmt.Sprintf("Iuran IPL (Tunai) Blok %s No. %s (%s)", houseBlock, houseNumber, billingPeriod)
	insertCashQuery := `
		INSERT INTO cash_transactions (type, category, amount, transaction_date, description, bill_id, created_by, created_at)
		SELECT 'income', 'iuran', $1, $2::date, $3, $4, $5, CURRENT_TIMESTAMP
		WHERE NOT EXISTS (SELECT 1 FROM cash_transactions WHERE bill_id = $4);
	`
	_, err = tx.ExecContext(ctx, insertCashQuery, amount, paymentDate.Format("2006-01-02"), cashDesc, billID, adminID)
	if err != nil {
		return nil, fmt.Errorf("failed to record cashbook transaction: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed to commit cash payment transaction: %w", err)
	}

	return &p, nil
}

func (r *PostgresBillingRepository) GetEligiblePeriodsByHouseID(ctx context.Context, houseID int64) ([]entity.EligibleDuesPeriod, error) {
	// Query ONLY bills that were officially generated by admin/pengurus for this house
	query := `
		SELECT id, house_id, billing_period, amount, status
		FROM bills
		WHERE house_id = $1
		ORDER BY billing_period ASC;
	`
	rows, err := r.db.QueryContext(ctx, query, houseID)
	if err != nil {
		return nil, fmt.Errorf("failed to get periods for house %d: %w", houseID, err)
	}
	defer rows.Close()

	var list []entity.EligibleDuesPeriod
	for rows.Next() {
		var item entity.EligibleDuesPeriod
		if err := rows.Scan(&item.BillID, &item.HouseID, &item.BillingPeriod, &item.Amount, &item.Status); err != nil {
			return nil, fmt.Errorf("failed to scan period: %w", err)
		}
		item.IsEligible = (item.Status == "unpaid" || item.Status == "rejected")
		list = append(list, item)
	}
	if list == nil {
		list = []entity.EligibleDuesPeriod{}
	}
	return list, nil
}

func (r *PostgresBillingRepository) GetEligibleResidentsForBilling(ctx context.Context) ([]entity.ResidentBillingOption, error) {
	query := `
		SELECT 
			u.id, 
			COALESCE(CASE WHEN u.salutation IS NOT NULL AND u.salutation != '' THEN u.salutation || ' ' || u.name ELSE u.name END, u.name) as name,
			COALESCE(u.phone, '') as phone,
			h.id as house_id,
			h.block,
			h.house_number,
			COALESCE(u.ownership_status, '') as ownership_status
		FROM users u
		JOIN houses h ON u.house_id = h.id
		WHERE u.status = 'active'
		ORDER BY h.block ASC, h.house_number ASC, u.name ASC;
	`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to get residents for billing: %w", err)
	}
	defer rows.Close()

	var list []entity.ResidentBillingOption
	for rows.Next() {
		var rbo entity.ResidentBillingOption
		if err := rows.Scan(&rbo.UserID, &rbo.Name, &rbo.Phone, &rbo.HouseID, &rbo.HouseBlock, &rbo.HouseNumber, &rbo.OwnershipStatus); err != nil {
			return nil, fmt.Errorf("failed to scan resident billing option: %w", err)
		}
		rbo.ResidentID = rbo.UserID
		rbo.ResidentName = rbo.Name
		rbo.ResidentPhone = rbo.Phone
		list = append(list, rbo)
	}
	if list == nil {
		list = []entity.ResidentBillingOption{}
	}
	return list, nil
}
