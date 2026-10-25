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
	"tetanggo-backend/internal/infrastructure/realtime"
	"tetanggo-backend/internal/usecase/auth"
)

type mockUserRepoWS struct {
	users map[int64]*entity.User
}

func (m *mockUserRepoWS) GetByID(ctx context.Context, id int64) (*entity.User, error) {
	return m.users[id], nil
}
func (m *mockUserRepoWS) GetByEmailOrPhone(ctx context.Context, identifier string) (*entity.User, error) {
	return nil, nil
}
func (m *mockUserRepoWS) Create(ctx context.Context, user *entity.User) error { return nil }
func (m *mockUserRepoWS) Update(ctx context.Context, user *entity.User) error { return nil }
func (m *mockUserRepoWS) Delete(ctx context.Context, id int64) error         { return nil }
func (m *mockUserRepoWS) UpdateProfile(ctx context.Context, id int64, name, phone string, photoURL *string) error {
	return nil
}
func (m *mockUserRepoWS) GetPendingUsers(ctx context.Context) ([]entity.PendingUser, error) {
	return nil, nil
}
func (m *mockUserRepoWS) UpdateStatus(ctx context.Context, id int64, status string, rejectionReason *string) error {
	return nil
}
func (m *mockUserRepoWS) CountPending(ctx context.Context) (int, error) { return 0, nil }
func (m *mockUserRepoWS) GetUnassignedResidents(ctx context.Context, search string) ([]entity.UnassignedResident, error) {
	return nil, nil
}
func (m *mockUserRepoWS) AssignHouse(ctx context.Context, userID int64, houseID int64, occupantType string) error {
	return nil
}
func (m *mockUserRepoWS) UnassignHouse(ctx context.Context, userID int64, houseID int64) error {
	return nil
}
func (m *mockUserRepoWS) GetOccupantsByHouseID(ctx context.Context, houseID int64) ([]entity.HouseOccupant, error) {
	return nil, nil
}
func (m *mockUserRepoWS) CountOccupantsByHouseID(ctx context.Context, houseID int64) (int, error) {
	return 0, nil
}
func (m *mockUserRepoWS) GetAllUsers(ctx context.Context, search, status, role string, houseID *int64) ([]entity.User, error) {
	return nil, nil
}
func (m *mockUserRepoWS) UpdatePassword(ctx context.Context, id int64, passwordHash string) error {
	return nil
}

type mockSecRepoWS struct {
	activeAssignments map[int64][]int64
}

func (m *mockSecRepoWS) GetNeighborhoodByID(ctx context.Context, id int64) (*entity.Neighborhood, error) {
	return nil, nil
}
func (m *mockSecRepoWS) GetAllNeighborhoods(ctx context.Context) ([]entity.Neighborhood, error) {
	return []entity.Neighborhood{}, nil
}
func (m *mockSecRepoWS) CreateNeighborhood(ctx context.Context, n *entity.Neighborhood) error {
	return nil
}
func (m *mockSecRepoWS) GetSecurityUsers(ctx context.Context) ([]entity.User, error) {
	return []entity.User{}, nil
}
func (m *mockSecRepoWS) CreateAssignment(ctx context.Context, a *entity.SecurityAssignment) error {
	return nil
}
func (m *mockSecRepoWS) GetAssignmentByID(ctx context.Context, id int64) (*entity.SecurityAssignment, error) {
	return nil, nil
}
func (m *mockSecRepoWS) GetAssignments(ctx context.Context, userID *int64, neighborhoodID *int64, activeOnly *bool) ([]entity.SecurityAssignment, error) {
	return []entity.SecurityAssignment{}, nil
}
func (m *mockSecRepoWS) UpdateAssignmentStatus(ctx context.Context, id int64, isActive bool, notes string) error {
	return nil
}
func (m *mockSecRepoWS) RevokeAssignment(ctx context.Context, id int64, revokedBy int64, notes string) error {
	return nil
}
func (m *mockSecRepoWS) HasActiveAssignmentInNeighborhood(ctx context.Context, userID int64, neighborhoodID int64) (bool, error) {
	for _, nid := range m.activeAssignments[userID] {
		if nid == neighborhoodID {
			return true, nil
		}
	}
	return false, nil
}
func (m *mockSecRepoWS) GetActiveNeighborhoodIDsForUser(ctx context.Context, userID int64) ([]int64, error) {
	return m.activeAssignments[userID], nil
}

