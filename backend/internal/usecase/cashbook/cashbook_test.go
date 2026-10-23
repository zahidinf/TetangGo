package cashbook_test

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"testing"
	"time"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
	"tetanggo-backend/internal/usecase/cashbook"
)

type mockCashbookRepo struct {
	transactions []entity.CashTransaction
	summary      *entity.CashbookSummary
}

func (m *mockCashbookRepo) GetSummary(ctx context.Context) (*entity.CashbookSummary, error) {
	return m.summary, nil
}

func (m *mockCashbookRepo) GetTransactions(ctx context.Context, filter entity.CashTransactionsFilter) (*entity.CashTransactionsResult, error) {
	var startDate, endDate, periodStr string
	if filter.Period != "" {
		parts := strings.Split(filter.Period, "-")
		if len(parts) == 2 {
			y, _ := strconv.Atoi(parts[0])
			mon, _ := strconv.Atoi(parts[1])
			if y > 0 && mon >= 1 && mon <= 12 {
				fDay := time.Date(y, time.Month(mon), 1, 0, 0, 0, 0, time.Local)
				lDay := fDay.AddDate(0, 1, -1)
				startDate = fDay.Format("2006-01-02")
				endDate = lDay.Format("2006-01-02")
				periodStr = fDay.Format("2006-01")
			}
		}
	}
	if startDate == "" && filter.Year > 0 && filter.Month >= 1 && filter.Month <= 12 {
		fDay := time.Date(filter.Year, time.Month(filter.Month), 1, 0, 0, 0, 0, time.Local)
		lDay := fDay.AddDate(0, 1, -1)
		startDate = fDay.Format("2006-01-02")
		endDate = lDay.Format("2006-01-02")
		periodStr = fDay.Format("2006-01")
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
		fDay := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.Local)
		lDay := fDay.AddDate(0, 1, -1)
		startDate = fDay.Format("2006-01-02")
		endDate = lDay.Format("2006-01-02")
		periodStr = fDay.Format("2006-01")
	}

	var previousBalance float64
	var periodIncome, periodExpense float64
	filtered := make([]entity.CashTransaction, 0)

	for _, tx := range m.transactions {
		if tx.TransactionDate < startDate {
			if tx.Type == "income" {
				previousBalance += tx.Amount
			} else {
				previousBalance -= tx.Amount
			}
		} else if tx.TransactionDate >= startDate && tx.TransactionDate <= endDate {
			if tx.Type == "income" {
				periodIncome += tx.Amount
			} else {
				periodExpense += tx.Amount
			}

			// apply type and category filters for returned records
			if (filter.Type == "" || filter.Type == "all" || filter.Type == tx.Type) &&
				(filter.Category == "" || filter.Category == "all" || filter.Category == tx.Category) {
				filtered = append(filtered, tx)
			}
		}
	}

	endingBalance := previousBalance + periodIncome - periodExpense

	return &entity.CashTransactionsResult{
		Transactions:    filtered,
		Total:           len(filtered),
		Page:            1,
		Limit:           20,
		Period:          periodStr,
		StartDate:       startDate,
		EndDate:         endDate,
		PreviousBalance: previousBalance,
		PeriodIncome:    periodIncome,
		PeriodExpense:   periodExpense,
		EndingBalance:   endingBalance,
	}, nil
}

func (m *mockCashbookRepo) GetTransactionByID(ctx context.Context, id int64) (*entity.CashTransaction, error) {
	for _, tx := range m.transactions {
		if tx.ID == id {
			return &tx, nil
		}
	}
	return nil, fmt.Errorf("transaksi tidak ditemukan")
}

func (m *mockCashbookRepo) CreateTransaction(ctx context.Context, tx *entity.CashTransaction) error {
	tx.ID = int64(len(m.transactions) + 1)
	m.transactions = append(m.transactions, *tx)
	return nil
}

func (m *mockCashbookRepo) DeleteManualTransaction(ctx context.Context, id int64) error {
	newTxs := make([]entity.CashTransaction, 0)
	for _, tx := range m.transactions {
		if tx.ID != id {
			newTxs = append(newTxs, tx)
		}
	}
	m.transactions = newTxs
	return nil
}

var _ repository.CashbookRepository = (*mockCashbookRepo)(nil)

