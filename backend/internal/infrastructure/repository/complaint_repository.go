package repository

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"tetanggo-backend/internal/domain/entity"
)

type PostgresComplaintRepository struct {
	db *sql.DB
}

func NewPostgresComplaintRepository(db *sql.DB) *PostgresComplaintRepository {
	return &PostgresComplaintRepository{db: db}
}

func (r *PostgresComplaintRepository) Create(ctx context.Context, comp *entity.Complaint) error {
	query := `
		INSERT INTO complaints (
			ticket_number, user_id, house_id, title, description, category, photo_url, status, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, created_at, updated_at
	`
	now := time.Now()
	if comp.CreatedAt.IsZero() {
		comp.CreatedAt = now
	}
	comp.UpdatedAt = now

	return r.db.QueryRowContext(
		ctx,
		query,
		comp.TicketNumber,
		comp.UserID,
		comp.HouseID,
		comp.Title,
		comp.Description,
		string(comp.Category),
		comp.PhotoURL,
		string(comp.Status),
		comp.CreatedAt,
		comp.UpdatedAt,
	).Scan(&comp.ID, &comp.CreatedAt, &comp.UpdatedAt)
}

func (r *PostgresComplaintRepository) GetByID(ctx context.Context, id int64) (*entity.Complaint, error) {
	query := `
		SELECT 
			c.id, c.ticket_number, c.user_id, c.house_id, c.title, c.description,
			c.category, c.photo_url, c.status, c.created_at, c.updated_at,
			u.name AS reporter_name,
			h.block AS house_block,
			h.house_number AS house_number,
			c.assigned_officer,
			c.assigned_officer_id,
			c.assigned_at
		FROM complaints c
		JOIN users u ON u.id = c.user_id
		JOIN houses h ON h.id = c.house_id
		WHERE c.id = $1
	`
	var comp entity.Complaint
	var catStr, statusStr string
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&comp.ID,
		&comp.TicketNumber,
		&comp.UserID,
		&comp.HouseID,
		&comp.Title,
		&comp.Description,
		&catStr,
		&comp.PhotoURL,
		&statusStr,
		&comp.CreatedAt,
		&comp.UpdatedAt,
		&comp.ReporterName,
		&comp.HouseBlock,
		&comp.HouseNumber,
		&comp.AssignedOfficer,
		&comp.AssignedOfficerID,
		&comp.AssignedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed getting complaint by id: %w", err)
	}
	comp.Category = entity.ComplaintCategory(catStr)
	comp.Status = entity.ComplaintStatus(statusStr)
	return &comp, nil
}

func (r *PostgresComplaintRepository) GetByTicketNumber(ctx context.Context, ticket string) (*entity.Complaint, error) {
	query := `
		SELECT 
			c.id, c.ticket_number, c.user_id, c.house_id, c.title, c.description,
			c.category, c.photo_url, c.status, c.created_at, c.updated_at,
			u.name AS reporter_name,
			h.block AS house_block,
			h.house_number AS house_number,
			c.assigned_officer,
			c.assigned_officer_id,
			c.assigned_at
		FROM complaints c
		JOIN users u ON u.id = c.user_id
		JOIN houses h ON h.id = c.house_id
		WHERE c.ticket_number = $1
	`
	var comp entity.Complaint
	var catStr, statusStr string
	err := r.db.QueryRowContext(ctx, query, ticket).Scan(
		&comp.ID,
		&comp.TicketNumber,
		&comp.UserID,
		&comp.HouseID,
		&comp.Title,
		&comp.Description,
		&catStr,
		&comp.PhotoURL,
		&statusStr,
		&comp.CreatedAt,
		&comp.UpdatedAt,
		&comp.ReporterName,
		&comp.HouseBlock,
		&comp.HouseNumber,
		&comp.AssignedOfficer,
		&comp.AssignedOfficerID,
		&comp.AssignedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed getting complaint by ticket: %w", err)
	}
	comp.Category = entity.ComplaintCategory(catStr)
	comp.Status = entity.ComplaintStatus(statusStr)
	return &comp, nil
}

