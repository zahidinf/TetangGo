package http_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	deliveryHttp "tetanggo-backend/internal/delivery/http"
	"tetanggo-backend/internal/delivery/http/handler"
	"tetanggo-backend/internal/delivery/http/middleware"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
	"tetanggo-backend/internal/usecase/auth"
	"tetanggo-backend/internal/usecase/billing"
	"tetanggo-backend/internal/usecase/cashbook"
	"tetanggo-backend/internal/usecase/dashboard"
	"tetanggo-backend/internal/usecase/house"
	"tetanggo-backend/internal/usecase/incident"
	"tetanggo-backend/internal/usecase/security"
)

// Mock repos for cumulative RBAC testing
type mockCumulativeBillingRepo struct {
	repository.BillingRepository
	bills map[int64]*entity.Bill
}

func (m *mockCumulativeBillingRepo) GetBillsByHouseID(ctx context.Context, houseID int64) ([]entity.Bill, error) {
	var res []entity.Bill
	for _, b := range m.bills {
		if b.HouseID == houseID {
			res = append(res, *b)
		}
	}
	return res, nil
}

func (m *mockCumulativeBillingRepo) GetBillsByHouseIDAndPeriod(ctx context.Context, houseID int64, period string) ([]entity.Bill, error) {
	var res []entity.Bill
	for _, b := range m.bills {
		if b.HouseID == houseID && b.BillingPeriod == period {
			res = append(res, *b)
		}
	}
	return res, nil
}

func (m *mockCumulativeBillingRepo) GetBillByID(ctx context.Context, id int64) (*entity.Bill, error) {
	b, ok := m.bills[id]
	if !ok {
		return nil, nil
	}
	return b, nil
}

func (m *mockCumulativeBillingRepo) CreateBill(ctx context.Context, bill *entity.Bill) error {
	return nil
}

func (m *mockCumulativeBillingRepo) UpdateBill(ctx context.Context, bill *entity.Bill) error {
	return nil
}

func (m *mockCumulativeBillingRepo) CreatePayment(ctx context.Context, payment *entity.Payment) error {
	return nil
}

func (m *mockCumulativeBillingRepo) GetPaymentByID(ctx context.Context, id int64) (*entity.Payment, error) {
	return nil, nil
}

func (m *mockCumulativeBillingRepo) UpdatePaymentStatus(ctx context.Context, id int64, status string, notes string) error {
	return nil
}

func (m *mockCumulativeBillingRepo) GetPendingPayments(ctx context.Context) ([]entity.PendingPaymentItem, error) {
	return []entity.PendingPaymentItem{}, nil
}

func (m *mockCumulativeBillingRepo) GetPaymentSettings(ctx context.Context) (*entity.PaymentSetting, error) {
	return &entity.PaymentSetting{
		MonthlyFee:    150000,
		BankName:      "BCA",
		AccountNumber: "1234567890",
		AccountHolder: "RT TetangGo",
	}, nil
}

func (m *mockCumulativeBillingRepo) UpdatePaymentSettings(ctx context.Context, settings *entity.PaymentSetting) error {
	return nil
}

func (m *mockCumulativeBillingRepo) CountTotalBillsByPeriod(ctx context.Context, period string) (int, error) {
	cnt := 0
	for _, b := range m.bills {
		if b.BillingPeriod == period {
			cnt++
		}
	}
	return cnt, nil
}

func (m *mockCumulativeBillingRepo) GenerateIndividualBill(ctx context.Context, houseID int64, period string, amount float64) (*entity.Bill, error) {
	id := int64(len(m.bills) + 100)
	bill := &entity.Bill{
		ID:            id,
		HouseID:       houseID,
		BillingPeriod: period,
		Amount:        amount,
		Status:        string(entity.BillStatusUnpaid),
	}
	m.bills[id] = bill
	return bill, nil
}

type mockCumulativeHouseRepo struct{}

