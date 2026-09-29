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

	// 1. Statistik Hunian
	// total_houses
	err := r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM houses;`).Scan(&stats.TotalHouses)
	if err != nil {
		return nil, err
	}

	// occupied_houses: SELECT COUNT(*) FROM houses WHERE status IN ('milik', 'kontrak');
	err = r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM houses WHERE status IN ('milik', 'kontrak');`).Scan(&stats.OccupiedHouses)
	if err != nil {
		return nil, err
	}

	// empty_houses: SELECT COUNT(*) FROM houses WHERE status = 'kosong';
	err = r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM houses WHERE status = 'kosong';`).Scan(&stats.EmptyHouses)
	if err != nil {
		return nil, err
	}

	// 2. Statistik Warga
	// total_residents: SELECT COUNT(*) FROM users WHERE status = 'active' AND role_id = (SELECT id FROM roles WHERE name = 'warga');
	err = r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM users WHERE status = 'active' AND role_id = (SELECT id FROM roles WHERE name = 'warga');`).Scan(&stats.TotalResidents)
	if err != nil {
		return nil, err
	}

	// pending_verifications: SELECT COUNT(*) FROM users WHERE status = 'pending_verification';
	err = r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM users WHERE status = 'pending_verification';`).Scan(&stats.PendingResidents)
	if err != nil {
		return nil, err
	}

	// 3. Statistik Iuran Bulan Berjalan
	// collected_amount: SELECT COALESCE(SUM(amount), 0) FROM bills WHERE billing_period = $1 AND status = 'paid';
	err = r.db.QueryRowContext(ctx, `SELECT COALESCE(SUM(amount), 0) FROM bills WHERE billing_period = $1 AND status = 'paid';`, period).Scan(&stats.CollectedAmount)
	if err != nil {
		return nil, err
	}

	// target_amount: SELECT COALESCE(SUM(amount), 0) FROM bills WHERE billing_period = $1;
	err = r.db.QueryRowContext(ctx, `SELECT COALESCE(SUM(amount), 0) FROM bills WHERE billing_period = $1;`, period).Scan(&stats.TargetAmount)
	if err != nil {
		return nil, err
	}

	// pending_payments_count: SELECT COUNT(*) FROM bills WHERE billing_period = $1 AND status = 'pending_verification';
	err = r.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM bills WHERE billing_period = $1 AND status = 'pending_verification';`, period).Scan(&stats.PendingPaymentsCount)
	if err != nil {
		return nil, err
	}

	// 4. Riwayat Aktivitas Pembayaran Terkini (5 transaksi terakhir)
	queryActivities := `
		SELECT 
			p.id,
			u.name AS resident_name,
			h.block,
			h.house_number,
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
