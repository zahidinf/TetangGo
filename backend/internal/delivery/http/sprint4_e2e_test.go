package http_test

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	deliveryHttp "tetanggo-backend/internal/delivery/http"
	"tetanggo-backend/internal/delivery/http/handler"
	"tetanggo-backend/internal/delivery/http/middleware"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
	"tetanggo-backend/internal/infrastructure/fcm"
	"tetanggo-backend/internal/infrastructure/realtime"
	"tetanggo-backend/internal/usecase/auth"
	"tetanggo-backend/internal/usecase/incident"
	"tetanggo-backend/internal/usecase/security"
)

// ----------------------------------------------------
// Mock Repositories for End-to-End Sprint 4 Integration
// ----------------------------------------------------

type mockE2EUserRepo struct {
	mu    sync.Mutex
	users map[int64]*entity.User
}

func (m *mockE2EUserRepo) GetByID(ctx context.Context, id int64) (*entity.User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.users[id], nil
}

func (m *mockE2EUserRepo) GetByEmailOrPhone(ctx context.Context, identifier string) (*entity.User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, u := range m.users {
		if u.Email == identifier || u.Phone == identifier {
			return u, nil
		}
	}
	return nil, nil
}

func (m *mockE2EUserRepo) Create(ctx context.Context, user *entity.User) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	user.ID = int64(len(m.users) + 1)
	m.users[user.ID] = user
	return nil
}

func (m *mockE2EUserRepo) Update(ctx context.Context, user *entity.User) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.users[user.ID] = user
	return nil
}

func (m *mockE2EUserRepo) Delete(ctx context.Context, id int64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.users, id)
	return nil
}

func (m *mockE2EUserRepo) UpdateProfile(ctx context.Context, id int64, name, phone string, photoURL *string) error {
	return nil
}

func (m *mockE2EUserRepo) GetPendingUsers(ctx context.Context) ([]entity.PendingUser, error) {
	return nil, nil
}

func (m *mockE2EUserRepo) UpdateStatus(ctx context.Context, id int64, status string, rejectionReason *string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if u, exists := m.users[id]; exists {
		u.Status = status
	}
	return nil
}

func (m *mockE2EUserRepo) CountPending(ctx context.Context) (int, error) {
	return 0, nil
}

func (m *mockE2EUserRepo) GetUnassignedResidents(ctx context.Context, search string) ([]entity.UnassignedResident, error) {
	return nil, nil
}

func (m *mockE2EUserRepo) AssignHouse(ctx context.Context, userID int64, houseID int64, occupantType string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if u, exists := m.users[userID]; exists {
		u.HouseID = &houseID
	}
	return nil
}

func (m *mockE2EUserRepo) UnassignHouse(ctx context.Context, userID int64, houseID int64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if u, exists := m.users[userID]; exists {
		u.HouseID = nil
	}
	return nil
}

func (m *mockE2EUserRepo) GetOccupantsByHouseID(ctx context.Context, houseID int64) ([]entity.HouseOccupant, error) {
	return nil, nil
}

func (m *mockE2EUserRepo) CountOccupantsByHouseID(ctx context.Context, houseID int64) (int, error) {
	return 0, nil
}

func (m *mockE2EUserRepo) GetAllUsers(ctx context.Context, search, status, role string, houseID *int64) ([]entity.User, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var res []entity.User
	for _, u := range m.users {
		res = append(res, *u)
	}
	return res, nil
}

func (m *mockE2EUserRepo) UpdatePassword(ctx context.Context, id int64, passwordHash string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if u, exists := m.users[id]; exists {
		u.PasswordHash = passwordHash
	}
	return nil
}

type mockE2ERoleRepo struct{}

func (m *mockE2ERoleRepo) GetByName(ctx context.Context, name string) (*entity.Role, error) {
	return &entity.Role{ID: 7, Name: name}, nil
}
func (m *mockE2ERoleRepo) GetAll(ctx context.Context) ([]entity.Role, error) {
	return []entity.Role{
		{ID: 1, Name: string(entity.RoleAdmin)},
		{ID: 2, Name: string(entity.RoleResident)},
		{ID: 7, Name: string(entity.RoleSecurity)},
	}, nil
}

type mockE2EHouseRepo struct{}

func (m *mockE2EHouseRepo) GetByID(ctx context.Context, id int64) (*entity.House, error) {
	nID := int64(1)
	return &entity.House{ID: id, Block: "B2", HouseNumber: "15", NeighborhoodID: &nID}, nil
}
func (m *mockE2EHouseRepo) GetAll(ctx context.Context, block, status, search string) ([]entity.House, error) {
	return nil, nil
}
func (m *mockE2EHouseRepo) GetAvailable(ctx context.Context) ([]entity.House, error) { return nil, nil }
func (m *mockE2EHouseRepo) GetDistinctBlocks(ctx context.Context) ([]string, error)   { return nil, nil }
func (m *mockE2EHouseRepo) Create(ctx context.Context, house *entity.House) error    { return nil }
func (m *mockE2EHouseRepo) Update(ctx context.Context, house *entity.House) error    { return nil }
func (m *mockE2EHouseRepo) Delete(ctx context.Context, id int64) error               { return nil }
func (m *mockE2EHouseRepo) BulkDelete(ctx context.Context, ids []int64) (int64, error) {
	return 0, nil
}

