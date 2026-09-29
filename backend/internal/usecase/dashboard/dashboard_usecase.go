package dashboard

import (
	"context"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type DashboardUseCase struct {
	dashboardRepo repository.DashboardRepository
}

func NewDashboardUseCase(dashboardRepo repository.DashboardRepository) *DashboardUseCase {
	return &DashboardUseCase{
		dashboardRepo: dashboardRepo,
	}
}

func (u *DashboardUseCase) GetAdminDashboardStats(ctx context.Context, period string) (*entity.AdminDashboardStats, error) {
	return u.dashboardRepo.GetAdminDashboardStats(ctx, period)
}
