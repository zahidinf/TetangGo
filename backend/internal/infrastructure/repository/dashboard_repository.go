package repository

import (
	"context"
	"database/sql"
	"time"

	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type PostgresDashboardRepository struct {
	db *sql.DB
}

func NewPostgresDashboardRepository(db *sql.DB) repository.DashboardRepository {
	return &PostgresDashboardRepository{db: db}
}

func (r *PostgresDashboardRepository) GetAdminDashboardStats(ctx context.Context, period string) (*entity.AdminDashboardStats, error) {
	if period == "" {
		period = time.Now().Format("2006-01")
	}

	stats := &entity.AdminDashboardStats{
		CurrentPeriod:    period,
		RecentActivities: make([]entity.DashboardRecentActivity, 0),
	}

	// 1, 2, 3. Consolidated Dashboard Stats (Hunian, Warga, Iuran)
	consolidatedQuery := `
		SELECT
			(SELECT COUNT(*) FROM houses),
			(SELECT COUNT(*) FROM houses WHERE status IN ('milik', 'kontrak')),
			(SELECT COUNT(*) FROM houses WHERE status = 'kosong'),
			(SELECT COUNT(*) FROM users WHERE status = 'active' AND role_id IN (SELECT id FROM roles WHERE name != 'ADMIN')),
			(SELECT COUNT(*) FROM users WHERE status = 'pending_verification'),
			(SELECT COALESCE(SUM(amount), 0) FROM bills WHERE billing_period = $1 AND status = 'paid'),
			(SELECT COALESCE(SUM(amount), 0) FROM bills WHERE billing_period = $1),
			(SELECT COUNT(*) FROM bills WHERE status = 'pending_verification');
	`
	err := r.db.QueryRowContext(ctx, consolidatedQuery, period).Scan(
		&stats.TotalHouses,
		&stats.OccupiedHouses,
		&stats.EmptyHouses,
		&stats.TotalResidents,
		&stats.PendingResidents,
		&stats.CollectedAmount,
		&stats.TargetAmount,
		&stats.PendingPaymentsCount,
	)
	if err != nil {
		return nil, err
	}


	// 4. Riwayat Aktivitas Pembayaran Terkini (5 transaksi terakhir)
	queryActivities := `
		SELECT 
			p.id,
			CASE WHEN u.salutation IS NOT NULL AND u.salutation != '' THEN u.salutation || ' ' || u.name ELSE u.name END AS resident_name,
			h.block,
			h.house_number,
			b.billing_period,
			p.amount_paid,
			b.status,
			p.created_at
		FROM payments p
		JOIN bills b ON b.id = p.bill_id
		JOIN users u ON u.id = p.user_id
		JOIN houses h ON h.id = b.house_id
		ORDER BY p.created_at DESC
		LIMIT 5;
	`
	rows, err := r.db.QueryContext(ctx, queryActivities)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var act entity.DashboardRecentActivity
		if err := rows.Scan(
			&act.ID,
			&act.ResidentName,
			&act.Block,
			&act.HouseNumber,
			&act.BillingPeriod,
			&act.AmountPaid,
			&act.Status,
			&act.CreatedAt,
		); err != nil {
			return nil, err
		}
		stats.RecentActivities = append(stats.RecentActivities, act)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return stats, nil
}
