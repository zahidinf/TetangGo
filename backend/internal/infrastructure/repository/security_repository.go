package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type PostgresSecurityRepository struct {
	db *sql.DB
}

func NewPostgresSecurityRepository(db *sql.DB) repository.SecurityRepository {
	return &PostgresSecurityRepository{db: db}
}

// Neighborhoods

func (r *PostgresSecurityRepository) GetNeighborhoodByID(ctx context.Context, id int64) (*entity.Neighborhood, error) {
	query := `
		SELECT id, name, COALESCE(code, ''), COALESCE(address, ''), created_at, updated_at
		FROM neighborhoods
		WHERE id = $1
	`
	row := r.db.QueryRowContext(ctx, query, id)

	var n entity.Neighborhood
	err := row.Scan(&n.ID, &n.Name, &n.Code, &n.Address, &n.CreatedAt, &n.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed getting neighborhood %d: %w", id, err)
	}
	return &n, nil
}

func (r *PostgresSecurityRepository) GetAllNeighborhoods(ctx context.Context) ([]entity.Neighborhood, error) {
	query := `
		SELECT id, name, COALESCE(code, ''), COALESCE(address, ''), created_at, updated_at
		FROM neighborhoods
		ORDER BY id ASC
	`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed querying neighborhoods: %w", err)
	}
	defer rows.Close()

	list := make([]entity.Neighborhood, 0)
	for rows.Next() {
		var n entity.Neighborhood
		if err := rows.Scan(&n.ID, &n.Name, &n.Code, &n.Address, &n.CreatedAt, &n.UpdatedAt); err != nil {
			return nil, fmt.Errorf("failed scanning neighborhood: %w", err)
		}
		list = append(list, n)
	}
	return list, nil
}

func (r *PostgresSecurityRepository) CreateNeighborhood(ctx context.Context, n *entity.Neighborhood) error {
	query := `
		INSERT INTO neighborhoods (name, code, address, created_at, updated_at)
		VALUES ($1, $2, $3, NOW(), NOW())
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query, n.Name, n.Code, n.Address).Scan(&n.ID, &n.CreatedAt, &n.UpdatedAt)
}

// Security Users

func (r *PostgresSecurityRepository) GetSecurityUsers(ctx context.Context) ([]entity.User, error) {
	query := `
		SELECT 
			u.id, COALESCE(u.salutation, 'Bapak'), u.name, u.phone, u.email, u.password_hash,
			u.role_id, r.name, u.house_id, u.status, COALESCE(u.ownership_status, ''),
			u.rejection_reason, u.profile_photo_url, u.created_at, u.updated_at
		FROM users u
		JOIN roles r ON u.role_id = r.id
		WHERE r.name = 'SECURITY'
		ORDER BY u.name ASC
	`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed querying security users: %w", err)
	}
	defer rows.Close()

	list := make([]entity.User, 0)
	for rows.Next() {
		var u entity.User
		var houseID sql.NullInt64
		err := rows.Scan(
			&u.ID, &u.Salutation, &u.Name, &u.Phone, &u.Email, &u.PasswordHash,
			&u.RoleID, &u.RoleName, &houseID, &u.Status, &u.OwnershipStatus,
			&u.RejectionReason, &u.ProfilePhotoURL, &u.CreatedAt, &u.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed scanning security user: %w", err)
		}
		if houseID.Valid {
			val := houseID.Int64
			u.HouseID = &val
		}
		list = append(list, u)
	}
	return list, nil
}

// Assignments

func (r *PostgresSecurityRepository) CreateAssignment(ctx context.Context, a *entity.SecurityAssignment) error {
	query := `
		INSERT INTO security_assignments (user_id, neighborhood_id, is_active, assigned_by, assigned_at, notes, created_at, updated_at)
		VALUES ($1, $2, $3, $4, NOW(), $5, NOW(), NOW())
		ON CONFLICT (user_id, neighborhood_id) 
		DO UPDATE SET 
			is_active = EXCLUDED.is_active,
			assigned_by = EXCLUDED.assigned_by,
			assigned_at = NOW(),
			revoked_at = NULL,
			revoked_by = NULL,
			notes = EXCLUDED.notes,
			updated_at = NOW()
		RETURNING id, assigned_at, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query,
		a.UserID,
		a.NeighborhoodID,
		a.IsActive,
		a.AssignedBy,
		a.Notes,
	).Scan(&a.ID, &a.AssignedAt, &a.CreatedAt, &a.UpdatedAt)
}

