package repository

import (
	"context"
	"database/sql"
	"errors"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type postgresVehicleRepository struct {
	db *sql.DB
}

func NewPostgresVehicleRepository(db *sql.DB) repository.VehicleRepository {
	return &postgresVehicleRepository{db: db}
}

func (r *postgresVehicleRepository) GetByHouseID(ctx context.Context, houseID int64) ([]entity.Vehicle, error) {
	query := `
		SELECT id, house_id, plate_number, vehicle_type, brand_model, created_at
		FROM vehicles
		WHERE house_id = $1
		ORDER BY created_at ASC
	`
	rows, err := r.db.QueryContext(ctx, query, houseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var vehicles []entity.Vehicle
	for rows.Next() {
		var v entity.Vehicle
		var brandModel sql.NullString
		if err := rows.Scan(&v.ID, &v.HouseID, &v.PlateNumber, &v.VehicleType, &brandModel, &v.CreatedAt); err != nil {
			return nil, err
		}
		if brandModel.Valid {
			v.BrandModel = &brandModel.String
		}
		vehicles = append(vehicles, v)
	}

	if vehicles == nil {
		vehicles = []entity.Vehicle{}
	}
	return vehicles, nil
}

func (r *postgresVehicleRepository) Create(ctx context.Context, v *entity.Vehicle) error {
	query := `
		INSERT INTO vehicles (house_id, plate_number, vehicle_type, brand_model, created_at)
		VALUES ($1, $2, $3, $4, NOW())
		RETURNING id, created_at
	`
	return r.db.QueryRowContext(ctx, query, v.HouseID, v.PlateNumber, v.VehicleType, v.BrandModel).Scan(&v.ID, &v.CreatedAt)
}

func (r *postgresVehicleRepository) Delete(ctx context.Context, id int64, houseID int64) error {
	query := `DELETE FROM vehicles WHERE id = $1 AND house_id = $2`
	res, err := r.db.ExecContext(ctx, query, id, houseID)
	if err != nil {
		return err
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return errors.New("kendaraan tidak ditemukan atau bukan milik rumah Anda")
	}
	return nil
}
