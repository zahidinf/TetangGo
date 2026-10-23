package billing

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strings"
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

	// Authoritative check on existing payment amounts for this period
	amounts, err := uc.billingRepo.GetDistinctPaymentAmountsByPeriod(ctx, period)
	if err != nil {
		return 0, fmt.Errorf("gagal mengecek status pembayaran periode: %w", err)
	}

	var targetNominal float64
	if len(amounts) > 1 {
		formattedList := make([]string, len(amounts))
		for i, a := range amounts {
			formattedList[i] = fmt.Sprintf("Rp %.0f", a)
		}
		return 0, fmt.Errorf("Terdapat beberapa pembayaran dengan nominal berbeda (%s) pada periode %s. Penerbitan tagihan baru diblokir untuk mencegah ketidakkonsistenan data. Harap periksa data terlebih dahulu.", strings.Join(formattedList, ", "), period)
	} else if len(amounts) == 1 {
		targetNominal = amounts[0]
	} else {
		settings, err := uc.billingRepo.GetPaymentSettings(ctx)
		if err != nil {
			return 0, fmt.Errorf("gagal mendapatkan konfigurasi tarif iuran: %w", err)
		}
		targetNominal = settings.MonthlyFee
	}

	return uc.billingRepo.GenerateMonthlyBills(ctx, period, targetNominal)
}

func (uc *BillingUseCase) GenerateIndividualBill(ctx context.Context, houseID int64, period string) (*entity.Bill, error) {
	if houseID <= 0 {
		return nil, errors.New("unit rumah tidak valid")
	}
	if period == "" {
		period = time.Now().Format("2006-01")
	}
	if !periodRegex.MatchString(period) {
		return nil, errors.New("format periode tidak valid, gunakan format YYYY-MM (contoh: 2026-10)")
	}

	existingBill, err := uc.billingRepo.GetBillByHouseAndPeriod(ctx, houseID, period)
	if err != nil {
		return nil, fmt.Errorf("gagal memeriksa tagihan yang sudah ada: %w", err)
	}
	if existingBill != nil {
		return nil, fmt.Errorf("Unit rumah ini sudah memiliki tagihan untuk periode %s (Status: %s). Penerbitan tagihan individual ditolak untuk mencegah duplikasi.", period, existingBill.Status)
	}

	// Authoritative check on existing payment amounts for this period
	amounts, err := uc.billingRepo.GetDistinctPaymentAmountsByPeriod(ctx, period)
	if err != nil {
		return nil, fmt.Errorf("gagal mengecek status pembayaran periode: %w", err)
	}

	var targetNominal float64
	if len(amounts) > 1 {
		formattedList := make([]string, len(amounts))
		for i, a := range amounts {
			formattedList[i] = fmt.Sprintf("Rp %.0f", a)
		}
		return nil, fmt.Errorf("Terdapat beberapa pembayaran dengan nominal berbeda (%s) pada periode %s. Penerbitan tagihan individual diblokir untuk mencegah ketidakkonsistenan data. Harap periksa data terlebih dahulu.", strings.Join(formattedList, ", "), period)
	} else if len(amounts) == 1 {
		targetNominal = amounts[0]
	} else {
		settings, err := uc.billingRepo.GetPaymentSettings(ctx)
		if err != nil {
			return nil, fmt.Errorf("gagal mendapatkan konfigurasi tarif iuran: %w", err)
		}
		targetNominal = settings.MonthlyFee
	}

	return uc.billingRepo.GenerateIndividualBill(ctx, houseID, period, targetNominal)
}

