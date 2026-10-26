package repository

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
	"time"

	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

type PostgresGuestInvitationRepository struct {
	db *sql.DB
}

func NewPostgresGuestInvitationRepository(db *sql.DB) repository.GuestInvitationRepository {
	return &PostgresGuestInvitationRepository{db: db}
}

func (r *PostgresGuestInvitationRepository) Create(ctx context.Context, inv *entity.GuestInvitation) error {
	query := `
		INSERT INTO guest_invitations (
			invitation_code, host_user_id, house_id, guest_name, visit_type,
			phone, notes, valid_from, valid_until, status, qr_payload,
			qr_token_hash, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW())
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(
		ctx,
		query,
		inv.InvitationCode,
		inv.HostUserID,
		inv.HouseID,
		inv.GuestName,
		inv.VisitType,
		inv.Phone,
		inv.Notes,
		inv.ValidFrom,
		inv.ValidUntil,
		inv.Status,
		inv.QRPayload,
		inv.QRTokenHash,
	).Scan(&inv.ID, &inv.CreatedAt, &inv.UpdatedAt)
}

func (r *PostgresGuestInvitationRepository) GetByID(ctx context.Context, id int64) (*entity.GuestInvitation, error) {
	query := `
		SELECT 
			gi.id, gi.invitation_code, gi.host_user_id, gi.house_id, gi.guest_name,
			gi.visit_type, gi.phone, gi.notes, gi.valid_from, gi.valid_until,
			CASE 
				WHEN gi.status = 'ACTIVE' AND gi.valid_until < NOW() THEN 'EXPIRED'
				ELSE gi.status 
			END as status,
			gi.qr_payload, gi.qr_token_hash, gi.cancelled_at, gi.cancelled_by,
			gi.cancellation_reason, gi.created_at, gi.updated_at,
			u.name AS host_name,
			h.block AS house_block,
			h.house_number AS house_number,
			EXISTS (SELECT 1 FROM guest_visits gv WHERE gv.invitation_id = gi.id AND gv.status = 'CHECKED_IN') AS has_active_session,
			(SELECT COUNT(*) FROM guest_visits gv WHERE gv.invitation_id = gi.id AND gv.status = 'CHECKED_OUT') AS completed_visits_count
		FROM guest_invitations gi
		JOIN users u ON u.id = gi.host_user_id
		JOIN houses h ON h.id = gi.house_id
		WHERE gi.id = $1
	`
	row := r.db.QueryRowContext(ctx, query, id)
	return r.scanInvitation(row)
}

func (r *PostgresGuestInvitationRepository) GetByCode(ctx context.Context, code string) (*entity.GuestInvitation, error) {
	query := `
		SELECT 
			gi.id, gi.invitation_code, gi.host_user_id, gi.house_id, gi.guest_name,
			gi.visit_type, gi.phone, gi.notes, gi.valid_from, gi.valid_until,
			CASE 
				WHEN gi.status = 'ACTIVE' AND gi.valid_until < NOW() THEN 'EXPIRED'
				ELSE gi.status 
			END as status,
			gi.qr_payload, gi.qr_token_hash, gi.cancelled_at, gi.cancelled_by,
			gi.cancellation_reason, gi.created_at, gi.updated_at,
			u.name AS host_name,
			h.block AS house_block,
			h.house_number AS house_number,
			EXISTS (SELECT 1 FROM guest_visits gv WHERE gv.invitation_id = gi.id AND gv.status = 'CHECKED_IN') AS has_active_session,
			(SELECT COUNT(*) FROM guest_visits gv WHERE gv.invitation_id = gi.id AND gv.status = 'CHECKED_OUT') AS completed_visits_count
		FROM guest_invitations gi
		JOIN users u ON u.id = gi.host_user_id
		JOIN houses h ON h.id = gi.house_id
		WHERE gi.invitation_code = $1
	`
	row := r.db.QueryRowContext(ctx, query, code)
	return r.scanInvitation(row)
}

func (r *PostgresGuestInvitationRepository) ListByHostUserID(ctx context.Context, hostUserID int64, limit, offset int) ([]entity.GuestInvitation, int, error) {
	if limit <= 0 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}

	// First count
	countQuery := `SELECT COUNT(*) FROM guest_invitations WHERE host_user_id = $1`
	var total int
	if err := r.db.QueryRowContext(ctx, countQuery, hostUserID).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := `
		SELECT 
			gi.id, gi.invitation_code, gi.host_user_id, gi.house_id, gi.guest_name,
			gi.visit_type, gi.phone, gi.notes, gi.valid_from, gi.valid_until,
			CASE 
				WHEN gi.status = 'ACTIVE' AND gi.valid_until < NOW() THEN 'EXPIRED'
				ELSE gi.status 
			END as status,
			gi.qr_payload, gi.qr_token_hash, gi.cancelled_at, gi.cancelled_by,
			gi.cancellation_reason, gi.created_at, gi.updated_at,
			u.name AS host_name,
			h.block AS house_block,
			h.house_number AS house_number,
			EXISTS (SELECT 1 FROM guest_visits gv WHERE gv.invitation_id = gi.id AND gv.status = 'CHECKED_IN') AS has_active_session,
			(SELECT COUNT(*) FROM guest_visits gv WHERE gv.invitation_id = gi.id AND gv.status = 'CHECKED_OUT') AS completed_visits_count
		FROM guest_invitations gi
		JOIN users u ON u.id = gi.host_user_id
		JOIN houses h ON h.id = gi.house_id
		WHERE gi.host_user_id = $1
		ORDER BY gi.created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.QueryContext(ctx, query, hostUserID, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var list []entity.GuestInvitation
	for rows.Next() {
		var inv entity.GuestInvitation
		var st string
		if err := rows.Scan(
			&inv.ID, &inv.InvitationCode, &inv.HostUserID, &inv.HouseID, &inv.GuestName,
			&inv.VisitType, &inv.Phone, &inv.Notes, &inv.ValidFrom, &inv.ValidUntil,
			&st, &inv.QRPayload, &inv.QRTokenHash, &inv.CancelledAt, &inv.CancelledBy,
			&inv.CancellationReason, &inv.CreatedAt, &inv.UpdatedAt,
			&inv.HostName, &inv.HouseBlock, &inv.HouseNumber,
			&inv.HasActiveSession, &inv.CompletedVisitsCount,
		); err != nil {
			return nil, 0, err
		}
		inv.Status = entity.InvitationStatus(st)
		list = append(list, inv)
	}

	return list, total, nil
}

func (r *PostgresGuestInvitationRepository) Cancel(ctx context.Context, id int64, cancelledBy int64, reason string) error {
	query := `
		UPDATE guest_invitations
		SET status = 'CANCELLED',
		    cancelled_at = NOW(),
		    cancelled_by = $2,
		    cancellation_reason = $3,
		    updated_at = NOW()
		WHERE id = $1 AND status = 'ACTIVE'
	`
	res, err := r.db.ExecContext(ctx, query, id, cancelledBy, reason)
	if err != nil {
		return err
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return fmt.Errorf("undangan tidak dapat dibatalkan atau sudah tidak aktif")
	}
	return nil
}

func (r *PostgresGuestInvitationRepository) ExpireOutdatedInvitations(ctx context.Context) (int64, error) {
	query := `
		UPDATE guest_invitations
		SET status = 'EXPIRED', updated_at = NOW()
		WHERE status = 'ACTIVE' AND valid_until < NOW()
	`
	res, err := r.db.ExecContext(ctx, query)
	if err != nil {
		return 0, err
	}
	return res.RowsAffected()
}

func (r *PostgresGuestInvitationRepository) CheckIn(ctx context.Context, id int64) error {
	query := `
		UPDATE guest_invitations
		SET status = 'USED', updated_at = NOW()
		WHERE id = $1 AND status = 'ACTIVE' AND valid_until >= NOW()
	`
	res, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return err
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return fmt.Errorf("undangan tidak dapat di-check-in: status bukan ACTIVE atau sudah kedaluwarsa")
	}
	return nil
}