type mockE2ESecurityRepo struct {
	mu          sync.Mutex
	assignments map[int64]*entity.SecurityAssignment
}

func (m *mockE2ESecurityRepo) GetNeighborhoodByID(ctx context.Context, id int64) (*entity.Neighborhood, error) {
	return &entity.Neighborhood{ID: id, Name: fmt.Sprintf("Cluster Lingkungan #%d", id)}, nil
}
func (m *mockE2ESecurityRepo) GetAllNeighborhoods(ctx context.Context) ([]entity.Neighborhood, error) {
	return nil, nil
}
func (m *mockE2ESecurityRepo) CreateNeighborhood(ctx context.Context, n *entity.Neighborhood) error {
	return nil
}
func (m *mockE2ESecurityRepo) GetSecurityUsers(ctx context.Context) ([]entity.User, error) {
	return nil, nil
}
func (m *mockE2ESecurityRepo) CreateAssignment(ctx context.Context, a *entity.SecurityAssignment) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	a.ID = int64(len(m.assignments) + 1)
	a.IsActive = true
	m.assignments[a.ID] = a
	return nil
}
func (m *mockE2ESecurityRepo) GetAssignmentByID(ctx context.Context, id int64) (*entity.SecurityAssignment, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.assignments[id], nil
}
func (m *mockE2ESecurityRepo) GetAssignments(ctx context.Context, userID *int64, neighborhoodID *int64, activeOnly *bool) ([]entity.SecurityAssignment, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var res []entity.SecurityAssignment
	for _, a := range m.assignments {
		if userID != nil && a.UserID != *userID {
			continue
		}
		if neighborhoodID != nil && a.NeighborhoodID != *neighborhoodID {
			continue
		}
		if activeOnly != nil && *activeOnly && !a.IsActive {
			continue
		}
		res = append(res, *a)
	}
	return res, nil
}
func (m *mockE2ESecurityRepo) UpdateAssignmentStatus(ctx context.Context, id int64, isActive bool, notes string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if a, exists := m.assignments[id]; exists {
		a.IsActive = isActive
		a.Notes = notes
	}
	return nil
}
func (m *mockE2ESecurityRepo) RevokeAssignment(ctx context.Context, id int64, revokedBy int64, notes string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if a, exists := m.assignments[id]; exists {
		a.IsActive = false
		a.RevokedBy = &revokedBy
		a.Notes = notes
	}
	return nil
}
func (m *mockE2ESecurityRepo) HasActiveAssignmentInNeighborhood(ctx context.Context, userID int64, neighborhoodID int64) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, a := range m.assignments {
		if a.UserID == userID && a.NeighborhoodID == neighborhoodID && a.IsActive {
			return true, nil
		}
	}
	return false, nil
}
func (m *mockE2ESecurityRepo) GetActiveNeighborhoodIDsForUser(ctx context.Context, userID int64) ([]int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var res []int64
	for _, a := range m.assignments {
		if a.UserID == userID && a.IsActive {
			res = append(res, a.NeighborhoodID)
		}
	}
	return res, nil
}

type mockE2EIncidentRepo struct {
	mu        sync.Mutex
	incidents map[int64]*entity.Incident
	logs      map[int64][]entity.IncidentLog
}

func newMockE2EIncidentRepo() *mockE2EIncidentRepo {
	return &mockE2EIncidentRepo{
		incidents: make(map[int64]*entity.Incident),
		logs:      make(map[int64][]entity.IncidentLog),
	}
}

func (m *mockE2EIncidentRepo) CreateIncident(ctx context.Context, inc *entity.Incident) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	inc.ID = int64(len(m.incidents) + 1)
	inc.ReportedAt = time.Now()
	m.incidents[inc.ID] = inc
	return nil
}

func (m *mockE2EIncidentRepo) CreateIncidentTx(ctx context.Context, inc *entity.Incident, log *entity.IncidentLog) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	inc.ID = int64(len(m.incidents) + 1)
	inc.ReportedAt = time.Now()
	m.incidents[inc.ID] = inc

	if log != nil {
		log.IncidentID = inc.ID
		log.CreatedAt = time.Now()
		m.logs[inc.ID] = append(m.logs[inc.ID], *log)
	}
	return nil
}

func (m *mockE2EIncidentRepo) GetIncidentByID(ctx context.Context, id int64) (*entity.Incident, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.incidents[id], nil
}

func e2eStatusPriority(status string) int {
	switch strings.ToUpper(strings.TrimSpace(status)) {
	case "ACTIVE", "REPORTED", "DILAPORKAN":
		return 1
	case "RESPONDING", "ACKNOWLEDGED", "SEDANG DITANGANI":
		return 2
	case "RESOLVED", "TERKENDALI":
		return 3
	default:
		return 4
	}
}