func (r *PostgresSecurityRepository) GetAssignmentByID(ctx context.Context, id int64) (*entity.SecurityAssignment, error) {
	query := `
		SELECT 
			sa.id, sa.user_id, sa.neighborhood_id, sa.is_active, sa.assigned_by,
			COALESCE(u_assigner.name, '') AS assigned_by_name,
			sa.assigned_at, sa.revoked_at, sa.revoked_by,
			COALESCE(u_revoker.name, '') AS revoked_by_name,
			COALESCE(sa.notes, ''), sa.created_at, sa.updated_at,
			u.name, u.phone, u.email, u.status,
			n.name, COALESCE(n.code, ''), COALESCE(n.address, '')
		FROM security_assignments sa
		JOIN users u ON sa.user_id = u.id
		JOIN neighborhoods n ON sa.neighborhood_id = n.id
		LEFT JOIN users u_assigner ON sa.assigned_by = u_assigner.id
		LEFT JOIN users u_revoker ON sa.revoked_by = u_revoker.id
		WHERE sa.id = $1
	`
	row := r.db.QueryRowContext(ctx, query, id)

	var a entity.SecurityAssignment
	var assignedBy, revokedBy sql.NullInt64
	var revokedAt sql.NullTime
	var uName, uPhone, uEmail, uStatus string
	var nName, nCode, nAddress string

	err := row.Scan(
		&a.ID, &a.UserID, &a.NeighborhoodID, &a.IsActive, &assignedBy,
		&a.AssignedByName,
		&a.AssignedAt, &revokedAt, &revokedBy,
		&a.RevokedByName,
		&a.Notes, &a.CreatedAt, &a.UpdatedAt,
		&uName, &uPhone, &uEmail, &uStatus,
		&nName, &nCode, &nAddress,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed getting security assignment %d: %w", id, err)
	}

	if assignedBy.Valid {
		val := assignedBy.Int64
		a.AssignedBy = &val
	}
	if revokedBy.Valid {
		val := revokedBy.Int64
		a.RevokedBy = &val
	}
	if revokedAt.Valid {
		a.RevokedAt = &revokedAt.Time
	}

	a.User = &entity.User{
		ID:     a.UserID,
		Name:   uName,
		Phone:  uPhone,
		Email:  uEmail,
		Status: uStatus,
	}
	a.Neighborhood = &entity.Neighborhood{
		ID:      a.NeighborhoodID,
		Name:    nName,
		Code:    nCode,
		Address: nAddress,
	}

	return &a, nil
}

