package http_test

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	delivery "tetanggo-backend/internal/delivery/http"
	"tetanggo-backend/internal/delivery/http/handler"
	"tetanggo-backend/internal/delivery/http/middleware"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
	"tetanggo-backend/internal/usecase/auth"
	"tetanggo-backend/internal/usecase/invitation"
)

type httpMockUserRepo struct {
	users map[int64]*entity.User
}

func (m *httpMockUserRepo) GetByID(ctx context.Context, id int64) (*entity.User, error) {
	if u, ok := m.users[id]; ok {
		return u, nil
	}
	return nil, nil
}
func (m *httpMockUserRepo) GetByEmailOrPhone(ctx context.Context, identifier string) (*entity.User, error) {
	return nil, nil
}
func (m *httpMockUserRepo) Create(ctx context.Context, user *entity.User) error { return nil }
func (m *httpMockUserRepo) Update(ctx context.Context, user *entity.User) error { return nil }
func (m *httpMockUserRepo) Delete(ctx context.Context, id int64) error          { return nil }
func (m *httpMockUserRepo) UpdateProfile(ctx context.Context, id int64, name, phone string, photoURL *string) error {
	return nil
}
func (m *httpMockUserRepo) GetPendingUsers(ctx context.Context) ([]entity.PendingUser, error) {
	return nil, nil
}
func (m *httpMockUserRepo) UpdateStatus(ctx context.Context, id int64, status string, rejectionReason *string) error {
	return nil
}
func (m *httpMockUserRepo) CountPending(ctx context.Context) (int, error) { return 0, nil }
func (m *httpMockUserRepo) GetUnassignedResidents(ctx context.Context, search string) ([]entity.UnassignedResident, error) {
	return nil, nil
}
func (m *httpMockUserRepo) AssignHouse(ctx context.Context, userID int64, houseID int64, occupantType string) error {
	return nil
}
func (m *httpMockUserRepo) UnassignHouse(ctx context.Context, userID int64, houseID int64) error {
	return nil
}
func (m *httpMockUserRepo) GetOccupantsByHouseID(ctx context.Context, houseID int64) ([]entity.HouseOccupant, error) {
	return nil, nil
}
func (m *httpMockUserRepo) CountOccupantsByHouseID(ctx context.Context, houseID int64) (int, error) {
	return 0, nil
}
func (m *httpMockUserRepo) GetAllUsers(ctx context.Context, search, status, role string, houseID *int64) ([]entity.User, error) {
	return nil, nil
}
func (m *httpMockUserRepo) UpdatePassword(ctx context.Context, id int64, passwordHash string) error {
	return nil
}

type httpMockHouseRepo struct {
	houses map[int64]*entity.House
}

func (m *httpMockHouseRepo) GetByID(ctx context.Context, id int64) (*entity.House, error) {
	if h, ok := m.houses[id]; ok {
		return h, nil
	}
	return nil, nil
}
func (m *httpMockHouseRepo) GetAll(ctx context.Context, block, status, search string) ([]entity.House, error) {
	return nil, nil
}
func (m *httpMockHouseRepo) GetAvailable(ctx context.Context) ([]entity.House, error) { return nil, nil }
func (m *httpMockHouseRepo) GetDistinctBlocks(ctx context.Context) ([]string, error)  { return nil, nil }
func (m *httpMockHouseRepo) Create(ctx context.Context, house *entity.House) error   { return nil }
func (m *httpMockHouseRepo) Update(ctx context.Context, house *entity.House) error   { return nil }
func (m *httpMockHouseRepo) Delete(ctx context.Context, id int64) error              { return nil }
func (m *httpMockHouseRepo) BulkDelete(ctx context.Context, ids []int64) (int64, error) {
	return 0, nil
}

type httpMockInvRepo struct {
	invs   map[int64]*entity.GuestInvitation
	visits map[int64]*entity.GuestVisit
	audits []*entity.GuestVisitAuditLog
	lastID int64
}