func TestCashbookFilterAndBalances(t *testing.T) {
	ctx := context.Background()

	// Sample transactions across August, September, October 2026
	repo := &mockCashbookRepo{
		transactions: []entity.CashTransaction{
			{ID: 1, Type: "income", Amount: 1000000, TransactionDate: "2026-08-15", Description: "Kas Awal"},
			{ID: 2, Type: "expense", Amount: 200000, TransactionDate: "2026-08-20", Description: "Beli Sapu"},
			// Ending Aug: 800,000

			{ID: 3, Type: "income", Amount: 500000, TransactionDate: "2026-09-01", Description: "Iuran Sep Day 1"},
			{ID: 4, Type: "expense", Amount: 100000, TransactionDate: "2026-09-30", Description: "Konsumsi Rapat Akhir Bulan"},
			// Sep: Inc 500k, Exp 100k -> Net +400k. Ending Sep: 1,200,000

			{ID: 5, Type: "income", Amount: 300000, TransactionDate: "2026-10-01", Description: "Iuran Okt Awal"},
			{ID: 6, Type: "expense", Amount: 150000, TransactionDate: "2026-10-15", Description: "Lampu Taman"},
			{ID: 7, Type: "income", Amount: 200000, TransactionDate: "2026-10-31", Description: "Iuran Okt Akhir"},
			// Oct: Inc 500k, Exp 150k -> Net +350k. Ending Oct: 1,550,000
		},
	}

	uc := cashbook.NewCashbookUseCase(repo)

	t.Run("Filter September 2026: Saldo sebelumnya dan batas tanggal akurat", func(t *testing.T) {
		res, err := uc.GetTransactions(ctx, entity.CashTransactionsFilter{
			Period: "2026-09",
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		if res.StartDate != "2026-09-01" || res.EndDate != "2026-09-30" {
			t.Fatalf("expected date boundary 2026-09-01 s/d 2026-09-30, got %s s/d %s", res.StartDate, res.EndDate)
		}
		if res.PreviousBalance != 800000 {
			t.Fatalf("expected PreviousBalance 800000, got: %f", res.PreviousBalance)
		}
		if res.PeriodIncome != 500000 {
			t.Fatalf("expected PeriodIncome 500000, got: %f", res.PeriodIncome)
		}
		if res.PeriodExpense != 100000 {
			t.Fatalf("expected PeriodExpense 100000, got: %f", res.PeriodExpense)
		}
		if res.EndingBalance != 1200000 {
			t.Fatalf("expected EndingBalance 1200000, got: %f", res.EndingBalance)
		}
		if len(res.Transactions) != 2 {
			t.Fatalf("expected 2 transactions in Sept, got %d", len(res.Transactions))
		}
	})

	t.Run("Filter Oktober 2026: Menghitung saldo akumulasi sebelumnya dengan tepat", func(t *testing.T) {
		res, err := uc.GetTransactions(ctx, entity.CashTransactionsFilter{
			Year:  2026,
			Month: 10,
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		if res.StartDate != "2026-10-01" || res.EndDate != "2026-10-31" {
			t.Fatalf("expected date boundary 2026-10-01 s/d 2026-10-31, got %s s/d %s", res.StartDate, res.EndDate)
		}
		if res.PreviousBalance != 1200000 {
			t.Fatalf("expected PreviousBalance 1200000, got: %f", res.PreviousBalance)
		}
		if res.PeriodIncome != 500000 {
			t.Fatalf("expected PeriodIncome 500000, got: %f", res.PeriodIncome)
		}
		if res.PeriodExpense != 150000 {
			t.Fatalf("expected PeriodExpense 150000, got: %f", res.PeriodExpense)
		}
		if res.EndingBalance != 1550000 {
			t.Fatalf("expected EndingBalance 1550000, got: %f", res.EndingBalance)
		}
		if len(res.Transactions) != 3 {
			t.Fatalf("expected 3 transactions in Oct, got %d", len(res.Transactions))
		}
	})

	t.Run("Periode tanpa transaksi: Saldo sebelumnya tetap otoritatif dan saldo akhir konsisten", func(t *testing.T) {
		res, err := uc.GetTransactions(ctx, entity.CashTransactionsFilter{
			Period: "2026-11",
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		if res.PreviousBalance != 1550000 {
			t.Fatalf("expected PreviousBalance 1550000, got: %f", res.PreviousBalance)
		}
		if res.PeriodIncome != 0 || res.PeriodExpense != 0 {
			t.Fatalf("expected 0 period flow, got inc: %f, exp: %f", res.PeriodIncome, res.PeriodExpense)
		}
		if res.EndingBalance != 1550000 {
			t.Fatalf("expected EndingBalance 1550000, got: %f", res.EndingBalance)
		}
		if len(res.Transactions) != 0 {
			t.Fatalf("expected 0 transactions, got %d", len(res.Transactions))
		}
	})

	t.Run("Periode paling awal tanpa riwayat sebelumnya: Saldo sebelumnya 0", func(t *testing.T) {
		res, err := uc.GetTransactions(ctx, entity.CashTransactionsFilter{
			Period: "2026-07",
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		if res.PreviousBalance != 0 {
			t.Fatalf("expected PreviousBalance 0, got: %f", res.PreviousBalance)
		}
		if res.EndingBalance != 0 {
			t.Fatalf("expected EndingBalance 0, got: %f", res.EndingBalance)
		}
	})
}
