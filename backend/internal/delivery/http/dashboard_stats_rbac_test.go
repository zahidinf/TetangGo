package http_test

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	deliveryHttp "tetanggo-backend/internal/delivery/http"
	"tetanggo-backend/internal/delivery/http/handler"
	"tetanggo-backend/internal/delivery/http/middleware"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/usecase/auth"
	"tetanggo-backend/internal/usecase/dashboard"
)

type mockDashboardRepo struct{}

func (m *mockDashboardRepo) GetAdminDashboardStats(ctx context.Context, period string) (*entity.AdminDashboardStats, error) {
	return &entity.AdminDashboardStats{
		CurrentPeriod: "2026-10",
		RecentActivities: []entity.DashboardRecentActivity{
			{
				ID:            1,
				ResidentName:  "Budi Santoso",
				Block:         "A",
				HouseNumber:   "1",
				BillingPeriod: "2026-10",
				AmountPaid:    100000,
				Status:        "paid",
				CreatedAt:     time.Now(),
			},
		},
	}, nil
}

func TestDashboardStatsRBAC(t *testing.T) {
	tokenService := auth.NewTokenService("testsecret_123456789012345678901234", 60, 7)
	authMid := middleware.NewAuthMiddleware(tokenService)

	dashRepo := &mockDashboardRepo{}
	dashUC := dashboard.NewDashboardUseCase(dashRepo)

	appHandler := handler.NewAppHandler(
		nil,
		nil,
		nil,
		nil,
		nil,
		dashUC,
		nil,
		nil,
		nil,
		nil,
	)

	app := deliveryHttp.SetupRouter(appHandler, authMid)

	generateToken := func(role string) string {
		token, _, err := tokenService.GenerateTokenPair(10, "test@tetanggo.id", role)
		if err != nil {
			t.Fatalf("failed to generate token: %v", err)
		}
		return token
	}

	tests := []struct {
		name         string
		role         string
		hasAuth      bool
		expectedCode int
	}{
		{
			name:         "1. Bendahara (TREASURER) can access dashboard stats and view all residents activities",
			role:         string(entity.RoleTreasurer),
			hasAuth:      true,
			expectedCode: http.StatusOK,
		},
		{
			name:         "2. Sekretaris (SECRETARY) can access dashboard stats and view all residents activities",
			role:         string(entity.RoleSecretary),
			hasAuth:      true,
			expectedCode: http.StatusOK,
		},
		{
			name:         "3. Admin (ADMIN) can access dashboard stats",
			role:         string(entity.RoleAdmin),
			hasAuth:      true,
			expectedCode: http.StatusOK,
		},
		{
			name:         "4. Ketua RT (CHAIRPERSON) can access dashboard stats",
			role:         string(entity.RoleChairperson),
			hasAuth:      true,
			expectedCode: http.StatusOK,
		},
		{
			name:         "5. Wakil Ketua RT (VICE_CHAIRPERSON) can access dashboard stats",
			role:         string(entity.RoleViceChairperson),
			hasAuth:      true,
			expectedCode: http.StatusOK,
		},
		{
			name:         "6. Warga (RESIDENT) is FORBIDDEN from accessing admin dashboard stats",
			role:         string(entity.RoleResident),
			hasAuth:      true,
			expectedCode: http.StatusForbidden,
		},
		{
			name:         "7. Unauthenticated user is UNAUTHORIZED",
			role:         "",
			hasAuth:      false,
			expectedCode: http.StatusUnauthorized,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v1/admin/dashboard/stats", nil)
			if tc.hasAuth {
				token := generateToken(tc.role)
				req.Header.Set("Authorization", "Bearer "+token)
			}

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("unexpected error making request: %v", err)
			}

			if resp.StatusCode != tc.expectedCode {
				t.Errorf("expected status %d, got %d", tc.expectedCode, resp.StatusCode)
			}
		})
	}
}
