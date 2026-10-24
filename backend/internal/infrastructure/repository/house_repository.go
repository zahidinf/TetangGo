package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type postgresHouseRepository struct {
	db *sql.DB
}

func NewPostgresHouseRepository(db *sql.DB) repository.HouseRepository {
	return &postgresHouseRepository{db: db}
}

func (r *postgresHouseRepository) GetAll(ctx context.Context, block, status, search string) ([]entity.House, error) {
	baseQuery := `
		SELECT 
			h.id, h.block, h.house_number, h.status,
			CASE 
				WHEN u.id IS NOT NULL THEN 
					CASE WHEN u.salutation IS NOT NULL AND u.salutation != '' THEN u.salutation || ' ' || u.name ELSE u.name END
				ELSE NULL 
			END AS resident_name,
			u.phone AS resident_phone,
			COALESCE(fm.family_count, 0) AS family_count,
			(CASE WHEN u.id IS NOT NULL THEN 1 ELSE 0 END + 
			 COALESCE(fm.family_count, 0)) AS total_occupants,
			COALESCE(v.vehicle_count, 0) AS vehicle_count
		FROM houses h
		LEFT JOIN users u ON u.house_id = h.id AND u.status = 'active'
		LEFT JOIN (
			SELECT house_id, COUNT(*) AS family_count
			FROM family_members
			GROUP BY house_id
		) fm ON fm.house_id = h.id
		LEFT JOIN (
			SELECT house_id, COUNT(*) AS vehicle_count
			FROM vehicles
			GROUP BY house_id
		) v ON v.house_id = h.id
	`

	var conditions []string
	var args []interface{}
	argIdx := 1

	if strings.TrimSpace(block) != "" && strings.ToLower(block) != "all" && strings.ToLower(block) != "semua" {
		conditions = append(conditions, fmt.Sprintf("LOWER(h.block) = LOWER($%d)", argIdx))
		args = append(args, strings.TrimSpace(block))
		argIdx++
	}

	if strings.TrimSpace(status) != "" && strings.ToLower(status) != "all" && strings.ToLower(status) != "semua" {
		conditions = append(conditions, fmt.Sprintf("LOWER(h.status) = LOWER($%d)", argIdx))
		args = append(args, strings.TrimSpace(status))
		argIdx++
	}

	if strings.TrimSpace(search) != "" {
		conditions = append(conditions, fmt.Sprintf("(h.house_number ILIKE $%d OR u.name ILIKE $%d OR h.block ILIKE $%d)", argIdx, argIdx, argIdx))
		args = append(args, "%"+strings.TrimSpace(search)+"%")
		argIdx++
	}

	if len(conditions) > 0 {
		baseQuery += " WHERE " + strings.Join(conditions, " AND ")
	}

	baseQuery += " ORDER BY h.block ASC, h.house_number ASC"

	rows, err := r.db.QueryContext(ctx, baseQuery, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var houses []entity.House
	for rows.Next() {
		var h entity.House
		var resName, resPhone sql.NullString
		if err := rows.Scan(
			&h.ID, &h.Block, &h.HouseNumber, &h.Status,
			&resName, &resPhone, &h.FamilyCount, &h.TotalOccupants, &h.VehicleCount,
		); err != nil {
			return nil, err
		}
		if resName.Valid {
			h.ResidentName = &resName.String
		}
		if resPhone.Valid {
			h.ResidentPhone = &resPhone.String
		}
		houses = append(houses, h)
	}

	if houses == nil {
		houses = []entity.House{}
	}

	return houses, nil
}

func (r *postgresHouseRepository) GetAvailable(ctx context.Context) ([]entity.House, error) {
	query := `
		SELECT id, block, house_number, status
		FROM houses
		ORDER BY block ASC, house_number ASC
	`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var houses []entity.House
	for rows.Next() {
		var h entity.House
		if err := rows.Scan(&h.ID, &h.Block, &h.HouseNumber, &h.Status); err != nil {
			return nil, err
		}
		houses = append(houses, h)
	}

	if houses == nil {
		houses = []entity.House{}
	}
	return houses, nil
}

func (r *postgresHouseRepository) GetDistinctBlocks(ctx context.Context) ([]string, error) {
	query := `
		SELECT DISTINCT block 
		FROM houses 
		WHERE block IS NOT NULL AND TRIM(block) != '' 
		ORDER BY block ASC;
	`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var blocks []string
	for rows.Next() {
		var b string
		if err := rows.Scan(&b); err != nil {
			return nil, err
		}
		blocks = append(blocks, b)
	}

	if blocks == nil {
		blocks = []string{}
	}
	return blocks, nil
}

func (r *postgresHouseRepository) GetByID(ctx context.Context, id int64) (*entity.House, error) {
	query := `
		SELECT 
			h.id, h.block, h.house_number, h.status,
			CASE 
				WHEN u.id IS NOT NULL THEN 
					CASE WHEN u.salutation IS NOT NULL AND u.salutation != '' THEN u.salutation || ' ' || u.name ELSE u.name END
				ELSE NULL 
			END AS resident_name,
			u.phone AS resident_phone,
			COALESCE((SELECT COUNT(*) FROM family_members fm WHERE fm.house_id = h.id), 0) AS family_count,
			COALESCE((SELECT COUNT(*) FROM vehicles v WHERE v.house_id = h.id), 0) AS vehicle_count
		FROM houses h
		LEFT JOIN users u ON u.house_id = h.id AND u.status = 'active'
		WHERE h.id = $1
	`
	row := r.db.QueryRowContext(ctx, query, id)

	var h entity.House
	var resName, resPhone sql.NullString
	err := row.Scan(
		&h.ID, &h.Block, &h.HouseNumber, &h.Status,
		&resName, &resPhone, &h.FamilyCount, &h.VehicleCount,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	if resName.Valid {
		h.ResidentName = &resName.String
	}
	if resPhone.Valid {
		h.ResidentPhone = &resPhone.String
	}
	return &h, nil
}

func (r *postgresHouseRepository) Create(ctx context.Context, h *entity.House) error {
	query := `
		INSERT INTO houses (block, house_number, status)
		VALUES ($1, $2, $3)
		RETURNING id
	`
	return r.db.QueryRowContext(ctx, query, h.Block, h.HouseNumber, h.Status).Scan(&h.ID)
}

func (r *postgresHouseRepository) Update(ctx context.Context, h *entity.House) error {
	query := `
		UPDATE houses 
		SET block = $1, house_number = $2, status = $3
		WHERE id = $4
	`
	res, err := r.db.ExecContext(ctx, query, h.Block, h.HouseNumber, h.Status, h.ID)
	if err != nil {
		return err
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *postgresHouseRepository) Delete(ctx context.Context, id int64) error {
	query := `DELETE FROM houses WHERE id = $1`
	res, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return err
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *postgresHouseRepository) BulkDelete(ctx context.Context, ids []int64) (int64, error) {
	if len(ids) == 0 {
		return 0, nil
	}

	idStrs := make([]string, len(ids))
	for i, id := range ids {
		idStrs[i] = strconv.FormatInt(id, 10)
	}
	arrayParam := "{" + strings.Join(idStrs, ",") + "}"

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	// Relasi warga/users yang terkait di-handle dengan aman: lepas relasi
	updateUsersQuery := `UPDATE users SET house_id = NULL WHERE house_id = ANY($1::int[])`
	if _, err := tx.ExecContext(ctx, updateUsersQuery, arrayParam); err != nil {
		return 0, err
	}

	deleteHousesQuery := `DELETE FROM houses WHERE id = ANY($1::int[])`
	res, err := tx.ExecContext(ctx, deleteHousesQuery, arrayParam)
	if err != nil {
		return 0, err
	}

	rowsAffected, err := res.RowsAffected()
	if err != nil {
		return 0, err
	}

	if err := tx.Commit(); err != nil {
		return 0, err
	}

	return rowsAffected, nil
}