func (uc *BillingUseCase) GetResidentBills(ctx context.Context, userID int64, period string) ([]entity.Bill, error) {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, errors.New("user tidak ditemukan")
	}
	if user.HouseID == nil {
		return nil, errors.New("akses ditolak: akun belum terdaftar pada hunian manapun")
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
		return nil, errors.New("akses ditolak: akun belum terdaftar pada hunian manapun")
	}

	// Rule 1: Warga hanya dapat memilih/membayar periode iuran yang tagihannya sudah diterbitkan oleh admin/pengurus.
	// Periode yang belum diterbitkan tidak boleh tersedia sebagai pilihan pembayaran.
	totalBills, err := uc.billingRepo.CountTotalBillsByPeriod(ctx, period)
	if err != nil {
		return nil, fmt.Errorf("gagal memeriksa ketersediaan tagihan periode: %w", err)
	}
	if totalBills == 0 {
		return nil, fmt.Errorf("Tagihan untuk periode %s belum diterbitkan oleh pengurus. Pembayaran hanya dapat dilakukan untuk periode yang tagihannya sudah diterbitkan.", period)
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

func (uc *BillingUseCase) ValidateDuesPeriodEligibility(bill *entity.Bill) error {
	if bill == nil {
		return errors.New("tagihan tidak ditemukan")
	}
	if bill.Status == string(entity.BillStatusPaid) {
		return errors.New("Pembayaran untuk periode iuran ini sudah tercatat lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan.")
	}
	if bill.Status == string(entity.BillStatusPendingVerification) {
		return errors.New("Pembayaran untuk periode ini sedang menunggu verifikasi pengurus")
	}
	return nil
}

func (uc *BillingUseCase) SubmitPayment(
	ctx context.Context,
	billID int64,
	userID int64,
	paymentMethod string,
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

	if err := uc.ValidateDuesPeriodEligibility(bill); err != nil {
		return err
	}

	// Verify user is resident of this house
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return errors.New("user tidak ditemukan")
	}
	if user.HouseID == nil || *user.HouseID != bill.HouseID {
		return errors.New("akses ditolak: Anda bukan penghuni rumah dari tagihan ini")
	}

	if paymentMethod == "" {
		paymentMethod = string(entity.PaymentMethodTransfer)
	}
	if paymentMethod != string(entity.PaymentMethodTransfer) && paymentMethod != string(entity.PaymentMethodCash) {
		return errors.New("metode pembayaran tidak valid, gunakan 'TRANSFER' atau 'CASH'")
	}

	if paymentMethod == string(entity.PaymentMethodTransfer) {
		if proofImageURL == "" {
			return errors.New("bukti transfer wajib diunggah")
		}
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
		PaymentMethod: paymentMethod,
		AmountPaid:    amountPaid,
		ProofImageURL: proofImageURL,
	}
	if senderBank != "" {
		payment.SenderBank = &senderBank
	}
	if senderName != "" {
		payment.SenderName = &senderName
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
		return errors.New("Pembayaran untuk periode iuran ini sudah tercatat lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan.")
	}
	if bill.Status != string(entity.BillStatusPendingVerification) {
		return fmt.Errorf("tagihan tidak dalam antrean verifikasi (status saat ini: %s)", bill.Status)
	}

	return uc.billingRepo.VerifyPayment(ctx, billID, action, rejectionReason, verifiedBy)
}

type DirectCashPaymentInput struct {
	ResidentID  int64     `json:"resident_id"`
	BillID      int64     `json:"bill_id"`
	Amount      float64   `json:"amount"`
	PaymentDate time.Time `json:"payment_date"`
	Notes       *string   `json:"notes,omitempty"`
}

func (uc *BillingUseCase) RecordDirectCashPayment(
	ctx context.Context,
	adminID int64,
	input DirectCashPaymentInput,
) (*entity.Payment, error) {
	if input.ResidentID <= 0 {
		return nil, errors.New("warga wajib dipilih")
	}
	if input.BillID <= 0 {
		return nil, errors.New("periode iuran wajib dipilih")
	}

	// 1. Authoritative check on resident
	resident, err := uc.userRepo.GetByID(ctx, input.ResidentID)
	if err != nil || resident == nil {
		return nil, errors.New("data warga tidak ditemukan")
	}
	if resident.HouseID == nil {
		return nil, errors.New("warga yang dipilih belum terdaftar pada hunian manapun")
	}

	// 2. Authoritative check on bill
	bill, err := uc.billingRepo.GetBillByID(ctx, input.BillID)
	if err != nil || bill == nil {
		return nil, errors.New("tagihan iuran tidak ditemukan")
	}
	if bill.HouseID != *resident.HouseID {
		return nil, errors.New("tagihan iuran tidak cocok dengan unit hunian warga yang dipilih")
	}

	// 3. Centralized check on bill status
	if bill.Status == string(entity.BillStatusPaid) {
		return nil, errors.New("Pembayaran untuk periode iuran ini sudah tercatat lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan.")
	}
	if bill.Status == string(entity.BillStatusPendingVerification) {
		return nil, errors.New("Pembayaran untuk periode iuran ini sedang dalam antrean verifikasi. Selesaikan verifikasi terlebih dahulu sebelum mencatat pembayaran tunai.")
	}

	// 4. Amount validation
	if input.Amount <= 0 {
		input.Amount = bill.Amount
	}
	if input.Amount != bill.Amount {
		return nil, fmt.Errorf("nominal pembayaran tidak valid. Nominal wajib sama persis dengan nominal tagihan (Rp %.0f)", bill.Amount)
	}

	if input.PaymentDate.IsZero() {
		input.PaymentDate = time.Now()
	}

	return uc.billingRepo.RecordDirectCashPayment(
		ctx,
		input.BillID,
		adminID,
		&resident.ID,
		input.Amount,
		input.PaymentDate,
		input.Notes,
	)
}