func (m *httpMockInvRepo) Create(ctx context.Context, inv *entity.GuestInvitation) error {
	m.lastID++
	inv.ID = m.lastID
	inv.CreatedAt = time.Now().UTC()
	inv.UpdatedAt = time.Now().UTC()
	stored := *inv
	m.invs[inv.ID] = &stored
	return nil
}
func (m *httpMockInvRepo) GetByID(ctx context.Context, id int64) (*entity.GuestInvitation, error) {
	if inv, ok := m.invs[id]; ok {
		res := *inv
		if res.Status == entity.InvitationStatusActive && res.ValidUntil.Before(time.Now().UTC()) {
			res.Status = entity.InvitationStatusExpired
		}
		for _, v := range m.visits {
			if v.InvitationID == id {
				if v.Status == entity.VisitStatusCheckedIn {
					res.HasActiveSession = true
				} else if v.Status == entity.VisitStatusCheckedOut {
					res.CompletedVisitsCount++
				}
			}
		}
		return &res, nil
	}
	return nil, nil
}
func (m *httpMockInvRepo) GetByCode(ctx context.Context, code string) (*entity.GuestInvitation, error) {
	for _, inv := range m.invs {
		if inv.InvitationCode == code {
			res := *inv
			if res.Status == entity.InvitationStatusActive && res.ValidUntil.Before(time.Now().UTC()) {
				res.Status = entity.InvitationStatusExpired
			}
			for _, v := range m.visits {
				if v.InvitationID == inv.ID {
					if v.Status == entity.VisitStatusCheckedIn {
						res.HasActiveSession = true
					} else if v.Status == entity.VisitStatusCheckedOut {
						res.CompletedVisitsCount++
					}
				}
			}
			return &res, nil
		}
	}
	return nil, nil
}
func (m *httpMockInvRepo) ListByHostUserID(ctx context.Context, hostUserID int64, limit, offset int) ([]entity.GuestInvitation, int, error) {
	var list []entity.GuestInvitation
	for _, inv := range m.invs {
		if inv.HostUserID == hostUserID {
			res := *inv
			if res.Status == entity.InvitationStatusActive && res.ValidUntil.Before(time.Now().UTC()) {
				res.Status = entity.InvitationStatusExpired
			}
			for _, v := range m.visits {
				if v.InvitationID == inv.ID {
					if v.Status == entity.VisitStatusCheckedIn {
						res.HasActiveSession = true
					} else if v.Status == entity.VisitStatusCheckedOut {
						res.CompletedVisitsCount++
					}
				}
			}
			list = append(list, res)
		}
	}
	return list, len(list), nil
}
func (m *httpMockInvRepo) Cancel(ctx context.Context, id int64, cancelledBy int64, reason string) error {
	inv, ok := m.invs[id]
	if !ok || inv.Status != entity.InvitationStatusActive {
		return fmt.Errorf("cannot cancel")
	}
	inv.Status = entity.InvitationStatusCancelled
	now := time.Now().UTC()
	inv.CancelledAt = &now
	inv.CancelledBy = &cancelledBy
	inv.CancellationReason = &reason
	return nil
}
func (m *httpMockInvRepo) ExpireOutdatedInvitations(ctx context.Context) (int64, error) {
	return 0, nil
}
func (m *httpMockInvRepo) CheckIn(ctx context.Context, id int64) error {
	inv, ok := m.invs[id]
	if !ok {
		return fmt.Errorf("not found")
	}
	inv.Status = entity.InvitationStatusUsed
	return nil
}
func (m *httpMockInvRepo) Complete(ctx context.Context, id int64) error {
	inv, ok := m.invs[id]
	if !ok {
		return fmt.Errorf("not found")
	}
	inv.Status = entity.InvitationStatusCompleted
	return nil
}
func (m *httpMockInvRepo) CreateVisit(ctx context.Context, visit *entity.GuestVisit) error {
	m.lastID++
	visit.ID = m.lastID
	visit.CreatedAt = time.Now().UTC()
	visit.UpdatedAt = time.Now().UTC()
	if inv := m.invs[visit.InvitationID]; inv != nil {
		visit.InvitationCode = inv.InvitationCode
		visit.GuestName = inv.GuestName
		visit.VisitType = inv.VisitType
		visit.HostName = inv.HostName
		visit.HouseBlock = inv.HouseBlock
		visit.HouseNumber = inv.HouseNumber
	}
	stored := *visit
	m.visits[visit.ID] = &stored
	return nil
}
func (m *httpMockInvRepo) GetActiveVisitByInvitationID(ctx context.Context, invitationID int64) (*entity.GuestVisit, error) {
	for _, v := range m.visits {
		if v.InvitationID == invitationID && v.Status == entity.VisitStatusCheckedIn {
			res := *v
			return &res, nil
		}
	}
	return nil, nil
}
func (m *httpMockInvRepo) GetVisitByID(ctx context.Context, visitID int64) (*entity.GuestVisit, error) {
	if v, ok := m.visits[visitID]; ok {
		res := *v
		return &res, nil
	}
	return nil, nil
}
func (m *httpMockInvRepo) CheckOutVisit(ctx context.Context, visitID int64, checkOutBy int64, checkOutAt time.Time, notes *string) error {
	v, ok := m.visits[visitID]
	if !ok || v.Status != entity.VisitStatusCheckedIn {
		return fmt.Errorf("visit not checked in")
	}
	v.Status = entity.VisitStatusCheckedOut
	v.CheckOutAt = &checkOutAt
	v.CheckOutBy = &checkOutBy
	v.Notes = notes
	v.UpdatedAt = checkOutAt
	return nil
}
func (m *httpMockInvRepo) ListVisits(ctx context.Context, filter entity.GuestVisitFilter) ([]entity.GuestVisit, int, error) {
	var list []entity.GuestVisit
	for _, v := range m.visits {
		list = append(list, *v)
	}
	return list, len(list), nil
}
func (m *httpMockInvRepo) ListGroupedVisits(ctx context.Context, filter entity.GuestVisitFilter) ([]entity.GuestVisitGroup, int, error) {
	groupedMap := make(map[int64]*entity.GuestVisitGroup)
	for _, v := range m.visits {
		g, ok := groupedMap[v.InvitationID]
		if !ok {
			inv := m.invs[v.InvitationID]
			var st entity.InvitationStatus
			var vUntil time.Time
			var vFrom time.Time
			if inv != nil {
				st = inv.Status
				vUntil = inv.ValidUntil
				vFrom = inv.ValidFrom
			}
			g = &entity.GuestVisitGroup{
				InvitationID:     v.InvitationID,
				InvitationCode:   v.InvitationCode,
				GuestName:        v.GuestName,
				VisitType:        v.VisitType,
				HostName:         v.HostName,
				HouseBlock:       v.HouseBlock,
				HouseNumber:      v.HouseNumber,
				InvitationStatus: st,
				ValidFrom:        vFrom,
				ValidUntil:       vUntil,
				FirstCheckInAt:   v.CheckInAt,
				LatestActivityAt: v.CheckInAt,
				Visits:           []entity.GuestVisit{},
			}
			groupedMap[v.InvitationID] = g
		}
		g.Visits = append(g.Visits, *v)
		g.TotalVisits++
		if v.Status == entity.VisitStatusCheckedIn {
			g.HasActiveSession = true
			vid := v.ID
			g.ActiveVisitID = &vid
		}
		if v.CheckOutAt != nil && v.CheckOutAt.After(g.LatestActivityAt) {
			g.LatestActivityAt = *v.CheckOutAt
		}
	}

	var result []entity.GuestVisitGroup
	for _, g := range groupedMap {
		result = append(result, *g)
	}
	return result, len(result), nil
}
func (m *httpMockInvRepo) CreateAuditLog(ctx context.Context, log *entity.GuestVisitAuditLog) error {
	m.audits = append(m.audits, log)
	return nil
}
func (m *httpMockInvRepo) CountCompletedVisitsByInvitationID(ctx context.Context, invitationID int64) (int, error) {
	count := 0
	for _, v := range m.visits {
		if v.InvitationID == invitationID && v.Status == entity.VisitStatusCheckedOut {
			count++
		}
	}
	return count, nil
}

