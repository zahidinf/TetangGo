package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"
	"tetanggo-backend/internal/domain/entity"
)

type PostgresBillingRepository struct {
	db *sql.DB
}

func NewPostgresBillingRepository(db *sql.DB) *PostgresBillingRepository {
	return &PostgresBillingRepository{db: db}
}

func (r *PostgresBillingRepository) GetPaymentSettings(ctx context.Context) (*entity.PaymentSetting, error) {
	query := `
		SELECT id, bank_name, account_number, account_holder, monthly_fee, created_at, updated_at
		FROM payment_settings
		ORDER BY id ASC
		LIMIT 1;
	`
	var s entity.PaymentSetting
	err := r.db.QueryRowContext(ctx, query).Scan(
		&s.ID,
		&s.BankName,
		&s.AccountNumber,
		&s.AccountHolder,
		&s.MonthlyFee,
		&s.CreatedAt,
		&s.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		// Insert default setting
		insertQuery := `
			INSERT INTO payment_settings (bank_name, account_number, account_holder, monthly_fee)
			VALUES ('BCA', '8830192831', 'Kas RT 05 RW 01', 100000.00)
			RETURNING id, bank_name, account_number, account_holder, monthly_fee, created_at, updated_at;
		`
		err = r.db.QueryRowContext(ctx, insertQuery).Scan(
			&s.ID,
			&s.BankName,
			&s.AccountNumber,
			&s.AccountHolder,
			&s.MonthlyFee,
			&s.CreatedAt,
			&s.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to initialize default payment settings: %w", err)
		}
		return &s, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get payment settings: %w", err)
	}
	return &s, nil
}

func (r *PostgresBillingRepository) UpdatePaymentSettings(ctx context.Context, s *entity.PaymentSetting) error {
	query := `
		UPDATE payment_settings
		SET bank_name = $1, account_number = $2, account_holder = $3, monthly_fee = $4, updated_at = CURRENT_TIMESTAMP
		WHERE id = (SELECT id FROM payment_settings ORDER BY id ASC LIMIT 1);
	`
	res, err := r.db.ExecContext(ctx, query, s.BankName, s.AccountNumber, s.AccountHolder, s.MonthlyFee)
	if err != nil {
		return fmt.Errorf("failed to update payment settings: %w", err)
	}
	rows, _ := res.RowsAffected()
	if rows == 0 {
		insertQuery := `
			INSERT INTO payment_settings (bank_name, account_number, account_holder, monthly_fee)
			VALUES ($1, $2, $3, $4);
		`
		_, err = r.db.ExecContext(ctx, insertQuery, s.BankName, s.AccountNumber, s.AccountHolder, s.MonthlyFee)
		if err != nil {
			return fmt.Errorf("failed to insert payment settings: %w", err)
		}
	}
	return nil
}

func (r *PostgresBillingRepository) CountPaidOrPendingBillsByPeriod(ctx context.Context, period string) (int, error) {
	var paidCount int
	err := r.db.QueryRowContext(ctx, `
		SELECT COUNT(*) 
		FROM bills 
		WHERE billing_period = $1 
		  AND status IN ('paid', 'pending_verification')
	`, period).Scan(&paidCount)
	if err != nil {
		return 0, fmt.Errorf("failed to count paid or pending bills: %w", err)
	}
	return paidCount, nil
}

func (r *PostgresBillingRepository) GenerateMonthlyBills(ctx context.Context, period string, amount float64) (int64, error) {
	query := `
		INSERT INTO bills (house_id, billing_period, amount, status)
		SELECT h.id, CAST($1 AS VARCHAR), CAST($2 AS NUMERIC), 'unpaid'
		FROM houses h
		WHERE h.status IN ('milik', 'kontrak')
		  AND NOT EXISTS (
		      SELECT 1 FROM bills b WHERE b.house_id = h.id AND b.billing_period = CAST($1 AS VARCHAR)
		  );
	`
	res, err := r.db.ExecContext(ctx, query, period, amount)
	if err != nil {
		return 0, fmt.Errorf("failed to generate monthly bills: %w", err)
	}
	return res.RowsAffected()
}

