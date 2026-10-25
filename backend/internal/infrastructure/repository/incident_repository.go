package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

var (
	ErrIncidentConflict = repository.ErrIncidentConflict
	ErrIncidentNotFound = repository.ErrIncidentNotFound
)

type PostgresIncidentRepository struct {
	db *sql.DB
}

func NewPostgresIncidentRepository(db *sql.DB) repository.IncidentRepository {
	return &PostgresIncidentRepository{db: db}
}

func (r *PostgresIncidentRepository) CreateIncident(ctx context.Context, inc *entity.Incident) error {
	status := inc.Status
	if status == "" {
		status = string(entity.IncidentStatusActive)
	}

	query := `
		INSERT INTO incidents (
			category, reporter_id, house_id, neighborhood_id, title, description,
			latitude, longitude, location_source, location_accuracy,
			reported_at, status, created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), $11, NOW(), NOW())
		RETURNING id, reported_at, status, created_at, updated_at
	`
	return r.db.QueryRowContext(ctx, query,
		inc.Category,
		inc.ReporterID,
		inc.HouseID,
		inc.NeighborhoodID,
		inc.Title,
		inc.Description,
		inc.Latitude,
		inc.Longitude,
		inc.LocationSource,
		inc.LocationAccuracy,
		status,
	).Scan(&inc.ID, &inc.ReportedAt, &inc.Status, &inc.CreatedAt, &inc.UpdatedAt)
}

func (r *PostgresIncidentRepository) CreateIncidentTx(ctx context.Context, inc *entity.Incident, log *entity.IncidentLog) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed starting transaction: %w", err)
	}
	defer tx.Rollback()

	status := inc.Status
	if status == "" {
		status = string(entity.IncidentStatusActive)
	}

	query := `
		INSERT INTO incidents (
			category, reporter_id, house_id, neighborhood_id, title, description,
			latitude, longitude, location_source, location_accuracy,
			reported_at, status, created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), $11, NOW(), NOW())
		RETURNING id, reported_at, status, created_at, updated_at
	`
	err = tx.QueryRowContext(ctx, query,
		inc.Category,
		inc.ReporterID,
		inc.HouseID,
		inc.NeighborhoodID,
		inc.Title,
		inc.Description,
		inc.Latitude,
		inc.Longitude,
		inc.LocationSource,
		inc.LocationAccuracy,
		status,
	).Scan(&inc.ID, &inc.ReportedAt, &inc.Status, &inc.CreatedAt, &inc.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed inserting incident: %w", err)
	}

	if log != nil {
		log.IncidentID = inc.ID
		logQuery := `
			INSERT INTO incident_logs (incident_id, user_id, action, previous_status, new_status, notes, created_at)
			VALUES ($1, $2, $3, $4, $5, $6, NOW())
			RETURNING id, created_at
		`
		err = tx.QueryRowContext(ctx, logQuery,
			log.IncidentID,
			log.UserID,
			log.Action,
			log.PreviousStatus,
			log.NewStatus,
			log.Notes,
		).Scan(&log.ID, &log.CreatedAt)
		if err != nil {
			return fmt.Errorf("failed inserting incident audit log: %w", err)
		}
	}

	return tx.Commit()
}

