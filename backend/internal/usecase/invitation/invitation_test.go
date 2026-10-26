package invitation_test

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"testing"
	"time"

	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/usecase/invitation"
)

type mockUserRepo struct {
	user *entity.User
	err  error
}

func (m *mockUserRepo) GetByID(ctx context.Context, id int64) (*entity.User, error) {
	return m.user, m.err
}
func (m *mockUserRepo) GetByEmailOrPhone(ctx context.Context, identifier string) (*entity.User, error) {
	return nil, nil
}
func (m *mockUserRepo) Create(ctx context.Context, user *entity.User) error { return nil }
func (m *mockUserRepo) Update(ctx context.Context, user *entity.User) error { return nil }
func (m *mockUserRepo) Delete(ctx context.Context, id int64) error          { return nil }
func (m *mockUserRepo) UpdateProfile(ctx context.Context, id int64, name, phone string, photoURL *string) error {
	return nil
}
func (m *mockUserRepo) GetPendingUsers(ctx context.Context) ([]entity.PendingUser, error) {
	return nil, nil
}
func (m *mockUserRepo) UpdateStatus(ctx context.Context, id int64, status string, rejectionReason *string) error {
	return nil
}
func (m *mockUserRepo) CountPending(ctx context.Context) (int, error) { return 0, nil }
func (m *mockUserRepo) GetUnassignedResidents(ctx context.Context, search string) ([]entity.UnassignedResident, error) {
	return nil, nil
}
func (m *mockUserRepo) AssignHouse(ctx context.Context, userID int64, houseID int64, occupantType string) error {
	return nil
}
func (m *mockUserRepo) UnassignHouse(ctx context.Context, userID int64, houseID int64) error {
	return nil
}
func (m *mockUserRepo) GetOccupantsByHouseID(ctx context.Context, houseID int64) ([]entity.HouseOccupant, error) {
	return nil, nil
}
func (m *mockUserRepo) CountOccupantsByHouseID(ctx context.Context, houseID int64) (int, error) {
	return 0, nil
}
func (m *mockUserRepo) GetAllUsers(ctx context.Context, search, status, role string, houseID *int64) ([]entity.User, error) {
	return nil, nil
}
func (m *mockUserRepo) UpdatePassword(ctx context.Context, id int64, passwordHash string) error {
	return nil
}

type mockHouseRepo struct {
	house *entity.House
	err   error
}

func (m *mockHouseRepo) GetByID(ctx context.Context, id int64) (*entity.House, error) {
	return m.house, m.err
}
func (m *mockHouseRepo) GetAll(ctx context.Context, block, status, search string) ([]entity.House, error) {
	return nil, nil
}
func (m *mockHouseRepo) GetAvailable(ctx context.Context) ([]entity.House, error) { return nil, nil }
func (m *mockHouseRepo) GetDistinctBlocks(ctx context.Context) ([]string, error)  { return nil, nil }
func (m *mockHouseRepo) Create(ctx context.Context, house *entity.House) error   { return nil }
func (m *mockHouseRepo) Update(ctx context.Context, house *entity.House) error   { return nil }
func (m *mockHouseRepo) Delete(ctx context.Context, id int64) error              { return nil }
func (m *mockHouseRepo) BulkDelete(ctx context.Context, ids []int64) (int64, error) {
	return 0, nil
}

type mockInvitationRepo struct {
	invMap   map[int64]*entity.GuestInvitation
	lastID   int64
	cancelFn func(id int64, cancelledBy int64, reason string) error
}

func newMockInvitationRepo() *mockInvitationRepo {
	return &mockInvitationRepo{
		invMap: make(map[int64]*entity.GuestInvitation),
	}
}

func (m *mockInvitationRepo) Create(ctx context.Context, inv *entity.GuestInvitation) error {
	m.lastID++
	inv.ID = m.lastID
	inv.CreatedAt = time.Now().UTC()
	inv.UpdatedAt = time.Now().UTC()
	stored := *inv
	m.invMap[inv.ID] = &stored
	return nil
}

func (m *mockInvitationRepo) GetByID(ctx context.Context, id int64) (*entity.GuestInvitation, error) {
	inv, ok := m.invMap[id]
	if !ok {
		return nil, nil
	}
	res := *inv
	// Check expiry
	if res.Status == entity.InvitationStatusActive && res.ValidUntil.Before(time.Now().UTC()) {
		res.Status = entity.InvitationStatusExpired
	}
	return &res, nil
}

