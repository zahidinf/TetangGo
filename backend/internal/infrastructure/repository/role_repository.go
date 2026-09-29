package repository

import (
	"context"
	"database/sql"
	"errors"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type postgresRoleRepository struct {
	db *sql.DB
}

func NewPostgresRoleRepository(db *sql.DB) repository.RoleRepository {
	return &postgresRoleRepository{db: db}
}

func (r *postgresRoleRepository) GetByName(ctx context.Context, name string) (*entity.Role, error) {
	query := `SELECT id, name FROM roles WHERE name = $1`
	var role entity.Role
	err := r.db.QueryRowContext(ctx, query, name).Scan(&role.ID, &role.Name)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &role, nil
}

func (r *postgresRoleRepository) GetAll(ctx context.Context) ([]entity.Role, error) {
	query := `SELECT id, name FROM roles ORDER BY id ASC`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var roles []entity.Role
	for rows.Next() {
		var role entity.Role
		if err := rows.Scan(&role.ID, &role.Name); err != nil {
			return nil, err
		}
		roles = append(roles, role)
	}
	return roles, nil
}