func setupTestApp() (*deliveryTestEnv, error) {
	secret := "jwt_test_secret_for_sprint_5_tetanggo"
	tokenService := auth.NewTokenService(secret, 60, 7)

	hID := int64(1)
	userRepo := &httpMockUserRepo{
		users: map[int64]*entity.User{
			1: {
				ID:      1,
				Name:    "Warga Budi",
				RoleID:  6,
				Status:  string(entity.UserStatusActive),
				HouseID: &hID,
			},
			2: {
				ID:      2,
				Name:    "Admin Tanpa Rumah",
				RoleID:  1,
				Status:  string(entity.UserStatusActive),
				HouseID: nil,
			},
			3: {
				ID:      3,
				Name:    "Satpam Pos",
				RoleID:  7,
				Status:  string(entity.UserStatusActive),
				HouseID: nil,
			},
			4: {
				ID:      4,
				Name:    "Warga Lain",
				RoleID:  6,
				Status:  string(entity.UserStatusActive),
				HouseID: &hID,
			},
		},
	}
	houseRepo := &httpMockHouseRepo{
		houses: map[int64]*entity.House{
			1: {
				ID:          1,
				Block:       "B",
				HouseNumber: "05",
			},
		},
	}
	invRepo := &httpMockInvRepo{
		invs:   make(map[int64]*entity.GuestInvitation),
		visits: make(map[int64]*entity.GuestVisit),
		audits: make([]*entity.GuestVisitAuditLog, 0),
	}

	invUC := invitation.NewInvitationUseCase(invRepo, userRepo, houseRepo, secret)

	appHandler := handler.NewAppHandler(
		&sql.DB{}, nil, nil, nil, nil, nil, nil, nil, nil, nil, invUC,
	)

	authMid := middleware.NewAuthMiddleware(tokenService, userRepo)
	app := delivery.SetupRouter(appHandler, authMid)

	return &deliveryTestEnv{
		app:          app,
		tokenService: tokenService,
		userRepo:     userRepo,
		invRepo:      invRepo,
	}, nil
}

type deliveryTestEnv struct {
	app          interface{ Test(req *http.Request, msTimeout ...int) (*http.Response, error) }
	tokenService *auth.TokenService
	userRepo     repository.UserRepository
	invRepo      repository.GuestInvitationRepository
}

func (e *deliveryTestEnv) generateToken(userID int64, email, role string) string {
	tok, _, _ := e.tokenService.GenerateTokenPair(userID, email, role)
	return tok
}

