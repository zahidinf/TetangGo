package billing

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"time"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type BillingUseCase struct {
	billingRepo repository.BillingRepository
	userRepo    repository.UserRepository
	houseRepo   repository.HouseRepository
}

func NewBillingUseCase(
	billingRepo repository.BillingRepository,
	userRepo repository.UserRepository,
	houseRepo repository.HouseRepository,
) *BillingUseCase {
	return &BillingUseCase{
		billingRepo: billingRepo,
		userRepo:    userRepo,
		houseRepo:   houseRepo,
	}
}

func (uc *BillingUseCase) GetPaymentSettings(ctx context.Context) (*entity.PaymentSetting, error) {
	return uc.billingRepo.GetPaymentSettings(ctx)
}

func (uc *BillingUseCase) UpdatePaymentSettings(ctx context.Context, bankName, accNum, accHolder string, monthlyFee float64) (*entity.PaymentSetting, error) {
	if bankName == "" || accNum == "" || accHolder == "" {
		return nil, errors.New("nama bank, nomor rekening, dan atas nama tidak boleh kosong")
	}
	if monthlyFee <= 0 {
		return nil, errors.New("nominal iuran bulanan harus lebih dari 0")
	}

	setting := &entity.PaymentSetting{
		BankName:      bankName,
		AccountNumber: accNum,
		AccountHolder: accHolder,
		MonthlyFee:    monthlyFee,
	}

	err := uc.billingRepo.UpdatePaymentSettings(ctx, setting)
	if err != nil {
		return nil, err
	}

	return uc.billingRepo.GetPaymentSettings(ctx)
}

var periodRegex = regexp.MustCompile(`^\d{4}-(0[1-9]|1[0-2])$`)

func (uc *BillingUseCase) GenerateMonthlyBills(ctx context.Context, period string) (int64, error) {
	if period == "" {
		period = time.Now().Format("2006-01")
	}
	if !periodRegex.MatchString(period) {
		return 0, errors.New("format periode tidak valid, gunakan format YYYY-MM (contoh: 2026-10)")
	}

	paidCount, err := uc.billingRepo.CountPaidOrPendingBillsByPeriod(ctx, period)
	if err != nil {
		return 0, fmt.Errorf("gagal mengecek status pembayaran periode: %w", err)
	}
	if paidCount > 0 {
		return 0, fmt.Errorf("Periode %s sudah terkunci karena sudah ada warga yang melakukan pembayaran. Tagihan pada periode ini tidak dapat diubah atau di-generate ulang.", period)
	}

	settings, err := uc.billingRepo.GetPaymentSettings(ctx)
	if err != nil {
		return 0, fmt.Errorf("gagal mendapatkan konfigurasi tarif iuran: %w", err)
	}

	return uc.billingRepo.GenerateMonthlyBills(ctx, period, settings.MonthlyFee)
}

func (uc *BillingUseCase) GetResidentBills(ctx context.Context, userID int64, period string) ([]entity.Bill, error) {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, errors.New("user tidak ditemukan")
	}
	if user.HouseID == nil {
		return nil, errors.New("warga belum ditautkan ke unit rumah manapun")
	}

	if period != "" {
		if !periodRegex.MatchString(period) {
			return nil, errors.New("format periode tidak valid, gunakan format YYYY-MM")
		}
		return uc.billingRepo.GetBillsByHouseIDAndPeriod(ctx, *user.HouseID, period)
	}

	return uc.billingRepo.GetBillsByHouseID(ctx, *user.HouseID)
}

