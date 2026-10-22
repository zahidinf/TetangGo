package billing_test

import (
	"context"
	"strings"
	"testing"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
	"tetanggo-backend/internal/usecase/billing"
)

type mockBillingRepo struct {
	bills    map[int64]*entity.Bill
	payments map[int64]*entity.Payment
	settings *entity.PaymentSetting
}

func (m *mockBillingRepo) GetPaymentSettings(ctx context.Context) (*entity.PaymentSetting, error) {
	return m.settings, nil
}

func (m *mockBillingRepo) UpdatePaymentSettings(ctx context.Context, setting *entity.PaymentSetting) error {
	m.settings = setting
	return nil
}

func (m *mockBillingRepo) GetBillsByHouseID(ctx context.Context, houseID int64) ([]entity.Bill, error) {
	var list []entity.Bill
	for _, b := range m.bills {
		if b.HouseID == houseID {
			list = append(list, *b)
		}
	}
	return list, nil
}

func (m *mockBillingRepo) GetBillsByHouseIDAndPeriod(ctx context.Context, houseID int64, period string) ([]entity.Bill, error) {
	var list []entity.Bill
	for _, b := range m.bills {
		if b.HouseID == houseID && b.BillingPeriod == period {
			list = append(list, *b)
		}
	}
	return list, nil
}

func (m *mockBillingRepo) GetBillByHouseAndPeriod(ctx context.Context, houseID int64, period string) (*entity.Bill, error) {
	for _, b := range m.bills {
		if b.HouseID == houseID && b.BillingPeriod == period {
			return b, nil
		}
	}
	return nil, nil
}

func (m *mockBillingRepo) CreateBill(ctx context.Context, bill *entity.Bill) error {
	bill.ID = int64(len(m.bills) + 1)
	m.bills[bill.ID] = bill
	return nil
}

func (m *mockBillingRepo) GetBillByID(ctx context.Context, id int64) (*entity.Bill, error) {
	if b, ok := m.bills[id]; ok {
		return b, nil
	}
	return nil, nil
}

func (m *mockBillingRepo) CreatePayment(ctx context.Context, payment *entity.Payment) error {
	payment.ID = int64(len(m.payments) + 1)
	m.payments[payment.ID] = payment
	return nil
}

func (m *mockBillingRepo) GetPendingPayments(ctx context.Context) ([]entity.PendingPaymentItem, error) {
	return nil, nil
}

func (m *mockBillingRepo) UpdateBillStatus(ctx context.Context, billID int64, status string) error {
	if b, ok := m.bills[billID]; ok {
		b.Status = status
	}
	return nil
}

func (m *mockBillingRepo) VerifyPayment(ctx context.Context, billID int64, action string, rejectionReason *string, verifiedBy int64) error {
	return nil
}

func (m *mockBillingRepo) GetBillingSummary(ctx context.Context, period string, block string) (*entity.BillingSummaryResponse, error) {
	return nil, nil
}

func (m *mockBillingRepo) CountPaidOrPendingBillsByPeriod(ctx context.Context, period string) (int, error) {
	return 0, nil
}

func (m *mockBillingRepo) GenerateMonthlyBills(ctx context.Context, period string, amount float64) (int64, error) {
	return 0, nil
}

var _ repository.BillingRepository = (*mockBillingRepo)(nil)

type mockUserRepoForBilling struct {
	users map[int64]*entity.User
}

func (m *mockUserRepoForBilling) Create(ctx context.Context, user *entity.User) error { return nil }
func (m *mockUserRepoForBilling) GetByID(ctx context.Context, id int64) (*entity.User, error) {
	return m.users[id], nil
}
func (m *mockUserRepoForBilling) GetByEmailOrPhone(ctx context.Context, identifier string) (*entity.User, error) {
	return nil, nil
}
func (m *mockUserRepoForBilling) Update(ctx context.Context, user *entity.User) error { return nil }
func (m *mockUserRepoForBilling) Delete(ctx context.Context, id int64) error         { return nil }
func (m *mockUserRepoForBilling) UpdateProfile(ctx context.Context, id int64, name, phone string, photoURL *string) error {
	return nil
}
func (m *mockUserRepoForBilling) GetPendingUsers(ctx context.Context) ([]entity.PendingUser, error) {
	return nil, nil
}
func (m *mockUserRepoForBilling) UpdateStatus(ctx context.Context, id int64, status string, rejectionReason *string) error {
	return nil
}
func (m *mockUserRepoForBilling) CountPending(ctx context.Context) (int, error) { return 0, nil }
func (m *mockUserRepoForBilling) GetUnassignedResidents(ctx context.Context, search string) ([]entity.UnassignedResident, error) {
	return nil, nil
}
func (m *mockUserRepoForBilling) AssignHouse(ctx context.Context, userID int64, houseID int64, occupantType string) error {
	return nil
}
func (m *mockUserRepoForBilling) UnassignHouse(ctx context.Context, userID int64, houseID int64) error {
	return nil
}
func (m *mockUserRepoForBilling) GetOccupantsByHouseID(ctx context.Context, houseID int64) ([]entity.HouseOccupant, error) {
	return nil, nil
}
func (m *mockUserRepoForBilling) CountOccupantsByHouseID(ctx context.Context, houseID int64) (int, error) {
	return 1, nil
}
func (m *mockUserRepoForBilling) GetAllUsers(ctx context.Context, search, status, role string, houseID *int64) ([]entity.User, error) {
	return nil, nil
}
func (m *mockUserRepoForBilling) UpdatePassword(ctx context.Context, id int64, passwordHash string) error {
	return nil
}