func (m *mockInvitationRepo) GetByCode(ctx context.Context, code string) (*entity.GuestInvitation, error) {
	for _, inv := range m.invMap {
		if inv.InvitationCode == code {
			res := *inv
			if res.Status == entity.InvitationStatusActive && res.ValidUntil.Before(time.Now().UTC()) {
				res.Status = entity.InvitationStatusExpired
			}
			return &res, nil
		}
	}
	return nil, nil
}

func (m *mockInvitationRepo) ListByHostUserID(ctx context.Context, hostUserID int64, limit, offset int) ([]entity.GuestInvitation, int, error) {
	var list []entity.GuestInvitation
	for _, inv := range m.invMap {
		if inv.HostUserID == hostUserID {
			res := *inv
			if res.Status == entity.InvitationStatusActive && res.ValidUntil.Before(time.Now().UTC()) {
				res.Status = entity.InvitationStatusExpired
			}
			list = append(list, res)
		}
	}
	return list, len(list), nil
}

func (m *mockInvitationRepo) Cancel(ctx context.Context, id int64, cancelledBy int64, reason string) error {
	if m.cancelFn != nil {
		return m.cancelFn(id, cancelledBy, reason)
	}
	inv, ok := m.invMap[id]
	if !ok {
		return nil
	}
	inv.Status = entity.InvitationStatusCancelled
	now := time.Now().UTC()
	inv.CancelledAt = &now
	inv.CancelledBy = &cancelledBy
	inv.CancellationReason = &reason
	return nil
}

func (m *mockInvitationRepo) ExpireOutdatedInvitations(ctx context.Context) (int64, error) {
	var count int64
	now := time.Now().UTC()
	for _, inv := range m.invMap {
		if inv.Status == entity.InvitationStatusActive && inv.ValidUntil.Before(now) {
			inv.Status = entity.InvitationStatusExpired
			count++
		}
	}
	return count, nil
}

func (m *mockInvitationRepo) CheckIn(ctx context.Context, id int64) error {
	inv, ok := m.invMap[id]
	if !ok {
		return fmt.Errorf("not found")
	}
	if inv.Status != entity.InvitationStatusActive {
		return fmt.Errorf("status not active")
	}
	inv.Status = entity.InvitationStatusUsed
	return nil
}

func (m *mockInvitationRepo) Complete(ctx context.Context, id int64) error {
	inv, ok := m.invMap[id]
	if !ok {
		return fmt.Errorf("not found")
	}
	if inv.Status != entity.InvitationStatusActive && inv.Status != entity.InvitationStatusUsed {
		return fmt.Errorf("status not active or used")
	}
	inv.Status = entity.InvitationStatusCompleted
	return nil
}

func (m *mockInvitationRepo) CreateVisit(ctx context.Context, visit *entity.GuestVisit) error {
	m.lastID++
	visit.ID = m.lastID
	visit.CreatedAt = time.Now().UTC()
	visit.UpdatedAt = time.Now().UTC()
	return nil
}

func (m *mockInvitationRepo) GetActiveVisitByInvitationID(ctx context.Context, invitationID int64) (*entity.GuestVisit, error) {
	return nil, nil
}

func (m *mockInvitationRepo) GetVisitByID(ctx context.Context, visitID int64) (*entity.GuestVisit, error) {
	return nil, nil
}

func (m *mockInvitationRepo) CheckOutVisit(ctx context.Context, visitID int64, checkOutBy int64, checkOutAt time.Time, notes *string) error {
	return nil
}

func (m *mockInvitationRepo) ListVisits(ctx context.Context, filter entity.GuestVisitFilter) ([]entity.GuestVisit, int, error) {
	return nil, 0, nil
}

func (m *mockInvitationRepo) ListGroupedVisits(ctx context.Context, filter entity.GuestVisitFilter) ([]entity.GuestVisitGroup, int, error) {
	return nil, 0, nil
}

func (m *mockInvitationRepo) CreateAuditLog(ctx context.Context, log *entity.GuestVisitAuditLog) error {
	return nil
}

func (m *mockInvitationRepo) CountCompletedVisitsByInvitationID(ctx context.Context, invitationID int64) (int, error) {
	return 0, nil
}

