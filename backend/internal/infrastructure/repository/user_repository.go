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

type postgresUserRepository struct {
	db *sql.DB
}

func NewPostgresUserRepository(db *sql.DB) repository.UserRepository {
	return &postgresUserRepository{db: db}
}

func (r *postgresUserRepository) GetByID(ctx context.Context, id int64) (*entity.User, error) {
	query := `
		SELECT 
			u.id, COALESCE(u.salutation, 'Bapak'), u.name, u.phone, u.email, u.password_hash, u.role_id, r.name,
			u.house_id, u.status, COALESCE(u.ownership_status, 'pemilik'),
			u.rejection_reason, u.profile_photo_url, u.created_at, u.updated_at,
			h.id, h.block, h.house_number, h.status
		FROM users u
		JOIN roles r ON u.role_id = r.id
		LEFT JOIN houses h ON u.house_id = h.id
		WHERE u.id = $1
	`
	row := r.db.QueryRowContext(ctx, query, id)

	var u entity.User
	var houseID sql.NullInt64
	var hID sql.NullInt64
	var hBlock, hNumber, hStatus sql.NullString

	err := row.Scan(
		&u.ID, &u.Salutation, &u.Name, &u.Phone, &u.Email, &u.PasswordHash,
		&u.RoleID, &u.RoleName, &houseID, &u.Status, &u.OwnershipStatus,
		&u.RejectionReason, &u.ProfilePhotoURL, &u.CreatedAt, &u.UpdatedAt,
		&hID, &hBlock, &hNumber, &hStatus,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	u.Salutation = entity.NormalizeSalutation(u.Salutation)
	if houseID.Valid {
		val := houseID.Int64
		u.HouseID = &val
	}
	if hID.Valid {
		u.House = &entity.House{
			ID:          hID.Int64,
			Block:       hBlock.String,
			HouseNumber: hNumber.String,
			Status:      hStatus.String,
		}
	}

	return &u, nil
}

func (r *postgresUserRepository) GetByEmailOrPhone(ctx context.Context, identifier string) (*entity.User, error) {
	query := `
		SELECT 
			u.id, COALESCE(u.salutation, 'Bapak'), u.name, u.phone, u.email, u.password_hash, u.role_id, r.name,
			u.house_id, u.status, COALESCE(u.ownership_status, 'pemilik'),
			u.rejection_reason, u.profile_photo_url, u.created_at, u.updated_at,
			h.id, h.block, h.house_number, h.status
		FROM users u
		JOIN roles r ON u.role_id = r.id
		LEFT JOIN houses h ON u.house_id = h.id
		WHERE u.email = $1 OR u.phone = $1
	`
	row := r.db.QueryRowContext(ctx, query, identifier)

	var u entity.User
	var houseID sql.NullInt64
	var hID sql.NullInt64
	var hBlock, hNumber, hStatus sql.NullString

	err := row.Scan(
		&u.ID, &u.Salutation, &u.Name, &u.Phone, &u.Email, &u.PasswordHash,
		&u.RoleID, &u.RoleName, &houseID, &u.Status, &u.OwnershipStatus,
		&u.RejectionReason, &u.ProfilePhotoURL, &u.CreatedAt, &u.UpdatedAt,
		&hID, &hBlock, &hNumber, &hStatus,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}

	u.Salutation = entity.NormalizeSalutation(u.Salutation)
	if houseID.Valid {
		val := houseID.Int64
		u.HouseID = &val
	}
	if hID.Valid {
		u.House = &entity.House{
			ID:          hID.Int64,
			Block:       hBlock.String,
			HouseNumber: hNumber.String,
			Status:      hStatus.String,
		}
	}

	return &u, nil
}

func (r *postgresUserRepository) Create(ctx context.Context, u *entity.User) error {
	u.Salutation = entity.NormalizeSalutation(u.Salutation)
	query := `
		INSERT INTO users (salutation, name, phone, email, password_hash, role_id, house_id, status, ownership_status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW())
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(
		ctx, query,
		u.Salutation, u.Name, u.Phone, u.Email, u.PasswordHash, u.RoleID, u.HouseID, u.Status, u.OwnershipStatus,
	).Scan(&u.ID, &u.CreatedAt, &u.UpdatedAt)
}

func (r *postgresUserRepository) UpdateProfile(ctx context.Context, id int64, name, phone string, photoURL *string) error {
	query := `
		UPDATE users 
		SET name = $1, phone = $2, profile_photo_url = $3, updated_at = NOW()
		WHERE id = $4
	`
	_, err := r.db.ExecContext(ctx, query, name, phone, photoURL, id)
	return err
}

func (r *postgresUserRepository) GetPendingUsers(ctx context.Context) ([]entity.PendingUser, error) {
	query := `
		SELECT 
			u.id, COALESCE(u.salutation, 'Bapak'), u.name, u.phone, u.email, r.name, u.house_id,
			COALESCE(h.block, ''), COALESCE(h.house_number, ''),
			COALESCE(u.ownership_status, 'pemilik'), u.status, u.created_at
		FROM users u
		JOIN roles r ON u.role_id = r.id
		LEFT JOIN houses h ON u.house_id = h.id
		WHERE u.status = 'pending_verification'
		ORDER BY u.created_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []entity.PendingUser
	for rows.Next() {
		var pu entity.PendingUser
		var houseID sql.NullInt64
		if err := rows.Scan(
			&pu.ID, &pu.Salutation, &pu.Name, &pu.Phone, &pu.Email, &pu.RoleName, &houseID,
			&pu.HouseBlock, &pu.HouseNumber, &pu.OwnershipStatus, &pu.Status, &pu.CreatedAt,
		); err != nil {
			return nil, err
		}
		pu.Salutation = entity.NormalizeSalutation(pu.Salutation)
		if houseID.Valid {
			val := houseID.Int64
			pu.HouseID = &val
		}
		result = append(result, pu)
	}

	if result == nil {
		result = []entity.PendingUser{}
	}
	return result, nil
}

func (r *postgresUserRepository) UpdateStatus(ctx context.Context, id int64, status string, rejectionReason *string) error {
	query := `
		UPDATE users 
		SET status = $1, rejection_reason = $2, updated_at = NOW()
		WHERE id = $3
	`
	res, err := r.db.ExecContext(ctx, query, status, rejectionReason, id)
	if err != nil {
		return err
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *postgresUserRepository) CountPending(ctx context.Context) (int, error) {
	var count int
	err := r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM users WHERE status = 'pending_verification'").Scan(&count)
	return count, err
}

func (r *postgresUserRepository) GetUnassignedResidents(ctx context.Context, search string) ([]entity.UnassignedResident, error) {
	query := `
		SELECT u.id, COALESCE(u.salutation, 'Bapak'), u.name, u.phone, u.email, r.name, u.status, u.created_at
		FROM users u
		JOIN roles r ON u.role_id = r.id
		WHERE u.house_id IS NULL AND u.status = 'active'
	`
	var args []interface{}
	if search != "" {
		query += " AND (u.name ILIKE $1 OR u.phone ILIKE $1 OR u.email ILIKE $1)"
		args = append(args, "%"+search+"%")
	}
	query += " ORDER BY u.name ASC"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var residents []entity.UnassignedResident
	for rows.Next() {
		var res entity.UnassignedResident
		if err := rows.Scan(
			&res.ID, &res.Salutation, &res.Name, &res.Phone, &res.Email, &res.Role, &res.Status, &res.CreatedAt,
		); err != nil {
			return nil, err
		}
		res.Salutation = entity.NormalizeSalutation(res.Salutation)
		residents = append(residents, res)
	}

	if residents == nil {
		residents = []entity.UnassignedResident{}
	}
	return residents, nil
}

func (r *postgresUserRepository) AssignHouse(ctx context.Context, userID int64, houseID int64, occupantType string) error {
	query := `
		UPDATE users
		SET house_id = $1, ownership_status = $2, updated_at = NOW()
		WHERE id = $3
	`
	res, err := r.db.ExecContext(ctx, query, houseID, occupantType, userID)
	if err != nil {
		return err
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return errors.New("pengguna tidak ditemukan")
	}
	return nil
}

func (r *postgresUserRepository) UnassignHouse(ctx context.Context, userID int64, houseID int64) error {
	query := `
		UPDATE users
		SET house_id = NULL, updated_at = NOW()
		WHERE id = $1 AND house_id = $2
	`
	res, err := r.db.ExecContext(ctx, query, userID, houseID)
	if err != nil {
		return err
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return errors.New("warga tidak terdaftar pada rumah ini")
	}
	return nil
}

func (r *postgresUserRepository) GetOccupantsByHouseID(ctx context.Context, houseID int64) ([]entity.HouseOccupant, error) {
	query := `
		SELECT u.id, COALESCE(u.salutation, 'Bapak'), u.name, u.phone, u.email, r.name, COALESCE(u.ownership_status, 'pemilik'), u.created_at
		FROM users u
		JOIN roles r ON u.role_id = r.id
		WHERE u.house_id = $1 AND u.status = 'active'
		ORDER BY u.created_at ASC
	`
	rows, err := r.db.QueryContext(ctx, query, houseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var occupants []entity.HouseOccupant
	for rows.Next() {
		var o entity.HouseOccupant
		if err := rows.Scan(
			&o.ID, &o.Salutation, &o.Name, &o.Phone, &o.Email, &o.Role, &o.OwnershipStatus, &o.CreatedAt,
		); err != nil {
			return nil, err
		}
		o.Salutation = entity.NormalizeSalutation(o.Salutation)
		occupants = append(occupants, o)
	}

	if occupants == nil {
		occupants = []entity.HouseOccupant{}
	}
	return occupants, nil
}

func (r *postgresUserRepository) CountOccupantsByHouseID(ctx context.Context, houseID int64) (int, error) {
	var count int
	err := r.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM users WHERE house_id = $1 AND status = 'active'", houseID).Scan(&count)
	return count, err
}

func (r *postgresUserRepository) Update(ctx context.Context, user *entity.User) error {
	user.Salutation = entity.NormalizeSalutation(user.Salutation)
	query := `
		UPDATE users
		SET salutation = $1, name = $2, phone = $3, email = $4, role_id = $5, house_id = $6,
		    status = $7, ownership_status = $8, updated_at = NOW()
		WHERE id = $9
	`
	res, err := r.db.ExecContext(ctx, query,
		user.Salutation,
		user.Name,
		user.Phone,
		user.Email,
		user.RoleID,
		user.HouseID,
		user.Status,
		user.OwnershipStatus,
		user.ID,
	)
	if err != nil {
		return err
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return errors.New("pengguna tidak ditemukan")
	}
	return nil
}

func (r *postgresUserRepository) Delete(ctx context.Context, id int64) error {
	query := `DELETE FROM users WHERE id = $1`
	res, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return err
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return errors.New("pengguna tidak ditemukan")
	}
	return nil
}

func (r *postgresUserRepository) UpdatePassword(ctx context.Context, id int64, passwordHash string) error {
	query := `UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`
	res, err := r.db.ExecContext(ctx, query, passwordHash, id)
	if err != nil {
		return err
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return errors.New("pengguna tidak ditemukan")
	}
	return nil
}

func (r *postgresUserRepository) GetAllUsers(ctx context.Context, search, status, role string, houseID *int64) ([]entity.User, error) {
	query := `
		SELECT 
			u.id, COALESCE(u.salutation, 'Bapak'), u.name, u.phone, u.email, u.role_id, r.name AS role_name,
			u.house_id, u.status, COALESCE(u.ownership_status, ''),
			u.profile_photo_url, u.created_at, u.updated_at,
			h.id, h.block, h.house_number, h.status
		FROM users u
		JOIN roles r ON u.role_id = r.id
		LEFT JOIN houses h ON u.house_id = h.id
	`
	var conditions []string
	var args []interface{}
	argIdx := 1

	if search != "" {
		conditions = append(conditions, fmt.Sprintf("(u.name ILIKE $%d OR u.phone ILIKE $%d OR u.email ILIKE $%d)", argIdx, argIdx, argIdx))
		args = append(args, "%"+search+"%")
		argIdx++
	}
	if status != "" && strings.ToLower(status) != "semua" && strings.ToLower(status) != "all" {
		conditions = append(conditions, fmt.Sprintf("u.status = $%d", argIdx))
		args = append(args, status)
		argIdx++
	}
	if role != "" && strings.ToLower(role) != "semua" && strings.ToLower(role) != "all" {
		conditions = append(conditions, fmt.Sprintf("r.name = $%d", argIdx))
		args = append(args, role)
		argIdx++
	}
	if houseID != nil {
		conditions = append(conditions, fmt.Sprintf("u.house_id = $%d", argIdx))
		args = append(args, *houseID)
		argIdx++
	}

	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}

	query += " ORDER BY u.created_at DESC"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []entity.User
	for rows.Next() {
		var u entity.User
		var hID sql.NullInt64
		var hBlock, hNumber, hStatus sql.NullString
		var houseIDVal sql.NullInt64

		if err := rows.Scan(
			&u.ID, &u.Salutation, &u.Name, &u.Phone, &u.Email, &u.RoleID, &u.RoleName,
			&houseIDVal, &u.Status, &u.OwnershipStatus,
			&u.ProfilePhotoURL, &u.CreatedAt, &u.UpdatedAt,
			&hID, &hBlock, &hNumber, &hStatus,
		); err != nil {
			return nil, err
		}

		u.Salutation = entity.NormalizeSalutation(u.Salutation)

		if houseIDVal.Valid {
			val := houseIDVal.Int64
			u.HouseID = &val
		}

		if hID.Valid {
			u.House = &entity.House{
				ID:          hID.Int64,
				Block:       hBlock.String,
				HouseNumber: hNumber.String,
				Status:      hStatus.String,
			}
		}

		users = append(users, u)
	}

	if users == nil {
		users = []entity.User{}
	}
	return users, nil
}