func (r *PostgresIncidentRepository) GetIncidentByID(ctx context.Context, id int64) (*entity.Incident, error) {
	query := `
		SELECT 
			i.id, i.category, i.reporter_id, i.house_id, i.neighborhood_id,
			COALESCE(i.title, ''), i.description,
			i.latitude, i.longitude, i.location_source, i.location_accuracy,
			i.reported_at, i.status,
			i.assigned_security_id, i.handling_started_at, i.resolved_at, i.resolution_notes,
			i.created_at, i.updated_at,
			u_rep.name, u_rep.phone, u_rep.email,
			h.block, h.house_number,
			n.name, COALESCE(n.code, ''), COALESCE(n.address, ''),
			u_sec.name, u_sec.phone
		FROM incidents i
		JOIN users u_rep ON i.reporter_id = u_rep.id
		JOIN neighborhoods n ON i.neighborhood_id = n.id
		LEFT JOIN houses h ON i.house_id = h.id
		LEFT JOIN users u_sec ON i.assigned_security_id = u_sec.id
		WHERE i.id = $1
	`
	row := r.db.QueryRowContext(ctx, query, id)

	var inc entity.Incident
	var houseID, secID sql.NullInt64
	var startedAt, resolvedAt sql.NullTime
	var resNotes, locSource sql.NullString
	var lat, lon, locAcc sql.NullFloat64
	var repName, repPhone, repEmail string
	var hBlock, hNum sql.NullString
	var nName, nCode, nAddress string
	var secName, secPhone sql.NullString

	err := row.Scan(
		&inc.ID, &inc.Category, &inc.ReporterID, &houseID, &inc.NeighborhoodID,
		&inc.Title, &inc.Description,
		&lat, &lon, &locSource, &locAcc,
		&inc.ReportedAt, &inc.Status,
		&secID, &startedAt, &resolvedAt, &resNotes,
		&inc.CreatedAt, &inc.UpdatedAt,
		&repName, &repPhone, &repEmail,
		&hBlock, &hNum,
		&nName, &nCode, &nAddress,
		&secName, &secPhone,
	)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("failed getting incident %d: %w", id, err)
	}

	if houseID.Valid {
		val := houseID.Int64
		inc.HouseID = &val
	}
	if secID.Valid {
		val := secID.Int64
		inc.AssignedSecurityID = &val
	}
	if startedAt.Valid {
		inc.HandlingStartedAt = &startedAt.Time
	}
	if resolvedAt.Valid {
		inc.ResolvedAt = &resolvedAt.Time
	}
	if resNotes.Valid {
		inc.ResolutionNotes = &resNotes.String
	}
	if locSource.Valid {
		inc.LocationSource = &locSource.String
	}
	if lat.Valid {
		inc.Latitude = &lat.Float64
	}
	if lon.Valid {
		inc.Longitude = &lon.Float64
	}
	if locAcc.Valid {
		inc.LocationAccuracy = &locAcc.Float64
	}

	inc.Reporter = &entity.User{
		ID:    inc.ReporterID,
		Name:  repName,
		Phone: repPhone,
		Email: repEmail,
	}

	if inc.HouseID != nil {
		inc.House = &entity.House{
			ID:          *inc.HouseID,
			Block:       hBlock.String,
			HouseNumber: hNum.String,
		}
	}

	inc.Neighborhood = &entity.Neighborhood{
		ID:      inc.NeighborhoodID,
		Name:    nName,
		Code:    nCode,
		Address: nAddress,
	}

	if inc.AssignedSecurityID != nil {
		inc.AssignedSecurity = &entity.User{
			ID:    *inc.AssignedSecurityID,
			Name:  secName.String,
			Phone: secPhone.String,
		}
	}

	return &inc, nil
}

