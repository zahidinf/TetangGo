package invitation

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

var (
	ErrUnauthorized       = errors.New("pengguna tidak memiliki izin untuk tindakan ini")
	ErrHouseNotMapped     = errors.New("akun belum terhubung dengan hunian yang sah")
	ErrInvalidInput       = errors.New("input data undangan tidak valid")
	ErrInvitationNotFound = errors.New("undangan tidak ditemukan")
	ErrCannotCancel       = errors.New("undangan sudah tidak dapat dibatalkan")
	ErrInvitationRevoked     = errors.New("Undangan telah dibatalkan. Akses ditolak.")
	ErrInvitationExpired     = errors.New("Undangan telah kedaluwarsa. Akses ditolak.")
	ErrInvitationUsed        = errors.New("Undangan telah digunakan. Akses ditolak.")
	ErrInvitationCompleted   = errors.New("Undangan telah diakhiri oleh pengundang. QR tidak dapat digunakan kembali.")
	ErrInvitationNotYetValid = errors.New("Undangan belum memasuki waktu berlaku. Akses ditolak.")
	ErrDoubleCheckIn         = errors.New("tamu sudah melakukan check-in dan belum check-out")
	ErrNoActiveVisit         = errors.New("tidak ada kunjungan aktif yang dapat di-check-out")
	ErrCannotComplete        = errors.New("undangan sudah tidak dapat diselesaikan")
	ErrCannotCompleteActiveVisit   = errors.New("tamu masih berada di dalam area perumahan. Pastikan satpam mencatat check-out terlebih dahulu.")
	ErrCannotCompleteNoVisit = errors.New("undangan belum pernah digunakan untuk kunjungan yang selesai")
)

type InvitationUseCase struct {
	invRepo   repository.GuestInvitationRepository
	userRepo  repository.UserRepository
	houseRepo repository.HouseRepository
	jwtSecret string
}

func NewInvitationUseCase(
	invRepo repository.GuestInvitationRepository,
	userRepo repository.UserRepository,
	houseRepo repository.HouseRepository,
	jwtSecret string,
) *InvitationUseCase {
	return &InvitationUseCase{
		invRepo:   invRepo,
		userRepo:  userRepo,
		houseRepo: houseRepo,
		jwtSecret: jwtSecret,
	}
}