func (m *mockE2EIncidentRepo) GetIncidents(ctx context.Context, filter entity.IncidentFilter) (*entity.IncidentListResult, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var res []entity.Incident
	for _, inc := range m.incidents {
		if filter.Category != "" && inc.Category != filter.Category {
			continue
		}
		if filter.Status != "" {
			st := strings.ToUpper(strings.TrimSpace(filter.Status))
			if st == "ACTIVE" || st == "REPORTED" {
				if inc.Status != "ACTIVE" && inc.Status != "REPORTED" {
					continue
				}
			} else if st == "ACKNOWLEDGED" || st == "RESPONDING" {
				if inc.Status != "ACKNOWLEDGED" && inc.Status != "RESPONDING" {
					continue
				}
			} else if inc.Status != st {
				continue
			}
		}
		if len(filter.Statuses) > 0 {
			match := false
			for _, st := range filter.Statuses {
				if inc.Status == st {
					match = true
					break
				}
			}
			if !match {
				continue
			}
		}
		if filter.ReporterID != nil && inc.ReporterID != *filter.ReporterID {
			continue
		}
		if filter.NeighborhoodID != nil && inc.NeighborhoodID != *filter.NeighborhoodID {
			continue
		}
		res = append(res, *inc)
	}

	sort.Slice(res, func(i, j int) bool {
		p1 := e2eStatusPriority(res[i].Status)
		p2 := e2eStatusPriority(res[j].Status)
		if p1 != p2 {
			return p1 < p2
		}
		if !res[i].ReportedAt.Equal(res[j].ReportedAt) {
			return res[i].ReportedAt.After(res[j].ReportedAt)
		}
		return res[i].ID > res[j].ID
	})

	total := len(res)
	limit := filter.Limit
	if limit <= 0 {
		limit = 20
	}
	page := filter.Page
	if page <= 0 {
		page = 1
	}
	offset := (page - 1) * limit
	if offset > total {
		offset = total
	}
	end := offset + limit
	if end > total {
		end = total
	}
	pagedList := res[offset:end]
	totalPages := int(math.Ceil(float64(total) / float64(limit)))
	if totalPages == 0 {
		totalPages = 1
	}

	return &entity.IncidentListResult{Incidents: pagedList, Total: total, Page: page, Limit: limit, TotalPages: totalPages}, nil
}

func (m *mockE2EIncidentRepo) GetActiveIncidents(ctx context.Context, neighborhoodIDs []int64) ([]entity.Incident, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	nMap := make(map[int64]bool)
	for _, nid := range neighborhoodIDs {
		nMap[nid] = true
	}
	var res []entity.Incident
	for _, inc := range m.incidents {
		if nMap[inc.NeighborhoodID] && (inc.Status == "ACTIVE" || inc.Status == "REPORTED" || inc.Status == "ACKNOWLEDGED") {
			res = append(res, *inc)
		}
	}
	return res, nil
}

func (m *mockE2EIncidentRepo) AcknowledgeIncidentTx(ctx context.Context, incidentID int64, securityID int64, startedAt time.Time, log *entity.IncidentLog) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	inc, exists := m.incidents[incidentID]
	if !exists {
		return fmt.Errorf("not found")
	}
	if inc.Status != "ACTIVE" && inc.Status != "REPORTED" {
		return repository.ErrIncidentConflict
	}
	inc.Status = "ACKNOWLEDGED"
	inc.AssignedSecurityID = &securityID
	inc.HandlingStartedAt = &startedAt

	if log != nil {
		log.IncidentID = incidentID
		log.CreatedAt = time.Now()
		m.logs[incidentID] = append(m.logs[incidentID], *log)
	}
	return nil
}

func (m *mockE2EIncidentRepo) ResolveIncidentTx(ctx context.Context, incidentID int64, actorID int64, resolvedAt time.Time, resolutionNotes string, log *entity.IncidentLog) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	inc, exists := m.incidents[incidentID]
	if !exists {
		return fmt.Errorf("not found")
	}
	if inc.Status == "RESOLVED" || inc.Status == "CANCELLED" {
		return repository.ErrIncidentConflict
	}
	inc.Status = "RESOLVED"
	inc.ResolvedAt = &resolvedAt
	inc.ResolutionNotes = &resolutionNotes
	if inc.AssignedSecurityID == nil {
		inc.AssignedSecurityID = &actorID
	}
	if inc.HandlingStartedAt == nil {
		inc.HandlingStartedAt = &resolvedAt
	}

	if log != nil {
		log.IncidentID = incidentID
		log.CreatedAt = time.Now()
		m.logs[incidentID] = append(m.logs[incidentID], *log)
	}
	return nil
}

func (m *mockE2EIncidentRepo) UpdateIncidentStatus(ctx context.Context, id int64, status string, securityID *int64, startedAt *time.Time, resolvedAt *time.Time, resolutionNotes *string) error {
	return nil
}

func (m *mockE2EIncidentRepo) CreateIncidentLog(ctx context.Context, log *entity.IncidentLog) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	log.CreatedAt = time.Now()
	m.logs[log.IncidentID] = append(m.logs[log.IncidentID], *log)
	return nil
}

func (m *mockE2EIncidentRepo) GetIncidentLogs(ctx context.Context, incidentID int64) ([]entity.IncidentLog, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.logs[incidentID], nil
}

func (m *mockE2EIncidentRepo) CountActiveIncidents(ctx context.Context, neighborhoodIDs []int64) (int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var count int64
	for _, inc := range m.incidents {
		if inc.Status == string(entity.IncidentStatusActive) || inc.Status == string(entity.IncidentStatusResponding) {
			if len(neighborhoodIDs) == 0 {
				count++
			} else {
				for _, nid := range neighborhoodIDs {
					if inc.NeighborhoodID == nid {
						count++
						break
					}
				}
			}
		}
	}
	return count, nil
}