func (r *PostgresBillingRepository) GetBillsByHouseID(ctx context.Context, houseID int64) ([]entity.Bill, error) {
	query := `
		SELECT 
			b.id, b.house_id, b.billing_period, b.amount, b.status, b.created_at, b.updated_at,
			h.id, h.block, h.house_number, h.status,
			p.id, p.amount_paid, p.proof_image_url, p.sender_bank, p.sender_name, p.notes, p.rejection_reason, p.verified_at, p.created_at
		FROM bills b
		INNER JOIN houses h ON h.id = b.house_id
		LEFT JOIN LATERAL (
			SELECT id, amount_paid, proof_image_url, sender_bank, sender_name, notes, rejection_reason, verified_at, created_at
			FROM payments
			WHERE payments.bill_id = b.id
			ORDER BY id DESC
			LIMIT 1
		) p ON true
		WHERE b.house_id = $1
		ORDER BY b.billing_period DESC;
	`
	rows, err := r.db.QueryContext(ctx, query, houseID)
	if err != nil {
		return nil, fmt.Errorf("failed to get bills for house %d: %w", houseID, err)
	}
	defer rows.Close()

	var bills []entity.Bill
	for rows.Next() {
		var b entity.Bill
		var h entity.House
		var pID sql.NullInt64
		var pAmountPaid sql.NullFloat64
		var pProofURL sql.NullString
		var pSenderBank sql.NullString
		var pSenderName sql.NullString
		var pNotes sql.NullString
		var pRejectionReason sql.NullString
		var pVerifiedAt sql.NullTime
		var pCreatedAt sql.NullTime

		err := rows.Scan(
			&b.ID,
			&b.HouseID,
			&b.BillingPeriod,
			&b.Amount,
			&b.Status,
			&b.CreatedAt,
			&b.UpdatedAt,
			&h.ID,
			&h.Block,
			&h.HouseNumber,
			&h.Status,
			&pID,
			&pAmountPaid,
			&pProofURL,
			&pSenderBank,
			&pSenderName,
			&pNotes,
			&pRejectionReason,
			&pVerifiedAt,
			&pCreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan bill: %w", err)
		}

		b.House = &h

		if pID.Valid {
			p := &entity.Payment{
				ID:            pID.Int64,
				BillID:        b.ID,
				AmountPaid:    pAmountPaid.Float64,
				ProofImageURL: pProofURL.String,
			}
			if pSenderBank.Valid {
				p.SenderBank = &pSenderBank.String
			}
			if pSenderName.Valid {
				p.SenderName = &pSenderName.String
			}
			if pNotes.Valid {
				p.Notes = &pNotes.String
			}
			if pRejectionReason.Valid {
				p.RejectionReason = &pRejectionReason.String
			}
			if pVerifiedAt.Valid {
				p.VerifiedAt = &pVerifiedAt.Time
			}
			if pCreatedAt.Valid {
				p.CreatedAt = pCreatedAt.Time
			}
			b.Payment = p
		}

		bills = append(bills, b)
	}

	return bills, nil
}

func (r *PostgresBillingRepository) GetBillsByHouseIDAndPeriod(ctx context.Context, houseID int64, period string) ([]entity.Bill, error) {
	query := `
		SELECT 
			b.id, b.house_id, b.billing_period, b.amount, b.status, b.created_at, b.updated_at,
			h.id, h.block, h.house_number, h.status,
			p.id, p.amount_paid, p.proof_image_url, p.sender_bank, p.sender_name, p.notes, p.rejection_reason, p.verified_at, p.created_at
		FROM bills b
		INNER JOIN houses h ON h.id = b.house_id
		LEFT JOIN LATERAL (
			SELECT id, amount_paid, proof_image_url, sender_bank, sender_name, notes, rejection_reason, verified_at, created_at
			FROM payments
			WHERE payments.bill_id = b.id
			ORDER BY id DESC
			LIMIT 1
		) p ON true
		WHERE b.house_id = $1 AND b.billing_period = $2
		ORDER BY b.billing_period DESC;
	`
	rows, err := r.db.QueryContext(ctx, query, houseID, period)
	if err != nil {
		return nil, fmt.Errorf("failed to get bills for house %d and period %s: %w", houseID, period, err)
	}
	defer rows.Close()

	var bills []entity.Bill
	for rows.Next() {
		var b entity.Bill
		var h entity.House
		var pID sql.NullInt64
		var pAmountPaid sql.NullFloat64
		var pProofURL sql.NullString
		var pSenderBank sql.NullString
		var pSenderName sql.NullString
		var pNotes sql.NullString
		var pRejectionReason sql.NullString
		var pVerifiedAt sql.NullTime
		var pCreatedAt sql.NullTime

		err := rows.Scan(
			&b.ID,
			&b.HouseID,
			&b.BillingPeriod,
			&b.Amount,
			&b.Status,
			&b.CreatedAt,
			&b.UpdatedAt,
			&h.ID,
			&h.Block,
			&h.HouseNumber,
			&h.Status,
			&pID,
			&pAmountPaid,
			&pProofURL,
			&pSenderBank,
			&pSenderName,
			&pNotes,
			&pRejectionReason,
			&pVerifiedAt,
			&pCreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan bill: %w", err)
		}

		b.House = &h

		if pID.Valid {
			p := &entity.Payment{
				ID:            pID.Int64,
				BillID:        b.ID,
				AmountPaid:    pAmountPaid.Float64,
				ProofImageURL: pProofURL.String,
			}
			if pSenderBank.Valid {
				p.SenderBank = &pSenderBank.String
			}
			if pSenderName.Valid {
				p.SenderName = &pSenderName.String
			}
			if pNotes.Valid {
				p.Notes = &pNotes.String
			}
			if pRejectionReason.Valid {
				p.RejectionReason = &pRejectionReason.String
			}
			if pVerifiedAt.Valid {
				p.VerifiedAt = &pVerifiedAt.Time
			}
			if pCreatedAt.Valid {
				p.CreatedAt = pCreatedAt.Time
			}
			b.Payment = p
		}

		bills = append(bills, b)
	}

	if bills == nil {
		bills = []entity.Bill{}
	}

	return bills, nil
}

