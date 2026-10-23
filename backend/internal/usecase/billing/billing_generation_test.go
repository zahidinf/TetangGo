package billing_test

import (
	"context"
	"strings"
	"testing"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/usecase/billing"
)

func TestDuesGenerationEnhancement(t *testing.T) {
	ctx := context.Background()

	setupUsecase := func() (*billing.BillingUseCase, *mockBillingRepo, *mockUserRepoForBilling) {
		h1 := int64(101)
		h2 := int64(102)
		h3 := int64(103)

		mBilling := &mockBillingRepo{
			bills:    make(map[int64]*entity.Bill),
			payments: make(map[int64]*entity.Payment),
			settings: &entity.PaymentSetting{
				MonthlyFee: 50000,
			},
		}

		mUser := &mockUserRepoForBilling{
			users: map[int64]*entity.User{
				1: {ID: 1, HouseID: &h1, RoleName: "RESIDENT"},
				2: {ID: 2, HouseID: &h2, RoleName: "RESIDENT"},
				3: {ID: 3, HouseID: &h3, RoleName: "RESIDENT"},
			},
		}

		uc := billing.NewBillingUseCase(mBilling, mUser, nil)
		return uc, mBilling, mUser
	}

	t.Run("Penerbitan baru tanpa pembayaran: menggunakan nominal konfigurasi", func(t *testing.T) {
		uc, mBilling, _ := setupUsecase()
		bill, err := uc.GenerateIndividualBill(ctx, 101, "2026-10")
		if err != nil {
			t.Fatalf("expected success, got: %v", err)
		}
		if bill.Amount != 50000 {
			t.Fatalf("expected amount 50000, got: %f", bill.Amount)
		}
		if bill.Status != "unpaid" {
			t.Fatalf("expected status unpaid, got: %s", bill.Status)
		}
		if len(mBilling.bills) != 1 {
			t.Fatalf("expected 1 bill in repository, got %d", len(mBilling.bills))
		}
	})

	t.Run("Penerbitan individual: cegah duplikasi jika sudah ada tagihan", func(t *testing.T) {
		uc, mBilling, _ := setupUsecase()
		mBilling.bills[1] = &entity.Bill{
			ID:            1,
			HouseID:       101,
			BillingPeriod: "2026-10",
			Amount:        50000,
			Status:        "unpaid",
		}

		_, err := uc.GenerateIndividualBill(ctx, 101, "2026-10")
		if err == nil || !strings.Contains(err.Error(), "sudah memiliki tagihan") {
			t.Fatalf("expected duplicate bill error, got: %v", err)
		}
	})

	t.Run("Penerbitan baru saat sudah ada pembayaran: wajib menggunakan nominal pembayaran yang ada", func(t *testing.T) {
		uc, mBilling, _ := setupUsecase()
		// House 101 already paid 75000
		mBilling.bills[1] = &entity.Bill{
			ID:            1,
			HouseID:       101,
			BillingPeriod: "2026-10",
			Amount:        75000,
			Status:        "paid",
			Payment: &entity.Payment{
				ID:         1,
				BillID:     1,
				AmountPaid: 75000,
			},
		}

		// Config fee is 50000, but existing payment is 75000.
		// Generating individual bill for House 102 should adopt 75000!
		bill2, err := uc.GenerateIndividualBill(ctx, 102, "2026-10")
		if err != nil {
			t.Fatalf("expected individual generation to succeed, got: %v", err)
		}
		if bill2.Amount != 75000 {
			t.Fatalf("expected bill amount to equal existing payment nominal 75000, got: %f", bill2.Amount)
		}

		// Mass bill generation should also use 75000
		mBilling.bills[3] = &entity.Bill{
			ID:            3,
			HouseID:       103,
			BillingPeriod: "2026-10",
			Amount:        50000,
			Status:        "unpaid",
		}
		count, err := uc.GenerateMonthlyBills(ctx, "2026-10")
		if err != nil {
			t.Fatalf("expected mass bill generation to succeed, got: %v", err)
		}
		if count == 0 {
			t.Fatalf("expected updated bills count > 0")
		}
		if mBilling.bills[3].Amount != 75000 {
			t.Fatalf("expected house 103 unpaid bill to be updated to 75000, got %f", mBilling.bills[3].Amount)
		}
	})

	t.Run("Konflik nominal pembayaran: blokir penerbitan baru dan tampilkan pesan jelas", func(t *testing.T) {
		uc, mBilling, _ := setupUsecase()
		// House 101 paid 50000
		mBilling.bills[1] = &entity.Bill{
			ID:            1,
			HouseID:       101,
			BillingPeriod: "2026-10",
			Amount:        50000,
			Status:        "paid",
			Payment: &entity.Payment{
				ID:         1,
				BillID:     1,
				AmountPaid: 50000,
			},
		}
		// House 102 paid 60000 (discrepancy)
		mBilling.bills[2] = &entity.Bill{
			ID:            2,
			HouseID:       102,
			BillingPeriod: "2026-10",
			Amount:        60000,
			Status:        "paid",
			Payment: &entity.Payment{
				ID:         2,
				BillID:     2,
				AmountPaid: 60000,
			},
		}

		// Individual generation should be blocked
		_, err := uc.GenerateIndividualBill(ctx, 103, "2026-10")
		if err == nil || !strings.Contains(err.Error(), "Terdapat beberapa pembayaran dengan nominal berbeda") {
			t.Fatalf("expected discrepancy error blocking individual generation, got: %v", err)
		}

		// Mass generation should be blocked
		_, err = uc.GenerateMonthlyBills(ctx, "2026-10")
		if err == nil || !strings.Contains(err.Error(), "Terdapat beberapa pembayaran dengan nominal berbeda") {
			t.Fatalf("expected discrepancy error blocking mass generation, got: %v", err)
		}
	})
}