func (r *PostgresIncidentRepository) GetIncidents(ctx context.Context, filter entity.IncidentFilter) (*entity.IncidentListResult, error) {
	whereClauses := []string{"1=1"}
	args := []interface{}{}
	argIdx := 1

	if filter.Category != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("i.category = $%d", argIdx))
		args = append(args, strings.ToUpper(strings.TrimSpace(filter.Category)))
		argIdx++
	}

	if filter.Status != "" {
		st := strings.ToUpper(strings.TrimSpace(filter.Status))
		// support alias mapping
		if st == "ACTIVE" || st == "REPORTED" {
			whereClauses = append(whereClauses, fmt.Sprintf("i.status IN ('ACTIVE', 'REPORTED')"))
		} else if st == "ACKNOWLEDGED" || st == "RESPONDING" {
			whereClauses = append(whereClauses, fmt.Sprintf("i.status IN ('ACKNOWLEDGED', 'RESPONDING')"))
		} else {
			whereClauses = append(whereClauses, fmt.Sprintf("i.status = $%d", argIdx))
			args = append(args, st)
			argIdx++
		}
	} else if len(filter.Statuses) > 0 {
		placeholders := make([]string, len(filter.Statuses))
		for i, s := range filter.Statuses {
			placeholders[i] = fmt.Sprintf("$%d", argIdx)
			args = append(args, strings.ToUpper(strings.TrimSpace(s)))
			argIdx++
		}
		whereClauses = append(whereClauses, fmt.Sprintf("i.status IN (%s)", strings.Join(placeholders, ", ")))
	}

	if filter.ReporterID != nil {
		whereClauses = append(whereClauses, fmt.Sprintf("i.reporter_id = $%d", argIdx))
		args = append(args, *filter.ReporterID)
		argIdx++
	}

	if filter.SecurityID != nil {
		whereClauses = append(whereClauses, fmt.Sprintf("i.assigned_security_id = $%d", argIdx))
		args = append(args, *filter.SecurityID)
		argIdx++
	}

	if filter.NeighborhoodID != nil {
		whereClauses = append(whereClauses, fmt.Sprintf("i.neighborhood_id = $%d", argIdx))
		args = append(args, *filter.NeighborhoodID)
		argIdx++
	} else if len(filter.NeighborhoodIDs) > 0 {
		placeholders := make([]string, len(filter.NeighborhoodIDs))
		for i, nid := range filter.NeighborhoodIDs {
			placeholders[i] = fmt.Sprintf("$%d", argIdx)
			args = append(args, nid)
			argIdx++
		}
		whereClauses = append(whereClauses, fmt.Sprintf("i.neighborhood_id IN (%s)", strings.Join(placeholders, ", ")))
	}

	if filter.StartDate != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("i.reported_at >= $%d", argIdx))
		args = append(args, filter.StartDate)
		argIdx++
	}

	if filter.EndDate != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("i.reported_at <= $%d", argIdx))
		args = append(args, filter.EndDate)
		argIdx++
	}

	whereSQL := strings.Join(whereClauses, " AND ")

	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM incidents i WHERE %s", whereSQL)
	var total int
	err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, fmt.Errorf("failed counting incidents: %w", err)
	}

	limit := filter.Limit
	if limit <= 0 {
		limit = 20
	}
	page := filter.Page
	if page <= 0 {
		page = 1
	}
	offset := (page - 1) * limit
	totalPages := int(math.Ceil(float64(total) / float64(limit)))
	if totalPages == 0 {
		totalPages = 1
	}

	query := fmt.Sprintf(`
		SELECT 
			i.id, i.category, i.reporter_id, i.house_id, i.neighborhood_id,
			COALESCE(i.title, ''), i.description,
			i.latitude, i.longitude, i.location_source, i.location_accuracy,
			i.reported_at, i.status,
			i.assigned_security_id, i.handling_started_at, i.resolved_at, i.resolution_notes,
			i.created_at, i.updated_at,
			u_rep.name, u_rep.phone, u_rep.email,
			h.block, h.house_number,
			n.name, COALESCE(n.code, ''), COALESCE(n.address, ''),
			u_sec.name, u_sec.phone
		FROM incidents i
		JOIN users u_rep ON i.reporter_id = u_rep.id
		JOIN neighborhoods n ON i.neighborhood_id = n.id
		LEFT JOIN houses h ON i.house_id = h.id
		LEFT JOIN users u_sec ON i.assigned_security_id = u_sec.id
		WHERE %s
		ORDER BY 
			CASE 
				WHEN UPPER(i.status) IN ('ACTIVE', 'REPORTED', 'DILAPORKAN') THEN 1
				WHEN UPPER(i.status) IN ('RESPONDING', 'ACKNOWLEDGED', 'SEDANG DITANGANI') THEN 2
				WHEN UPPER(i.status) IN ('RESOLVED', 'TERKENDALI') THEN 3
				ELSE 4
			END ASC,
			i.reported_at DESC,
			i.id DESC
		LIMIT $%d OFFSET $%d
	`, whereSQL, argIdx, argIdx+1)

	queryArgs := append(args, limit, offset)
	rows, err := r.db.QueryContext(ctx, query, queryArgs...)
	if err != nil {
		return nil, fmt.Errorf("failed querying incidents: %w", err)
	}
	defer rows.Close()

	list := make([]entity.Incident, 0)
	for rows.Next() {
		var inc entity.Incident
		var houseID, secID sql.NullInt64
		var startedAt, resolvedAt sql.NullTime
		var resNotes, locSource sql.NullString
		var lat, lon, locAcc sql.NullFloat64
		var repName, repPhone, repEmail string
		var hBlock, hNum sql.NullString
		var nName, nCode, nAddress string
		var secName, secPhone sql.NullString

		err := rows.Scan(
			&inc.ID, &inc.Category, &inc.ReporterID, &houseID, &inc.NeighborhoodID,
			&inc.Title, &inc.Description,
			&lat, &lon, &locSource, &locAcc,
			&inc.ReportedAt, &inc.Status,
			&secID, &startedAt, &resolvedAt, &resNotes,
			&inc.CreatedAt, &inc.UpdatedAt,
			&repName, &repPhone, &repEmail,
			&hBlock, &hNum,
			&nName, &nCode, &nAddress,
			&secName, &secPhone,
		)
		if err != nil {
			return nil, fmt.Errorf("failed scanning incident: %w", err)
		}

		if houseID.Valid {
			val := houseID.Int64
			inc.HouseID = &val
		}
		if secID.Valid {
			val := secID.Int64
			inc.AssignedSecurityID = &val
		}
		if startedAt.Valid {
			inc.HandlingStartedAt = &startedAt.Time
		}
		if resolvedAt.Valid {
			inc.ResolvedAt = &resolvedAt.Time
		}
		if resNotes.Valid {
			inc.ResolutionNotes = &resNotes.String
		}
		if locSource.Valid {
			inc.LocationSource = &locSource.String
		}
		if lat.Valid {
			inc.Latitude = &lat.Float64
		}
		if lon.Valid {
			inc.Longitude = &lon.Float64
		}
		if locAcc.Valid {
			inc.LocationAccuracy = &locAcc.Float64
		}

		inc.Reporter = &entity.User{
			ID:    inc.ReporterID,
			Name:  repName,
			Phone: repPhone,
			Email: repEmail,
		}

		if inc.HouseID != nil {
			inc.House = &entity.House{
				ID:          *inc.HouseID,
				Block:       hBlock.String,
				HouseNumber: hNum.String,
			}
		}

		inc.Neighborhood = &entity.Neighborhood{
			ID:      inc.NeighborhoodID,
			Name:    nName,
			Code:    nCode,
			Address: nAddress,
		}

		if inc.AssignedSecurityID != nil {
			inc.AssignedSecurity = &entity.User{
				ID:    *inc.AssignedSecurityID,
				Name:  secName.String,
				Phone: secPhone.String,
			}
		}

		list = append(list, inc)
	}

	return &entity.IncidentListResult{
		Incidents:  list,
		Total:      total,
		Page:       page,
		Limit:      limit,
		TotalPages: totalPages,
	}, nil
}