func (r *PostgresBillingRepository) GetBillByHouseAndPeriod(ctx context.Context, houseID int64, period string) (*entity.Bill, error) {
	bills, err := r.GetBillsByHouseIDAndPeriod(ctx, houseID, period)
	if err != nil {
		return nil, err
	}
	if len(bills) == 0 {
		return nil, errors.New("tagihan tidak ditemukan")
	}
	return &bills[0], nil
}

func (r *PostgresBillingRepository) CreateBill(ctx context.Context, bill *entity.Bill) error {
	query := `
		INSERT INTO bills (house_id, billing_period, amount, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, NOW(), NOW())
		RETURNING id, created_at, updated_at;
	`
	return r.db.QueryRowContext(ctx, query, bill.HouseID, bill.BillingPeriod, bill.Amount, bill.Status).
		Scan(&bill.ID, &bill.CreatedAt, &bill.UpdatedAt)
}

func (r *PostgresBillingRepository) GetBillByID(ctx context.Context, billID int64) (*entity.Bill, error) {
	query := `
		SELECT 
			b.id, b.house_id, b.billing_period, b.amount, b.status, b.created_at, b.updated_at,
			h.block, h.house_number, h.status,
			p.id, p.user_id, p.amount_paid, p.proof_image_url, p.sender_bank, p.sender_name, 
			p.notes, p.rejection_reason, p.verified_by, u_admin.name, p.verified_at, p.created_at
		FROM bills b
		JOIN houses h ON h.id = b.house_id
		LEFT JOIN LATERAL (
			SELECT id, user_id, amount_paid, proof_image_url, sender_bank, sender_name, notes, rejection_reason, verified_by, verified_at, created_at
			FROM payments
			WHERE payments.bill_id = b.id
			ORDER BY id DESC
			LIMIT 1
		) p ON true
		LEFT JOIN users u_admin ON u_admin.id = p.verified_by
		WHERE b.id = $1;
	`
	var b entity.Bill
	var h entity.House
	var pID sql.NullInt64
	var pUserID sql.NullInt64
	var pAmountPaid sql.NullFloat64
	var pProofURL sql.NullString
	var pSenderBank sql.NullString
	var pSenderName sql.NullString
	var pNotes sql.NullString
	var pRejectionReason sql.NullString
	var pVerifiedBy sql.NullInt64
	var pVerifiedByName sql.NullString
	var pVerifiedAt sql.NullTime
	var pCreatedAt sql.NullTime

	err := r.db.QueryRowContext(ctx, query, billID).Scan(
		&b.ID,
		&b.HouseID,
		&b.BillingPeriod,
		&b.Amount,
		&b.Status,
		&b.CreatedAt,
		&b.UpdatedAt,
		&h.Block,
		&h.HouseNumber,
		&h.Status,
		&pID,
		&pUserID,
		&pAmountPaid,
		&pProofURL,
		&pSenderBank,
		&pSenderName,
		&pNotes,
		&pRejectionReason,
		&pVerifiedBy,
		&pVerifiedByName,
		&pVerifiedAt,
		&pCreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("bill with id %d not found", billID)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get bill by id: %w", err)
	}

	h.ID = b.HouseID
	b.House = &h

	if pID.Valid {
		p := &entity.Payment{
			ID:            pID.Int64,
			BillID:        b.ID,
			AmountPaid:    pAmountPaid.Float64,
			ProofImageURL: pProofURL.String,
		}
		if pUserID.Valid {
			p.UserID = &pUserID.Int64
		}
		if pSenderBank.Valid {
			p.SenderBank = &pSenderBank.String
		}
		if pSenderName.Valid {
			p.SenderName = &pSenderName.String
		}
		if pNotes.Valid {
			p.Notes = &pNotes.String
		}
		if pRejectionReason.Valid {
			p.RejectionReason = &pRejectionReason.String
		}
		if pVerifiedBy.Valid {
			p.VerifiedBy = &pVerifiedBy.Int64
		}
		if pVerifiedByName.Valid {
			p.VerifiedByName = &pVerifiedByName.String
		}
		if pVerifiedAt.Valid {
			p.VerifiedAt = &pVerifiedAt.Time
		}
		if pCreatedAt.Valid {
			p.CreatedAt = pCreatedAt.Time
		}
		b.Payment = p
	}

	return &b, nil
}