func (r *PostgresComplaintRepository) GetByPhotoFilename(ctx context.Context, filename string) (*entity.Complaint, error) {
	query := `
		SELECT 
			c.id, c.ticket_number, c.user_id, c.house_id, c.title, c.description,
			c.category, c.photo_url, c.status, c.created_at, c.updated_at,
			u.name AS reporter_name,
			h.block AS house_block,
			h.house_number AS house_number,
			c.assigned_officer,
			c.assigned_officer_id,
			c.assigned_at
		FROM complaints c
		JOIN users u ON u.id = c.user_id
		JOIN houses h ON h.id = c.house_id
		WHERE c.photo_url LIKE $1
		LIMIT 1
	`
	suffix := "%" + filename
	var comp entity.Complaint
	var catStr, statusStr string
	err := r.db.QueryRowContext(ctx, query, suffix).Scan(
		&comp.ID,
		&comp.TicketNumber,
		&comp.UserID,
		&comp.HouseID,
		&comp.Title,
		&comp.Description,
		&catStr,
		&comp.PhotoURL,
		&statusStr,
		&comp.CreatedAt,
		&comp.UpdatedAt,
		&comp.ReporterName,
		&comp.HouseBlock,
		&comp.HouseNumber,
		&comp.AssignedOfficer,
		&comp.AssignedOfficerID,
		&comp.AssignedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("failed getting complaint by photo filename: %w", err)
	}
	comp.Category = entity.ComplaintCategory(catStr)
	comp.Status = entity.ComplaintStatus(statusStr)
	return &comp, nil
}