func (r *PostgresIncidentRepository) GetActiveIncidents(ctx context.Context, neighborhoodIDs []int64) ([]entity.Incident, error) {
	if len(neighborhoodIDs) == 0 {
		return []entity.Incident{}, nil
	}

	placeholders := make([]string, len(neighborhoodIDs))
	args := make([]interface{}, len(neighborhoodIDs))
	for i, nid := range neighborhoodIDs {
		placeholders[i] = fmt.Sprintf("$%d", i+1)
		args[i] = nid
	}

	query := fmt.Sprintf(`
		SELECT 
			i.id, i.category, i.reporter_id, i.house_id, i.neighborhood_id,
			COALESCE(i.title, ''), i.description,
			i.latitude, i.longitude, i.location_source, i.location_accuracy,
			i.reported_at, i.status,
			i.assigned_security_id, i.handling_started_at, i.resolved_at, i.resolution_notes,
			i.created_at, i.updated_at,
			u_rep.name, u_rep.phone, u_rep.email,
			h.block, h.house_number,
			n.name, COALESCE(n.code, ''), COALESCE(n.address, ''),
			u_sec.name, u_sec.phone
		FROM incidents i
		JOIN users u_rep ON i.reporter_id = u_rep.id
		JOIN neighborhoods n ON i.neighborhood_id = n.id
		LEFT JOIN houses h ON i.house_id = h.id
		LEFT JOIN users u_sec ON i.assigned_security_id = u_sec.id
		WHERE i.neighborhood_id IN (%s)
		  AND i.status IN ('ACTIVE', 'ACKNOWLEDGED', 'REPORTED', 'RESPONDING')
		ORDER BY 
			CASE 
				WHEN UPPER(i.status) IN ('ACTIVE', 'REPORTED', 'DILAPORKAN') THEN 1
				WHEN UPPER(i.status) IN ('RESPONDING', 'ACKNOWLEDGED', 'SEDANG DITANGANI') THEN 2
				WHEN UPPER(i.status) IN ('RESOLVED', 'TERKENDALI') THEN 3
				ELSE 4
			END ASC,
			i.reported_at DESC,
			i.id DESC
	`, strings.Join(placeholders, ", "))

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed querying active incidents: %w", err)
	}
	defer rows.Close()

	list := make([]entity.Incident, 0)
	for rows.Next() {
		var inc entity.Incident
		var houseID, secID sql.NullInt64
		var startedAt, resolvedAt sql.NullTime
		var resNotes, locSource sql.NullString
		var lat, lon, locAcc sql.NullFloat64
		var repName, repPhone, repEmail string
		var hBlock, hNum sql.NullString
		var nName, nCode, nAddress string
		var secName, secPhone sql.NullString

		err := rows.Scan(
			&inc.ID, &inc.Category, &inc.ReporterID, &houseID, &inc.NeighborhoodID,
			&inc.Title, &inc.Description,
			&lat, &lon, &locSource, &locAcc,
			&inc.ReportedAt, &inc.Status,
			&secID, &startedAt, &resolvedAt, &resNotes,
			&inc.CreatedAt, &inc.UpdatedAt,
			&repName, &repPhone, &repEmail,
			&hBlock, &hNum,
			&nName, &nCode, &nAddress,
			&secName, &secPhone,
		)
		if err != nil {
			return nil, fmt.Errorf("failed scanning active incident: %w", err)
		}

		if houseID.Valid {
			val := houseID.Int64
			inc.HouseID = &val
		}
		if secID.Valid {
			val := secID.Int64
			inc.AssignedSecurityID = &val
		}
		if startedAt.Valid {
			inc.HandlingStartedAt = &startedAt.Time
		}
		if resolvedAt.Valid {
			inc.ResolvedAt = &resolvedAt.Time
		}
		if resNotes.Valid {
			inc.ResolutionNotes = &resNotes.String
		}
		if locSource.Valid {
			inc.LocationSource = &locSource.String
		}
		if lat.Valid {
			inc.Latitude = &lat.Float64
		}
		if lon.Valid {
			inc.Longitude = &lon.Float64
		}
		if locAcc.Valid {
			inc.LocationAccuracy = &locAcc.Float64
		}

		inc.Reporter = &entity.User{
			ID:    inc.ReporterID,
			Name:  repName,
			Phone: repPhone,
			Email: repEmail,
		}

		if inc.HouseID != nil {
			inc.House = &entity.House{
				ID:          *inc.HouseID,
				Block:       hBlock.String,
				HouseNumber: hNum.String,
			}
		}

		inc.Neighborhood = &entity.Neighborhood{
			ID:      inc.NeighborhoodID,
			Name:    nName,
			Code:    nCode,
			Address: nAddress,
		}

		if inc.AssignedSecurityID != nil {
			inc.AssignedSecurity = &entity.User{
				ID:    *inc.AssignedSecurityID,
				Name:  secName.String,
				Phone: secPhone.String,
			}
		}

		list = append(list, inc)
	}

	return list, nil
}