var _ repository.UserRepository = (*mockUserRepoForBilling)(nil)

func TestBillingHousingEligibilityAndIsolation(t *testing.T) {
	house1ID := int64(101)
	house2ID := int64(102)

	userRepo := &mockUserRepoForBilling{
		users: map[int64]*entity.User{
			// Resident with House 101
			1: {ID: 1, Name: "Warga Rumah 101", RoleName: "RESIDENT", HouseID: &house1ID},
			// Chairperson with House 101
			2: {ID: 2, Name: "Ketua Rumah 101", RoleName: "CHAIRPERSON", HouseID: &house1ID},
			// Treasurer with House 102
			3: {ID: 3, Name: "Bendahara Rumah 102", RoleName: "TREASURER", HouseID: &house2ID},
			// Secretary without House
			4: {ID: 4, Name: "Sekretaris Kosong", RoleName: "SECRETARY", HouseID: nil},
			// Resident without House
			5: {ID: 5, Name: "Warga Tanpa Rumah", RoleName: "RESIDENT", HouseID: nil},
			// Admin with House 101
			6: {ID: 6, Name: "Admin Rumah 101", RoleName: "ADMIN", HouseID: &house1ID},
			// Admin without House
			7: {ID: 7, Name: "Admin Tanpa Rumah", RoleName: "ADMIN", HouseID: nil},
		},
	}

	billingRepo := &mockBillingRepo{
		bills: map[int64]*entity.Bill{
			1: {ID: 1, HouseID: house1ID, BillingPeriod: "2026-10", Amount: 150000, Status: string(entity.BillStatusUnpaid)},
			2: {ID: 2, HouseID: house2ID, BillingPeriod: "2026-10", Amount: 150000, Status: string(entity.BillStatusUnpaid)},
		},
		payments: make(map[int64]*entity.Payment),
		settings: &entity.PaymentSetting{
			MonthlyFee:    150000,
			BankName:      "BCA",
			AccountNumber: "1234567890",
			AccountHolder: "RT TetangGo",
		},
	}

	uc := billing.NewBillingUseCase(billingRepo, userRepo, nil)
	ctx := context.Background()

	// 1. Resident with House 101 can get their bills
	bills, err := uc.GetResidentBills(ctx, 1, "2026-10")
	if err != nil {
		t.Fatalf("expected resident with house to access bills, got error: %v", err)
	}
	if len(bills) != 1 || bills[0].HouseID != house1ID {
		t.Fatalf("expected 1 bill for house 101, got %+v", bills)
	}

	// 2. Chairperson with House 101 can also get their personal resident bills
	bills, err = uc.GetResidentBills(ctx, 2, "2026-10")
	if err != nil {
		t.Fatalf("expected chairperson with house to access resident bills, got error: %v", err)
	}
	if len(bills) != 1 || bills[0].HouseID != house1ID {
		t.Fatalf("expected 1 bill for house 101, got %+v", bills)
	}

	// 3. Admin with House 101 can also get their personal resident bills
	bills, err = uc.GetResidentBills(ctx, 6, "2026-10")
	if err != nil {
		t.Fatalf("expected admin with house to access resident bills, got error: %v", err)
	}
	if len(bills) != 1 || bills[0].HouseID != house1ID {
		t.Fatalf("expected 1 bill for house 101, got %+v", bills)
	}

	// 4. Resident without House CANNOT access resident bills
	_, err = uc.GetResidentBills(ctx, 5, "")
	if err == nil || !strings.Contains(err.Error(), "belum terdaftar") {
		t.Fatalf("expected access denial for resident without house, got: %v", err)
	}

	// 5. Secretary without House CANNOT access resident bills
	_, err = uc.GetResidentBills(ctx, 4, "")
	if err == nil || !strings.Contains(err.Error(), "belum terdaftar") {
		t.Fatalf("expected access denial for secretary without house, got: %v", err)
	}

	// 6. Admin without House CANNOT access resident bills
	_, err = uc.GetResidentBills(ctx, 7, "")
	if err == nil || !strings.Contains(err.Error(), "belum terdaftar") {
		t.Fatalf("expected access denial for admin without house, got: %v", err)
	}

	// 7. Household isolation: Resident of House 101 cannot access Bill of House 102
	_, err = uc.GetBillDetail(ctx, 2, 1, false)
	if err == nil || !strings.Contains(err.Error(), "akses ditolak") {
		t.Fatalf("expected access denial when resident accesses another house's bill, got: %v", err)
	}

	// 8. Household isolation: Resident of House 101 cannot pay Bill of House 102
	err = uc.SubmitPayment(ctx, 2, 1, "BCA", "Warga 101", 150000, "/uploads/proof.jpg", "notes")
	if err == nil || !strings.Contains(err.Error(), "akses ditolak") {
		t.Fatalf("expected access denial when resident pays another house's bill, got: %v", err)
	}

	// 9. Legitimate payment: Resident of House 101 can pay their own bill (Bill 1)
	err = uc.SubmitPayment(ctx, 1, 1, "BCA", "Warga 101", 150000, "/uploads/proof.jpg", "Bayar iuran")
	if err != nil {
		t.Fatalf("expected successful payment for own bill, got error: %v", err)
	}

	// 10. Billing staff (Admin/Treasurer) can view any bill details via administrative scope (isAdmin = true)
	adminBill, err := uc.GetBillDetail(ctx, 2, 3, true)
	if err != nil || adminBill == nil {
		t.Fatalf("expected billing staff to view bill in admin scope, got error: %v", err)
	}
}