func TestSprint5_GuestInvitationAPI(t *testing.T) {
	env, err := setupTestApp()
	if err != nil {
		t.Fatalf("failed setup: %v", err)
	}

	residentToken := env.generateToken(1, "budi@tetanggo.id", string(entity.RoleResident))
	adminToken := env.generateToken(2, "admin@tetanggo.id", string(entity.RoleAdmin))
	securityToken := env.generateToken(3, "satpam@tetanggo.id", string(entity.RoleSecurity))
	otherResidentToken := env.generateToken(4, "warga2@tetanggo.id", string(entity.RoleResident))

	var createdInvID int64
	var createdQRPayload string

	t.Run("1. Resident creates valid TAMU invitation", func(t *testing.T) {
		body := map[string]interface{}{
			"guest_name":  "Bambang Sudirman",
			"visit_type":  "TAMU",
			"phone":       "08123456789",
			"notes":       "Kunjungan silaturahmi keluarga",
			"valid_hours": 24,
		}
		jsonBytes, _ := json.Marshal(body)
		req := httptest.NewRequest("POST", "/api/v1/invitations", bytes.NewReader(jsonBytes))
		req.Header.Set("Authorization", "Bearer "+residentToken)
		req.Header.Set("Content-Type", "application/json")

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("expected 201 Created, got %d", resp.StatusCode)
		}

		var resBody struct {
			Success bool                   `json:"success"`
			Data    entity.GuestInvitation `json:"data"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&resBody)
		if !resBody.Success {
			t.Error("expected success true")
		}
		if resBody.Data.GuestName != "Bambang Sudirman" {
			t.Errorf("expected Bambang Sudirman, got %s", resBody.Data.GuestName)
		}
		if resBody.Data.QRPayload == "" {
			t.Error("expected non-empty QR payload")
		}
		createdInvID = resBody.Data.ID
		createdQRPayload = resBody.Data.QRPayload
	})

	t.Run("2. Admin without house mapping is FORBIDDEN from creating invitation", func(t *testing.T) {
		body := map[string]interface{}{
			"guest_name": "Kurir Paket",
			"visit_type": "KURIR",
		}
		jsonBytes, _ := json.Marshal(body)
		req := httptest.NewRequest("POST", "/api/v1/invitations", bytes.NewReader(jsonBytes))
		req.Header.Set("Authorization", "Bearer "+adminToken)
		req.Header.Set("Content-Type", "application/json")

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Errorf("expected 403 Forbidden, got %d", resp.StatusCode)
		}
	})

	t.Run("3. Security without house mapping is FORBIDDEN from creating invitation", func(t *testing.T) {
		body := map[string]interface{}{
			"guest_name": "Kurir Makanan",
			"visit_type": "KURIR",
		}
		jsonBytes, _ := json.Marshal(body)
		req := httptest.NewRequest("POST", "/api/v1/invitations", bytes.NewReader(jsonBytes))
		req.Header.Set("Authorization", "Bearer "+securityToken)
		req.Header.Set("Content-Type", "application/json")

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Errorf("expected 403 Forbidden, got %d", resp.StatusCode)
		}
	})

	t.Run("4. Resident views own invitations list", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/api/v1/invitations?page=1&limit=10", nil)
		req.Header.Set("Authorization", "Bearer "+residentToken)

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK, got %d", resp.StatusCode)
		}

		var resBody struct {
			Success bool                     `json:"success"`
			Data    []entity.GuestInvitation `json:"data"`
			Total   int                      `json:"total"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&resBody)
		if len(resBody.Data) == 0 {
			t.Error("expected non-empty invitations list")
		}
	})

	t.Run("5. Security can view invitation detail for verification", func(t *testing.T) {
		req := httptest.NewRequest("GET", fmt.Sprintf("/api/v1/invitations/%d", createdInvID), nil)
		req.Header.Set("Authorization", "Bearer "+securityToken)

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK, got %d", resp.StatusCode)
		}
	})

	t.Run("6. Other resident CANNOT view private invitation detail", func(t *testing.T) {
		req := httptest.NewRequest("GET", fmt.Sprintf("/api/v1/invitations/%d", createdInvID), nil)
		req.Header.Set("Authorization", "Bearer "+otherResidentToken)

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Errorf("expected 403 Forbidden, got %d", resp.StatusCode)
		}
	})

	t.Run("7. Other resident CANNOT cancel invitation", func(t *testing.T) {
		body := map[string]interface{}{"reason": "Hacking cancel"}
		jsonBytes, _ := json.Marshal(body)
		req := httptest.NewRequest("POST", fmt.Sprintf("/api/v1/invitations/%d/cancel", createdInvID), bytes.NewReader(jsonBytes))
		req.Header.Set("Authorization", "Bearer "+otherResidentToken)
		req.Header.Set("Content-Type", "application/json")

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Errorf("expected 403 Forbidden, got %d", resp.StatusCode)
		}
	})

	t.Run("8. Host resident cancels own invitation", func(t *testing.T) {
		body := map[string]interface{}{"reason": "Tamu menunda jadwal kedatangan"}
		jsonBytes, _ := json.Marshal(body)
		req := httptest.NewRequest("POST", fmt.Sprintf("/api/v1/invitations/%d/cancel", createdInvID), bytes.NewReader(jsonBytes))
		req.Header.Set("Authorization", "Bearer "+residentToken)
		req.Header.Set("Content-Type", "application/json")

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK, got %d", resp.StatusCode)
		}

		// Verify status cancelled
		detailReq := httptest.NewRequest("GET", fmt.Sprintf("/api/v1/invitations/%d", createdInvID), nil)
		detailReq.Header.Set("Authorization", "Bearer "+residentToken)
		detailResp, _ := env.app.Test(detailReq)
		var resBody struct {
			Data entity.GuestInvitation `json:"data"`
		}
		_ = json.NewDecoder(detailResp.Body).Decode(&resBody)
		if resBody.Data.Status != entity.InvitationStatusCancelled {
			t.Errorf("expected CANCELLED, got %s", resBody.Data.Status)
		}
	})

	t.Run("9. Security scans revoked invitation QR -> Access Denied (US-1 & US-3)", func(t *testing.T) {
		// Satpam scan QR code yang baru saja dibatalkan pada step 8
		verifyBody := map[string]interface{}{
			"code": createdQRPayload,
		}
		jsonBytes, _ := json.Marshal(verifyBody)
		req := httptest.NewRequest("POST", "/api/v1/invitations/verify", bytes.NewReader(jsonBytes))
		req.Header.Set("Authorization", "Bearer "+securityToken)
		req.Header.Set("Content-Type", "application/json")

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}

		// Harus ditolak dengan status 403 Forbidden
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for cancelled invitation, got %d", resp.StatusCode)
		}

		var verifyResp struct {
			Success bool   `json:"success"`
			Valid   bool   `json:"valid"`
			Status  string `json:"status"`
			Message string `json:"message"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&verifyResp)

		if verifyResp.Valid {
			t.Error("expected valid=false")
		}
		if verifyResp.Status != string(entity.InvitationStatusCancelled) {
			t.Errorf("expected status CANCELLED, got %s", verifyResp.Status)
		}
		if verifyResp.Message != "Undangan telah dibatalkan. Akses ditolak." {
			t.Errorf("unexpected message: %s", verifyResp.Message)
		}
	})

	t.Run("10. Resident without role cannot call verify endpoint (RBAC check)", func(t *testing.T) {
		verifyBody := map[string]interface{}{
			"code": "ANY-CODE",
		}
		jsonBytes, _ := json.Marshal(verifyBody)
		req := httptest.NewRequest("POST", "/api/v1/invitations/verify", bytes.NewReader(jsonBytes))
		req.Header.Set("Authorization", "Bearer "+residentToken) // Warga biasa
		req.Header.Set("Content-Type", "application/json")

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("req failed: %v", err)
		}
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for resident calling verify, got %d", resp.StatusCode)
		}
	})

	t.Run("11. US-5.2 Gate Operations: Check-In by Security officer", func(t *testing.T) {
		// Buat undangan aktif baru untuk di-check-in
		now := time.Now().UTC()
		activeInv := &entity.GuestInvitation{
			InvitationCode: "INV-GATE-CHECKIN",
			HostUserID:     1,
			HouseID:        1,
			GuestName:      "Tamu Khusus",
			VisitType:      "TAMU",
			ValidFrom:      now.Add(-1 * time.Hour),
			ValidUntil:     now.Add(24 * time.Hour),
			Status:         entity.InvitationStatusActive,
		}
		_ = env.invRepo.Create(context.Background(), activeInv)

		// 11.a Security Check-in SUCCESS
		checkInBody := map[string]interface{}{
			"code":  activeInv.InvitationCode,
			"notes": "Masuk via Gerbang Utama",
		}
		jsonBytes, _ := json.Marshal(checkInBody)
		req := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(jsonBytes))
		req.Header.Set("Authorization", "Bearer "+securityToken)
		req.Header.Set("Content-Type", "application/json")

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("check-in request failed: %v", err)
		}
		if resp.StatusCode != http.StatusCreated {
			t.Fatalf("expected 201 Created for check-in by security, got %d", resp.StatusCode)
		}

		// 11.b Double Check-In rejected (409 Conflict)
		reqDuplicate := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(jsonBytes))
		reqDuplicate.Header.Set("Authorization", "Bearer "+securityToken)
		reqDuplicate.Header.Set("Content-Type", "application/json")

		respDup, _ := env.app.Test(reqDuplicate)
		if respDup.StatusCode != http.StatusConflict {
			t.Fatalf("expected 409 Conflict for double check-in, got %d", respDup.StatusCode)
		}
	})

	t.Run("12. US-5.2 RBAC: Admin & Pengurus rejected from check-in/check-out operational endpoints", func(t *testing.T) {
		adminToken := env.generateToken(2, "admin@tetanggo.id", string(entity.RoleAdmin))
		chairpersonToken := env.generateToken(5, "ketua@tetanggo.id", string(entity.RoleChairperson))
		treasurerToken := env.generateToken(6, "bendahara@tetanggo.id", string(entity.RoleTreasurer))

		checkInBody := map[string]interface{}{
			"code": "INV-GATE-CHECKIN",
		}
		jsonBytes, _ := json.Marshal(checkInBody)

		// Admin coba check-in -> 403 Forbidden
		reqAdmin := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(jsonBytes))
		reqAdmin.Header.Set("Authorization", "Bearer "+adminToken)
		reqAdmin.Header.Set("Content-Type", "application/json")
		respAdmin, _ := env.app.Test(reqAdmin)
		if respAdmin.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for Admin on check-in, got %d", respAdmin.StatusCode)
		}

		// Ketua coba check-in -> 403 Forbidden
		reqChair := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(jsonBytes))
		reqChair.Header.Set("Authorization", "Bearer "+chairpersonToken)
		reqChair.Header.Set("Content-Type", "application/json")
		respChair, _ := env.app.Test(reqChair)
		if respChair.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for Chairperson on check-in, got %d", respChair.StatusCode)
		}

		// Bendahara coba check-out -> 403 Forbidden
		reqTreas := httptest.NewRequest("POST", "/api/v1/invitations/check-out", bytes.NewReader(jsonBytes))
		reqTreas.Header.Set("Authorization", "Bearer "+treasurerToken)
		reqTreas.Header.Set("Content-Type", "application/json")
		respTreas, _ := env.app.Test(reqTreas)
		if respTreas.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for Treasurer on check-out, got %d", respTreas.StatusCode)
		}
	})

	t.Run("13. US-5.2 Read-only Visit History: Accessible by Admin, Pengurus, and Security; Denied for Resident", func(t *testing.T) {
		adminToken := env.generateToken(2, "admin@tetanggo.id", string(entity.RoleAdmin))
		chairpersonToken := env.generateToken(5, "ketua@tetanggo.id", string(entity.RoleChairperson))
		treasurerToken := env.generateToken(6, "bendahara@tetanggo.id", string(entity.RoleTreasurer))
		secretaryToken := env.generateToken(7, "sekretaris@tetanggo.id", string(entity.RoleSecretary))

		// 13.a Security accesses visits -> 200 OK
		reqSec := httptest.NewRequest("GET", "/api/v1/invitations/visits", nil)
		reqSec.Header.Set("Authorization", "Bearer "+securityToken)
		respSec, _ := env.app.Test(reqSec)
		if respSec.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for Security on visits list, got %d", respSec.StatusCode)
		}

		// 13.b Admin accesses visits -> 200 OK
		reqAdmin := httptest.NewRequest("GET", "/api/v1/invitations/visits", nil)
		reqAdmin.Header.Set("Authorization", "Bearer "+adminToken)
		respAdmin, _ := env.app.Test(reqAdmin)
		if respAdmin.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for Admin on visits list, got %d", respAdmin.StatusCode)
		}

		// 13.c Chairperson accesses visits -> 200 OK
		reqChair := httptest.NewRequest("GET", "/api/v1/invitations/visits", nil)
		reqChair.Header.Set("Authorization", "Bearer "+chairpersonToken)
		respChair, _ := env.app.Test(reqChair)
		if respChair.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for Chairperson on visits list, got %d", respChair.StatusCode)
		}

		// 13.d Treasurer accesses visits -> 200 OK
		reqTreas := httptest.NewRequest("GET", "/api/v1/invitations/visits", nil)
		reqTreas.Header.Set("Authorization", "Bearer "+treasurerToken)
		respTreas, _ := env.app.Test(reqTreas)
		if respTreas.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for Treasurer on visits list, got %d", respTreas.StatusCode)
		}

		// 13.e Secretary accesses visits -> 200 OK
		reqSecr := httptest.NewRequest("GET", "/api/v1/invitations/visits", nil)
		reqSecr.Header.Set("Authorization", "Bearer "+secretaryToken)
		respSecr, _ := env.app.Test(reqSecr)
		if respSecr.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for Secretary on visits list, got %d", respSecr.StatusCode)
		}

		// 13.f Resident denied access to visits -> 403 Forbidden
		reqRes := httptest.NewRequest("GET", "/api/v1/invitations/visits", nil)
		reqRes.Header.Set("Authorization", "Bearer "+residentToken)
		respRes, _ := env.app.Test(reqRes)
		if respRes.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for Resident on visits list, got %d", respRes.StatusCode)
		}
	})

	t.Run("14. US-5.2 Gate Operations: Check-Out by Security officer", func(t *testing.T) {
		checkOutBody := map[string]interface{}{
			"code":  "INV-GATE-CHECKIN",
			"notes": "Keluar gerbang dengan tertib",
		}
		jsonBytes, _ := json.Marshal(checkOutBody)
		req := httptest.NewRequest("POST", "/api/v1/invitations/check-out", bytes.NewReader(jsonBytes))
		req.Header.Set("Authorization", "Bearer "+securityToken)
		req.Header.Set("Content-Type", "application/json")

		resp, err := env.app.Test(req)
		if err != nil {
			t.Fatalf("check-out request failed: %v", err)
		}
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for check-out by security, got %d", resp.StatusCode)
		}

		// Check-Out berulang ditolak (404 / no active visit)
		reqRepeat := httptest.NewRequest("POST", "/api/v1/invitations/check-out", bytes.NewReader(jsonBytes))
		reqRepeat.Header.Set("Authorization", "Bearer "+securityToken)
		reqRepeat.Header.Set("Content-Type", "application/json")
		respRepeat, _ := env.app.Test(reqRepeat)
		if respRepeat.StatusCode != http.StatusNotFound {
			t.Fatalf("expected 404 for check-out without active checked-in visit, got %d", respRepeat.StatusCode)
		}
	})

	t.Run("15. US-5.2 Enhancement: Repeated check-in/check-out cycles and resident completion", func(t *testing.T) {
		now := time.Now().UTC()
		multiInv := &entity.GuestInvitation{
			InvitationCode: "INV-REPEATED-CYCLE",
			HostUserID:     1,
			HouseID:        1,
			GuestName:      "Tamu Berulang",
			VisitType:      "TAMU",
			ValidFrom:      now.Add(-1 * time.Hour),
			ValidUntil:     now.Add(24 * time.Hour),
			Status:         entity.InvitationStatusActive,
		}
		_ = env.invRepo.Create(context.Background(), multiInv)

		// Siklus 1: Check-in
		bodyCheckIn, _ := json.Marshal(map[string]interface{}{"code": multiInv.InvitationCode})
		req1 := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(bodyCheckIn))
		req1.Header.Set("Authorization", "Bearer "+securityToken)
		req1.Header.Set("Content-Type", "application/json")
		resp1, _ := env.app.Test(req1)
		if resp1.StatusCode != http.StatusCreated {
			t.Fatalf("cycle 1 check-in failed, got %d", resp1.StatusCode)
		}

		// Siklus 1: Check-out
		bodyCheckOut, _ := json.Marshal(map[string]interface{}{"code": multiInv.InvitationCode})
		req2 := httptest.NewRequest("POST", "/api/v1/invitations/check-out", bytes.NewReader(bodyCheckOut))
		req2.Header.Set("Authorization", "Bearer "+securityToken)
		req2.Header.Set("Content-Type", "application/json")
		resp2, _ := env.app.Test(req2)
		if resp2.StatusCode != http.StatusOK {
			t.Fatalf("cycle 1 check-out failed, got %d", resp2.StatusCode)
		}

		// Siklus 2: Check-in ulang dengan QR yang sama -> SUCCESS
		req3 := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(bodyCheckIn))
		req3.Header.Set("Authorization", "Bearer "+securityToken)
		req3.Header.Set("Content-Type", "application/json")
		resp3, _ := env.app.Test(req3)
		if resp3.StatusCode != http.StatusCreated {
			t.Fatalf("cycle 2 check-in failed, expected 201 Created, got %d", resp3.StatusCode)
		}

		// Siklus 2: Check-out
		req4 := httptest.NewRequest("POST", "/api/v1/invitations/check-out", bytes.NewReader(bodyCheckOut))
		req4.Header.Set("Authorization", "Bearer "+securityToken)
		req4.Header.Set("Content-Type", "application/json")
		resp4, _ := env.app.Test(req4)
		if resp4.StatusCode != http.StatusOK {
			t.Fatalf("cycle 2 check-out failed, got %d", resp4.StatusCode)
		}

		// Warga menyelesaikan kunjungan
		completeURL := fmt.Sprintf("/api/v1/invitations/%d/complete", multiInv.ID)
		reqComp := httptest.NewRequest("POST", completeURL, nil)
		reqComp.Header.Set("Authorization", "Bearer "+residentToken)
		respComp, _ := env.app.Test(reqComp)
		if respComp.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for resident completing invitation, got %d", respComp.StatusCode)
		}

		// Scan berikutnya ditolak (StatusGone / 410)
		reqVerifyAfter := httptest.NewRequest("POST", "/api/v1/invitations/verify", bytes.NewReader(bodyCheckIn))
		reqVerifyAfter.Header.Set("Authorization", "Bearer "+securityToken)
		reqVerifyAfter.Header.Set("Content-Type", "application/json")
		respVerifyAfter, _ := env.app.Test(reqVerifyAfter)
		if respVerifyAfter.StatusCode != http.StatusGone {
			t.Fatalf("expected 410 Gone for completed invitation scan, got %d", respVerifyAfter.StatusCode)
		}

		// Check-in baru setelah complete ditolak
		reqCheckInAfter := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(bodyCheckIn))
		reqCheckInAfter.Header.Set("Authorization", "Bearer "+securityToken)
		reqCheckInAfter.Header.Set("Content-Type", "application/json")
		respCheckInAfter, _ := env.app.Test(reqCheckInAfter)
		if respCheckInAfter.StatusCode != http.StatusGone && respCheckInAfter.StatusCode != http.StatusBadRequest {
			t.Fatalf("expected rejection for check-in after completion, got %d", respCheckInAfter.StatusCode)
		}
	})

	t.Run("16. US-5.2 Active visit rejects host completion, but can checkout and then be completed", func(t *testing.T) {
		now := time.Now().UTC()
		invWithActive := &entity.GuestInvitation{
			InvitationCode: "INV-ACTIVE-WHEN-COMPLETED",
			HostUserID:     1,
			HouseID:        1,
			GuestName:      "Tamu Dalam Lingkungan",
			VisitType:      "TAMU",
			ValidFrom:      now.Add(-1 * time.Hour),
			ValidUntil:     now.Add(24 * time.Hour),
			Status:         entity.InvitationStatusActive,
		}
		_ = env.invRepo.Create(context.Background(), invWithActive)

		// 1. Check-in tamu
		bodyCode, _ := json.Marshal(map[string]interface{}{"code": invWithActive.InvitationCode})
		reqIn := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(bodyCode))
		reqIn.Header.Set("Authorization", "Bearer "+securityToken)
		reqIn.Header.Set("Content-Type", "application/json")
		respIn, _ := env.app.Test(reqIn)
		if respIn.StatusCode != http.StatusCreated {
			t.Fatalf("check-in failed: %d", respIn.StatusCode)
		}

		// 2. Warga mencoba menyelesaikan undangan saat tamu masih di dalam -> DITOLAK (409 Conflict)
		completeURL := fmt.Sprintf("/api/v1/invitations/%d/complete", invWithActive.ID)
		reqCompWhileActive := httptest.NewRequest("POST", completeURL, nil)
		reqCompWhileActive.Header.Set("Authorization", "Bearer "+residentToken)
		respCompWhileActive, _ := env.app.Test(reqCompWhileActive)
		if respCompWhileActive.StatusCode != http.StatusConflict {
			t.Fatalf("expected 409 Conflict when completing while visit is active, got %d", respCompWhileActive.StatusCode)
		}

		// 3. Scan check-out oleh satpam berhasil menutup sesi aktif
		reqOut := httptest.NewRequest("POST", "/api/v1/invitations/check-out", bytes.NewReader(bodyCode))
		reqOut.Header.Set("Authorization", "Bearer "+securityToken)
		reqOut.Header.Set("Content-Type", "application/json")
		respOut, _ := env.app.Test(reqOut)
		if respOut.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for checking out active visit, got %d", respOut.StatusCode)
		}

		// 4. Setelah checkout selesai, warga sekarang berhasil menyelesaikan undangan
		reqCompAfterOut := httptest.NewRequest("POST", completeURL, nil)
		reqCompAfterOut.Header.Set("Authorization", "Bearer "+residentToken)
		respCompAfterOut, _ := env.app.Test(reqCompAfterOut)
		if respCompAfterOut.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for completing after checkout, got %d", respCompAfterOut.StatusCode)
		}

		// 5. Setelah diakhiri, check-in baru ditolak (410 Gone)
		reqInAgain := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(bodyCode))
		reqInAgain.Header.Set("Authorization", "Bearer "+securityToken)
		reqInAgain.Header.Set("Content-Type", "application/json")
		respInAgain, _ := env.app.Test(reqInAgain)
		if respInAgain.StatusCode != http.StatusGone && respInAgain.StatusCode != http.StatusBadRequest {
			t.Fatalf("expected rejection for check-in after completed invitation closed, got %d", respInAgain.StatusCode)
		}
	})

	t.Run("17. US-5.2 Check-out with end_invitation closes visit and completes invitation", func(t *testing.T) {
		now := time.Now().UTC()
		invToEnd := &entity.GuestInvitation{
			InvitationCode: "INV-CHECKOUT-AND-END",
			HostUserID:     1,
			HouseID:        1,
			GuestName:      "Tamu Mau Diakhiri Sekalian",
			VisitType:      "TAMU",
			ValidFrom:      now.Add(-1 * time.Hour),
			ValidUntil:     now.Add(24 * time.Hour),
			Status:         entity.InvitationStatusActive,
		}
		_ = env.invRepo.Create(context.Background(), invToEnd)

		// 1. Check-in tamu
		bodyCode, _ := json.Marshal(map[string]interface{}{"code": invToEnd.InvitationCode})
		reqIn := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(bodyCode))
		reqIn.Header.Set("Authorization", "Bearer "+securityToken)
		reqIn.Header.Set("Content-Type", "application/json")
		respIn, _ := env.app.Test(reqIn)
		if respIn.StatusCode != http.StatusCreated {
			t.Fatalf("check-in failed: %d", respIn.StatusCode)
		}

		// 2. Satpam Check-out dengan end_invitation = true
		bodyCheckOutEnd, _ := json.Marshal(map[string]interface{}{
			"code":           invToEnd.InvitationCode,
			"end_invitation": true,
		})
		reqOutEnd := httptest.NewRequest("POST", "/api/v1/invitations/check-out", bytes.NewReader(bodyCheckOutEnd))
		reqOutEnd.Header.Set("Authorization", "Bearer "+securityToken)
		reqOutEnd.Header.Set("Content-Type", "application/json")
		respOutEnd, _ := env.app.Test(reqOutEnd)
		if respOutEnd.StatusCode != http.StatusOK {
			t.Fatalf("check-out with end_invitation failed: %d", respOutEnd.StatusCode)
		}

		// 3. Undangan harus berubah menjadi COMPLETED
		invCheck, _ := env.invRepo.GetByID(context.Background(), invToEnd.ID)
		if invCheck.Status != entity.InvitationStatusCompleted {
			t.Fatalf("expected invitation status COMPLETED, got %s", invCheck.Status)
		}

		// 4. Scan QR selanjutnya ditolak
		reqVerify := httptest.NewRequest("POST", "/api/v1/invitations/verify", bytes.NewReader(bodyCode))
		reqVerify.Header.Set("Authorization", "Bearer "+securityToken)
		reqVerify.Header.Set("Content-Type", "application/json")
		respVerify, _ := env.app.Test(reqVerify)
		if respVerify.StatusCode != http.StatusGone {
			t.Fatalf("expected 410 Gone for ended invitation, got %d", respVerify.StatusCode)
		}
	})

	t.Run("18. US-5.2 Grouped visits endpoint returns one entry with multi-session history", func(t *testing.T) {
		reqGrouped := httptest.NewRequest("GET", "/api/v1/invitations/visits?grouped=true", nil)
		reqGrouped.Header.Set("Authorization", "Bearer "+securityToken)
		respGrouped, _ := env.app.Test(reqGrouped)
		if respGrouped.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for grouped visits, got %d", respGrouped.StatusCode)
		}

		var body struct {
			Success bool                    `json:"success"`
			Data    []entity.GuestVisitGroup `json:"data"`
		}
		_ = json.NewDecoder(respGrouped.Body).Decode(&body)
		if !body.Success || len(body.Data) == 0 {
			t.Fatalf("expected valid grouped visits data, got: %+v", body)
		}

		// Temukan group INV-REPEATED-CYCLE yang punya 2 siklus
		var foundMulti *entity.GuestVisitGroup
		for _, g := range body.Data {
			if g.InvitationCode == "INV-REPEATED-CYCLE" {
				copyG := g
				foundMulti = &copyG
				break
			}
		}
		if foundMulti == nil {
			t.Fatalf("expected to find grouped invitation INV-REPEATED-CYCLE")
		}
		if foundMulti.TotalVisits != 2 || len(foundMulti.Visits) != 2 {
			t.Fatalf("expected 2 visits under INV-REPEATED-CYCLE, got total_visits=%d, visits_len=%d", foundMulti.TotalVisits, len(foundMulti.Visits))
		}
	})

	t.Run("19. BugFix: Host resident ends invitation after checkout when time remains, subsequent check-in rejected", func(t *testing.T) {
		now := time.Now().UTC()
		courierInv := &entity.GuestInvitation{
			InvitationCode: "INV-COURIER-24H",
			HostUserID:     1,
			HouseID:        1,
			GuestName:      "Kurir Paket Kilat",
			VisitType:      "PENGANTARAN",
			ValidFrom:      now.Add(-1 * time.Hour),
			ValidUntil:     now.Add(23 * time.Hour), // Masih tersisa 23 jam
			Status:         entity.InvitationStatusActive,
		}
		_ = env.invRepo.Create(context.Background(), courierInv)

		// 1. Kurir check-in oleh satpam
		bodyCode, _ := json.Marshal(map[string]interface{}{"code": courierInv.InvitationCode})
		reqIn := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(bodyCode))
		reqIn.Header.Set("Authorization", "Bearer "+securityToken)
		reqIn.Header.Set("Content-Type", "application/json")
		respIn, _ := env.app.Test(reqIn)
		if respIn.StatusCode != http.StatusCreated {
			t.Fatalf("kurir check-in failed, status: %d", respIn.StatusCode)
		}

		// 2. Kurir selesai antar & check-out biasa oleh satpam
		reqOut := httptest.NewRequest("POST", "/api/v1/invitations/check-out", bytes.NewReader(bodyCode))
		reqOut.Header.Set("Authorization", "Bearer "+securityToken)
		reqOut.Header.Set("Content-Type", "application/json")
		respOut, _ := env.app.Test(reqOut)
		if respOut.StatusCode != http.StatusOK {
			t.Fatalf("kurir check-out biasa failed, status: %d", respOut.StatusCode)
		}

		// Verifikasi sebelum diakhiri warga: QR masih valid untuk check-in ulang (skenario A)
		reqVerifyActive := httptest.NewRequest("POST", "/api/v1/invitations/verify", bytes.NewReader(bodyCode))
		reqVerifyActive.Header.Set("Authorization", "Bearer "+securityToken)
		reqVerifyActive.Header.Set("Content-Type", "application/json")
		respVerifyActive, _ := env.app.Test(reqVerifyActive)
		if respVerifyActive.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for still-valid QR before host termination, got %d", respVerifyActive.StatusCode)
		}

		// 3. User lain yang bukan host mencoba mengakhiri -> 403 Forbidden
		reqOtherComplete := httptest.NewRequest("POST", fmt.Sprintf("/api/v1/invitations/%d/complete", courierInv.ID), nil)
		reqOtherComplete.Header.Set("Authorization", "Bearer "+otherResidentToken)
		respOtherComplete, _ := env.app.Test(reqOtherComplete)
		if respOtherComplete.StatusCode != http.StatusForbidden {
			t.Fatalf("expected 403 Forbidden for non-host trying to end invitation, got %d", respOtherComplete.StatusCode)
		}

		// 4. Warga pengundang mengakhiri undangan setelah tamu checkout
		reqHostComplete := httptest.NewRequest("POST", fmt.Sprintf("/api/v1/invitations/%d/complete", courierInv.ID), nil)
		reqHostComplete.Header.Set("Authorization", "Bearer "+residentToken)
		respHostComplete, _ := env.app.Test(reqHostComplete)
		if respHostComplete.StatusCode != http.StatusOK {
			t.Fatalf("expected 200 OK for host ending invitation after checkout, got %d", respHostComplete.StatusCode)
		}

		// 5. Periksa status undangan di DB sudah COMPLETED
		invAfterEnd, _ := env.invRepo.GetByID(context.Background(), courierInv.ID)
		if invAfterEnd.Status != entity.InvitationStatusCompleted {
			t.Fatalf("expected status COMPLETED, got %s", invAfterEnd.Status)
		}

		// 6. Kurir mencoba check-in kembali menggunakan QR yang sama -> DITOLAK backend (410 Gone / ErrInvitationCompleted)
		reqReCheckIn := httptest.NewRequest("POST", "/api/v1/invitations/check-in", bytes.NewReader(bodyCode))
		reqReCheckIn.Header.Set("Authorization", "Bearer "+securityToken)
		reqReCheckIn.Header.Set("Content-Type", "application/json")
		respReCheckIn, _ := env.app.Test(reqReCheckIn)
		if respReCheckIn.StatusCode != http.StatusGone {
			t.Fatalf("expected 410 Gone when checking in with ended invitation, got %d", respReCheckIn.StatusCode)
		}

		var errBody map[string]interface{}
		_ = json.NewDecoder(respReCheckIn.Body).Decode(&errBody)
		expectedMsg := "Undangan telah diakhiri oleh pengundang. QR tidak dapat digunakan kembali."
		if errBody["message"] != expectedMsg {
			t.Fatalf("expected rejection message '%s', got '%v'", expectedMsg, errBody["message"])
		}

		// 7. Undangan yang sudah diakhiri tidak bisa diakhiri lagi (idempotensi/status conflict)
		reqRepeatComplete := httptest.NewRequest("POST", fmt.Sprintf("/api/v1/invitations/%d/complete", courierInv.ID), nil)
		reqRepeatComplete.Header.Set("Authorization", "Bearer "+residentToken)
		respRepeatComplete, _ := env.app.Test(reqRepeatComplete)
		if respRepeatComplete.StatusCode != http.StatusConflict {
			t.Fatalf("expected 409 Conflict when re-ending already completed invitation, got %d", respRepeatComplete.StatusCode)
		}
	})
}