func (uc *BillingUseCase) GetResidentEligiblePeriods(ctx context.Context, residentID int64) ([]entity.EligibleDuesPeriod, error) {
	resident, err := uc.userRepo.GetByID(ctx, residentID)
	if err != nil || resident == nil {
		return nil, errors.New("data warga tidak ditemukan")
	}
	if resident.HouseID == nil {
		return nil, errors.New("warga yang dipilih belum terdaftar pada hunian manapun")
	}
	return uc.billingRepo.GetEligiblePeriodsByHouseID(ctx, *resident.HouseID)
}

func (uc *BillingUseCase) GetEligibleResidentsForBilling(ctx context.Context) ([]entity.ResidentBillingOption, error) {
	return uc.billingRepo.GetEligibleResidentsForBilling(ctx)
}

func (uc *BillingUseCase) GetBillingSummary(ctx context.Context, period string, block string) (*entity.BillingSummaryResponse, error) {
	if period == "" {
		period = time.Now().Format("2006-01")
	}
	if !periodRegex.MatchString(period) {
		return nil, errors.New("format periode tidak valid, gunakan format YYYY-MM (contoh: 2026-10)")
	}
	return uc.billingRepo.GetBillingSummary(ctx, period, block)
}

type BulkProcessPaymentsInput struct {
	Period        string   `json:"period"`
	PaymentMethod string   `json:"payment_method"` // 'TRANSFER' or 'CASH'
	BillIDs       []int64  `json:"bill_ids"`
	Notes         *string  `json:"notes,omitempty"`
}