func (r *PostgresIncidentRepository) AcknowledgeIncidentTx(ctx context.Context, incidentID int64, securityID int64, startedAt time.Time, log *entity.IncidentLog) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed starting transaction: %w", err)
	}
	defer tx.Rollback()

	// Row-level lock FOR UPDATE
	var currentStatus string
	var assignedSecID sql.NullInt64
	lockQuery := `
		SELECT status, assigned_security_id
		FROM incidents
		WHERE id = $1
		FOR UPDATE
	`
	err = tx.QueryRowContext(ctx, lockQuery, incidentID).Scan(&currentStatus, &assignedSecID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return sql.ErrNoRows
		}
		return fmt.Errorf("failed locking incident row: %w", err)
	}

	// Verify status: must be ACTIVE or REPORTED to be acknowledged
	if currentStatus != string(entity.IncidentStatusActive) && currentStatus != string(entity.IncidentStatusReported) {
		return ErrIncidentConflict
	}

	newStatus := string(entity.IncidentStatusAcknowledged)
	updateQuery := `
		UPDATE incidents
		SET status = $1, assigned_security_id = $2, handling_started_at = $3, updated_at = NOW()
		WHERE id = $4
	`
	_, err = tx.ExecContext(ctx, updateQuery, newStatus, securityID, startedAt, incidentID)
	if err != nil {
		return fmt.Errorf("failed updating incident to acknowledged: %w", err)
	}

	if log != nil {
		log.IncidentID = incidentID
		log.UserID = securityID
		log.Action = "ACKNOWLEDGED"
		log.PreviousStatus = currentStatus
		log.NewStatus = newStatus

		logQuery := `
			INSERT INTO incident_logs (incident_id, user_id, action, previous_status, new_status, notes, created_at)
			VALUES ($1, $2, $3, $4, $5, $6, NOW())
		`
		_, err = tx.ExecContext(ctx, logQuery,
			log.IncidentID,
			log.UserID,
			log.Action,
			log.PreviousStatus,
			log.NewStatus,
			log.Notes,
		)
		if err != nil {
			return fmt.Errorf("failed inserting acknowledge audit log: %w", err)
		}
	}

	return tx.Commit()
}