func (r *PostgresBillingRepository) CreatePayment(ctx context.Context, p *entity.Payment) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	insertPaymentQuery := `
		INSERT INTO payments (bill_id, user_id, sender_bank, sender_name, amount_paid, proof_image_url, notes, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP)
		RETURNING id, created_at;
	`
	err = tx.QueryRowContext(
		ctx,
		insertPaymentQuery,
		p.BillID,
		p.UserID,
		p.SenderBank,
		p.SenderName,
		p.AmountPaid,
		p.ProofImageURL,
		p.Notes,
	).Scan(&p.ID, &p.CreatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert payment: %w", err)
	}

	updateBillQuery := `
		UPDATE bills
		SET status = 'pending_verification', updated_at = CURRENT_TIMESTAMP
		WHERE id = $1;
	`
	_, err = tx.ExecContext(ctx, updateBillQuery, p.BillID)
	if err != nil {
		return fmt.Errorf("failed to update bill status: %w", err)
	}

	return tx.Commit()
}

func (r *PostgresBillingRepository) UpdateBillStatus(ctx context.Context, billID int64, status string) error {
	query := `UPDATE bills SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2;`
	_, err := r.db.ExecContext(ctx, query, status, billID)
	return err
}

func (r *PostgresBillingRepository) VerifyPayment(ctx context.Context, billID int64, action string, rejectionReason *string, verifiedBy int64) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	now := time.Now()
	newStatus := "paid"
	if action == "reject" {
		newStatus = "rejected"
	}

	updateBillQuery := `
		UPDATE bills
		SET status = $1, updated_at = CURRENT_TIMESTAMP
		WHERE id = $2;
	`
	_, err = tx.ExecContext(ctx, updateBillQuery, newStatus, billID)
	if err != nil {
		return fmt.Errorf("failed to update bill status on verify: %w", err)
	}

	var updatePaymentQuery string
	if action == "reject" {
		updatePaymentQuery = `
			UPDATE payments
			SET verified_by = $1, verified_at = $2, rejection_reason = $3
			WHERE id = (SELECT id FROM payments WHERE bill_id = $4 ORDER BY id DESC LIMIT 1);
		`
		_, err = tx.ExecContext(ctx, updatePaymentQuery, verifiedBy, now, rejectionReason, billID)
	} else {
		updatePaymentQuery = `
			UPDATE payments
			SET verified_by = $1, verified_at = $2, rejection_reason = NULL
			WHERE id = (SELECT id FROM payments WHERE bill_id = $3 ORDER BY id DESC LIMIT 1);
		`
		_, err = tx.ExecContext(ctx, updatePaymentQuery, verifiedBy, now, billID)
	}
	if err != nil {
		return fmt.Errorf("failed to update payment verification details: %w", err)
	}

	return tx.Commit()
}