func (uc *BillingUseCase) BulkProcessPayments(
	ctx context.Context,
	treasurerID int64,
	input BulkProcessPaymentsInput,
) (*entity.BulkProcessPaymentResult, error) {
	period := strings.TrimSpace(input.Period)
	if period == "" {
		return nil, errors.New("periode iuran wajib diisi")
	}
	if !periodRegex.MatchString(period) {
		return nil, errors.New("format periode tidak valid, gunakan format YYYY-MM (contoh: 2026-10)")
	}

	method := strings.ToUpper(strings.TrimSpace(input.PaymentMethod))
	if method != string(entity.PaymentMethodCash) && method != string(entity.PaymentMethodTransfer) {
		return nil, errors.New("metode pembayaran tidak valid, gunakan 'TRANSFER' atau 'CASH'")
	}

	// Rule 4 & 3: Pastikan tagihan untuk periode yang dipilih sudah diterbitkan sebelum bulk process dijalankan
	totalBills, err := uc.billingRepo.CountTotalBillsByPeriod(ctx, period)
	if err != nil {
		return nil, fmt.Errorf("gagal memeriksa tagihan periode: %w", err)
	}
	if totalBills == 0 {
		return nil, fmt.Errorf("Tagihan untuk periode %s belum diterbitkan. Bulk process pembayaran tidak dapat dijalankan.", period)
	}

	if len(input.BillIDs) == 0 {
		return nil, errors.New("pilih minimal satu warga/tagihan untuk diproses")
	}

	// Verify treasurer role / user exists
	treasurer, err := uc.userRepo.GetByID(ctx, treasurerID)
	if err != nil || treasurer == nil {
		return nil, errors.New("data bendahara/pengurus tidak ditemukan")
	}

	result := &entity.BulkProcessPaymentResult{
		Period:         period,
		PaymentMethod:  method,
		TotalProcessed: len(input.BillIDs),
		Results:        make([]entity.BulkProcessPaymentItemResult, 0, len(input.BillIDs)),
	}

	now := time.Now()

	for _, billID := range input.BillIDs {
		itemRes := entity.BulkProcessPaymentItemResult{
			BillID:  billID,
			Success: false,
		}

		bill, err := uc.billingRepo.GetBillByID(ctx, billID)
		if err != nil || bill == nil {
			itemRes.Status = "failed"
			itemRes.Message = "Tagihan tidak ditemukan"
			result.FailedCount++
			result.Results = append(result.Results, itemRes)
			continue
		}

		itemRes.HouseID = bill.HouseID
		itemRes.Amount = bill.Amount
		if bill.House != nil {
			itemRes.HouseBlock = bill.House.Block
			itemRes.HouseNumber = bill.House.HouseNumber
		}

		// Ensure bill belongs to requested period
		if bill.BillingPeriod != period {
			itemRes.Status = "failed"
			itemRes.Message = fmt.Sprintf("Tagihan berada pada periode %s, bukan periode %s", bill.BillingPeriod, period)
			result.FailedCount++
			result.Results = append(result.Results, itemRes)
			continue
		}

		// Strict eligibility validation
		if bill.Status == string(entity.BillStatusPaid) {
			itemRes.Status = "skipped"
			itemRes.Message = "Iuran sudah tercatat lunas"
			result.FailedCount++
			result.Results = append(result.Results, itemRes)
			continue
		}

		if bill.Status == string(entity.BillStatusPendingVerification) {
			itemRes.Status = "skipped"
			itemRes.Message = "Sedang menunggu verifikasi pengurus"
			result.FailedCount++
			result.Results = append(result.Results, itemRes)
			continue
		}

		if bill.Status != string(entity.BillStatusUnpaid) && bill.Status != string(entity.BillStatusRejected) {
			itemRes.Status = "failed"
			itemRes.Message = fmt.Sprintf("Status tagihan tidak valid untuk pembayaran (%s)", bill.Status)
			result.FailedCount++
			result.Results = append(result.Results, itemRes)
			continue
		}

		// Process payment based on method
		if method == string(entity.PaymentMethodCash) {
			// Direct cash: directly marks paid and inserts ledger entry atomically
			notes := "Bulk process tunai bendahara"
			if input.Notes != nil && strings.TrimSpace(*input.Notes) != "" {
				notes = *input.Notes
			}
			_, err := uc.billingRepo.RecordDirectCashPayment(
				ctx,
				bill.ID,
				treasurerID,
				nil, // No specific resident user ID required if bulk by house
				bill.Amount,
				now,
				&notes,
			)
			if err != nil {
				itemRes.Status = "failed"
				itemRes.Message = err.Error()
				result.FailedCount++
			} else {
				itemRes.Success = true
				itemRes.Status = "paid"
				itemRes.Message = "Pembayaran tunai berhasil dicatat dan lunas"
				result.SuccessCount++
			}
		} else {
			// TRANSFER: marks status as pending_verification (does NOT mark paid automatically)
			// Must go through verification flow before being marked paid or entered into cashbook!
			payment := &entity.Payment{
				BillID:        bill.ID,
				PaymentMethod: string(entity.PaymentMethodTransfer),
				AmountPaid:    bill.Amount,
				Notes:         input.Notes,
				ProofImageURL: "bulk_transfer_treasurer",
			}
			err := uc.billingRepo.CreatePayment(ctx, payment)
			if err != nil {
				itemRes.Status = "failed"
				itemRes.Message = err.Error()
				result.FailedCount++
			} else {
				itemRes.Success = true
				itemRes.Status = "pending_verification"
				itemRes.Message = "Pengajuan transfer berhasil dibuat, menunggu verifikasi pengurus"
				result.SuccessCount++
			}
		}

		result.Results = append(result.Results, itemRes)
	}

	return result, nil
}