func (r *PostgresIncidentRepository) ResolveIncidentTx(ctx context.Context, incidentID int64, actorID int64, resolvedAt time.Time, resolutionNotes string, log *entity.IncidentLog) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed starting transaction: %w", err)
	}
	defer tx.Rollback()

	// Row-level lock FOR UPDATE
	var currentStatus string
	var assignedSecID sql.NullInt64
	lockQuery := `
		SELECT status, assigned_security_id
		FROM incidents
		WHERE id = $1
		FOR UPDATE
	`
	err = tx.QueryRowContext(ctx, lockQuery, incidentID).Scan(&currentStatus, &assignedSecID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return sql.ErrNoRows
		}
		return fmt.Errorf("failed locking incident row: %w", err)
	}

	// Verify status: terminal states cannot be re-resolved
	if currentStatus == string(entity.IncidentStatusResolved) || currentStatus == string(entity.IncidentStatusCancelled) {
		return ErrIncidentConflict
	}

	newStatus := string(entity.IncidentStatusResolved)
	updateQuery := `
		UPDATE incidents
		SET status = $1, 
		    resolved_at = $2, 
		    resolution_notes = $3, 
		    assigned_security_id = COALESCE(assigned_security_id, $4),
		    handling_started_at = COALESCE(handling_started_at, $2),
		    updated_at = NOW()
		WHERE id = $5
	`
	_, err = tx.ExecContext(ctx, updateQuery, newStatus, resolvedAt, resolutionNotes, actorID, incidentID)
	if err != nil {
		return fmt.Errorf("failed updating incident to resolved: %w", err)
	}

	if log != nil {
		log.IncidentID = incidentID
		log.UserID = actorID
		log.Action = "RESOLVED"
		log.PreviousStatus = currentStatus
		log.NewStatus = newStatus

		logQuery := `
			INSERT INTO incident_logs (incident_id, user_id, action, previous_status, new_status, notes, created_at)
			VALUES ($1, $2, $3, $4, $5, $6, NOW())
		`
		_, err = tx.ExecContext(ctx, logQuery,
			log.IncidentID,
			log.UserID,
			log.Action,
			log.PreviousStatus,
			log.NewStatus,
			log.Notes,
		)
		if err != nil {
			return fmt.Errorf("failed inserting resolve audit log: %w", err)
		}
	}

	return tx.Commit()
}