// GenerateRandomToken generates cryptographically secure high-entropy random bytes
func GenerateRandomToken(n int) (string, error) {
	bytes := make([]byte, n)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// ComputeHMAC generates a cryptographically signed HMAC-SHA256 signature
func ComputeHMAC(data, secret string) string {
	h := hmac.New(sha256.New, []byte(secret))
	h.Write([]byte(data))
	return hex.EncodeToString(h.Sum(nil))
}

type QRPayloadStructure struct {
	V    string `json:"v"`    // Version "1"
	Code string `json:"code"` // Public Invitation Code
	Type string `json:"type"` // TAMU / KURIR
	Name string `json:"name"` // Guest Name
	Exp  int64  `json:"exp"`  // Unix Expiration timestamp
	Sig  string `json:"sig"`  // Cryptographic signature
}

func (uc *InvitationUseCase) CreateInvitation(
	ctx context.Context,
	hostUserID int64,
	req entity.CreateInvitationRequest,
) (*entity.GuestInvitation, error) {
	guestName := strings.TrimSpace(req.GuestName)
	if guestName == "" {
		return nil, fmt.Errorf("%w: nama tamu wajib diisi", ErrInvalidInput)
	}

	visitType := strings.ToUpper(strings.TrimSpace(req.VisitType))
	if !entity.IsValidVisitType(visitType) {
		return nil, fmt.Errorf("%w: jenis kunjungan harus TAMU atau KURIR", ErrInvalidInput)
	}

	// Verify host user and house
	user, err := uc.userRepo.GetByID(ctx, hostUserID)
	if err != nil || user == nil {
		return nil, ErrUnauthorized
	}
	if user.Status != string(entity.UserStatusActive) {
		return nil, fmt.Errorf("%w: akun tidak aktif", ErrUnauthorized)
	}
	if user.HouseID == nil || *user.HouseID <= 0 {
		return nil, ErrHouseNotMapped
	}

	houseID := *user.HouseID
	house, err := uc.houseRepo.GetByID(ctx, houseID)
	if err != nil || house == nil {
		return nil, fmt.Errorf("%w: data hunian tidak ditemukan", ErrHouseNotMapped)
	}

	// Duration calculation (Default 24 hours, max 72 hours, min 1 hour)
	durationHours := req.ValidHours
	if durationHours <= 0 {
		durationHours = 24
	}
	if durationHours > 72 {
		return nil, fmt.Errorf("%w: masa berlaku maksimal 72 jam", ErrInvalidInput)
	}

	now := time.Now().UTC()
	validUntil := now.Add(time.Duration(durationHours) * time.Hour)

	// High entropy token & unique code
	randomHex, err := GenerateRandomToken(16)
	if err != nil {
		return nil, fmt.Errorf("gagal menghasilkan token acak: %w", err)
	}
	invitationCode := fmt.Sprintf("INV-%d-%s", now.Unix(), strings.ToUpper(randomHex[:8]))

	// Hash the token for internal verification
	tokenHashBytes := sha256.Sum256([]byte(randomHex))
	tokenHash := hex.EncodeToString(tokenHashBytes[:])

	// Sign payload: Code|Type|Exp
	sigPayload := fmt.Sprintf("%s|%s|%d", invitationCode, visitType, validUntil.Unix())
	sig := ComputeHMAC(sigPayload, uc.jwtSecret)

	qrStruct := QRPayloadStructure{
		V:    "1",
		Code: invitationCode,
		Type: visitType,
		Name: guestName,
		Exp:  validUntil.Unix(),
		Sig:  sig,
	}

	qrJSON, err := json.Marshal(qrStruct)
	if err != nil {
		return nil, fmt.Errorf("gagal menyusun qr payload: %w", err)
	}
	qrPayloadBase64 := base64.StdEncoding.EncodeToString(qrJSON)

	inv := &entity.GuestInvitation{
		InvitationCode: invitationCode,
		HostUserID:     hostUserID,
		HouseID:        houseID,
		GuestName:      guestName,
		VisitType:      visitType,
		Phone:          req.Phone,
		Notes:          req.Notes,
		ValidFrom:      now,
		ValidUntil:     validUntil,
		Status:         entity.InvitationStatusActive,
		QRPayload:      qrPayloadBase64,
		QRTokenHash:    tokenHash,
		HostName:       user.Name,
		HouseBlock:     house.Block,
		HouseNumber:    house.HouseNumber,
	}

	if err := uc.invRepo.Create(ctx, inv); err != nil {
		return nil, fmt.Errorf("gagal menyimpan undangan: %w", err)
	}

	return inv, nil
}

func (uc *InvitationUseCase) GetMyInvitations(
	ctx context.Context,
	hostUserID int64,
	page, limit int,
) ([]entity.GuestInvitation, int, int, error) {
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	offset := (page - 1) * limit

	invs, total, err := uc.invRepo.ListByHostUserID(ctx, hostUserID, limit, offset)
	if err != nil {
		return nil, 0, 0, err
	}

	totalPages := (total + limit - 1) / limit
	return invs, total, totalPages, nil
}

func (uc *InvitationUseCase) GetInvitationDetail(
	ctx context.Context,
	invitationID int64,
	requesterUserID int64,
	requesterRole string,
) (*entity.GuestInvitation, error) {
	inv, err := uc.invRepo.GetByID(ctx, invitationID)
	if err != nil {
		return nil, err
	}
	if inv == nil {
		return nil, ErrInvitationNotFound
	}

	// Access control:
	// Host can view.
	// Admin / Security can view.
	isHost := inv.HostUserID == requesterUserID
	isAdminOrSecurity := requesterRole == string(entity.RoleAdmin) ||
		requesterRole == string(entity.RoleChairperson) ||
		requesterRole == string(entity.RoleViceChairperson) ||
		requesterRole == string(entity.RoleSecretary) ||
		requesterRole == string(entity.RoleSecurity)

	if !isHost && !isAdminOrSecurity {
		return nil, ErrUnauthorized
	}

	// US-2: Jika status dibatalkan/kedaluwarsa/selesai, kosongkan qr_payload agar tidak dapat direkonstruksi
	if inv.Status == entity.InvitationStatusCancelled || inv.Status == entity.InvitationStatusExpired || inv.Status == entity.InvitationStatusCompleted {
		inv.QRPayload = ""
	}

	return inv, nil
}

func (uc *InvitationUseCase) CompleteInvitation(
	ctx context.Context,
	invitationID int64,
	requesterUserID int64,
) error {
	inv, err := uc.invRepo.GetByID(ctx, invitationID)
	if err != nil {
		return err
	}
	if inv == nil {
		return ErrInvitationNotFound
	}

	// Only host user can complete their own invitation
	if inv.HostUserID != requesterUserID {
		return ErrUnauthorized
	}

	// Hanya undangan yang berstatus ACTIVE atau USED dan belum kedaluwarsa waktu yang dapat diakhiri
	now := time.Now().UTC()
	if now.After(inv.ValidUntil) || now.Equal(inv.ValidUntil) {
		return ErrCannotComplete
	}

	if inv.Status != entity.InvitationStatusActive && inv.Status != entity.InvitationStatusUsed {
		return ErrCannotComplete
	}

	// Tolak jika masih ada sesi kunjungan aktif yang belum check-out
	activeVisit, err := uc.invRepo.GetActiveVisitByInvitationID(ctx, invitationID)
	if err != nil {
		return err
	}
	if activeVisit != nil {
		return ErrCannotCompleteActiveVisit
	}

	// Tolak jika belum ada sesi kunjungan yang selesai checkout
	completedCount, err := uc.invRepo.CountCompletedVisitsByInvitationID(ctx, invitationID)
	if err != nil {
		return err
	}
	if completedCount <= 0 {
		return ErrCannotCompleteNoVisit
	}

	return uc.invRepo.Complete(ctx, invitationID)
}

func (uc *InvitationUseCase) CancelInvitation(
	ctx context.Context,
	invitationID int64,
	requesterUserID int64,
	reason string,
) error {
	inv, err := uc.invRepo.GetByID(ctx, invitationID)
	if err != nil {
		return err
	}
	if inv == nil {
		return ErrInvitationNotFound
	}

	// Only host user can cancel their own invitation
	if inv.HostUserID != requesterUserID {
		return ErrUnauthorized
	}

	if inv.Status != entity.InvitationStatusActive {
		return ErrCannotCancel
	}

	cleanReason := strings.TrimSpace(reason)
	if cleanReason == "" {
		cleanReason = "Dibatalkan oleh tuan rumah"
	}

	return uc.invRepo.Cancel(ctx, invitationID, requesterUserID, cleanReason)
}

// VerifyAndScanInvitation verifies QR code validity against DB persistence and RBAC
func (uc *InvitationUseCase) VerifyAndScanInvitation(
	ctx context.Context,
	rawCodeOrPayload string,
	checkIn bool,
) (*entity.VerifyInvitationResponse, error) {
	cleanInput := strings.TrimSpace(rawCodeOrPayload)
	if cleanInput == "" {
		return &entity.VerifyInvitationResponse{
			Valid:   false,
			Message: "Kode atau payload QR wajib diisi",
		}, ErrInvalidInput
	}

	invitationCode := cleanInput

	// Cek apakah input berupa QR Payload Base64 JSON
	if strings.HasPrefix(cleanInput, "ey") {
		decoded, err := base64.StdEncoding.DecodeString(cleanInput)
		if err == nil {
			var qrStruct QRPayloadStructure
			if jsonErr := json.Unmarshal(decoded, &qrStruct); jsonErr == nil && qrStruct.Code != "" {
				invitationCode = qrStruct.Code
			}
		}
	}

	// Wajib cek status terbaru dari basis data persisten
	inv, err := uc.invRepo.GetByCode(ctx, invitationCode)
	if err != nil {
		return nil, fmt.Errorf("gagal memeriksa undangan di database: %w", err)
	}
	if inv == nil {
		return &entity.VerifyInvitationResponse{
			Valid:   false,
			Message: "Undangan tidak ditemukan dalam sistem",
		}, ErrInvitationNotFound
	}

	now := time.Now().UTC()

	// Ambil active visit jika ada
	activeVisit, _ := uc.invRepo.GetActiveVisitByInvitationID(ctx, inv.ID)

	// 1. Cek status pembatalan (US-1 & US-3: QR lama/screenshot yang dibatalkan wajib ditolak)
	if inv.Status == entity.InvitationStatusCancelled {
		return &entity.VerifyInvitationResponse{
			Valid:      false,
			Status:     entity.InvitationStatusCancelled,
			Message:    "Undangan telah dibatalkan. Akses ditolak.",
			Invitation: inv,
		}, ErrInvitationRevoked
	}

	// 2. Cek status selesai oleh warga (US-5.2)
	if inv.Status == entity.InvitationStatusCompleted {
		return &entity.VerifyInvitationResponse{
			Valid:       false,
			Status:      entity.InvitationStatusCompleted,
			Message:     "Undangan telah diakhiri oleh pengundang. QR tidak dapat digunakan kembali.",
			Invitation:  inv,
			ActiveVisit: activeVisit,
		}, ErrInvitationCompleted
	}

	// 3. Cek belum berlaku (Not yet valid)
	if now.Before(inv.ValidFrom) {
		return &entity.VerifyInvitationResponse{
			Valid:      false,
			Status:     inv.Status,
			Message:    "Undangan belum memasuki waktu berlaku. Akses ditolak.",
			Invitation: inv,
		}, ErrInvitationNotYetValid
	}

	// 4. Cek kedaluwarsa waktu
	if inv.Status == entity.InvitationStatusExpired || now.After(inv.ValidUntil) || now.Equal(inv.ValidUntil) {
		return &entity.VerifyInvitationResponse{
			Valid:       false,
			Status:      entity.InvitationStatusExpired,
			Message:     "Undangan telah kedaluwarsa. Akses ditolak.",
			Invitation:  inv,
			ActiveVisit: activeVisit,
		}, ErrInvitationExpired
	}

	// 5. Undangan aktif dan valid
	if checkIn {
		if err := uc.invRepo.CheckIn(ctx, inv.ID); err != nil {
			return &entity.VerifyInvitationResponse{
				Valid:       false,
				Status:      inv.Status,
				Message:     fmt.Sprintf("Gagal check-in tamu: %v", err),
				Invitation:  inv,
				ActiveVisit: activeVisit,
			}, err
		}
		inv.Status = entity.InvitationStatusUsed
	}

	return &entity.VerifyInvitationResponse{
		Valid:       true,
		Status:      inv.Status,
		Message:     "Undangan aktif dan sah. Izin masuk diberikan.",
		Invitation:  inv,
		ActiveVisit: activeVisit,
	}, nil
}

// US-5.2: Security Gate Operations (Check-In, Check-Out, History)

// CheckInGuest handles gate check-in by security officer
func (uc *InvitationUseCase) CheckInGuest(
	ctx context.Context,
	securityUserID int64,
	securityRole string,
	rawCodeOrPayload string,
	notes *string,
) (*entity.GuestVisit, error) {
	// Guard RBAC: Hanya SECURITY yang berhak operasional gerbang
	if securityRole != string(entity.RoleSecurity) {
		_ = uc.invRepo.CreateAuditLog(ctx, &entity.GuestVisitAuditLog{
			ActorID:   securityUserID,
			ActorRole: securityRole,
			Action:    "CHECK_IN",
			Status:    "FAILED",
			Notes:     strPtr("Akses ditolak: role tidak memiliki izin operasional gerbang"),
		})
		return nil, ErrUnauthorized
	}

	cleanInput := strings.TrimSpace(rawCodeOrPayload)

	// Cari kode undangan
	invitationCode := cleanInput
	if strings.HasPrefix(cleanInput, "ey") {
		decoded, err := base64.StdEncoding.DecodeString(cleanInput)
		if err == nil {
			var qrStruct QRPayloadStructure
			if jsonErr := json.Unmarshal(decoded, &qrStruct); jsonErr == nil && qrStruct.Code != "" {
				invitationCode = qrStruct.Code
			}
		}
	}

	existingInv, _ := uc.invRepo.GetByCode(ctx, invitationCode)
	if existingInv != nil {
		// Prioritaskan cek kunjungan aktif untuk deteksi double check-in
		activeVisit, _ := uc.invRepo.GetActiveVisitByInvitationID(ctx, existingInv.ID)
		if activeVisit != nil {
			_ = uc.invRepo.CreateAuditLog(ctx, &entity.GuestVisitAuditLog{
				InvitationID: &existingInv.ID,
				VisitID:      &activeVisit.ID,
				ActorID:      securityUserID,
				ActorRole:    securityRole,
				Action:       "CHECK_IN",
				Status:       "FAILED",
				Notes:        strPtr("Ditolak: Tamu sudah check-in dan belum check-out"),
			})
			return nil, ErrDoubleCheckIn
		}
	}

	// 1. Verifikasi QR Code
	verifyRes, err := uc.VerifyAndScanInvitation(ctx, rawCodeOrPayload, false)
	if err != nil {
		_ = uc.invRepo.CreateAuditLog(ctx, &entity.GuestVisitAuditLog{
			ActorID:   securityUserID,
			ActorRole: securityRole,
			Action:    "CHECK_IN",
			Status:    "FAILED",
			Notes:     strPtr("Verifikasi QR gagal: " + err.Error()),
		})
		return nil, err
	}

	inv := verifyRes.Invitation
	if inv == nil {
		return nil, ErrInvitationNotFound
	}

	// 2. Buat catatan kunjungan baru
	now := time.Now().UTC()
	visit := &entity.GuestVisit{
		InvitationID: inv.ID,
		CheckInAt:   now,
		CheckInBy:   securityUserID,
		Status:      entity.VisitStatusCheckedIn,
		Notes:       notes,
	}

	if err := uc.invRepo.CreateVisit(ctx, visit); err != nil {
		_ = uc.invRepo.CreateAuditLog(ctx, &entity.GuestVisitAuditLog{
			InvitationID: &inv.ID,
			ActorID:      securityUserID,
			ActorRole:    securityRole,
			Action:       "CHECK_IN",
			Status:       "FAILED",
			Notes:        strPtr("Gagal menyimpan kunjungan: " + err.Error()),
		})
		return nil, fmt.Errorf("gagal mencatat check-in kunjungan: %w", err)
	}

	// US-5.2 Enhancement: Check-in tidak mengubah status undangan menjadi USED yang memblokir scan ulang.
	// Undangan tetap dapat digunakan keluar-masuk berulang kali selama masih valid dan belum selesai/kedaluwarsa.
	// _ = uc.invRepo.CheckIn(ctx, inv.ID)

	// 4. Catat Audit Log
	_ = uc.invRepo.CreateAuditLog(ctx, &entity.GuestVisitAuditLog{
		InvitationID: &inv.ID,
		VisitID:      &visit.ID,
		ActorID:      securityUserID,
		ActorRole:    securityRole,
		Action:       "CHECK_IN",
		Status:       "SUCCESS",
		Notes:        notes,
	})

	// Fetch detail lengkap untuk returned object
	fullVisit, err := uc.invRepo.GetVisitByID(ctx, visit.ID)
	if err == nil && fullVisit != nil {
		return fullVisit, nil
	}
	return visit, nil
}

// CheckOutGuest handles gate check-out by security officer
func (uc *InvitationUseCase) CheckOutGuest(
	ctx context.Context,
	securityUserID int64,
	securityRole string,
	req entity.CheckOutGuestRequest,
) (*entity.GuestVisit, error) {
	// Guard RBAC: Hanya SECURITY yang berhak operasional gerbang
	if securityRole != string(entity.RoleSecurity) {
		_ = uc.invRepo.CreateAuditLog(ctx, &entity.GuestVisitAuditLog{
			ActorID:   securityUserID,
			ActorRole: securityRole,
			Action:    "CHECK_OUT",
			Status:    "FAILED",
			Notes:     strPtr("Akses ditolak: role tidak memiliki izin operasional gerbang"),
		})
		return nil, ErrUnauthorized
	}

	var targetVisitID int64

	if req.VisitID != nil && *req.VisitID > 0 {
		targetVisitID = *req.VisitID
	} else if req.Code != nil && strings.TrimSpace(*req.Code) != "" {
		// Cari melalui code/payload
		invCode := strings.TrimSpace(*req.Code)
		if strings.HasPrefix(invCode, "ey") {
			decoded, err := base64.StdEncoding.DecodeString(invCode)
			if err == nil {
				var qrStruct QRPayloadStructure
				if jsonErr := json.Unmarshal(decoded, &qrStruct); jsonErr == nil && qrStruct.Code != "" {
					invCode = qrStruct.Code
				}
			}
		}
		inv, err := uc.invRepo.GetByCode(ctx, invCode)
		if err != nil || inv == nil {
			return nil, ErrInvitationNotFound
		}
		activeVisit, err := uc.invRepo.GetActiveVisitByInvitationID(ctx, inv.ID)
		if err != nil || activeVisit == nil {
			return nil, ErrNoActiveVisit
		}
		targetVisitID = activeVisit.ID
	} else {
		return nil, ErrInvalidInput
	}

	// Pastikan kunjungan ada dan sedang CHECKED_IN
	visit, err := uc.invRepo.GetVisitByID(ctx, targetVisitID)
	if err != nil || visit == nil {
		return nil, ErrNoActiveVisit
	}
	if visit.Status != entity.VisitStatusCheckedIn {
		return nil, ErrNoActiveVisit
	}

	now := time.Now().UTC()
	if err := uc.invRepo.CheckOutVisit(ctx, visit.ID, securityUserID, now, req.Notes); err != nil {
		_ = uc.invRepo.CreateAuditLog(ctx, &entity.GuestVisitAuditLog{
			VisitID:   &visit.ID,
			ActorID:   securityUserID,
			ActorRole: securityRole,
			Action:    "CHECK_OUT",
			Status:    "FAILED",
			Notes:     strPtr("Gagal check-out: " + err.Error()),
		})
		return nil, fmt.Errorf("gagal check-out kunjungan: %w", err)
	}

	// If requested to end invitation simultaneously:
	if req.EndInvitation {
		_ = uc.invRepo.Complete(ctx, visit.InvitationID)
		_ = uc.invRepo.CreateAuditLog(ctx, &entity.GuestVisitAuditLog{
			InvitationID: &visit.InvitationID,
			VisitID:      &visit.ID,
			ActorID:      securityUserID,
			ActorRole:    securityRole,
			Action:       "COMPLETE_INVITATION",
			Status:       "SUCCESS",
			Notes:        strPtr("Undangan diakhiri saat check-out oleh petugas satpam"),
		})
	}

	// Catat audit log
	_ = uc.invRepo.CreateAuditLog(ctx, &entity.GuestVisitAuditLog{
		InvitationID: &visit.InvitationID,
		VisitID:      &visit.ID,
		ActorID:      securityUserID,
		ActorRole:    securityRole,
		Action:       "CHECK_OUT",
		Status:       "SUCCESS",
		Notes:        req.Notes,
	})

	return uc.invRepo.GetVisitByID(ctx, visit.ID)
}

// ListVisits retrieves visits history for authorized roles (Security, Admin, Chairperson, Vice Chairperson, Treasurer, Secretary)
func (uc *InvitationUseCase) ListVisits(
	ctx context.Context,
	callerRole string,
	filter entity.GuestVisitFilter,
) ([]entity.GuestVisit, int, error) {
	// Guard RBAC
	switch callerRole {
	case string(entity.RoleSecurity),
		string(entity.RoleAdmin),
		string(entity.RoleChairperson),
		string(entity.RoleViceChairperson),
		string(entity.RoleTreasurer),
		string(entity.RoleSecretary):
		// Authorized
	default:
		return nil, 0, ErrUnauthorized
	}

	return uc.invRepo.ListVisits(ctx, filter)
}

// ListGroupedVisits retrieves visits grouped by unique invitation QR
func (uc *InvitationUseCase) ListGroupedVisits(
	ctx context.Context,
	callerRole string,
	filter entity.GuestVisitFilter,
) ([]entity.GuestVisitGroup, int, error) {
	// Guard RBAC
	switch callerRole {
	case string(entity.RoleSecurity),
		string(entity.RoleAdmin),
		string(entity.RoleChairperson),
		string(entity.RoleViceChairperson),
		string(entity.RoleTreasurer),
		string(entity.RoleSecretary):
		// Authorized
	default:
		return nil, 0, ErrUnauthorized
	}

	return uc.invRepo.ListGroupedVisits(ctx, filter)
}

// GetVisitDetail retrieves one visit detail
func (uc *InvitationUseCase) GetVisitDetail(
	ctx context.Context,
	callerRole string,
	visitID int64,
) (*entity.GuestVisit, error) {
	// Guard RBAC
	switch callerRole {
	case string(entity.RoleSecurity),
		string(entity.RoleAdmin),
		string(entity.RoleChairperson),
		string(entity.RoleViceChairperson),
		string(entity.RoleTreasurer),
		string(entity.RoleSecretary):
		// Authorized
	default:
		return nil, ErrUnauthorized
	}

	visit, err := uc.invRepo.GetVisitByID(ctx, visitID)
	if err != nil {
		return nil, err
	}
	if visit == nil {
		return nil, errors.New("data kunjungan tidak ditemukan")
	}
	return visit, nil
}

func strPtr(s string) *string {
	return &s
}

