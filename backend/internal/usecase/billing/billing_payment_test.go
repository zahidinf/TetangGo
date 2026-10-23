package billing_test

import (
	"context"
	"strings"
	"testing"
	"time"
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
		err := uc.SubmitPayment(ctx, unpaidBill.ID, userID, "TRANSFER", "BCA", "Warga Test", 35000, "/uploads/proof1.jpg", "")
		if err != nil {
			t.Fatalf("expected payment to succeed, got error: %v", err)
		}
	})

	t.Run("2. Periode memiliki pembayaran pending: pembayaran baru ditolak backend", func(t *testing.T) {
		err := uc.SubmitPayment(ctx, pendingBill.ID, userID, "TRANSFER", "BCA", "Warga Test", 35000, "/uploads/proof2.jpg", "")
		if err == nil {
			t.Fatalf("expected payment on pending bill to fail, but it succeeded")
		}
	})

	t.Run("3. Periode memiliki pembayaran paid/approved: pembayaran baru ditolak backend", func(t *testing.T) {
		err := uc.SubmitPayment(ctx, paidBill.ID, userID, "TRANSFER", "BCA", "Warga Test", 35000, "/uploads/proof3.jpg", "")
		if err == nil {
			t.Fatalf("expected payment on paid bill to fail, but it succeeded")
		}
	})

	t.Run("4. Periode memiliki pembayaran rejected: warga dapat mengajukan ulang", func(t *testing.T) {
		err := uc.SubmitPayment(ctx, rejectedBill.ID, userID, "TRANSFER", "BCA", "Warga Test", 35000, "/uploads/proof4.jpg", "")
		if err != nil {
			t.Fatalf("expected re-submitting payment on rejected bill to succeed, got: %v", err)
		}
	})

	t.Run("5. Warga lain tanpa akses unit hunian ditolak membayar tagihan", func(t *testing.T) {
		err := uc.SubmitPayment(ctx, unpaidBill.ID, otherUserID, "TRANSFER", "BCA", "Warga Asing", 35000, "/uploads/proof5.jpg", "")
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

	t.Run("8. Submit pembayaran CASH warga: berhasil tanpa bukti transfer", func(t *testing.T) {
		cashBill := &entity.Bill{
			ID:            50,
			HouseID:       houseID,
			BillingPeriod: "2026-06",
			Amount:        35000,
			Status:        string(entity.BillStatusUnpaid),
		}
		mockBilling.bills[cashBill.ID] = cashBill

		err := uc.SubmitPayment(ctx, cashBill.ID, userID, "CASH", "", "", 35000, "", "Bayar cash ke Pak RT")
		if err != nil {
			t.Fatalf("expected cash payment declaration to succeed: %v", err)
		}
	})

	t.Run("9. Admin catat pembayaran tunai langsung: berhasil dan langsung lunas", func(t *testing.T) {
		directBill := &entity.Bill{
			ID:            51,
			HouseID:       houseID,
			BillingPeriod: "2026-07",
			Amount:        35000,
			Status:        string(entity.BillStatusUnpaid),
		}
		mockBilling.bills[directBill.ID] = directBill

		payment, err := uc.RecordDirectCashPayment(ctx, 1, billing.DirectCashPaymentInput{
			ResidentID:  userID,
			BillID:      directBill.ID,
			Amount:      35000,
			PaymentDate: time.Now(),
		})
		if err != nil {
			t.Fatalf("expected direct cash payment to succeed: %v", err)
		}
		if payment.PaymentMethod != "CASH" {
			t.Fatalf("expected payment method CASH, got: %s", payment.PaymentMethod)
		}
		if directBill.Status != string(entity.BillStatusPaid) {
			t.Fatalf("expected bill status paid, got: %s", directBill.Status)
		}
	})

	t.Run("10. Admin catat pembayaran tunai pada tagihan yang sudah lunas: ditolak dengan pesan otoritatif", func(t *testing.T) {
		_, err := uc.RecordDirectCashPayment(ctx, 1, billing.DirectCashPaymentInput{
			ResidentID:  userID,
			BillID:      paidBill.ID,
			Amount:      35000,
			PaymentDate: time.Now(),
		})
		if err == nil {
			t.Fatalf("expected direct cash payment on paid bill to be rejected")
		}
		expectedMsg := "Pembayaran untuk periode iuran ini sudah tercatat lunas. Silakan periksa riwayat pembayaran sebelum melanjutkan."
		if !strings.Contains(err.Error(), expectedMsg) {
			t.Fatalf("expected exact authoritative message %q, got: %v", expectedMsg, err)
		}
	})

	t.Run("11. Admin catat pembayaran tunai pada tagihan pending: ditolak", func(t *testing.T) {
		_, err := uc.RecordDirectCashPayment(ctx, 1, billing.DirectCashPaymentInput{
			ResidentID:  userID,
			BillID:      pendingBill.ID,
			Amount:      35000,
			PaymentDate: time.Now(),
		})
		if err == nil {
			t.Fatalf("expected direct cash payment on pending bill to be rejected")
		}
	})

	t.Run("12. Admin memuat periode iuran untuk warga tanpa riwayat tagihan: semua periode sistem tetap muncul", func(t *testing.T) {
		unpaidHouseID := int64(999)
		unpaidResident := &entity.User{
			ID:       99,
			HouseID:  &unpaidHouseID,
			RoleName: string(entity.RoleResident),
		}
		mockUser.users[unpaidResident.ID] = unpaidResident

		periods, err := uc.GetResidentEligiblePeriods(ctx, unpaidResident.ID)
		if err != nil {
			t.Fatalf("expected GetResidentEligiblePeriods to succeed: %v", err)
		}
		if len(periods) == 0 {
			t.Fatalf("expected periods to be populated even for resident without prior bills, got 0")
		}
		for _, p := range periods {
			if !p.IsEligible {
				t.Fatalf("expected newly populated period %s to be eligible/unpaid", p.BillingPeriod)
			}
		}
	})
}