func (r *PostgresComplaintRepository) ListByUser(ctx context.Context, userID int64, limit, offset int) ([]entity.Complaint, int, error) {
	if limit <= 0 {
		limit = 10
	}
	if offset < 0 {
		offset = 0
	}

	countQuery := `SELECT COUNT(*) FROM complaints WHERE user_id = $1`
	var total int
	if err := r.db.QueryRowContext(ctx, countQuery, userID).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("failed counting user complaints: %w", err)
	}

	query := `
		SELECT 
			c.id, c.ticket_number, c.user_id, c.house_id, c.title, c.description,
			c.category, c.photo_url, c.status, c.created_at, c.updated_at,
			u.name AS reporter_name,
			h.block AS house_block,
			h.house_number AS house_number,
			c.assigned_officer,
			c.assigned_officer_id,
			c.assigned_at
		FROM complaints c
		JOIN users u ON u.id = c.user_id
		JOIN houses h ON h.id = c.house_id
		WHERE c.user_id = $1
		ORDER BY c.created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.QueryContext(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("failed listing user complaints: %w", err)
	}
	defer rows.Close()

	var list []entity.Complaint
	for rows.Next() {
		var comp entity.Complaint
		var catStr, statusStr string
		if err := rows.Scan(
			&comp.ID,
			&comp.TicketNumber,
			&comp.UserID,
			&comp.HouseID,
			&comp.Title,
			&comp.Description,
			&catStr,
			&comp.PhotoURL,
			&statusStr,
			&comp.CreatedAt,
			&comp.UpdatedAt,
			&comp.ReporterName,
			&comp.HouseBlock,
			&comp.HouseNumber,
			&comp.AssignedOfficer,
			&comp.AssignedOfficerID,
			&comp.AssignedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("failed scanning complaint row: %w", err)
		}
		comp.Category = entity.ComplaintCategory(catStr)
		comp.Status = entity.ComplaintStatus(statusStr)
		list = append(list, comp)
	}

	return list, total, nil
}

// US-5.4: Pengelolaan Tiket Pengelola (Admin/Pengurus)
func (r *PostgresComplaintRepository) ListAdmin(ctx context.Context, filter entity.AdminComplaintFilter) ([]entity.Complaint, int, error) {
	if filter.Limit <= 0 {
		filter.Limit = 10
	}
	if filter.Page <= 0 {
		filter.Page = 1
	}
	offset := (filter.Page - 1) * filter.Limit

	var conditions []string
	var args []interface{}
	argIdx := 1

	if strings.TrimSpace(filter.Status) != "" {
		conditions = append(conditions, fmt.Sprintf("c.status = $%d", argIdx))
		args = append(args, strings.TrimSpace(filter.Status))
		argIdx++
	}

	if strings.TrimSpace(filter.Category) != "" {
		conditions = append(conditions, fmt.Sprintf("c.category = $%d", argIdx))
		args = append(args, strings.TrimSpace(filter.Category))
		argIdx++
	}

	if strings.TrimSpace(filter.Officer) != "" {
		conditions = append(conditions, fmt.Sprintf("c.assigned_officer ILIKE $%d", argIdx))
		args = append(args, "%"+strings.TrimSpace(filter.Officer)+"%")
		argIdx++
	}

	if strings.TrimSpace(filter.StartDate) != "" {
		conditions = append(conditions, fmt.Sprintf("c.created_at >= $%d", argIdx))
		args = append(args, strings.TrimSpace(filter.StartDate)+" 00:00:00")
		argIdx++
	}

	if strings.TrimSpace(filter.EndDate) != "" {
		conditions = append(conditions, fmt.Sprintf("c.created_at <= $%d", argIdx))
		args = append(args, strings.TrimSpace(filter.EndDate)+" 23:59:59")
		argIdx++
	}

	if strings.TrimSpace(filter.Search) != "" {
		s := "%" + strings.TrimSpace(filter.Search) + "%"
		conditions = append(conditions, fmt.Sprintf(
			"(c.title ILIKE $%d OR c.description ILIKE $%d OR c.ticket_number ILIKE $%d OR u.name ILIKE $%d)",
			argIdx, argIdx, argIdx, argIdx,
		))
		args = append(args, s)
		argIdx++
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}

	countQuery := fmt.Sprintf(`
		SELECT COUNT(*)
		FROM complaints c
		JOIN users u ON u.id = c.user_id
		JOIN houses h ON h.id = c.house_id
		%s
	`, whereClause)

	var total int
	if err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("failed counting admin complaints: %w", err)
	}

	query := fmt.Sprintf(`
		SELECT 
			c.id, c.ticket_number, c.user_id, c.house_id, c.title, c.description,
			c.category, c.photo_url, c.status, c.created_at, c.updated_at,
			u.name AS reporter_name,
			h.block AS house_block,
			h.house_number AS house_number,
			c.assigned_officer,
			c.assigned_officer_id,
			c.assigned_at
		FROM complaints c
		JOIN users u ON u.id = c.user_id
		JOIN houses h ON h.id = c.house_id
		%s
		ORDER BY c.created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argIdx, argIdx+1)

	args = append(args, filter.Limit, offset)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("failed querying admin complaints: %w", err)
	}
	defer rows.Close()

	var list []entity.Complaint
	for rows.Next() {
		var comp entity.Complaint
		var catStr, statusStr string
		if err := rows.Scan(
			&comp.ID,
			&comp.TicketNumber,
			&comp.UserID,
			&comp.HouseID,
			&comp.Title,
			&comp.Description,
			&catStr,
			&comp.PhotoURL,
			&statusStr,
			&comp.CreatedAt,
			&comp.UpdatedAt,
			&comp.ReporterName,
			&comp.HouseBlock,
			&comp.HouseNumber,
			&comp.AssignedOfficer,
			&comp.AssignedOfficerID,
			&comp.AssignedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("failed scanning admin complaint row: %w", err)
		}
		comp.Category = entity.ComplaintCategory(catStr)
		comp.Status = entity.ComplaintStatus(statusStr)
		list = append(list, comp)
	}

	return list, total, nil
}

// US-5.4: Kanban Grouping
func (r *PostgresComplaintRepository) GetKanban(ctx context.Context, filter entity.AdminComplaintFilter) (*entity.KanbanComplaintsResult, error) {
	// Re-use ListAdmin with high limit (e.g. 300) to populate Kanban columns
	filter.Limit = 300
	filter.Page = 1
	// Notice: we do not filter by single status when fetching all kanban columns, unless specified
	items, _, err := r.ListAdmin(ctx, filter)
	if err != nil {
		return nil, err
	}

	res := &entity.KanbanComplaintsResult{
		Menunggu: make([]entity.Complaint, 0),
		Diproses: make([]entity.Complaint, 0),
		Selesai:  make([]entity.Complaint, 0),
		Counts: map[string]int{
			"Menunggu": 0,
			"Diproses": 0,
			"Selesai":  0,
			"Ditolak":  0,
		},
	}

	for _, item := range items {
		res.Counts[string(item.Status)]++
		switch item.Status {
		case entity.ComplaintStatusMenunggu:
			res.Menunggu = append(res.Menunggu, item)
		case entity.ComplaintStatusDiproses:
			res.Diproses = append(res.Diproses, item)
		case entity.ComplaintStatusSelesai:
			res.Selesai = append(res.Selesai, item)
		}
	}

	return res, nil
}