func TestSecurityWebSocketHandshake(t *testing.T) {
	tokenService := auth.NewTokenService("testsecret_123456789012345678901234", 60, 7)
	authMid := middleware.NewAuthMiddleware(tokenService)

	userRepo := &mockUserRepoWS{
		users: map[int64]*entity.User{
			1: {ID: 1, Name: "Warga A", RoleName: string(entity.RoleResident), Status: string(entity.UserStatusActive)},
			2: {ID: 2, Name: "Satpam Aktif", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusActive)},
			3: {ID: 3, Name: "Satpam Nonaktif", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusInactive)},
			4: {ID: 4, Name: "Satpam Tanpa Tugas", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusActive)},
		},
	}

	secRepo := &mockSecRepoWS{
		activeAssignments: map[int64][]int64{
			2: {1}, // Satpam Aktif has neighborhood 1
		},
	}

	hub := realtime.NewHub()
	go hub.Run()
	defer func() { _ = hub.Shutdown(context.Background()) }()

	appHandler := handler.NewAppHandler(nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
	appHandler.SetRealtime(hub, tokenService, secRepo, userRepo)

	app := deliveryHttp.SetupRouter(appHandler, authMid)

	generateToken := func(userID int64, role string) string {
		token, _, _ := tokenService.GenerateTokenPair(userID, "test@tetanggo.id", role)
		return token
	}

	t.Run("1. Non-upgrade HTTP request returns 426 Upgrade Required", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/incidents/ws", nil)
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		if resp.StatusCode != http.StatusUpgradeRequired {
			t.Errorf("expected 426 Upgrade Required, got %d", resp.StatusCode)
		}
	})

	t.Run("2. WebSocket upgrade without token returns 401 Unauthorized", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/api/v1/incidents/ws", nil)
		req.Header.Set("Upgrade", "websocket")
		req.Header.Set("Connection", "Upgrade")
		req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
		req.Header.Set("Sec-WebSocket-Version", "13")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		if resp.StatusCode != http.StatusUnauthorized {
			t.Errorf("expected 401 Unauthorized, got %d", resp.StatusCode)
		}
	})

	t.Run("3. Resident token returns 403 Forbidden", func(t *testing.T) {
		token := generateToken(1, string(entity.RoleResident))
		req := httptest.NewRequest(http.MethodGet, "/api/v1/incidents/ws?token="+token, nil)
		req.Header.Set("Upgrade", "websocket")
		req.Header.Set("Connection", "Upgrade")
		req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
		req.Header.Set("Sec-WebSocket-Version", "13")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Errorf("expected 403 Forbidden, got %d", resp.StatusCode)
		}
	})

	t.Run("4. Inactive security account returns 403 Forbidden", func(t *testing.T) {
		token := generateToken(3, string(entity.RoleSecurity))
		req := httptest.NewRequest(http.MethodGet, "/api/v1/incidents/ws", nil)
		req.Header.Set("Authorization", "Bearer "+token)
		req.Header.Set("Upgrade", "websocket")
		req.Header.Set("Connection", "Upgrade")
		req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
		req.Header.Set("Sec-WebSocket-Version", "13")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Errorf("expected 403 Forbidden, got %d", resp.StatusCode)
		}
	})

	t.Run("5. Security account without active assignments returns 403 Forbidden", func(t *testing.T) {
		token := generateToken(4, string(entity.RoleSecurity))
		req := httptest.NewRequest(http.MethodGet, "/api/v1/incidents/ws?token="+token, nil)
		req.Header.Set("Upgrade", "websocket")
		req.Header.Set("Connection", "Upgrade")
		req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
		req.Header.Set("Sec-WebSocket-Version", "13")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Errorf("expected 403 Forbidden, got %d", resp.StatusCode)
		}
	})

	t.Run("6. Active security with valid assignment connects (101 Switching Protocols)", func(t *testing.T) {
		token := generateToken(2, string(entity.RoleSecurity))
		req := httptest.NewRequest(http.MethodGet, "/api/v1/incidents/ws?token="+token+"&device_id=sec-pos-1", nil)
		req.Header.Set("Upgrade", "websocket")
		req.Header.Set("Connection", "Upgrade")
		req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
		req.Header.Set("Sec-WebSocket-Version", "13")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		if resp.StatusCode != http.StatusSwitchingProtocols {
			t.Errorf("expected 101 Switching Protocols, got %d", resp.StatusCode)
		}
	})

	t.Run("7. Alias route /api/v1/ws/security/alarms also connects", func(t *testing.T) {
		token := generateToken(2, string(entity.RoleSecurity))
		req := httptest.NewRequest(http.MethodGet, "/api/v1/ws/security/alarms?token="+token+"&device_id=sec-pos-1", nil)
		req.Header.Set("Upgrade", "websocket")
		req.Header.Set("Connection", "Upgrade")
		req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")
		req.Header.Set("Sec-WebSocket-Version", "13")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("request failed: %v", err)
		}
		if resp.StatusCode != http.StatusSwitchingProtocols {
			t.Errorf("expected 101 Switching Protocols, got %d", resp.StatusCode)
		}
	})
}
