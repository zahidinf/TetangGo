package cashbook

import (
	"context"
	"fmt"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type CashbookUseCase struct {
	cashbookRepo repository.CashbookRepository
}

func NewCashbookUseCase(cashbookRepo repository.CashbookRepository) *CashbookUseCase {
	return &CashbookUseCase{
		cashbookRepo: cashbookRepo,
	}
}

func (uc *CashbookUseCase) GetSummary(ctx context.Context) (*entity.CashbookSummary, error) {
	return uc.cashbookRepo.GetSummary(ctx)
}

func (uc *CashbookUseCase) GetTransactions(ctx context.Context, filter entity.CashTransactionsFilter) ([]entity.CashTransaction, int, error) {
	return uc.cashbookRepo.GetTransactions(ctx, filter)
}

func (uc *CashbookUseCase) CreateManualTransaction(ctx context.Context, tx *entity.CashTransaction) error {
	if tx.Type != "income" && tx.Type != "expense" {
		return fmt.Errorf("tipe transaksi harus 'income' atau 'expense'")
	}
	if tx.Amount <= 0 {
		return fmt.Errorf("nominal transaksi harus lebih besar dari 0")
	}
	if tx.Description == "" {
		return fmt.Errorf("keterangan transaksi wajib diisi")
	}
	if tx.Category == "" {
		return fmt.Errorf("kategori transaksi wajib diisi")
	}
	if tx.TransactionDate == "" {
		return fmt.Errorf("tanggal transaksi wajib diisi")
	}

	return uc.cashbookRepo.CreateTransaction(ctx, tx)
}

func (uc *CashbookUseCase) DeleteManualTransaction(ctx context.Context, id int64) error {
	return uc.cashbookRepo.DeleteManualTransaction(ctx, id)
}
