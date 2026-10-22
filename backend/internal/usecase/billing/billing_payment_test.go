package billing_test

import (
	"context"
	"testing"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/usecase/billing"
)

func TestDoublePaymentAndCashbookIntegrity(t *testing.T) {
	ctx := context.Background()
	houseID := int64(101)
	userID := int64(1)
	otherUserID := int64(2)

	unpaidBill := &entity.Bill{
		ID:            1,
		HouseID:       houseID,
		BillingPeriod: "2026-10",
		Amount:        35000,
		Status:        string(entity.BillStatusUnpaid),
	}

	pendingBill := &entity.Bill{
		ID:            2,
		HouseID:       houseID,
		BillingPeriod: "2026-11",
		Amount:        35000,
		Status:        string(entity.BillStatusPendingVerification),
	}

	paidBill := &entity.Bill{
		ID:            3,
		HouseID:       houseID,
		BillingPeriod: "2026-09",
		Amount:        35000,
		Status:        string(entity.BillStatusPaid),
	}

	rejectedBill := &entity.Bill{
		ID:            4,
		HouseID:       houseID,
		BillingPeriod: "2026-08",
		Amount:        35000,
		Status:        string(entity.BillStatusRejected),
	}

	mockBilling := &mockBillingRepo{
		bills: map[int64]*entity.Bill{
			1: unpaidBill,
			2: pendingBill,
			3: paidBill,
			4: rejectedBill,
		},
		payments: make(map[int64]*entity.Payment),
		settings: &entity.PaymentSetting{
			MonthlyFee: 35000,
		},
	}

	userHouseID := houseID
	mockUser := &mockUserRepoForBilling{
		users: map[int64]*entity.User{
			1: {ID: userID, HouseID: &userHouseID, RoleName: "RESIDENT"},
			2: {ID: otherUserID, HouseID: nil, RoleName: "RESIDENT"},
		},
	}

	uc := billing.NewBillingUseCase(mockBilling, mockUser, nil)

	t.Run("1. Periode belum memiliki pembayaran / unpaid: pembayaran berhasil dibuat", func(t *testing.T) {
		err := uc.SubmitPayment(ctx, unpaidBill.ID, userID, "BCA", "Warga Test", 35000, "/uploads/proof1.jpg", "")
		if err != nil {
			t.Fatalf("expected payment to succeed, got error: %v", err)
		}
	})

	t.Run("2. Periode memiliki pembayaran pending: pembayaran baru ditolak backend", func(t *testing.T) {
		err := uc.SubmitPayment(ctx, pendingBill.ID, userID, "BCA", "Warga Test", 35000, "/uploads/proof2.jpg", "")
		if err == nil {
			t.Fatalf("expected payment on pending bill to fail, but it succeeded")
		}
	})

	t.Run("3. Periode memiliki pembayaran paid/approved: pembayaran baru ditolak backend", func(t *testing.T) {
		err := uc.SubmitPayment(ctx, paidBill.ID, userID, "BCA", "Warga Test", 35000, "/uploads/proof3.jpg", "")
		if err == nil {
			t.Fatalf("expected payment on paid bill to fail, but it succeeded")
		}
	})

	t.Run("4. Periode memiliki pembayaran rejected: warga dapat mengajukan ulang", func(t *testing.T) {
		err := uc.SubmitPayment(ctx, rejectedBill.ID, userID, "BCA", "Warga Test", 35000, "/uploads/proof4.jpg", "")
		if err != nil {
			t.Fatalf("expected re-submitting payment on rejected bill to succeed, got: %v", err)
		}
	})

	t.Run("5. Warga lain tanpa akses unit hunian ditolak membayar tagihan", func(t *testing.T) {
		err := uc.SubmitPayment(ctx, unpaidBill.ID, otherUserID, "BCA", "Warga Asing", 35000, "/uploads/proof5.jpg", "")
		if err == nil {
			t.Fatalf("expected payment by user without house to be rejected")
		}
	})

	t.Run("6. Verifikasi reject pembayaran yang bukan pending ditolak", func(t *testing.T) {
		reason := "Bukti salah"
		err := uc.VerifyPayment(ctx, paidBill.ID, "reject", &reason, 1)
		if err == nil {
			t.Fatalf("expected reject on non-pending bill to fail")
		}
	})

	t.Run("7. Verifikasi approve pembayaran yang bukan pending ditolak", func(t *testing.T) {
		err := uc.VerifyPayment(ctx, paidBill.ID, "approve", nil, 1)
		if err == nil {
			t.Fatalf("expected approve on already paid bill to fail")
		}
	})
}
