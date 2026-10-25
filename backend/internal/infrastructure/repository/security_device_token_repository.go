package repository

import (
	"context"
	"database/sql"
	"fmt"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type PostgresSecurityDeviceTokenRepository struct {
	db *sql.DB
}

func NewPostgresSecurityDeviceTokenRepository(db *sql.DB) repository.SecurityDeviceTokenRepository {
	return &PostgresSecurityDeviceTokenRepository{db: db}
}

func (r *PostgresSecurityDeviceTokenRepository) UpsertDeviceToken(ctx context.Context, t *entity.SecurityDeviceToken) error {
	query := `
		INSERT INTO security_device_tokens (user_id, device_id, device_token, platform, is_active, last_seen_at, updated_at)
		VALUES ($1, $2, $3, $4, true, NOW(), NOW())
		ON CONFLICT (user_id, device_id)
		DO UPDATE SET
			device_token = EXCLUDED.device_token,
			platform = EXCLUDED.platform,
			is_active = true,
			last_seen_at = NOW(),
			updated_at = NOW()
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query, t.UserID, t.DeviceID, t.DeviceToken, t.Platform).Scan(&t.ID, &t.CreatedAt, &t.UpdatedAt)
}

func (r *PostgresSecurityDeviceTokenRepository) RevokeDeviceToken(ctx context.Context, userID int64, deviceID string) error {
	query := `
		UPDATE security_device_tokens
		SET is_active = false, updated_at = NOW()
		WHERE user_id = $1 AND device_id = $2
	`
	_, err := r.db.ExecContext(ctx, query, userID, deviceID)
	return err
}

func (r *PostgresSecurityDeviceTokenRepository) DeactivateTokenByValue(ctx context.Context, tokenValue string) error {
	query := `
		UPDATE security_device_tokens
		SET is_active = false, updated_at = NOW()
		WHERE device_token = $1
	`
	_, err := r.db.ExecContext(ctx, query, tokenValue)
	return err
}

func (r *PostgresSecurityDeviceTokenRepository) GetActiveTokensForNeighborhood(ctx context.Context, neighborhoodID int64) ([]entity.SecurityDeviceToken, error) {
	// Query tokens ONLY for active security users with active assignments in this neighborhood
	query := `
		SELECT sdt.id, sdt.user_id, sdt.device_id, sdt.device_token, sdt.platform, sdt.is_active, sdt.last_seen_at, sdt.created_at, sdt.updated_at
		FROM security_device_tokens sdt
		JOIN security_assignments sa ON sdt.user_id = sa.user_id
		JOIN users u ON sdt.user_id = u.id
		WHERE sa.neighborhood_id = $1
		  AND sa.is_active = true
		  AND u.status = 'active'
		  AND sdt.is_active = true
	`
	rows, err := r.db.QueryContext(ctx, query, neighborhoodID)
	if err != nil {
		return nil, fmt.Errorf("failed querying security device tokens: %w", err)
	}
	defer rows.Close()

	var tokens []entity.SecurityDeviceToken
	for rows.Next() {
		var t entity.SecurityDeviceToken
		if err := rows.Scan(
			&t.ID, &t.UserID, &t.DeviceID, &t.DeviceToken, &t.Platform,
			&t.IsActive, &t.LastSeenAt, &t.CreatedAt, &t.UpdatedAt,
		); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, nil
}

func (r *PostgresSecurityDeviceTokenRepository) GetActiveTokensForUser(ctx context.Context, userID int64) ([]entity.SecurityDeviceToken, error) {
	query := `
		SELECT id, user_id, device_id, device_token, platform, is_active, last_seen_at, created_at, updated_at
		FROM security_device_tokens
		WHERE user_id = $1 AND is_active = true
	`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []entity.SecurityDeviceToken
	for rows.Next() {
		var t entity.SecurityDeviceToken
		if err := rows.Scan(
			&t.ID, &t.UserID, &t.DeviceID, &t.DeviceToken, &t.Platform,
			&t.IsActive, &t.LastSeenAt, &t.CreatedAt, &t.UpdatedAt,
		); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, nil
}