func (m *mockCumulativeHouseRepo) GetAll(ctx context.Context, block, status, search string) ([]entity.House, error) {
	return []entity.House{}, nil
}
func (m *mockCumulativeHouseRepo) GetAvailable(ctx context.Context) ([]entity.House, error) {
	return []entity.House{}, nil
}
func (m *mockCumulativeHouseRepo) GetDistinctBlocks(ctx context.Context) ([]string, error) {
	return []string{"A", "B"}, nil
}
func (m *mockCumulativeHouseRepo) GetByID(ctx context.Context, id int64) (*entity.House, error) {
	nID := int64(1)
	return &entity.House{ID: id, Block: "A", HouseNumber: "1", NeighborhoodID: &nID}, nil
}
func (m *mockCumulativeHouseRepo) Create(ctx context.Context, house *entity.House) error {
	return nil
}
func (m *mockCumulativeHouseRepo) Update(ctx context.Context, house *entity.House) error {
	return nil
}
func (m *mockCumulativeHouseRepo) Delete(ctx context.Context, id int64) error {
	return nil
}
func (m *mockCumulativeHouseRepo) BulkDelete(ctx context.Context, ids []int64) (int64, error) {
	return int64(len(ids)), nil
}

func TestCumulativeAccessAndHousingRBAC(t *testing.T) {
	tokenService := auth.NewTokenService("testsecret_123456789012345678901234", 60, 7)
	house101 := int64(101)
	house102 := int64(102)

	users := map[int64]*entity.User{
		// 1. Warga biasa with house 101
		1: {ID: 1, Name: "Warga Biasa", Email: "warga@tetanggo.id", RoleName: string(entity.RoleResident), Status: string(entity.UserStatusActive), HouseID: &house101},
		// 2. Ketua RT with house 101
		2: {ID: 2, Name: "Ketua RT", Email: "ketua@tetanggo.id", RoleName: string(entity.RoleChairperson), Status: string(entity.UserStatusActive), HouseID: &house101},
		// 3. Wakil Ketua RT with house 101
		3: {ID: 3, Name: "Wakil Ketua", Email: "wakil@tetanggo.id", RoleName: string(entity.RoleViceChairperson), Status: string(entity.UserStatusActive), HouseID: &house101},
		// 4. Bendahara with house 101
		4: {ID: 4, Name: "Bendahara", Email: "bendahara@tetanggo.id", RoleName: string(entity.RoleTreasurer), Status: string(entity.UserStatusActive), HouseID: &house101},
		// 5. Sekretaris with house 101
		5: {ID: 5, Name: "Sekretaris", Email: "sekretaris@tetanggo.id", RoleName: string(entity.RoleSecretary), Status: string(entity.UserStatusActive), HouseID: &house101},
		// 6. Admin with house 101
		6: {ID: 6, Name: "Admin Berhunian", Email: "admin_house@tetanggo.id", RoleName: string(entity.RoleAdmin), Status: string(entity.UserStatusActive), HouseID: &house101},
		// 7. Admin TANPA mapping hunian
		7: {ID: 7, Name: "Admin Luar", Email: "admin_external@tetanggo.id", RoleName: string(entity.RoleAdmin), Status: string(entity.UserStatusActive), HouseID: nil},
		// 8. Security TANPA mapping hunian
		8: {ID: 8, Name: "Satpam Standby", Email: "satpam@tetanggo.id", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusActive), HouseID: nil},
		// 9. Warga TANPA mapping hunian (belum ditempatkan)
		9: {ID: 9, Name: "Warga Mengambang", Email: "unassigned@tetanggo.id", RoleName: string(entity.RoleResident), Status: string(entity.UserStatusActive), HouseID: nil},
	}

	bills := map[int64]*entity.Bill{
		10: {ID: 10, HouseID: house101, BillingPeriod: "2026-10", Amount: 150000, Status: string(entity.BillStatusUnpaid)},
		20: {ID: 20, HouseID: house102, BillingPeriod: "2026-10", Amount: 150000, Status: string(entity.BillStatusUnpaid)},
	}

	userRepo := &mockUserRepoWS{users: users}
	authMid := middleware.NewAuthMiddleware(tokenService, userRepo)

	billingRepo := &mockCumulativeBillingRepo{bills: bills}
	houseRepo := &mockCumulativeHouseRepo{}
	billingUC := billing.NewBillingUseCase(billingRepo, userRepo, houseRepo)

	dashRepo := &mockDashboardRepo{}
	dashUC := dashboard.NewDashboardUseCase(dashRepo)

	cashbookUC := cashbook.NewCashbookUseCase(nil)
	secRepo := &mockSecurityRepoHTTP{}
	secUC := security.NewSecurityUseCase(secRepo, nil, nil)
	incUC := incident.NewIncidentUseCase(nil, secRepo, userRepo, houseRepo)
	houseUC := house.NewHouseUseCase(houseRepo, userRepo, nil, nil)

	appHandler := handler.NewAppHandler(
		nil,
		nil,
		houseUC,
		nil,
		billingUC,
		dashUC,
		cashbookUC,
		nil,
		secUC,
		incUC,
	)

	app := deliveryHttp.SetupRouter(appHandler, authMid)

	generateToken := func(userID int64, role string) string {
		u := users[userID]
		token, _, err := tokenService.GenerateTokenPair(userID, u.Email, role)
		if err != nil {
			t.Fatalf("failed token generation: %v", err)
		}
		return token
	}

	t.Run("Positive 1: Warga biasa with house mapping can get resident bills", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(1, string(entity.RoleResident)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK, got %d", resp.StatusCode)
		}
	})

	t.Run("Positive 2: Chairperson with house mapping can get resident bills", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(2, string(entity.RoleChairperson)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for chairperson with house, got %d", resp.StatusCode)
		}
	})

	t.Run("Positive 3: Vice Chairperson with house mapping can get resident bills", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(3, string(entity.RoleViceChairperson)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for vice chairperson with house, got %d", resp.StatusCode)
		}
	})

	t.Run("Positive 4: Treasurer with house mapping can get resident bills", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(4, string(entity.RoleTreasurer)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for treasurer with house, got %d", resp.StatusCode)
		}
	})

	t.Run("Positive 5: Secretary with house mapping can get resident bills", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(5, string(entity.RoleSecretary)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for secretary with house, got %d", resp.StatusCode)
		}
	})

	t.Run("Positive 6: Admin with house mapping can get resident bills", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(6, string(entity.RoleAdmin)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for admin with house, got %d", resp.StatusCode)
		}
	})

	t.Run("Positive 7: Admin without house mapping can access admin dashboard stats", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/dashboard/stats", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(7, string(entity.RoleAdmin)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for admin without house on admin stats, got %d", resp.StatusCode)
		}
	})

	t.Run("Positive 8: Security without house mapping can view my-assignments", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/security/my-assignments", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(8, string(entity.RoleSecurity)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for security assignments, got %d", resp.StatusCode)
		}
	})

	t.Run("Negative 1: Admin without house mapping is FORBIDDEN from resident bills", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(7, string(entity.RoleAdmin)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for admin without house, got %d", resp.StatusCode)
		}
	})

	t.Run("Negative 2: Security without house mapping is FORBIDDEN from resident bills", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(8, string(entity.RoleSecurity)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for security without house, got %d", resp.StatusCode)
		}
	})

	t.Run("Negative 3: Warga without house mapping is FORBIDDEN from resident bills", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(9, string(entity.RoleResident)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for resident without house, got %d", resp.StatusCode)
		}
	})

	t.Run("Negative 4: User cannot access other house bill detail by changing ID", func(t *testing.T) {
		// User 1 belongs to house 101. Bill 20 belongs to house 102.
		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills/20", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(1, string(entity.RoleResident)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden when accessing another house's bill, got %d", resp.StatusCode)
		}
	})

	t.Run("Negative 5: Treasurer cannot manage security accounts", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/security/users", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(4, string(entity.RoleTreasurer)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for treasurer on security accounts, got %d", resp.StatusCode)
		}
	})

	t.Run("Negative 6: Secretary cannot access financial management (bills/pending)", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/bills/pending", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(5, string(entity.RoleSecretary)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for secretary on financial management, got %d", resp.StatusCode)
		}
	})

	t.Run("Negative 7: Regular Resident cannot access admin endpoints directly", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/dashboard/stats", nil)
		req.Header.Set("Authorization", "Bearer "+generateToken(1, string(entity.RoleResident)))
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for resident on admin stats, got %d", resp.StatusCode)
		}
	})

	t.Run("Negative 8: Revoking house mapping immediately revokes resident bills access", func(t *testing.T) {
		// User 2 initially had house 101. Simulate house unassignment:
		user2Token := generateToken(2, string(entity.RoleChairperson))
		users[2].HouseID = nil

		req := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		req.Header.Set("Authorization", "Bearer "+user2Token)
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("unexpected err: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden after house mapping removed, got %d", resp.StatusCode)
		}
		// restore
		users[2].HouseID = &house101
	})
}