func (m *mockE2EIncidentRepo) CorrectIncidentTx(
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
	m.mu.Lock()
	defer m.mu.Unlock()
	inc := m.incidents[incidentID]
	if inc == nil {
		return nil, errors.New("not found")
	}
	prevStatus := inc.Status
	if newStatus != nil {
		inc.Status = *newStatus
	}
	if newCategory != nil {
		inc.Category = *newCategory
	}
	if newTitle != nil {
		inc.Title = *newTitle
	}
	if newDescription != nil {
		inc.Description = *newDescription
	}
	if log != nil {
		log.IncidentID = incidentID
		log.UserID = adminID
		log.Action = "CORRECTED"
		log.PreviousStatus = prevStatus
		log.NewStatus = inc.Status
		log.CreatedAt = time.Now()
		m.logs[incidentID] = append(m.logs[incidentID], *log)
	}
	return inc, nil
}

type mockE2EDeviceTokenRepo struct {
	mu     sync.Mutex
	tokens map[string]*entity.SecurityDeviceToken
}

func (m *mockE2EDeviceTokenRepo) UpsertDeviceToken(ctx context.Context, token *entity.SecurityDeviceToken) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.tokens[token.DeviceID] = token
	return nil
}
func (m *mockE2EDeviceTokenRepo) RevokeDeviceToken(ctx context.Context, userID int64, deviceID string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if t, ok := m.tokens[deviceID]; ok && t.UserID == userID {
		t.IsActive = false
	}
	return nil
}
func (m *mockE2EDeviceTokenRepo) DeactivateTokenByValue(ctx context.Context, tokenValue string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	for _, t := range m.tokens {
		if t.DeviceToken == tokenValue {
			t.IsActive = false
		}
	}
	return nil
}
func (m *mockE2EDeviceTokenRepo) GetActiveTokensForNeighborhood(ctx context.Context, neighborhoodID int64) ([]entity.SecurityDeviceToken, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var res []entity.SecurityDeviceToken
	for _, t := range m.tokens {
		if t.IsActive {
			res = append(res, *t)
		}
	}
	return res, nil
}
func (m *mockE2EDeviceTokenRepo) GetActiveTokensForUser(ctx context.Context, userID int64) ([]entity.SecurityDeviceToken, error) {
	return nil, nil
}

// Dummy mock connection for realtime testing
type e2eWSConn struct {
	writeChan chan []byte
}

func (c *e2eWSConn) WriteMessage(messageType int, data []byte) error {
	c.writeChan <- data
	return nil
}
func (c *e2eWSConn) ReadMessage() (int, []byte, error) {
	return 0, nil, nil
}
func (c *e2eWSConn) SetWriteDeadline(t time.Time) error { return nil }
func (c *e2eWSConn) SetReadDeadline(t time.Time) error  { return nil }
func (c *e2eWSConn) SetReadLimit(limit int64)          {}
func (c *e2eWSConn) SetPongHandler(h func(string) error) {}
func (c *e2eWSConn) Close() error {
	return nil
}

// ----------------------------------------------------
// End-to-End Integration & DoD Test Suite (US-4.8)
// ----------------------------------------------------