func (r *PostgresGuestInvitationRepository) Complete(ctx context.Context, id int64) error {
	query := `
		UPDATE guest_invitations
		SET status = 'COMPLETED', updated_at = NOW()
		WHERE id = $1 AND status IN ('ACTIVE', 'USED')
	`
	res, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return err
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return fmt.Errorf("undangan tidak dapat diselesaikan: status bukan ACTIVE atau USED")
	}
	return nil
}

func (r *PostgresGuestInvitationRepository) scanInvitation(row *sql.Row) (*entity.GuestInvitation, error) {
	var inv entity.GuestInvitation
	var st string
	err := row.Scan(
		&inv.ID, &inv.InvitationCode, &inv.HostUserID, &inv.HouseID, &inv.GuestName,
		&inv.VisitType, &inv.Phone, &inv.Notes, &inv.ValidFrom, &inv.ValidUntil,
		&st, &inv.QRPayload, &inv.QRTokenHash, &inv.CancelledAt, &inv.CancelledBy,
		&inv.CancellationReason, &inv.CreatedAt, &inv.UpdatedAt,
		&inv.HostName, &inv.HouseBlock, &inv.HouseNumber,
		&inv.HasActiveSession, &inv.CompletedVisitsCount,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	inv.Status = entity.InvitationStatus(st)
	return &inv, nil
}

// US-5.2 Implementation

func (r *PostgresGuestInvitationRepository) CreateVisit(ctx context.Context, visit *entity.GuestVisit) error {
	query := `
		INSERT INTO guest_visits (
			invitation_id, check_in_at, check_in_by, status, notes, created_at, updated_at
		) VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
		RETURNING id, created_at, updated_at
	`
	return r.db.QueryRowContext(
		ctx,
		query,
		visit.InvitationID,
		visit.CheckInAt,
		visit.CheckInBy,
		visit.Status,
		visit.Notes,
	).Scan(&visit.ID, &visit.CreatedAt, &visit.UpdatedAt)
}

func (r *PostgresGuestInvitationRepository) GetActiveVisitByInvitationID(ctx context.Context, invitationID int64) (*entity.GuestVisit, error) {
	query := `
		SELECT 
			gv.id, gv.invitation_id, gv.check_in_at, gv.check_in_by, gv.check_out_at, gv.check_out_by,
			gv.status, gv.notes, gv.created_at, gv.updated_at,
			gi.invitation_code, gi.guest_name, gi.visit_type,
			u_host.name AS host_name, h.block AS house_block, h.house_number,
			u_in.name AS check_in_by_name, u_out.name AS check_out_by_name
		FROM guest_visits gv
		JOIN guest_invitations gi ON gv.invitation_id = gi.id
		JOIN users u_host ON gi.host_user_id = u_host.id
		JOIN houses h ON gi.house_id = h.id
		JOIN users u_in ON gv.check_in_by = u_in.id
		LEFT JOIN users u_out ON gv.check_out_by = u_out.id
		WHERE gv.invitation_id = $1 AND gv.status = 'CHECKED_IN'
		ORDER BY gv.id DESC
		LIMIT 1
	`
	row := r.db.QueryRowContext(ctx, query, invitationID)
	return r.scanVisit(row)
}

func (r *PostgresGuestInvitationRepository) GetVisitByID(ctx context.Context, visitID int64) (*entity.GuestVisit, error) {
	query := `
		SELECT 
			gv.id, gv.invitation_id, gv.check_in_at, gv.check_in_by, gv.check_out_at, gv.check_out_by,
			gv.status, gv.notes, gv.created_at, gv.updated_at,
			gi.invitation_code, gi.guest_name, gi.visit_type,
			u_host.name AS host_name, h.block AS house_block, h.house_number,
			u_in.name AS check_in_by_name, u_out.name AS check_out_by_name
		FROM guest_visits gv
		JOIN guest_invitations gi ON gv.invitation_id = gi.id
		JOIN users u_host ON gi.host_user_id = u_host.id
		JOIN houses h ON gi.house_id = h.id
		JOIN users u_in ON gv.check_in_by = u_in.id
		LEFT JOIN users u_out ON gv.check_out_by = u_out.id
		WHERE gv.id = $1
	`
	row := r.db.QueryRowContext(ctx, query, visitID)
	return r.scanVisit(row)
}

func (r *PostgresGuestInvitationRepository) CheckOutVisit(ctx context.Context, visitID int64, checkOutBy int64, checkOutAt time.Time, notes *string) error {
	query := `
		UPDATE guest_visits
		SET status = 'CHECKED_OUT', check_out_at = $1, check_out_by = $2,
		    notes = COALESCE($3, notes), updated_at = NOW()
		WHERE id = $4 AND status = 'CHECKED_IN'
	`
	res, err := r.db.ExecContext(ctx, query, checkOutAt, checkOutBy, notes, visitID)
	if err != nil {
		return err
	}
	affected, err := res.RowsAffected()
	if err != nil {
		return err
	}
	if affected == 0 {
		return fmt.Errorf("kunjungan tidak dalam status CHECKED_IN atau sudah di-check-out")
	}
	return nil
}

func (r *PostgresGuestInvitationRepository) ListVisits(ctx context.Context, filter entity.GuestVisitFilter) ([]entity.GuestVisit, int, error) {
	whereClauses := []string{"1=1"}
	args := []interface{}{}
	argIndex := 1

	if filter.Status != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("gv.status = $%d", argIndex))
		args = append(args, strings.ToUpper(filter.Status))
		argIndex++
	}

	if filter.VisitType != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("gi.visit_type = $%d", argIndex))
		args = append(args, strings.ToUpper(filter.VisitType))
		argIndex++
	}

	if filter.Search != "" {
		pattern := "%" + strings.TrimSpace(filter.Search) + "%"
		whereClauses = append(whereClauses, fmt.Sprintf(
			"(gi.guest_name ILIKE $%d OR gi.invitation_code ILIKE $%d OR u_host.name ILIKE $%d OR h.block ILIKE $%d OR h.house_number ILIKE $%d)",
			argIndex, argIndex, argIndex, argIndex, argIndex,
		))
		args = append(args, pattern)
		argIndex++
	}

	whereSQL := strings.Join(whereClauses, " AND ")

	countQuery := fmt.Sprintf(`
		SELECT COUNT(*)
		FROM guest_visits gv
		JOIN guest_invitations gi ON gv.invitation_id = gi.id
		JOIN users u_host ON gi.host_user_id = u_host.id
		JOIN houses h ON gi.house_id = h.id
		WHERE %s
	`, whereSQL)

	var total int
	if err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	limit := filter.Limit
	if limit <= 0 {
		limit = 20
	}
	offset := filter.Offset
	if offset < 0 {
		offset = 0
	}

	dataQuery := fmt.Sprintf(`
		SELECT 
			gv.id, gv.invitation_id, gv.check_in_at, gv.check_in_by, gv.check_out_at, gv.check_out_by,
			gv.status, gv.notes, gv.created_at, gv.updated_at,
			gi.invitation_code, gi.guest_name, gi.visit_type,
			u_host.name AS host_name, h.block AS house_block, h.house_number,
			u_in.name AS check_in_by_name, u_out.name AS check_out_by_name,
			gi.status AS invitation_status, gi.valid_until
		FROM guest_visits gv
		JOIN guest_invitations gi ON gv.invitation_id = gi.id
		JOIN users u_host ON gi.host_user_id = u_host.id
		JOIN houses h ON gi.house_id = h.id
		JOIN users u_in ON gv.check_in_by = u_in.id
		LEFT JOIN users u_out ON gv.check_out_by = u_out.id
		WHERE %s
		ORDER BY gv.check_in_at DESC
		LIMIT $%d OFFSET $%d
	`, whereSQL, argIndex, argIndex+1)

	queryArgs := append(args, limit, offset)
	rows, err := r.db.QueryContext(ctx, dataQuery, queryArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var visits []entity.GuestVisit
	for rows.Next() {
		var v entity.GuestVisit
		var st string
		var checkOutBy sql.NullInt64
		var checkOutAt sql.NullTime
		var notes sql.NullString
		var checkOutByName sql.NullString
		var invSt sql.NullString
		var validUntil sql.NullTime

		err := rows.Scan(
			&v.ID, &v.InvitationID, &v.CheckInAt, &v.CheckInBy, &checkOutAt, &checkOutBy,
			&st, &notes, &v.CreatedAt, &v.UpdatedAt,
			&v.InvitationCode, &v.GuestName, &v.VisitType,
			&v.HostName, &v.HouseBlock, &v.HouseNumber,
			&v.CheckInByName, &checkOutByName,
			&invSt, &validUntil,
		)
		if err != nil {
			return nil, 0, err
		}

		v.Status = entity.VisitStatus(st)
		if checkOutBy.Valid {
			v.CheckOutBy = &checkOutBy.Int64
		}
		if checkOutAt.Valid {
			v.CheckOutAt = &checkOutAt.Time
		}
		if notes.Valid {
			v.Notes = &notes.String
		}
		if checkOutByName.Valid {
			v.CheckOutByName = &checkOutByName.String
		}
		if invSt.Valid {
			v.InvitationStatus = entity.InvitationStatus(invSt.String)
		}
		if validUntil.Valid {
			v.ValidUntil = &validUntil.Time
		}

		visits = append(visits, v)
	}

	return visits, total, nil
}