func TestInvitationUseCase(t *testing.T) {
	ctx := context.Background()
	secret := "super_secret_test_key"

	houseID := int64(10)
	residentUser := &entity.User{
		ID:      1,
		Name:    "Budi Santoso",
		Status:  string(entity.UserStatusActive),
		HouseID: &houseID,
	}
	house := &entity.House{
		ID:          houseID,
		Block:       "A",
		HouseNumber: "12",
	}

	userRepo := &mockUserRepo{user: residentUser}
	houseRepo := &mockHouseRepo{house: house}
	invRepo := newMockInvitationRepo()

	uc := invitation.NewInvitationUseCase(invRepo, userRepo, houseRepo, secret)

	t.Run("Create Invitation with valid default duration (24h)", func(t *testing.T) {
		req := entity.CreateInvitationRequest{
			GuestName: "Pak Supri",
			VisitType: "TAMU",
		}
		inv, err := uc.CreateInvitation(ctx, 1, req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if inv.GuestName != "Pak Supri" {
			t.Errorf("expected Pak Supri, got %s", inv.GuestName)
		}
		if inv.VisitType != "TAMU" {
			t.Errorf("expected TAMU, got %s", inv.VisitType)
		}
		if inv.Status != entity.InvitationStatusActive {
			t.Errorf("expected ACTIVE, got %s", inv.Status)
		}
		if inv.QRPayload == "" {
			t.Error("expected QR payload not empty")
		}

		// Verify QR payload format
		rawJSON, err := base64.StdEncoding.DecodeString(inv.QRPayload)
		if err != nil {
			t.Fatalf("failed decoding base64 qr: %v", err)
		}
		var qrStruct invitation.QRPayloadStructure
		if err := json.Unmarshal(rawJSON, &qrStruct); err != nil {
			t.Fatalf("failed parsing qr json: %v", err)
		}
		if qrStruct.Code != inv.InvitationCode {
			t.Errorf("expected qr code %s, got %s", inv.InvitationCode, qrStruct.Code)
		}
		if qrStruct.Sig == "" {
			t.Error("expected HMAC signature in QR payload")
		}
	})

	t.Run("Validation: Guest name empty rejected", func(t *testing.T) {
		req := entity.CreateInvitationRequest{
			GuestName: "   ",
			VisitType: "TAMU",
		}
		_, err := uc.CreateInvitation(ctx, 1, req)
		if err == nil {
			t.Fatal("expected error, got nil")
		}
	})

	t.Run("Validation: Invalid visit type rejected", func(t *testing.T) {
		req := entity.CreateInvitationRequest{
			GuestName: "Budi",
			VisitType: "WISATA",
		}
		_, err := uc.CreateInvitation(ctx, 1, req)
		if err == nil {
			t.Fatal("expected error, got nil")
		}
	})

	t.Run("Validation: Duration exceeding 72h rejected", func(t *testing.T) {
		req := entity.CreateInvitationRequest{
			GuestName:  "Budi",
			VisitType:  "KURIR",
			ValidHours: 100,
		}
		_, err := uc.CreateInvitation(ctx, 1, req)
		if err == nil {
			t.Fatal("expected error for >72h, got nil")
		}
	})

	t.Run("Authorization: User without house mapping cannot create invitation", func(t *testing.T) {
		noHouseUser := &entity.User{
			ID:      2,
			Name:    "Admin Tanpa Rumah",
			Status:  string(entity.UserStatusActive),
			HouseID: nil,
		}
		noHouseUserRepo := &mockUserRepo{user: noHouseUser}
		ucNoHouse := invitation.NewInvitationUseCase(invRepo, noHouseUserRepo, houseRepo, secret)

		req := entity.CreateInvitationRequest{
			GuestName: "Kurir J&T",
			VisitType: "KURIR",
		}
		_, err := ucNoHouse.CreateInvitation(ctx, 2, req)
		if err == nil {
			t.Fatal("expected house mapping error, got nil")
		}
	})

	t.Run("Cancel Invitation: Host can cancel active invitation", func(t *testing.T) {
		req := entity.CreateInvitationRequest{
			GuestName: "Tamu Mau Datang",
			VisitType: "TAMU",
		}
		inv, err := uc.CreateInvitation(ctx, 1, req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		err = uc.CancelInvitation(ctx, inv.ID, 1, "Rencana dibatalkan")
		if err != nil {
			t.Fatalf("failed to cancel: %v", err)
		}

		updated, err := uc.GetInvitationDetail(ctx, inv.ID, 1, string(entity.RoleResident))
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if updated.Status != entity.InvitationStatusCancelled {
			t.Errorf("expected CANCELLED, got %s", updated.Status)
		}
	})

	t.Run("Cancel Invitation: Other user cannot cancel", func(t *testing.T) {
		req := entity.CreateInvitationRequest{
			GuestName: "Tamu Pribadi",
			VisitType: "TAMU",
		}
		inv, err := uc.CreateInvitation(ctx, 1, req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		err = uc.CancelInvitation(ctx, inv.ID, 999, "Hacker cancel")
		if err == nil {
			t.Fatal("expected unauthorized error, got nil")
		}
	})

	t.Run("Access Detail: Security and Admin can view, stranger resident cannot", func(t *testing.T) {
		req := entity.CreateInvitationRequest{
			GuestName: "Tamu Penting",
			VisitType: "TAMU",
		}
		inv, err := uc.CreateInvitation(ctx, 1, req)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}

		// Security view
		_, err = uc.GetInvitationDetail(ctx, inv.ID, 88, string(entity.RoleSecurity))
		if err != nil {
			t.Errorf("security should be able to view, got: %v", err)
		}

		// Admin view
		_, err = uc.GetInvitationDetail(ctx, inv.ID, 99, string(entity.RoleAdmin))
		if err != nil {
			t.Errorf("admin should be able to view, got: %v", err)
		}

		// Stranger resident view
		_, err = uc.GetInvitationDetail(ctx, inv.ID, 2, string(entity.RoleResident))
		if err == nil {
			t.Error("stranger resident should NOT be able to view")
		}
	})

	t.Run("Security: Revocation of QR Access (US-1 & US-3)", func(t *testing.T) {
		req := entity.CreateInvitationRequest{
			GuestName:  "Tamu Khusus",
			VisitType:  "TAMU",
			ValidHours: 24,
		}
		inv, err := uc.CreateInvitation(ctx, 1, req)
		if err != nil {
			t.Fatalf("unexpected error creating invitation: %v", err)
		}

		oldQRPayload := inv.QRPayload
		invitationCode := inv.InvitationCode

		// 1. Verifikasi awal: QR aktif sah dan lolos verifikasi
		resActive, err := uc.VerifyAndScanInvitation(ctx, oldQRPayload, false)
		if err != nil || !resActive.Valid {
			t.Fatalf("active invitation must be valid, err: %v", err)
		}

		// 2. Batalkan undangan oleh tuan rumah
		err = uc.CancelInvitation(ctx, inv.ID, 1, "Rencana dibatalkan mendadak")
		if err != nil {
			t.Fatalf("failed to cancel invitation: %v", err)
		}

		// 3. Verifikasi ulang menggunakan QR payload lama (screenshot / file unduhan)
		// Wajib DITOLAK backend dengan pesan "Undangan telah dibatalkan. Akses ditolak."
		resRevokedPayload, err := uc.VerifyAndScanInvitation(ctx, oldQRPayload, false)
		if err == nil {
			t.Fatal("expected error on revoked old QR payload, got nil")
		}
		if resRevokedPayload.Valid {
			t.Fatal("expected valid=false for revoked QR payload")
		}
		if resRevokedPayload.Status != entity.InvitationStatusCancelled {
			t.Fatalf("expected status CANCELLED, got %s", resRevokedPayload.Status)
		}
		if resRevokedPayload.Message != "Undangan telah dibatalkan. Akses ditolak." {
			t.Fatalf("expected revocation message, got: %s", resRevokedPayload.Message)
		}

		// 4. Verifikasi ulang menggunakan invitation code langsung
		resRevokedCode, err := uc.VerifyAndScanInvitation(ctx, invitationCode, true)
		if err == nil {
			t.Fatal("expected error on revoked code, got nil")
		}
		if resRevokedCode.Valid {
			t.Fatal("expected valid=false for revoked code")
		}

		// 5. Pastikan detail undangan yang dibatalkan tidak lagi membocorkan QR aktif
		detail, err := uc.GetInvitationDetail(ctx, inv.ID, 1, string(entity.RoleResident))
		if err != nil {
			t.Fatalf("failed to get detail: %v", err)
		}
		if detail.QRPayload != "" {
			t.Fatalf("cancelled invitation must have empty qr_payload, got: %s", detail.QRPayload)
		}
	})
}