func TestSprint4_EndToEnd_And_DefinitionOfDone(t *testing.T) {
	residentHouseID := int64(10)
	userRepo := &mockE2EUserRepo{
		users: map[int64]*entity.User{
			1: {
				ID:       1,
				Name:     "Pak RT Bambang",
				Email:    "rt@tetanggo.com",
				RoleID:   1,
				RoleName: string(entity.RoleChairperson),
				Status:   "active",
			},
			2: {
				ID:       2,
				Name:     "Warga Budi Santoso",
				Email:    "warga@tetanggo.com",
				RoleID:   2,
				RoleName: string(entity.RoleResident),
				Status:   "active",
				HouseID:  &residentHouseID,
			},
			3: {
				ID:       3,
				Name:     "Satpam Pos Utama",
				Email:    "satpam1@tetanggo.com",
				RoleID:   7,
				RoleName: string(entity.RoleSecurity),
				Status:   "active",
				HouseID:  nil, // NO housing requirement
			},
			4: {
				ID:       4,
				Name:     "Satpam Luar Komplek",
				Email:    "satpam2@tetanggo.com",
				RoleID:   7,
				RoleName: string(entity.RoleSecurity),
				Status:   "active",
				HouseID:  nil,
			},
		},
	}

	roleRepo := &mockE2ERoleRepo{}
	houseRepo := &mockE2EHouseRepo{}
	secRepo := &mockE2ESecurityRepo{
		assignments: map[int64]*entity.SecurityAssignment{
			1: {
				ID:             1,
				UserID:         3,
				NeighborhoodID: 1, // Satpam 3 assigned to neighborhood 1
				IsActive:       true,
			},
			2: {
				ID:             2,
				UserID:         4,
				NeighborhoodID: 2, // Satpam 4 assigned ONLY to neighborhood 2
				IsActive:       true,
			},
		},
	}

	incRepo := newMockE2EIncidentRepo()
	tokenRepo := &mockE2EDeviceTokenRepo{
		tokens: make(map[string]*entity.SecurityDeviceToken),
	}

	tokenService := auth.NewTokenService("test_e2e_jwt_secret_key_1234567890123456", 60, 7)
	incidentUC := incident.NewIncidentUseCase(incRepo, secRepo, userRepo, houseRepo)
	securityUC := security.NewSecurityUseCase(secRepo, userRepo, roleRepo)

	hub := realtime.NewHub()
	go hub.Run()
	defer hub.Shutdown(context.Background())

	publisher := realtime.NewRealtimeEventPublisher(hub)
	incidentUC.SetPublisher(publisher)

	fcmService := fcm.NewFCMService(tokenRepo, "mock", "mock")
	incidentUC.SetPushNotification(tokenRepo, fcmService)

	appHandler := handler.NewAppHandler(
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		securityUC,
		incidentUC,
	)
	appHandler.SetRealtime(hub, tokenService, secRepo, userRepo)
	appHandler.SetDeviceTokenRepo(tokenRepo)

	authMid := middleware.NewAuthMiddleware(tokenService, userRepo)
	app := deliveryHttp.SetupRouter(appHandler, authMid)

	rtToken, _, _ := tokenService.GenerateTokenPair(1, "rt@tetanggo.com", string(entity.RoleChairperson))
	wargaToken, _, _ := tokenService.GenerateTokenPair(2, "warga@tetanggo.com", string(entity.RoleResident))
	satpam1Token, _, _ := tokenService.GenerateTokenPair(3, "satpam1@tetanggo.com", string(entity.RoleSecurity))
	satpam2Token, _, _ := tokenService.GenerateTokenPair(4, "satpam2@tetanggo.com", string(entity.RoleSecurity))

	// Connect a dummy mock realtime client for Satpam 1 (Neighborhood 1)
	wsConnSatpam1 := &e2eWSConn{writeChan: make(chan []byte, 10)}
	clientSatpam1 := realtime.NewClient(hub, wsConnSatpam1, 3, "pos-satpam-tab-1", "conn-satpam-1", []int64{1})
	hub.Register(clientSatpam1)
	go clientSatpam1.WritePump()

	var createdIncidentID int64

	// 1. E2E Flow: Device Token Registration
	t.Run("E2E-1: Security registers device token without housing linkage", func(t *testing.T) {
		reqBody := `{"device_id":"pos-satpam-tab-1","device_token":"fcm_token_guard_101","platform":"android"}`
		req := httptest.NewRequest(http.MethodPost, "/api/v1/security/device-token", strings.NewReader(reqBody))
		req.Header.Set("Authorization", "Bearer "+satpam1Token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil || resp.StatusCode != http.StatusOK {
			t.Fatalf("expected HTTP 200 registering device token, got status %d err %v", resp.StatusCode, err)
		}
	})

	// 2. E2E Flow: CORS Preflight & Resident triggers Panic Button & Event is published
	t.Run("E2E-CORS: Preflight OPTIONS /api/v1/incidents from browser with X-Idempotency-Key", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodOptions, "/api/v1/incidents", nil)
		req.Header.Set("Origin", "http://localhost:5000")
		req.Header.Set("Access-Control-Request-Method", "POST")
		req.Header.Set("Access-Control-Request-Headers", "authorization, content-type, x-idempotency-key")

		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("preflight OPTIONS failed: %v", err)
		}
		if resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusOK {
			t.Fatalf("expected preflight 204 or 200, got %d", resp.StatusCode)
		}

		allowOrigin := resp.Header.Get("Access-Control-Allow-Origin")
		if allowOrigin != "*" && allowOrigin != "http://localhost:5000" {
			t.Errorf("expected Access-Control-Allow-Origin, got '%s'", allowOrigin)
		}

		allowHeaders := resp.Header.Get("Access-Control-Allow-Headers")
		if !strings.Contains(strings.ToLower(allowHeaders), "x-idempotency-key") {
			t.Errorf("expected Access-Control-Allow-Headers to include 'x-idempotency-key', got '%s'", allowHeaders)
		}
	})

	t.Run("E2E-2: Resident presses Panic Button and event publishes to Security WebSocket", func(t *testing.T) {
		panicBody := `{
			"category": "KEJAHATAN",
			"description": "Maling terlihat membongkar jendela rumah",
			"latitude": -6.2088,
			"longitude": 106.8456,
			"location_accuracy": 5.0
		}`
		req := httptest.NewRequest(http.MethodPost, "/api/v1/incidents", strings.NewReader(panicBody))
		req.Header.Set("Authorization", "Bearer "+wargaToken)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil || resp.StatusCode != http.StatusCreated {
			t.Fatalf("expected HTTP 201 for incident creation, got %d", resp.StatusCode)
		}

		var resMap map[string]interface{}
		_ = json.NewDecoder(resp.Body).Decode(&resMap)
		data := resMap["data"].(map[string]interface{})
		createdIncidentID = int64(data["id"].(float64))

		if createdIncidentID <= 0 {
			t.Fatalf("expected valid positive incident ID, got %d", createdIncidentID)
		}

		// Verify that Satpam 1 received the realtime WebSocket event
		select {
		case msg := <-wsConnSatpam1.writeChan:
			var wsEvent map[string]interface{}
			if err := json.Unmarshal(msg, &wsEvent); err != nil {
				t.Fatalf("failed unmarshaling ws event: %v", err)
			}
			if wsEvent["event_type"] != "INCIDENT_CREATED" {
				t.Errorf("expected event_type INCIDENT_CREATED, got %v", wsEvent["event_type"])
			}
		case <-time.After(500 * time.Millisecond):
			t.Fatal("timeout waiting for realtime websocket broadcast to satpam 1")
		}
	})

	// 3. E2E Flow: Security Assigned (Neighborhood 1) CAN fetch incident detail
	t.Run("E2E-3: Assigned Security fetches incident detail", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/incidents/%d", createdIncidentID), nil)
		req.Header.Set("Authorization", "Bearer "+satpam1Token)

		resp, err := app.Test(req)
		if err != nil || resp.StatusCode != http.StatusOK {
			t.Fatalf("expected HTTP 200 for assigned security viewing incident, got %d", resp.StatusCode)
		}
	})

	// 4. Security Check: Cross-neighborhood Security access is forbidden
	t.Run("E2E-4: Security from OTHER neighborhood is 403 Forbidden", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/incidents/%d", createdIncidentID), nil)
		req.Header.Set("Authorization", "Bearer "+satpam2Token)

		resp, err := app.Test(req)
		if err != nil || resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected HTTP 403 Forbidden for cross-neighborhood security, got %d", resp.StatusCode)
		}
	})

	// 5. Security Check: Security CANNOT access Cashbook or Billing endpoints
	t.Run("E2E-5: Security CANNOT access Cashbook or Resident Billing", func(t *testing.T) {
		reqCashbook := httptest.NewRequest(http.MethodGet, "/api/v1/cashbook/summary", nil)
		reqCashbook.Header.Set("Authorization", "Bearer "+satpam1Token)
		respCash, _ := app.Test(reqCashbook)
		if respCash.StatusCode != http.StatusForbidden {
			t.Errorf("expected HTTP 403 Forbidden when security accesses cashbook, got %d", respCash.StatusCode)
		}

		reqBills := httptest.NewRequest(http.MethodGet, "/api/v1/resident/bills", nil)
		reqBills.Header.Set("Authorization", "Bearer "+satpam1Token)
		respBills, _ := app.Test(reqBills)
		if respBills.StatusCode != http.StatusForbidden {
			t.Errorf("expected HTTP 403 Forbidden when security accesses resident bills, got %d", respBills.StatusCode)
		}
	})

	// 6. E2E Flow: Incident Handling ('Sedang Ditangani')
	t.Run("E2E-6: Security acknowledges incident ('Sedang Ditangani')", func(t *testing.T) {
		reqBody := `{"notes":"Petugas Satpam 1 meluncur ke lokasi"}`
		req := httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/incidents/%d/acknowledge", createdIncidentID), strings.NewReader(reqBody))
		req.Header.Set("Authorization", "Bearer "+satpam1Token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil || resp.StatusCode != http.StatusOK {
			t.Fatalf("expected HTTP 200 acknowledging incident, got %d", resp.StatusCode)
		}
	})

	// 7. Conflict Check: Double handling returns 409 Conflict
	t.Run("E2E-7: Conflict check returns HTTP 409 on second acknowledge", func(t *testing.T) {
		reqBody := `{"notes":"Coba tangani ulang"}`
		req := httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/incidents/%d/acknowledge", createdIncidentID), strings.NewReader(reqBody))
		req.Header.Set("Authorization", "Bearer "+satpam1Token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil || resp.StatusCode != http.StatusConflict {
			t.Fatalf("expected HTTP 409 Conflict for double acknowledge, got %d", resp.StatusCode)
		}
	})

	// 8. E2E Flow: Incident Resolution ('Situasi Terkendali')
	t.Run("E2E-8: Security resolves incident ('Situasi Terkendali')", func(t *testing.T) {
		resolveBody := `{"resolution_notes":"Pelaku telah diamankan dan diserahkan ke posko terpadu."}`
		req := httptest.NewRequest(http.MethodPost, fmt.Sprintf("/api/v1/incidents/%d/resolve", createdIncidentID), strings.NewReader(resolveBody))
		req.Header.Set("Authorization", "Bearer "+satpam1Token)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		if err != nil || resp.StatusCode != http.StatusOK {
			t.Fatalf("expected HTTP 200 resolving incident, got %d", resp.StatusCode)
		}
	})

	// 9. E2E Flow: Revoking assignment blocks subsequent operational access
	t.Run("E2E-9: Revoked Security assignment immediately blocks access", func(t *testing.T) {
		revokeBody := `{"is_active":false,"notes":"Surat tugas pos satpam berakhir"}`
		revokeReq := httptest.NewRequest(http.MethodPut, "/api/v1/admin/security/assignments/1/status", strings.NewReader(revokeBody))
		revokeReq.Header.Set("Authorization", "Bearer "+rtToken)
		revokeReq.Header.Set("Content-Type", "application/json")

		respRevoke, err := app.Test(revokeReq)
		if err != nil || respRevoke.StatusCode != http.StatusOK {
			t.Fatalf("expected HTTP 200 revoking security assignment, got %d", respRevoke.StatusCode)
		}

		req := httptest.NewRequest(http.MethodGet, "/api/v1/incidents/active", nil)
		req.Header.Set("Authorization", "Bearer "+satpam1Token)
		resp, _ := app.Test(req)
		if resp.StatusCode != http.StatusForbidden {
			t.Fatalf("expected HTTP 403 Forbidden for revoked security accessing active incidents, got %d", resp.StatusCode)
		}
	})

	// 10. E2E Flow: Active Incident Count & Admin Correction with Audit Trail
	t.Run("E2E-10: Active Incident Count & Admin Correction with Audit Trail", func(t *testing.T) {
		// Admin token (ID 1 is admin)
		adminToken, _, _ := tokenService.GenerateTokenPair(1, "admin@tetanggo.com", string(entity.RoleAdmin))

		// 1. Warga reports new incident
		newPanicBody := `{"category":"MEDIS","description":"Warga butuh pertolongan medis darurat","latitude":-6.2088,"longitude":106.8456}`
		reqNew := httptest.NewRequest(http.MethodPost, "/api/v1/incidents", strings.NewReader(newPanicBody))
		reqNew.Header.Set("Authorization", "Bearer "+wargaToken)
		reqNew.Header.Set("Content-Type", "application/json")
		respNew, err := app.Test(reqNew)
		if err != nil || respNew.StatusCode != http.StatusCreated {
			t.Fatalf("expected HTTP 201 reporting emergency incident, got %d", respNew.StatusCode)
		}
		var newIncRes struct {
			Data entity.Incident `json:"data"`
		}
		json.NewDecoder(respNew.Body).Decode(&newIncRes)
		secondIncidentID := newIncRes.Data.ID

		// 2. Check active-count: should be >= 1
		reqCount := httptest.NewRequest(http.MethodGet, "/api/v1/incidents/active-count", nil)
		reqCount.Header.Set("Authorization", "Bearer "+adminToken)
		respCount, err := app.Test(reqCount)
		if err != nil || respCount.StatusCode != http.StatusOK {
			t.Fatalf("expected HTTP 200 for active-count, got %d", respCount.StatusCode)
		}
		var countRes struct {
			Success bool `json:"success"`
			Data    struct {
				ActiveCount int `json:"active_count"`
			} `json:"data"`
		}
		json.NewDecoder(respCount.Body).Decode(&countRes)
		if countRes.Data.ActiveCount < 1 {
			t.Fatalf("expected active_count >= 1, got %d", countRes.Data.ActiveCount)
		}

		// 3. Non-admin attempting correction: must be 403 Forbidden
		corrBody := `{"status":"RESOLVED","title":"Koreksi Judul","notes":"Koreksi oleh Warga ilegal"}`
		reqCorrWarga := httptest.NewRequest(http.MethodPatch, fmt.Sprintf("/api/v1/incidents/%d/correct", secondIncidentID), strings.NewReader(corrBody))
		reqCorrWarga.Header.Set("Authorization", "Bearer "+wargaToken)
		reqCorrWarga.Header.Set("Content-Type", "application/json")
		respCorrWarga, _ := app.Test(reqCorrWarga)
		if respCorrWarga.StatusCode != http.StatusForbidden {
			t.Fatalf("expected HTTP 403 Forbidden for warga calling admin correction, got %d", respCorrWarga.StatusCode)
		}

		// 4. Admin performs correction
		adminCorrBody := `{"status":"RESOLVED","title":"Insiden Medis Terkendali","category":"MEDIS","notes":"Koreksi Admin: Satpam sudah menangani dan situasi aman"}`
		reqCorrAdmin := httptest.NewRequest(http.MethodPatch, fmt.Sprintf("/api/v1/incidents/%d/correct", secondIncidentID), strings.NewReader(adminCorrBody))
		reqCorrAdmin.Header.Set("Authorization", "Bearer "+adminToken)
		reqCorrAdmin.Header.Set("Content-Type", "application/json")
		respCorrAdmin, err := app.Test(reqCorrAdmin)
		if err != nil || respCorrAdmin.StatusCode != http.StatusOK {
			t.Fatalf("expected HTTP 200 for admin correction, got %d", respCorrAdmin.StatusCode)
		}

		// 5. Verify Audit Logs has CORRECTED action
		reqLogs := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/incidents/%d/logs", secondIncidentID), nil)
		reqLogs.Header.Set("Authorization", "Bearer "+adminToken)
		respLogs, _ := app.Test(reqLogs)
		if respLogs.StatusCode != http.StatusOK {
			t.Fatalf("expected HTTP 200 for incident logs, got %d", respLogs.StatusCode)
		}
		var logsRes struct {
			Success bool                 `json:"success"`
			Data    []entity.IncidentLog `json:"data"`
		}
		json.NewDecoder(respLogs.Body).Decode(&logsRes)
		var foundCorrectedLog bool
		for _, l := range logsRes.Data {
			if l.Action == "CORRECTED" {
				foundCorrectedLog = true
				if l.NewStatus != "RESOLVED" {
					t.Errorf("expected CORRECTED log new_status RESOLVED, got %s", l.NewStatus)
				}
				break
			}
		}
		if !foundCorrectedLog {
			t.Fatalf("expected audit log with action CORRECTED to be recorded")
		}
	})
}

// ----------------------------------------------------
// Rigorous Latency Benchmark Test (< 2 seconds target)
// ----------------------------------------------------

func TestSprint4_EmergencyAlarmLatencyBenchmark(t *testing.T) {
	sampleCount := 50
	residentHouseID := int64(10)
	userRepo := &mockE2EUserRepo{
		users: map[int64]*entity.User{
			2: {
				ID:       2,
				Name:     "Warga Budi Santoso",
				Email:    "warga@tetanggo.com",
				RoleID:   2,
				RoleName: string(entity.RoleResident),
				Status:   "active",
				HouseID:  &residentHouseID,
			},
			3: {
				ID:       3,
				Name:     "Satpam Pos Utama",
				Email:    "satpam1@tetanggo.com",
				RoleID:   7,
				RoleName: string(entity.RoleSecurity),
				Status:   "active",
				HouseID:  nil,
			},
		},
	}

	roleRepo := &mockE2ERoleRepo{}
	houseRepo := &mockE2EHouseRepo{}
	secRepo := &mockE2ESecurityRepo{
		assignments: map[int64]*entity.SecurityAssignment{
			1: {
				ID:             1,
				UserID:         3,
				NeighborhoodID: 1,
				IsActive:       true,
			},
		},
	}

	incRepo := newMockE2EIncidentRepo()
	tokenRepo := &mockE2EDeviceTokenRepo{
		tokens: make(map[string]*entity.SecurityDeviceToken),
	}

	tokenService := auth.NewTokenService("test_e2e_jwt_secret_key_1234567890123456", 60, 7)
	incidentUC := incident.NewIncidentUseCase(incRepo, secRepo, userRepo, houseRepo)
	securityUC := security.NewSecurityUseCase(secRepo, userRepo, roleRepo)

	hub := realtime.NewHub()
	go hub.Run()
	defer hub.Shutdown(context.Background())

	publisher := realtime.NewRealtimeEventPublisher(hub)
	incidentUC.SetPublisher(publisher)

	appHandler := handler.NewAppHandler(
		nil, nil, nil, nil, nil, nil, nil, nil,
		securityUC, incidentUC,
	)
	appHandler.SetRealtime(hub, tokenService, secRepo, userRepo)
	appHandler.SetDeviceTokenRepo(tokenRepo)

	authMid := middleware.NewAuthMiddleware(tokenService, userRepo)
	app := deliveryHttp.SetupRouter(appHandler, authMid)

	wargaToken, _, _ := tokenService.GenerateTokenPair(2, "warga@tetanggo.com", string(entity.RoleResident))

	wsConn := &e2eWSConn{writeChan: make(chan []byte, 100)}
	client := realtime.NewClient(hub, wsConn, 3, "pos-device-bench", "conn-bench-1", []int64{1})
	hub.Register(client)
	go client.WritePump()

	// Give registration a moment
	time.Sleep(20 * time.Millisecond)

	backendLatencies := make([]time.Duration, 0, sampleCount)
	deliveryLatencies := make([]time.Duration, 0, sampleCount)
	failures := 0

	for i := 0; i < sampleCount; i++ {
		tReq := time.Now()

		panicBody := fmt.Sprintf(`{
			"category": "MEDIS",
			"description": "Tes latensi darurat sampel #%d",
			"latitude": -6.2088,
			"longitude": 106.8456,
			"location_accuracy": 5.0
		}`, i+1)

		req := httptest.NewRequest(http.MethodPost, "/api/v1/incidents", strings.NewReader(panicBody))
		req.Header.Set("Authorization", "Bearer "+wargaToken)
		req.Header.Set("Content-Type", "application/json")

		resp, err := app.Test(req)
		tBackendDone := time.Now()

		if err != nil || resp.StatusCode != http.StatusCreated {
			failures++
			continue
		}

		bLatency := tBackendDone.Sub(tReq)
		backendLatencies = append(backendLatencies, bLatency)

		// Wait for message on WebSocket client channel
		select {
		case <-wsConn.writeChan:
			tRecv := time.Now()
			dLatency := tRecv.Sub(tReq)
			deliveryLatencies = append(deliveryLatencies, dLatency)
		case <-time.After(2 * time.Second):
			failures++
		}
	}

	if len(deliveryLatencies) == 0 {
		t.Fatalf("no successful samples captured")
	}

	sort.Slice(backendLatencies, func(i, j int) bool { return backendLatencies[i] < backendLatencies[j] })
	sort.Slice(deliveryLatencies, func(i, j int) bool { return deliveryLatencies[i] < deliveryLatencies[j] })

	calcMetrics := func(lats []time.Duration) (median, p95, max time.Duration) {
		n := len(lats)
		median = lats[n/2]
		p95Idx := int(math.Floor(float64(n) * 0.95))
		if p95Idx >= n {
			p95Idx = n - 1
		}
		p95 = lats[p95Idx]
		max = lats[n-1]
		return
	}

	bMedian, bP95, bMax := calcMetrics(backendLatencies)
	dMedian, dP95, dMax := calcMetrics(deliveryLatencies)

	t.Logf("=== SPRINT 4 EMERGENCY LATENCY MEASUREMENT REPORT ===")
	t.Logf("Sample Count: %d, Failures: %d", sampleCount, failures)
	t.Logf("Backend Processing (T_req -> T_db/pub): Median=%v, p95=%v, Max=%v", bMedian, bP95, bMax)
	t.Logf("Realtime End-to-End (T_req -> Client WS Recv): Median=%v, p95=%v, Max=%v", dMedian, dP95, dMax)

	if dP95 >= 2*time.Second {
		t.Errorf("p95 latency exceeded 2s target: %v", dP95)
	}
}