func (r *PostgresBillingRepository) GetPendingPayments(ctx context.Context) ([]entity.PendingPaymentItem, error) {
	query := `
		SELECT 
			b.id AS bill_id,
			p.id AS payment_id,
			h.id AS house_id,
			h.block,
			h.house_number,
			COALESCE(u.name, 'Penghuni') AS resident_name,
			COALESCE(u.phone, '') AS resident_phone,
			b.billing_period,
			b.amount AS bill_amount,
			p.amount_paid,
			COALESCE(p.sender_bank, '') AS sender_bank,
			COALESCE(p.sender_name, '') AS sender_name,
			p.proof_image_url,
			COALESCE(p.notes, '') AS notes,
			p.created_at
		FROM bills b
		JOIN houses h ON h.id = b.house_id
		JOIN LATERAL (
			SELECT id, user_id, amount_paid, sender_bank, sender_name, proof_image_url, notes, created_at
			FROM payments
			WHERE payments.bill_id = b.id
			ORDER BY id DESC
			LIMIT 1
		) p ON true
		LEFT JOIN users u ON u.id = p.user_id
		WHERE b.status = 'pending_verification'
		ORDER BY p.created_at ASC;
	`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query pending payments: %w", err)
	}
	defer rows.Close()

	var list []entity.PendingPaymentItem
	for rows.Next() {
		var item entity.PendingPaymentItem
		err := rows.Scan(
			&item.BillID,
			&item.PaymentID,
			&item.HouseID,
			&item.HouseBlock,
			&item.HouseNumber,
			&item.ResidentName,
			&item.ResidentPhone,
			&item.BillingPeriod,
			&item.BillAmount,
			&item.AmountPaid,
			&item.SenderBank,
			&item.SenderName,
			&item.ProofImageURL,
			&item.Notes,
			&item.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan pending payment item: %w", err)
		}
		list = append(list, item)
	}

	return list, nil
}

func (r *PostgresBillingRepository) GetBillingSummary(ctx context.Context, period string, block string) (*entity.BillingSummaryResponse, error) {
	// Base query for houses
	baseQuery := `
		SELECT 
			h.id, h.block, h.house_number,
			COALESCE(head.name, 'Belum Terdaftar') AS resident_name,
			COALESCE(head.phone, '-') AS resident_phone,
			COALESCE(b.status, 'unpaid') AS bill_status,
			b.id AS bill_id,
			COALESCE(b.amount, (SELECT COALESCE(monthly_fee, 0) FROM payment_settings ORDER BY id ASC LIMIT 1), 0) AS bill_amount,
			p.verified_at AS paid_at,
			p.proof_image_url
		FROM houses h
		LEFT JOIN LATERAL (
			SELECT u.name, u.phone
			FROM users u
			WHERE u.house_id = h.id AND u.status = 'active'
			ORDER BY u.id ASC
			LIMIT 1
		) head ON true
		LEFT JOIN bills b ON b.house_id = h.id AND b.billing_period = $1
		LEFT JOIN LATERAL (
			SELECT verified_at, proof_image_url
			FROM payments
			WHERE payments.bill_id = b.id
			ORDER BY id DESC
			LIMIT 1
		) p ON true
		WHERE h.status IN ('milik', 'kontrak')
	`

	var rows *sql.Rows
	var err error
	if block != "" && block != "all" {
		baseQuery += " AND h.block = $2 ORDER BY h.block ASC, h.house_number ASC;"
		rows, err = r.db.QueryContext(ctx, baseQuery, period, block)
	} else {
		baseQuery += " ORDER BY h.block ASC, h.house_number ASC;"
		rows, err = r.db.QueryContext(ctx, baseQuery, period)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get billing summary: %w", err)
	}
	defer rows.Close()

	summary := &entity.BillingSummaryResponse{
		Period:            period,
		Block:             block,
		TotalHouses:       0,
		PaidHouses:        0,
		UnpaidHouses:      0,
		TotalPaidHouses:   0,
		TotalUnpaidHouses: 0,
		TotalPaidAmount:   0,
		TotalUnpaidAmount: 0,
		HouseBills:        make([]entity.HouseBillStatus, 0),
		Items:             make([]entity.HouseBillStatus, 0),
	}

	for rows.Next() {
		var item entity.HouseBillStatus
		var bID sql.NullInt64
		var pPaidAt sql.NullTime
		var pProofURL sql.NullString

		err := rows.Scan(
			&item.HouseID,
			&item.Block,
			&item.HouseNumber,
			&item.ResidentName,
			&item.ResidentPhone,
			&item.Status,
			&bID,
			&item.Amount,
			&pPaidAt,
			&pProofURL,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan house bill status: %w", err)
		}

		if bID.Valid {
			item.BillID = &bID.Int64
		}
		if pPaidAt.Valid {
			item.PaidAt = &pPaidAt.Time
		}
		if pProofURL.Valid {
			item.ProofImageURL = &pProofURL.String
		}

		summary.TotalHouses++
		if item.Status == "paid" {
			summary.PaidHouses++
			summary.TotalPaidAmount += item.Amount
		} else {
			summary.UnpaidHouses++
			summary.TotalUnpaidAmount += item.Amount
		}

		summary.HouseBills = append(summary.HouseBills, item)
	}

	summary.Items = summary.HouseBills
	summary.TotalPaidHouses = summary.PaidHouses
	summary.TotalUnpaidHouses = summary.UnpaidHouses

	return summary, nil
}
