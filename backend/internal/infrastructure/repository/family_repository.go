package repository

import (
	"context"
	"database/sql"
	"errors"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type postgresFamilyRepository struct {
	db *sql.DB
}

func NewPostgresFamilyRepository(db *sql.DB) repository.FamilyRepository {
	return &postgresFamilyRepository{db: db}
}

func (r *postgresFamilyRepository) GetByHouseID(ctx context.Context, houseID int64) ([]entity.FamilyMember, error) {
	query := `
		SELECT id, house_id, name, relation, phone, created_at
		FROM family_members
		WHERE house_id = $1
		ORDER BY created_at ASC
	`
	rows, err := r.db.QueryContext(ctx, query, houseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []entity.FamilyMember
	for rows.Next() {
		var m entity.FamilyMember
		var phone sql.NullString
		if err := rows.Scan(&m.ID, &m.HouseID, &m.Name, &m.Relation, &phone, &m.CreatedAt); err != nil {
			return nil, err
		}
		if phone.Valid {
			m.Phone = &phone.String
		}
		members = append(members, m)
	}

	if members == nil {
		members = []entity.FamilyMember{}
	}
	return members, nil
}

func (r *postgresFamilyRepository) Create(ctx context.Context, m *entity.FamilyMember) error {
	query := `
		INSERT INTO family_members (house_id, name, relation, phone, created_at)
		VALUES ($1, $2, $3, $4, NOW())
		RETURNING id, created_at
	`
	return r.db.QueryRowContext(ctx, query, m.HouseID, m.Name, m.Relation, m.Phone).Scan(&m.ID, &m.CreatedAt)
}

func (r *postgresFamilyRepository) Delete(ctx context.Context, id int64, houseID int64) error {
	query := `DELETE FROM family_members WHERE id = $1 AND house_id = $2`
	res, err := r.db.ExecContext(ctx, query, id, houseID)
	if err != nil {
		return err
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return errors.New("anggota keluarga tidak ditemukan atau bukan milik rumah Anda")
	}
	return nil
}