func (r *PostgresGuestInvitationRepository) ListGroupedVisits(ctx context.Context, filter entity.GuestVisitFilter) ([]entity.GuestVisitGroup, int, error) {
	whereClauses := []string{"1=1"}
	args := []interface{}{}
	argIndex := 1

	if filter.Status != "" {
		if strings.ToUpper(filter.Status) == "CHECKED_IN" {
			whereClauses = append(whereClauses, `EXISTS (SELECT 1 FROM guest_visits gv_active WHERE gv_active.invitation_id = gi.id AND gv_active.status = 'CHECKED_IN')`)
		} else if strings.ToUpper(filter.Status) == "CHECKED_OUT" {
			whereClauses = append(whereClauses, `NOT EXISTS (SELECT 1 FROM guest_visits gv_active WHERE gv_active.invitation_id = gi.id AND gv_active.status = 'CHECKED_IN')`)
		}
	}

	if filter.VisitType != "" {
		whereClauses = append(whereClauses, fmt.Sprintf("gi.visit_type = $%d", argIndex))
		args = append(args, strings.ToUpper(filter.VisitType))
		argIndex++
	}

	if filter.Search != "" {
		pattern := "%" + strings.TrimSpace(filter.Search) + "%"
		whereClauses = append(whereClauses, fmt.Sprintf(
			"(gi.guest_name ILIKE $%d OR gi.invitation_code ILIKE $%d OR u_host.name ILIKE $%d OR h.block ILIKE $%d OR h.house_number ILIKE $%d)",
			argIndex, argIndex, argIndex, argIndex, argIndex,
		))
		args = append(args, pattern)
		argIndex++
	}

	whereSQL := strings.Join(whereClauses, " AND ")

	countQuery := fmt.Sprintf(`
		SELECT COUNT(DISTINCT gi.id)
		FROM guest_invitations gi
		JOIN guest_visits gv ON gv.invitation_id = gi.id
		JOIN users u_host ON gi.host_user_id = u_host.id
		JOIN houses h ON gi.house_id = h.id
		WHERE %s
	`, whereSQL)

	var total int
	if err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	limit := filter.Limit
	if limit <= 0 {
		limit = 20
	}
	offset := filter.Offset
	if offset < 0 {
		offset = 0
	}

	invitationsQuery := fmt.Sprintf(`
		SELECT 
			gi.id, gi.invitation_code, gi.guest_name, gi.visit_type,
			u_host.name AS host_name, h.block AS house_block, h.house_number,
			gi.status, gi.valid_from, gi.valid_until, gi.phone, gi.notes,
			MIN(gv.check_in_at) AS first_check_in_at,
			MAX(COALESCE(gv.check_out_at, gv.check_in_at)) AS latest_activity_at,
			COUNT(gv.id) AS total_visits
		FROM guest_invitations gi
		JOIN guest_visits gv ON gv.invitation_id = gi.id
		JOIN users u_host ON gi.host_user_id = u_host.id
		JOIN houses h ON gi.house_id = h.id
		WHERE %s
		GROUP BY gi.id, gi.invitation_code, gi.guest_name, gi.visit_type,
		         u_host.name, h.block, h.house_number,
		         gi.status, gi.valid_from, gi.valid_until, gi.phone, gi.notes
		ORDER BY latest_activity_at DESC
		LIMIT $%d OFFSET $%d
	`, whereSQL, argIndex, argIndex+1)

	invArgs := append(args, limit, offset)
	rows, err := r.db.QueryContext(ctx, invitationsQuery, invArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var groups []entity.GuestVisitGroup
	var invIDs []int64

	for rows.Next() {
		var g entity.GuestVisitGroup
		var st string
		var phone sql.NullString
		var notes sql.NullString

		err := rows.Scan(
			&g.InvitationID, &g.InvitationCode, &g.GuestName, &g.VisitType,
			&g.HostName, &g.HouseBlock, &g.HouseNumber,
			&st, &g.ValidFrom, &g.ValidUntil, &phone, &notes,
			&g.FirstCheckInAt, &g.LatestActivityAt, &g.TotalVisits,
		)
		if err != nil {
			return nil, 0, err
		}

		g.InvitationStatus = entity.InvitationStatus(st)
		if phone.Valid {
			g.Phone = &phone.String
		}
		if notes.Valid {
			g.Notes = &notes.String
		}
		g.Visits = []entity.GuestVisit{}

		groups = append(groups, g)
		invIDs = append(invIDs, g.InvitationID)
	}

	if len(invIDs) == 0 {
		return groups, total, nil
	}

	// Fetch all visits for these grouped invitation IDs
	placeholders := make([]string, len(invIDs))
	idArgs := make([]interface{}, len(invIDs))
	for i, id := range invIDs {
		placeholders[i] = fmt.Sprintf("$%d", i+1)
		idArgs[i] = id
	}

	visitsQuery := fmt.Sprintf(`
		SELECT 
			gv.id, gv.invitation_id, gv.check_in_at, gv.check_in_by, gv.check_out_at, gv.check_out_by,
			gv.status, gv.notes, gv.created_at, gv.updated_at,
			gi.invitation_code, gi.guest_name, gi.visit_type,
			u_host.name AS host_name, h.block AS house_block, h.house_number,
			u_in.name AS check_in_by_name, u_out.name AS check_out_by_name,
			gi.status AS invitation_status, gi.valid_until
		FROM guest_visits gv
		JOIN guest_invitations gi ON gv.invitation_id = gi.id
		JOIN users u_host ON gi.host_user_id = u_host.id
		JOIN houses h ON gi.house_id = h.id
		JOIN users u_in ON gv.check_in_by = u_in.id
		LEFT JOIN users u_out ON gv.check_out_by = u_out.id
		WHERE gv.invitation_id IN (%s)
		ORDER BY gv.check_in_at ASC
	`, strings.Join(placeholders, ","))

	vRows, err := r.db.QueryContext(ctx, visitsQuery, idArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer vRows.Close()

	visitsByInv := make(map[int64][]entity.GuestVisit)
	for vRows.Next() {
		var v entity.GuestVisit
		var st string
		var checkOutBy sql.NullInt64
		var checkOutAt sql.NullTime
		var notes sql.NullString
		var checkOutByName sql.NullString
		var invSt sql.NullString
		var validUntil sql.NullTime

		err := vRows.Scan(
			&v.ID, &v.InvitationID, &v.CheckInAt, &v.CheckInBy, &checkOutAt, &checkOutBy,
			&st, &notes, &v.CreatedAt, &v.UpdatedAt,
			&v.InvitationCode, &v.GuestName, &v.VisitType,
			&v.HostName, &v.HouseBlock, &v.HouseNumber,
			&v.CheckInByName, &checkOutByName,
			&invSt, &validUntil,
		)
		if err != nil {
			return nil, 0, err
		}

		v.Status = entity.VisitStatus(st)
		if checkOutBy.Valid {
			v.CheckOutBy = &checkOutBy.Int64
		}
		if checkOutAt.Valid {
			v.CheckOutAt = &checkOutAt.Time
		}
		if notes.Valid {
			v.Notes = &notes.String
		}
		if checkOutByName.Valid {
			v.CheckOutByName = &checkOutByName.String
		}
		if invSt.Valid {
			v.InvitationStatus = entity.InvitationStatus(invSt.String)
		}
		if validUntil.Valid {
			v.ValidUntil = &validUntil.Time
		}

		visitsByInv[v.InvitationID] = append(visitsByInv[v.InvitationID], v)
	}

	for i := range groups {
		invID := groups[i].InvitationID
		visits := visitsByInv[invID]
		groups[i].Visits = visits
		for _, v := range visits {
			if v.Status == entity.VisitStatusCheckedIn {
				groups[i].HasActiveSession = true
				visitIDCopy := v.ID
				groups[i].ActiveVisitID = &visitIDCopy
				break
			}
		}
	}

	return groups, total, nil
}

func (r *PostgresGuestInvitationRepository) CreateAuditLog(ctx context.Context, log *entity.GuestVisitAuditLog) error {
	query := `
		INSERT INTO guest_visit_audit_logs (
			visit_id, invitation_id, actor_id, actor_role, action, status, notes, created_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
		RETURNING id, created_at
	`
	return r.db.QueryRowContext(
		ctx,
		query,
		log.VisitID,
		log.InvitationID,
		log.ActorID,
		log.ActorRole,
		log.Action,
		log.Status,
		log.Notes,
	).Scan(&log.ID, &log.CreatedAt)
}

func (r *PostgresGuestInvitationRepository) scanVisit(row *sql.Row) (*entity.GuestVisit, error) {
	var v entity.GuestVisit
	var st string
	var checkOutBy sql.NullInt64
	var checkOutAt sql.NullTime
	var notes sql.NullString
	var checkOutByName sql.NullString

	err := row.Scan(
		&v.ID, &v.InvitationID, &v.CheckInAt, &v.CheckInBy, &checkOutAt, &checkOutBy,
		&st, &notes, &v.CreatedAt, &v.UpdatedAt,
		&v.InvitationCode, &v.GuestName, &v.VisitType,
		&v.HostName, &v.HouseBlock, &v.HouseNumber,
		&v.CheckInByName, &checkOutByName,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}

	v.Status = entity.VisitStatus(st)
	if checkOutBy.Valid {
		v.CheckOutBy = &checkOutBy.Int64
	}
	if checkOutAt.Valid {
		v.CheckOutAt = &checkOutAt.Time
	}
	if notes.Valid {
		v.Notes = &notes.String
	}
	if checkOutByName.Valid {
		v.CheckOutByName = &checkOutByName.String
	}

	return &v, nil
}

func (r *PostgresGuestInvitationRepository) CountCompletedVisitsByInvitationID(ctx context.Context, invitationID int64) (int, error) {
	query := `
		SELECT COUNT(*)
		FROM guest_visits
		WHERE invitation_id = $1 AND status = 'CHECKED_OUT'
	`
	var count int
	if err := r.db.QueryRowContext(ctx, query, invitationID).Scan(&count); err != nil {
		return 0, err
	}
	return count, nil
}


