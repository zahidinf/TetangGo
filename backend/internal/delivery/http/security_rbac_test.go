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
	"tetanggo-backend/internal/usecase/auth"
	"tetanggo-backend/internal/usecase/dashboard"
	"tetanggo-backend/internal/usecase/security"
)

type mockSecurityRepoHTTP struct{}

func (m *mockSecurityRepoHTTP) GetNeighborhoodByID(ctx context.Context, id int64) (*entity.Neighborhood, error) {
	return nil, nil
}
func (m *mockSecurityRepoHTTP) GetAllNeighborhoods(ctx context.Context) ([]entity.Neighborhood, error) {
	return []entity.Neighborhood{}, nil
}
func (m *mockSecurityRepoHTTP) CreateNeighborhood(ctx context.Context, n *entity.Neighborhood) error {
	return nil
}
func (m *mockSecurityRepoHTTP) GetSecurityUsers(ctx context.Context) ([]entity.User, error) {
	return []entity.User{}, nil
}
func (m *mockSecurityRepoHTTP) CreateAssignment(ctx context.Context, a *entity.SecurityAssignment) error {
	return nil
}
func (m *mockSecurityRepoHTTP) GetAssignmentByID(ctx context.Context, id int64) (*entity.SecurityAssignment, error) {
	return nil, nil
}
func (m *mockSecurityRepoHTTP) GetAssignments(ctx context.Context, userID *int64, neighborhoodID *int64, activeOnly *bool) ([]entity.SecurityAssignment, error) {
	return []entity.SecurityAssignment{}, nil
}
func (m *mockSecurityRepoHTTP) UpdateAssignmentStatus(ctx context.Context, id int64, isActive bool, notes string) error {
	return nil
}
func (m *mockSecurityRepoHTTP) RevokeAssignment(ctx context.Context, id int64, revokedBy int64, notes string) error {
	return nil
}
func (m *mockSecurityRepoHTTP) HasActiveAssignmentInNeighborhood(ctx context.Context, userID int64, neighborhoodID int64) (bool, error) {
	return false, nil
}
func (m *mockSecurityRepoHTTP) GetActiveNeighborhoodIDsForUser(ctx context.Context, userID int64) ([]int64, error) {
	return []int64{}, nil
}

func TestSecurityRBACIsolation(t *testing.T) {
	tokenService := auth.NewTokenService("testsecret_123456789012345678901234", 60, 7)
	mockUserRepo := &mockUserRepoWS{
		users: map[int64]*entity.User{
			99: {
				ID:       99,
				Name:     "Security Test",
				Email:    "sec@tetanggo.id",
				RoleName: string(entity.RoleSecurity),
				Status:   string(entity.UserStatusActive),
				HouseID:  nil,
			},
		},
	}
	authMid := middleware.NewAuthMiddleware(tokenService, mockUserRepo)

	dashRepo := &mockDashboardRepo{}
	dashUC := dashboard.NewDashboardUseCase(dashRepo)

	secRepo := &mockSecurityRepoHTTP{}
	secUC := security.NewSecurityUseCase(secRepo, nil, nil)

	appHandler := handler.NewAppHandler(
		nil,
		nil,
		nil,
		nil,
		nil,
		dashUC,
		nil,
		nil,
		secUC,
		nil,
	)

	app := deliveryHttp.SetupRouter(appHandler, authMid)

	generateToken := func(role string) string {
		token, _, err := tokenService.GenerateTokenPair(99, "sec@tetanggo.id", role)
		if err != nil {
			t.Fatalf("failed to generate token: %v", err)
		}
		return token
	}

	tests := []struct {
		name         string
		role         string
		path         string
		method       string
		expectedCode int
	}{
		{
			name:         "1. Security is FORBIDDEN from admin dashboard stats",
			role:         string(entity.RoleSecurity),
			path:         "/api/v1/admin/dashboard/stats",
			method:       http.MethodGet,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "2. Security is FORBIDDEN from cashbook summary",
			role:         string(entity.RoleSecurity),
			path:         "/api/v1/cashbook/summary",
			method:       http.MethodGet,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "3. Security is FORBIDDEN from resident bills",
			role:         string(entity.RoleSecurity),
			path:         "/api/v1/resident/bills",
			method:       http.MethodGet,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "4. Security is FORBIDDEN from managing security accounts",
			role:         string(entity.RoleSecurity),
			path:         "/api/v1/admin/security/users",
			method:       http.MethodGet,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "5. Resident is FORBIDDEN from managing security accounts",
			role:         string(entity.RoleResident),
			path:         "/api/v1/admin/security/users",
			method:       http.MethodGet,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "6. Bendahara is FORBIDDEN from managing security accounts",
			role:         string(entity.RoleTreasurer),
			path:         "/api/v1/admin/security/users",
			method:       http.MethodGet,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "7. Admin is ALLOWED to view security accounts",
			role:         string(entity.RoleAdmin),
			path:         "/api/v1/admin/security/users",
			method:       http.MethodGet,
			expectedCode: http.StatusOK,
		},
		{
			name:         "8. Chairperson (Ketua RT) is ALLOWED to view security accounts",
			role:         string(entity.RoleChairperson),
			path:         "/api/v1/admin/security/users",
			method:       http.MethodGet,
			expectedCode: http.StatusOK,
		},
		{
			name:         "9. Vice Chairperson (Wakil Ketua RT) is ALLOWED to view security accounts",
			role:         string(entity.RoleViceChairperson),
			path:         "/api/v1/admin/security/users",
			method:       http.MethodGet,
			expectedCode: http.StatusOK,
		},
		{
			name:         "10. Security is FORBIDDEN from reporting incident via POST /incidents",
			role:         string(entity.RoleSecurity),
			path:         "/api/v1/incidents",
			method:       http.MethodPost,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "11. Resident is FORBIDDEN from GET /incidents/active (security only)",
			role:         string(entity.RoleResident),
			path:         "/api/v1/incidents/active",
			method:       http.MethodGet,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "12. Resident is FORBIDDEN from POST /incidents/:id/acknowledge (security only)",
			role:         string(entity.RoleResident),
			path:         "/api/v1/incidents/1/acknowledge",
			method:       http.MethodPost,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "13. Resident is FORBIDDEN from POST /incidents/:id/resolve",
			role:         string(entity.RoleResident),
			path:         "/api/v1/incidents/1/resolve",
			method:       http.MethodPost,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "14. Treasurer is FORBIDDEN from POST /incidents/:id/resolve",
			role:         string(entity.RoleTreasurer),
			path:         "/api/v1/incidents/1/resolve",
			method:       http.MethodPost,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "15. Resident is FORBIDDEN from POST /api/v1/security/device-token",
			role:         string(entity.RoleResident),
			path:         "/api/v1/security/device-token",
			method:       http.MethodPost,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "16. Security is ALLOWED to POST /api/v1/security/device-token",
			role:         string(entity.RoleSecurity),
			path:         "/api/v1/security/device-token",
			method:       http.MethodPost,
			expectedCode: http.StatusBadRequest, // Bad request because body is empty, proves RBAC passed
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(tc.method, tc.path, nil)
			token := generateToken(tc.role)
			req.Header.Set("Authorization", "Bearer "+token)

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("request failed: %v", err)
			}

			if resp.StatusCode != tc.expectedCode {
				t.Errorf("expected status %d, got %d", tc.expectedCode, resp.StatusCode)
			}
		})
	}
}