// US-5.4: Penugasan Petugas dengan Audit Trail
func (r *PostgresComplaintRepository) AssignOfficer(ctx context.Context, assignment *entity.ComplaintAssignment, newStatus *string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if assignment.AssignedAt.IsZero() {
		assignment.AssignedAt = time.Now()
	}

	// 1. Insert assignment record
	insertAssignQuery := `
		INSERT INTO complaint_assignments (
			complaint_id, officer_name, officer_user_id, assigned_by, notes, assigned_at
		) VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at
	`
	err = tx.QueryRowContext(
		ctx,
		insertAssignQuery,
		assignment.ComplaintID,
		assignment.OfficerName,
		assignment.OfficerUserID,
		assignment.AssignedBy,
		assignment.Notes,
		assignment.AssignedAt,
	).Scan(&assignment.ID, &assignment.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed inserting complaint assignment: %w", err)
	}

	// 2. Update complaint table with current assigned officer
	if newStatus != nil && *newStatus != "" {
		updateQuery := `
			UPDATE complaints
			SET assigned_officer = $1, assigned_officer_id = $2, assigned_at = $3, status = $4, updated_at = NOW()
			WHERE id = $5
		`
		_, err = tx.ExecContext(ctx, updateQuery, assignment.OfficerName, assignment.OfficerUserID, assignment.AssignedAt, *newStatus, assignment.ComplaintID)
	} else {
		updateQuery := `
			UPDATE complaints
			SET assigned_officer = $1, assigned_officer_id = $2, assigned_at = $3, updated_at = NOW()
			WHERE id = $4
		`
		_, err = tx.ExecContext(ctx, updateQuery, assignment.OfficerName, assignment.OfficerUserID, assignment.AssignedAt, assignment.ComplaintID)
	}
	if err != nil {
		return fmt.Errorf("failed updating complaint assigned officer: %w", err)
	}

	return tx.Commit()
}

// US-5.4: Status Update
func (r *PostgresComplaintRepository) UpdateStatus(ctx context.Context, id int64, status entity.ComplaintStatus) error {
	query := `UPDATE complaints SET status = $1, updated_at = NOW() WHERE id = $2`
	res, err := r.db.ExecContext(ctx, query, string(status), id)
	if err != nil {
		return fmt.Errorf("failed updating complaint status: %w", err)
	}
	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("complaint not found")
	}
	return nil
}

// US-5.4: Assignment History for Audit
func (r *PostgresComplaintRepository) GetAssignmentsByComplaintID(ctx context.Context, complaintID int64) ([]entity.ComplaintAssignment, error) {
	query := `
		SELECT 
			ca.id, ca.complaint_id, ca.officer_name, ca.officer_user_id,
			ca.assigned_by, u.name AS assigned_by_name,
			COALESCE(ca.notes, ''), ca.assigned_at, ca.created_at
		FROM complaint_assignments ca
		JOIN users u ON u.id = ca.assigned_by
		WHERE ca.complaint_id = $1
		ORDER BY ca.assigned_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, complaintID)
	if err != nil {
		return nil, fmt.Errorf("failed getting complaint assignments: %w", err)
	}
	defer rows.Close()

	var list []entity.ComplaintAssignment
	for rows.Next() {
		var a entity.ComplaintAssignment
		if err := rows.Scan(
			&a.ID,
			&a.ComplaintID,
			&a.OfficerName,
			&a.OfficerUserID,
			&a.AssignedBy,
			&a.AssignedByName,
			&a.Notes,
			&a.AssignedAt,
			&a.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("failed scanning complaint assignment: %w", err)
		}
		list = append(list, a)
	}
	return list, nil
}