func (r *PostgresSecurityRepository) GetAssignments(ctx context.Context, userID *int64, neighborhoodID *int64, activeOnly *bool) ([]entity.SecurityAssignment, error) {
	whereClauses := []string{"1=1"}
	args := []interface{}{}
	argIdx := 1

	if userID != nil {
		whereClauses = append(whereClauses, fmt.Sprintf("sa.user_id = $%d", argIdx))
		args = append(args, *userID)
		argIdx++
	}

	if neighborhoodID != nil {
		whereClauses = append(whereClauses, fmt.Sprintf("sa.neighborhood_id = $%d", argIdx))
		args = append(args, *neighborhoodID)
		argIdx++
	}

	if activeOnly != nil {
		whereClauses = append(whereClauses, fmt.Sprintf("sa.is_active = $%d", argIdx))
		args = append(args, *activeOnly)
		argIdx++
	}

	whereSQL := strings.Join(whereClauses, " AND ")

	query := fmt.Sprintf(`
		SELECT 
			sa.id, sa.user_id, sa.neighborhood_id, sa.is_active, sa.assigned_by,
			COALESCE(u_assigner.name, '') AS assigned_by_name,
			sa.assigned_at, sa.revoked_at, sa.revoked_by,
			COALESCE(u_revoker.name, '') AS revoked_by_name,
			COALESCE(sa.notes, ''), sa.created_at, sa.updated_at,
			u.name, u.phone, u.email, u.status,
			n.name, COALESCE(n.code, ''), COALESCE(n.address, '')
		FROM security_assignments sa
		JOIN users u ON sa.user_id = u.id
		JOIN neighborhoods n ON sa.neighborhood_id = n.id
		LEFT JOIN users u_assigner ON sa.assigned_by = u_assigner.id
		LEFT JOIN users u_revoker ON sa.revoked_by = u_revoker.id
		WHERE %s
		ORDER BY sa.is_active DESC, sa.assigned_at DESC
	`, whereSQL)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed querying security assignments: %w", err)
	}
	defer rows.Close()

	list := make([]entity.SecurityAssignment, 0)
	for rows.Next() {
		var a entity.SecurityAssignment
		var assignedBy, revokedBy sql.NullInt64
		var revokedAt sql.NullTime
		var uName, uPhone, uEmail, uStatus string
		var nName, nCode, nAddress string

		err := rows.Scan(
			&a.ID, &a.UserID, &a.NeighborhoodID, &a.IsActive, &assignedBy,
			&a.AssignedByName,
			&a.AssignedAt, &revokedAt, &revokedBy,
			&a.RevokedByName,
			&a.Notes, &a.CreatedAt, &a.UpdatedAt,
			&uName, &uPhone, &uEmail, &uStatus,
			&nName, &nCode, &nAddress,
		)
		if err != nil {
			return nil, fmt.Errorf("failed scanning security assignment: %w", err)
		}

		if assignedBy.Valid {
			val := assignedBy.Int64
			a.AssignedBy = &val
		}
		if revokedBy.Valid {
			val := revokedBy.Int64
			a.RevokedBy = &val
		}
		if revokedAt.Valid {
			a.RevokedAt = &revokedAt.Time
		}

		a.User = &entity.User{
			ID:     a.UserID,
			Name:   uName,
			Phone:  uPhone,
			Email:  uEmail,
			Status: uStatus,
		}
		a.Neighborhood = &entity.Neighborhood{
			ID:      a.NeighborhoodID,
			Name:    nName,
			Code:    nCode,
			Address: nAddress,
		}

		list = append(list, a)
	}
	return list, nil
}

func (r *PostgresSecurityRepository) UpdateAssignmentStatus(ctx context.Context, id int64, isActive bool, notes string) error {
	query := `
		UPDATE security_assignments
		SET is_active = $1, notes = COALESCE(NULLIF($2, ''), notes), updated_at = NOW()
		WHERE id = $3
	`
	res, err := r.db.ExecContext(ctx, query, isActive, notes, id)
	if err != nil {
		return fmt.Errorf("failed updating assignment status: %w", err)
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *PostgresSecurityRepository) RevokeAssignment(ctx context.Context, id int64, revokedBy int64, notes string) error {
	query := `
		UPDATE security_assignments
		SET is_active = false, revoked_at = NOW(), revoked_by = $1, notes = COALESCE(NULLIF($2, ''), notes), updated_at = NOW()
		WHERE id = $3
	`
	res, err := r.db.ExecContext(ctx, query, revokedBy, notes, id)
	if err != nil {
		return fmt.Errorf("failed revoking assignment: %w", err)
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *PostgresSecurityRepository) HasActiveAssignmentInNeighborhood(ctx context.Context, userID int64, neighborhoodID int64) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1 FROM security_assignments sa
			JOIN users u ON sa.user_id = u.id
			WHERE sa.user_id = $1 
			  AND sa.neighborhood_id = $2 
			  AND sa.is_active = true
			  AND u.status = 'active'
		)
	`
	var exists bool
	err := r.db.QueryRowContext(ctx, query, userID, neighborhoodID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("failed checking active assignment: %w", err)
	}
	return exists, nil
}

func (r *PostgresSecurityRepository) GetActiveNeighborhoodIDsForUser(ctx context.Context, userID int64) ([]int64, error) {
	query := `
		SELECT sa.neighborhood_id
		FROM security_assignments sa
		JOIN users u ON sa.user_id = u.id
		WHERE sa.user_id = $1 
		  AND sa.is_active = true
		  AND u.status = 'active'
		ORDER BY sa.neighborhood_id ASC
	`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed getting active neighborhoods for user: %w", err)
	}
	defer rows.Close()

	ids := make([]int64, 0)
	for rows.Next() {
		var id int64
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("failed scanning neighborhood id: %w", err)
		}
		ids = append(ids, id)
	}
	return ids, nil
}