func (r *PostgresIncidentRepository) UpdateIncidentStatus(
	ctx context.Context,
	id int64,
	status string,
	securityID *int64,
	startedAt *time.Time,
	resolvedAt *time.Time,
	resolutionNotes *string,
) error {
	query := `
		UPDATE incidents
		SET 
			status = $1,
			assigned_security_id = COALESCE($2, assigned_security_id),
			handling_started_at = COALESCE($3, handling_started_at),
			resolved_at = COALESCE($4, resolved_at),
			resolution_notes = COALESCE($5, resolution_notes),
			updated_at = NOW()
		WHERE id = $6
	`
	res, err := r.db.ExecContext(ctx, query, status, securityID, startedAt, resolvedAt, resolutionNotes, id)
	if err != nil {
		return fmt.Errorf("failed updating incident status: %w", err)
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *PostgresIncidentRepository) CreateIncidentLog(ctx context.Context, l *entity.IncidentLog) error {
	query := `
		INSERT INTO incident_logs (incident_id, user_id, action, previous_status, new_status, notes, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW())
		RETURNING id, created_at
	`
	return r.db.QueryRowContext(ctx, query,
		l.IncidentID,
		l.UserID,
		l.Action,
		l.PreviousStatus,
		l.NewStatus,
		l.Notes,
	).Scan(&l.ID, &l.CreatedAt)
}

func (r *PostgresIncidentRepository) GetIncidentLogs(ctx context.Context, incidentID int64) ([]entity.IncidentLog, error) {
	query := `
		SELECT 
			il.id, il.incident_id, il.user_id, il.action,
			COALESCE(il.previous_status, ''), COALESCE(il.new_status, ''),
			COALESCE(il.notes, ''), il.created_at,
			u.name, r.name
		FROM incident_logs il
		JOIN users u ON il.user_id = u.id
		JOIN roles r ON u.role_id = r.id
		WHERE il.incident_id = $1
		ORDER BY il.created_at ASC
	`
	rows, err := r.db.QueryContext(ctx, query, incidentID)
	if err != nil {
		return nil, fmt.Errorf("failed querying incident logs: %w", err)
	}
	defer rows.Close()

	list := make([]entity.IncidentLog, 0)
	for rows.Next() {
		var l entity.IncidentLog
		err := rows.Scan(
			&l.ID, &l.IncidentID, &l.UserID, &l.Action,
			&l.PreviousStatus, &l.NewStatus,
			&l.Notes, &l.CreatedAt,
			&l.UserName, &l.UserRole,
		)
		if err != nil {
			return nil, fmt.Errorf("failed scanning incident log: %w", err)
		}
		list = append(list, l)
	}
	return list, nil
}

func (r *PostgresIncidentRepository) CountActiveIncidents(ctx context.Context, neighborhoodIDs []int64) (int64, error) {
	query := `
		SELECT COUNT(*)
		FROM incidents
		WHERE status IN ('ACTIVE', 'ACKNOWLEDGED', 'REPORTED', 'RESPONDING')
	`
	args := []interface{}{}
	if len(neighborhoodIDs) > 0 {
		placeholders := make([]string, len(neighborhoodIDs))
		for i, nid := range neighborhoodIDs {
			placeholders[i] = fmt.Sprintf("$%d", i+1)
			args = append(args, nid)
		}
		query += fmt.Sprintf(" AND neighborhood_id IN (%s)", strings.Join(placeholders, ", "))
	}

	var count int64
	err := r.db.QueryRowContext(ctx, query, args...).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("failed counting active incidents: %w", err)
	}
	return count, nil
}