func (uc *BillingUseCase) InitiateResidentBill(ctx context.Context, userID int64, period string) (*entity.Bill, error) {
	if period == "" {
		period = time.Now().Format("2006-01")
	}
	if !periodRegex.MatchString(period) {
		return nil, errors.New("format periode tidak valid, gunakan format YYYY-MM (contoh: 2026-10)")
	}

	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, errors.New("user tidak ditemukan")
	}
	if user.HouseID == nil {
		return nil, errors.New("warga belum ditautkan ke unit rumah manapun")
	}

	existingBill, err := uc.billingRepo.GetBillByHouseAndPeriod(ctx, *user.HouseID, period)
	if err == nil && existingBill != nil {
		return existingBill, nil
	}

	settings, err := uc.billingRepo.GetPaymentSettings(ctx)
	if err != nil {
		return nil, fmt.Errorf("gagal mendapatkan konfigurasi tarif iuran: %w", err)
	}

	newBill := &entity.Bill{
		HouseID:       *user.HouseID,
		BillingPeriod: period,
		Amount:        settings.MonthlyFee,
		Status:        string(entity.BillStatusUnpaid),
	}

	if err := uc.billingRepo.CreateBill(ctx, newBill); err != nil {
		return nil, fmt.Errorf("gagal membuat record tagihan baru: %w", err)
	}

	return uc.billingRepo.GetBillByID(ctx, newBill.ID)
}

func (uc *BillingUseCase) GetBillDetail(ctx context.Context, billID int64, userID int64, isAdmin bool) (*entity.Bill, error) {
	bill, err := uc.billingRepo.GetBillByID(ctx, billID)
	if err != nil {
		return nil, err
	}

	if !isAdmin {
		user, err := uc.userRepo.GetByID(ctx, userID)
		if err != nil {
			return nil, errors.New("user tidak valid")
		}
		if user.HouseID == nil || *user.HouseID != bill.HouseID {
			return nil, errors.New("akses ditolak: tagihan ini bukan untuk unit rumah Anda")
		}
	}

	return bill, nil
}

func (uc *BillingUseCase) SubmitPayment(
	ctx context.Context,
	billID int64,
	userID int64,
	senderBank string,
	senderName string,
	amountPaid float64,
	proofImageURL string,
	notes string,
) error {
	bill, err := uc.billingRepo.GetBillByID(ctx, billID)
	if err != nil {
		return errors.New("tagihan tidak ditemukan")
	}

	if bill.Status == string(entity.BillStatusPaid) {
		return errors.New("tagihan ini sudah lunas")
	}

	// Verify user is resident of this house
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return errors.New("user tidak ditemukan")
	}
	if user.HouseID == nil || *user.HouseID != bill.HouseID {
		return errors.New("akses ditolak: Anda bukan penghuni rumah dari tagihan ini")
	}

	if proofImageURL == "" {
		return errors.New("bukti transfer wajib diunggah")
	}

	if amountPaid <= 0 {
		amountPaid = bill.Amount
	}

	if amountPaid != bill.Amount {
		return fmt.Errorf("nominal pembayaran tidak valid. Nominal wajib sama persis dengan nominal tagihan (Rp %.0f)", bill.Amount)
	}

	payment := &entity.Payment{
		BillID:        billID,
		UserID:        &userID,
		SenderBank:    &senderBank,
		SenderName:    &senderName,
		AmountPaid:    amountPaid,
		ProofImageURL: proofImageURL,
	}
	if notes != "" {
		payment.Notes = &notes
	}

	return uc.billingRepo.CreatePayment(ctx, payment)
}

func (uc *BillingUseCase) GetPendingPayments(ctx context.Context) ([]entity.PendingPaymentItem, error) {
	return uc.billingRepo.GetPendingPayments(ctx)
}

func (uc *BillingUseCase) VerifyPayment(ctx context.Context, billID int64, action string, rejectionReason *string, verifiedBy int64) error {
	if action != "approve" && action != "reject" {
		return errors.New("aksi verifikasi harus 'approve' atau 'reject'")
	}

	if action == "reject" {
		if rejectionReason == nil || *rejectionReason == "" {
			return errors.New("alasan penolakan wajib disertakan")
		}
	}

	bill, err := uc.billingRepo.GetBillByID(ctx, billID)
	if err != nil {
		return errors.New("tagihan tidak ditemukan")
	}

	if bill.Status == string(entity.BillStatusPaid) && action == "approve" {
		return errors.New("tagihan sudah dalam status lunas")
	}

	return uc.billingRepo.VerifyPayment(ctx, billID, action, rejectionReason, verifiedBy)
}

func (uc *BillingUseCase) GetBillingSummary(ctx context.Context, period string, block string) (*entity.BillingSummaryResponse, error) {
	if period == "" {
		period = time.Now().Format("2006-01")
	}
	return uc.billingRepo.GetBillingSummary(ctx, period, block)
}