func (r *PostgresIncidentRepository) CorrectIncidentTx(
	ctx context.Context,
	incidentID int64,
	adminID int64,
	newStatus *string,
	newCategory *string,
	newTitle *string,
	newDescription *string,
	notes string,
	log *entity.IncidentLog,
) (*entity.Incident, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed starting transaction: %w", err)
	}
	defer tx.Rollback()

	var currentStatus, currentCategory, currentTitle, currentDesc string
	var currentResolvedAt *time.Time
	var currentResolutionNotes *string

	selectQuery := `
		SELECT status, category, COALESCE(title, ''), COALESCE(description, ''), resolved_at, resolution_notes
		FROM incidents
		WHERE id = $1
		FOR UPDATE
	`
	err = tx.QueryRowContext(ctx, selectQuery, incidentID).
		Scan(&currentStatus, &currentCategory, &currentTitle, &currentDesc, &currentResolvedAt, &currentResolutionNotes)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrIncidentNotFound
		}
		return nil, fmt.Errorf("failed locking incident %d: %w", incidentID, err)
	}

	finalStatus := currentStatus
	if newStatus != nil && strings.TrimSpace(*newStatus) != "" {
		st := strings.ToUpper(strings.TrimSpace(*newStatus))
		if st == "DILAPORKAN" {
			st = string(entity.IncidentStatusActive)
		} else if st == "SEDANG DITANGANI" {
			st = string(entity.IncidentStatusResponding)
		} else if st == "TERKENDALI" {
			st = string(entity.IncidentStatusResolved)
		}
		finalStatus = st
	}

	finalCategory := currentCategory
	if newCategory != nil && strings.TrimSpace(*newCategory) != "" {
		finalCategory = strings.ToUpper(strings.TrimSpace(*newCategory))
	}

	finalTitle := currentTitle
	if newTitle != nil && strings.TrimSpace(*newTitle) != "" {
		finalTitle = strings.TrimSpace(*newTitle)
	}

	finalDesc := currentDesc
	if newDescription != nil {
		finalDesc = strings.TrimSpace(*newDescription)
	}

	var finalResolvedAt *time.Time
	var finalResolutionNotes *string

	if finalStatus == string(entity.IncidentStatusResolved) {
		if currentResolvedAt != nil {
			finalResolvedAt = currentResolvedAt
		} else {
			now := time.Now()
			finalResolvedAt = &now
		}

		if currentResolutionNotes != nil && strings.TrimSpace(*currentResolutionNotes) != "" {
			finalResolutionNotes = currentResolutionNotes
		} else if strings.TrimSpace(notes) != "" {
			trimmedNotes := strings.TrimSpace(notes)
			finalResolutionNotes = &trimmedNotes
		}
	} else {
		finalResolvedAt = nil
		finalResolutionNotes = nil
	}

	updateQuery := `
		UPDATE incidents
		SET status = $1,
		    category = $2,
		    title = $3,
		    description = $4,
		    resolved_at = $5,
		    resolution_notes = $6,
		    updated_at = NOW()
		WHERE id = $7
	`
	_, err = tx.ExecContext(ctx, updateQuery, finalStatus, finalCategory, finalTitle, finalDesc, finalResolvedAt, finalResolutionNotes, incidentID)
	if err != nil {
		return nil, fmt.Errorf("failed updating incident: %w", err)
	}

	if log != nil {
		log.IncidentID = incidentID
		log.UserID = adminID
		log.Action = "CORRECTED"
		log.PreviousStatus = currentStatus
		log.NewStatus = finalStatus

		logQuery := `
			INSERT INTO incident_logs (incident_id, user_id, action, previous_status, new_status, notes, created_at)
			VALUES ($1, $2, $3, $4, $5, $6, NOW())
		`
		_, err = tx.ExecContext(ctx, logQuery,
			log.IncidentID,
			log.UserID,
			log.Action,
			log.PreviousStatus,
			log.NewStatus,
			log.Notes,
		)
		if err != nil {
			return nil, fmt.Errorf("failed inserting correction audit log: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("failed committing correction tx: %w", err)
	}

	return r.GetIncidentByID(ctx, incidentID)
}
