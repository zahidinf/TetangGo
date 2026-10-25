package incident_test

import (
	"context"
	"errors"
	"math"
	"sort"
	"strings"
	"testing"
	"time"

	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
	"tetanggo-backend/internal/usecase/incident"
)

type mockUserRepo struct {
	users map[int64]*entity.User
}

func (m *mockUserRepo) GetByID(ctx context.Context, id int64) (*entity.User, error) {
	return m.users[id], nil
}

func (m *mockUserRepo) GetByEmailOrPhone(ctx context.Context, identifier string) (*entity.User, error) {
	return nil, nil
}
func (m *mockUserRepo) Create(ctx context.Context, user *entity.User) error { return nil }
func (m *mockUserRepo) Update(ctx context.Context, user *entity.User) error { return nil }
func (m *mockUserRepo) Delete(ctx context.Context, id int64) error         { return nil }
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
	houses map[int64]*entity.House
}

func (m *mockHouseRepo) GetByID(ctx context.Context, id int64) (*entity.House, error) {
	return m.houses[id], nil
}
func (m *mockHouseRepo) GetAll(ctx context.Context, block, status, search string) ([]entity.House, error) {
	return nil, nil
}
func (m *mockHouseRepo) GetAvailable(ctx context.Context) ([]entity.House, error) { return nil, nil }
func (m *mockHouseRepo) GetDistinctBlocks(ctx context.Context) ([]string, error)   { return nil, nil }
func (m *mockHouseRepo) Create(ctx context.Context, house *entity.House) error    { return nil }
func (m *mockHouseRepo) Update(ctx context.Context, house *entity.House) error    { return nil }
func (m *mockHouseRepo) Delete(ctx context.Context, id int64) error               { return nil }
func (m *mockHouseRepo) BulkDelete(ctx context.Context, ids []int64) (int64, error) {
	return 0, nil
}

type mockSecurityRepo struct {
	activeAssignments map[int64][]int64 // userID -> []neighborhoodID
}

func (m *mockSecurityRepo) GetNeighborhoodByID(ctx context.Context, id int64) (*entity.Neighborhood, error) {
	return &entity.Neighborhood{ID: id, Name: "Test Neighborhood"}, nil
}
func (m *mockSecurityRepo) GetAllNeighborhoods(ctx context.Context) ([]entity.Neighborhood, error) {
	return nil, nil
}
func (m *mockSecurityRepo) CreateNeighborhood(ctx context.Context, n *entity.Neighborhood) error {
	return nil
}
func (m *mockSecurityRepo) GetSecurityUsers(ctx context.Context) ([]entity.User, error) {
	return nil, nil
}
func (m *mockSecurityRepo) CreateAssignment(ctx context.Context, a *entity.SecurityAssignment) error {
	return nil
}
func (m *mockSecurityRepo) GetAssignmentByID(ctx context.Context, id int64) (*entity.SecurityAssignment, error) {
	return nil, nil
}
func (m *mockSecurityRepo) GetAssignments(ctx context.Context, userID *int64, neighborhoodID *int64, activeOnly *bool) ([]entity.SecurityAssignment, error) {
	return nil, nil
}
func (m *mockSecurityRepo) UpdateAssignmentStatus(ctx context.Context, id int64, isActive bool, notes string) error {
	return nil
}
func (m *mockSecurityRepo) RevokeAssignment(ctx context.Context, id int64, revokedBy int64, notes string) error {
	return nil
}
func (m *mockSecurityRepo) HasActiveAssignmentInNeighborhood(ctx context.Context, userID int64, neighborhoodID int64) (bool, error) {
	if nids, ok := m.activeAssignments[userID]; ok {
		for _, nid := range nids {
			if nid == neighborhoodID {
				return true, nil
			}
		}
	}
	return false, nil
}
func (m *mockSecurityRepo) GetActiveNeighborhoodIDsForUser(ctx context.Context, userID int64) ([]int64, error) {
	return m.activeAssignments[userID], nil
}

type mockIncidentRepo struct {
	incidents map[int64]*entity.Incident
	logs      map[int64][]entity.IncidentLog
	nextIncID int64
	nextLogID int64
}

func newMockIncidentRepo() *mockIncidentRepo {
	return &mockIncidentRepo{
		incidents: make(map[int64]*entity.Incident),
		logs:      make(map[int64][]entity.IncidentLog),
	}
}

func (m *mockIncidentRepo) CreateIncident(ctx context.Context, inc *entity.Incident) error {
	m.nextIncID++
	inc.ID = m.nextIncID
	inc.ReportedAt = time.Now()
	if inc.Status == "" {
		inc.Status = string(entity.IncidentStatusActive)
	}
	m.incidents[inc.ID] = inc
	return nil
}

func (m *mockIncidentRepo) CreateIncidentTx(ctx context.Context, inc *entity.Incident, log *entity.IncidentLog) error {
	if err := m.CreateIncident(ctx, inc); err != nil {
		return err
	}
	if log != nil {
		log.IncidentID = inc.ID
		_ = m.CreateIncidentLog(ctx, log)
	}
	return nil
}

func (m *mockIncidentRepo) GetIncidentByID(ctx context.Context, id int64) (*entity.Incident, error) {
	return m.incidents[id], nil
}

func statusPriority(status string) int {
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

func (m *mockIncidentRepo) GetIncidents(ctx context.Context, filter entity.IncidentFilter) (*entity.IncidentListResult, error) {
	var list []entity.Incident
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
			matchStatus := false
			for _, st := range filter.Statuses {
				if inc.Status == st {
					matchStatus = true
					break
				}
			}
			if !matchStatus {
				continue
			}
		}
		if filter.ReporterID != nil && inc.ReporterID != *filter.ReporterID {
			continue
		}
		if filter.NeighborhoodID != nil && inc.NeighborhoodID != *filter.NeighborhoodID {
			continue
		}
		if len(filter.NeighborhoodIDs) > 0 {
			found := false
			for _, nid := range filter.NeighborhoodIDs {
				if inc.NeighborhoodID == nid {
					found = true
					break
				}
			}
			if !found {
				continue
			}
		}
		list = append(list, *inc)
	}

	sort.Slice(list, func(i, j int) bool {
		p1 := statusPriority(list[i].Status)
		p2 := statusPriority(list[j].Status)
		if p1 != p2 {
			return p1 < p2
		}
		if !list[i].ReportedAt.Equal(list[j].ReportedAt) {
			return list[i].ReportedAt.After(list[j].ReportedAt)
		}
		return list[i].ID > list[j].ID
	})

	total := len(list)
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
	pagedList := list[offset:end]
	totalPages := int(math.Ceil(float64(total) / float64(limit)))
	if totalPages == 0 {
		totalPages = 1
	}

	return &entity.IncidentListResult{
		Incidents:  pagedList,
		Total:      total,
		Page:       page,
		Limit:      limit,
		TotalPages: totalPages,
	}, nil
}

func (m *mockIncidentRepo) GetActiveIncidents(ctx context.Context, neighborhoodIDs []int64) ([]entity.Incident, error) {
	var list []entity.Incident
	for _, inc := range m.incidents {
		if inc.Status != string(entity.IncidentStatusActive) && inc.Status != string(entity.IncidentStatusAcknowledged) &&
			inc.Status != string(entity.IncidentStatusReported) && inc.Status != string(entity.IncidentStatusResponding) {
			continue
		}
		for _, nid := range neighborhoodIDs {
			if inc.NeighborhoodID == nid {
				list = append(list, *inc)
				break
			}
		}
	}
	return list, nil
}

func (m *mockIncidentRepo) AcknowledgeIncidentTx(ctx context.Context, incidentID int64, securityID int64, startedAt time.Time, log *entity.IncidentLog) error {
	inc := m.incidents[incidentID]
	if inc == nil {
		return errors.New("not found")
	}
	if inc.Status != string(entity.IncidentStatusActive) && inc.Status != string(entity.IncidentStatusReported) {
		return repository.ErrIncidentConflict
	}
	prev := inc.Status
	inc.Status = string(entity.IncidentStatusAcknowledged)
	inc.AssignedSecurityID = &securityID
	inc.HandlingStartedAt = &startedAt

	if log != nil {
		log.IncidentID = incidentID
		log.UserID = securityID
		log.PreviousStatus = prev
		log.NewStatus = inc.Status
		_ = m.CreateIncidentLog(ctx, log)
	}
	return nil
}

func (m *mockIncidentRepo) ResolveIncidentTx(ctx context.Context, incidentID int64, actorID int64, resolvedAt time.Time, resolutionNotes string, log *entity.IncidentLog) error {
	inc := m.incidents[incidentID]
	if inc == nil {
		return errors.New("not found")
	}
	if inc.Status == string(entity.IncidentStatusResolved) || inc.Status == string(entity.IncidentStatusCancelled) {
		return repository.ErrIncidentConflict
	}
	prev := inc.Status
	inc.Status = string(entity.IncidentStatusResolved)
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
		log.UserID = actorID
		log.PreviousStatus = prev
		log.NewStatus = inc.Status
		_ = m.CreateIncidentLog(ctx, log)
	}
	return nil
}

func (m *mockIncidentRepo) UpdateIncidentStatus(
	ctx context.Context,
	id int64,
	status string,
	securityID *int64,
	startedAt *time.Time,
	resolvedAt *time.Time,
	resolutionNotes *string,
) error {
	inc := m.incidents[id]
	if inc == nil {
		return errors.New("not found")
	}
	inc.Status = status
	if securityID != nil {
		inc.AssignedSecurityID = securityID
	}
	if startedAt != nil {
		inc.HandlingStartedAt = startedAt
	}
	if resolvedAt != nil {
		inc.ResolvedAt = resolvedAt
	}
	if resolutionNotes != nil {
		inc.ResolutionNotes = resolutionNotes
	}
	return nil
}

func (m *mockIncidentRepo) CreateIncidentLog(ctx context.Context, log *entity.IncidentLog) error {
	m.nextLogID++
	log.ID = m.nextLogID
	log.CreatedAt = time.Now()
	m.logs[log.IncidentID] = append(m.logs[log.IncidentID], *log)
	return nil
}

func (m *mockIncidentRepo) GetIncidentLogs(ctx context.Context, incidentID int64) ([]entity.IncidentLog, error) {
	return m.logs[incidentID], nil
}

func (m *mockIncidentRepo) CountActiveIncidents(ctx context.Context, neighborhoodIDs []int64) (int64, error) {
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

func (m *mockIncidentRepo) CorrectIncidentTx(
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
		m.CreateIncidentLog(ctx, log)
	}
	return inc, nil
}

var _ repository.UserRepository = (*mockUserRepo)(nil)
var _ repository.HouseRepository = (*mockHouseRepo)(nil)
var _ repository.SecurityRepository = (*mockSecurityRepo)(nil)
var _ repository.IncidentRepository = (*mockIncidentRepo)(nil)

func TestIncidentLifecycleAndIsolation(t *testing.T) {
	houseID := int64(10)
	nID := int64(1)

	userRepo := &mockUserRepo{
		users: map[int64]*entity.User{
			1: {ID: 1, Name: "Warga A", RoleName: string(entity.RoleResident), Status: string(entity.UserStatusActive), HouseID: &houseID},
			2: {ID: 2, Name: "Warga B (Lain)", RoleName: string(entity.RoleResident), Status: string(entity.UserStatusActive)},
			3: {ID: 3, Name: "Satpam 1 (Lingkungan 1)", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusActive)},
			4: {ID: 4, Name: "Satpam 2 (Lingkungan 2 saja)", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusActive)},
			5: {ID: 5, Name: "Satpam Nonaktif", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusInactive)},
			6: {ID: 6, Name: "Satpam Tanpa Penugasan", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusActive)},
			7: {ID: 7, Name: "Ketua RT", RoleName: string(entity.RoleChairperson), Status: string(entity.UserStatusActive)},
		},
	}

	houseRepo := &mockHouseRepo{
		houses: map[int64]*entity.House{
			10: {ID: 10, Block: "B1", HouseNumber: "05", NeighborhoodID: &nID},
		},
	}

	secRepo := &mockSecurityRepo{
		activeAssignments: map[int64][]int64{
			3: {1}, // Satpam 1 actively assigned to neighborhood 1
			4: {2}, // Satpam 2 actively assigned to neighborhood 2 only
		},
	}

	incRepo := newMockIncidentRepo()
	uc := incident.NewIncidentUseCase(incRepo, secRepo, userRepo, houseRepo)

	var createdIncID int64

	t.Run("1. Resident creates valid emergency incident with coordinates", func(t *testing.T) {
		lat := -6.2088
		lon := 106.8456
		acc := 5.0
		input := incident.ReportIncidentInput{
			Category:         string(entity.IncidentCategoryCrime),
			Title:            "Pencurian Motor",
			Description:      "Motor matic hilang di depan pagar rumah",
			Latitude:         &lat,
			Longitude:        &lon,
			LocationAccuracy: &acc,
		}

		inc, err := uc.ReportIncident(context.Background(), 1, input)
		if err != nil {
			t.Fatalf("unexpected error reporting incident: %v", err)
		}

		if inc.Status != string(entity.IncidentStatusActive) && inc.Status != string(entity.IncidentStatusReported) {
			t.Errorf("expected status ACTIVE, got %s", inc.Status)
		}
		if inc.ReporterID != 1 {
			t.Errorf("expected reporter_id 1, got %d", inc.ReporterID)
		}
		if inc.NeighborhoodID != 1 {
			t.Errorf("expected neighborhood_id 1, got %d", inc.NeighborhoodID)
		}
		if inc.HouseID == nil || *inc.HouseID != 10 {
			t.Errorf("expected house_id 10 from resident profile")
		}

		createdIncID = inc.ID

		// Check audit log created
		logs, _ := incRepo.GetIncidentLogs(context.Background(), createdIncID)
		if len(logs) != 1 || logs[0].Action != "CREATED" {
			t.Errorf("expected 1 audit log with action CREATED")
		}
	})

	t.Run("1b. Invalid category returns error", func(t *testing.T) {
		input := incident.ReportIncidentInput{
			Category:    "INVALID_CAT",
			Description: "Tidak valid",
		}
		_, err := uc.ReportIncident(context.Background(), 1, input)
		if err != incident.ErrInvalidCategory {
			t.Fatalf("expected ErrInvalidCategory, got %v", err)
		}
	})

	t.Run("1c. Invalid coordinates return error", func(t *testing.T) {
		lat := 100.0 // out of -90..90
		input := incident.ReportIncidentInput{
			Category:    string(entity.IncidentCategoryCrime),
			Description: "Test koordinat",
			Latitude:    &lat,
		}
		_, err := uc.ReportIncident(context.Background(), 1, input)
		if err != incident.ErrInvalidCoordinates {
			t.Fatalf("expected ErrInvalidCoordinates, got %v", err)
		}
	})

	t.Run("2. Security with active assignment in neighborhood 1 can view incident and list active", func(t *testing.T) {
		inc, err := uc.GetIncidentDetail(context.Background(), 3, string(entity.RoleSecurity), createdIncID)
		if err != nil {
			t.Fatalf("unexpected error: security should be able to view incident: %v", err)
		}
		if inc.ID != createdIncID {
			t.Errorf("incident ID mismatch")
		}

		activeList, err := uc.GetActiveIncidentsForSecurity(context.Background(), 3)
		if err != nil {
			t.Fatalf("unexpected error fetching active incidents: %v", err)
		}
		if len(activeList) == 0 {
			t.Errorf("expected active incidents for security 3, got 0")
		}
	})

	t.Run("3. Security assigned ONLY to neighborhood 2 CANNOT view incident in neighborhood 1", func(t *testing.T) {
		_, err := uc.GetIncidentDetail(context.Background(), 4, string(entity.RoleSecurity), createdIncID)
		if err != incident.ErrIncidentAccessForbidden {
			t.Fatalf("expected ErrIncidentAccessForbidden, got: %v", err)
		}
	})

	t.Run("4. Security without active assignment CANNOT view incidents", func(t *testing.T) {
		_, err := uc.GetIncidents(context.Background(), 6, string(entity.RoleSecurity), entity.IncidentFilter{})
		if err != incident.ErrNoActiveSecurityAssignment {
			t.Fatalf("expected ErrNoActiveSecurityAssignment, got: %v", err)
		}

		_, err = uc.GetActiveIncidentsForSecurity(context.Background(), 6)
		if err != incident.ErrNoActiveSecurityAssignment {
			t.Fatalf("expected ErrNoActiveSecurityAssignment, got: %v", err)
		}
	})

	t.Run("5. Inactive security account CANNOT access incidents", func(t *testing.T) {
		_, err := uc.GetIncidents(context.Background(), 5, string(entity.RoleSecurity), entity.IncidentFilter{})
		if err != incident.ErrUserInactive {
			t.Fatalf("expected ErrUserInactive, got: %v", err)
		}

		_, err = uc.GetActiveIncidentsForSecurity(context.Background(), 5)
		if err != incident.ErrUserInactive {
			t.Fatalf("expected ErrUserInactive, got: %v", err)
		}
	})

	t.Run("6. Other resident CANNOT view incident reported by resident 1", func(t *testing.T) {
		_, err := uc.GetIncidentDetail(context.Background(), 2, string(entity.RoleResident), createdIncID)
		if err != incident.ErrIncidentAccessForbidden {
			t.Fatalf("expected ErrIncidentAccessForbidden, got: %v", err)
		}
	})

	t.Run("7. Security with active assignment acknowledges incident", func(t *testing.T) {
		inc, err := uc.AcknowledgeIncident(context.Background(), 3, createdIncID, "Petugas segera merapat ke lokasi")
		if err != nil {
			t.Fatalf("unexpected error acknowledging incident: %v", err)
		}

		if inc.Status != string(entity.IncidentStatusAcknowledged) {
			t.Errorf("expected status ACKNOWLEDGED, got %s", inc.Status)
		}
		if inc.AssignedSecurityID == nil || *inc.AssignedSecurityID != 3 {
			t.Errorf("expected assigned_security_id 3")
		}
		if inc.HandlingStartedAt == nil {
			t.Errorf("expected handling_started_at to be set")
		}

		// Check audit log for ACKNOWLEDGED
		logs, _ := incRepo.GetIncidentLogs(context.Background(), createdIncID)
		if len(logs) != 2 || logs[1].Action != "ACKNOWLEDGED" {
			t.Errorf("expected audit log for ACKNOWLEDGED, got %v", logs)
		}
	})

	t.Run("7b. Concurrent or re-acknowledging acknowledged incident fails with conflict", func(t *testing.T) {
		_, err := uc.AcknowledgeIncident(context.Background(), 3, createdIncID, "Coba acknowledge ulang")
		if err != incident.ErrIncidentAlreadyAcknowledged {
			t.Fatalf("expected ErrIncidentAlreadyAcknowledged, got %v", err)
		}
	})

	t.Run("7c. Security assigned ONLY to neighborhood 2 cannot acknowledge neighborhood 1 incident", func(t *testing.T) {
		_, err := uc.AcknowledgeIncident(context.Background(), 4, createdIncID, "Petugas luar coba ambil")
		if err != incident.ErrSecurityNotAssignedToComplex {
			t.Fatalf("expected ErrSecurityNotAssignedToComplex, got %v", err)
		}
	})

	t.Run("8. Security resolves incident with final notes", func(t *testing.T) {
		inc, err := uc.ResolveIncident(context.Background(), 3, string(entity.RoleSecurity), createdIncID, "Pelaku diamankan bersama Babinsa")
		if err != nil {
			t.Fatalf("unexpected error resolving incident: %v", err)
		}

		if inc.Status != string(entity.IncidentStatusResolved) {
			t.Errorf("expected status RESOLVED, got %s", inc.Status)
		}
		if inc.ResolvedAt == nil {
			t.Errorf("expected resolved_at to be set")
		}
		if inc.ResolutionNotes == nil || *inc.ResolutionNotes != "Pelaku diamankan bersama Babinsa" {
			t.Errorf("expected resolution notes to be saved")
		}

		// Check audit log for RESOLVED
		logs, _ := incRepo.GetIncidentLogs(context.Background(), createdIncID)
		if len(logs) != 3 || logs[2].Action != "RESOLVED" {
			t.Errorf("expected audit log for RESOLVED, got %v", logs)
		}
	})

	t.Run("8b. Double resolution fails with conflict", func(t *testing.T) {
		_, err := uc.ResolveIncident(context.Background(), 3, string(entity.RoleSecurity), createdIncID, "Selesaikan ulang")
		if err != incident.ErrIncidentAlreadyResolved {
			t.Fatalf("expected ErrIncidentAlreadyResolved, got %v", err)
		}
	})

	t.Run("8c. Resident cannot resolve incident", func(t *testing.T) {
		_, err := uc.ResolveIncident(context.Background(), 1, string(entity.RoleResident), createdIncID, "Warga coba selesaikan")
		if err != incident.ErrCannotModifyOthersIncident {
			t.Fatalf("expected ErrCannotModifyOthersIncident, got %v", err)
		}
	})

	t.Run("8d. Empty resolution notes rejected with error", func(t *testing.T) {
		_, err := uc.ResolveIncident(context.Background(), 3, string(entity.RoleSecurity), createdIncID, "   ")
		if err == nil {
			t.Fatalf("expected error for empty resolution notes, got nil")
		}
	})

	t.Run("8e. Revoked assignment security cannot resolve incident", func(t *testing.T) {
		// Revoke security 3 assignment by clearing active assignments for neighborhood 1
		secRepo.activeAssignments[3] = []int64{}
		defer func() {
			secRepo.activeAssignments[3] = []int64{1}
		}()

		// Create fresh active incident
		newInc, err := uc.ReportIncident(context.Background(), 1, incident.ReportIncidentInput{
			Category:    "MEDIS",
			Title:       "Darurat Medis Blok A",
			Description: "Warga pingsan butuh pertolongan pertama",
		})
		if err != nil {
			t.Fatalf("failed creating incident: %v", err)
		}

		_, err = uc.ResolveIncident(context.Background(), 3, string(entity.RoleSecurity), newInc.ID, "Catatan penanganan")
		if err != incident.ErrIncidentAccessForbidden {
			t.Fatalf("expected ErrIncidentAccessForbidden for revoked assignment, got %v", err)
		}
	})

	t.Run("8f. Inactive security account cannot resolve incident", func(t *testing.T) {
		newInc, err := uc.ReportIncident(context.Background(), 1, incident.ReportIncidentInput{
			Category:    "KEBAKARAN",
			Title:       "Konsleting Listrik Blok C",
			Description: "Asap tebal di meteran listrik",
		})
		if err != nil {
			t.Fatalf("failed creating incident: %v", err)
		}

		// User 5 is inactive security
		_, err = uc.ResolveIncident(context.Background(), 5, string(entity.RoleSecurity), newInc.ID, "Catatan penanganan")
		if err != incident.ErrUserInactive {
			t.Fatalf("expected ErrUserInactive for inactive security, got %v", err)
		}
	})

	t.Run("9. Incident logs history retrieval and permissions", func(t *testing.T) {
		logs, err := uc.GetIncidentLogs(context.Background(), 3, string(entity.RoleSecurity), createdIncID)
		if err != nil {
			t.Fatalf("unexpected error getting incident logs: %v", err)
		}
		if len(logs) != 3 {
			t.Fatalf("expected 3 audit logs, got %d", len(logs))
		}

		// Resident who reported it can see the logs
		resLogs, err := uc.GetIncidentLogs(context.Background(), 1, string(entity.RoleResident), createdIncID)
		if err != nil {
			t.Fatalf("reporter should be able to view logs: %v", err)
		}
		if len(resLogs) != 3 {
			t.Fatalf("expected 3 logs for reporter, got %d", len(resLogs))
		}

		// Other resident forbidden
		_, err = uc.GetIncidentLogs(context.Background(), 2, string(entity.RoleResident), createdIncID)
		if err != incident.ErrIncidentAccessForbidden {
			t.Fatalf("expected ErrIncidentAccessForbidden for other resident, got %v", err)
		}
	})
}

type mockPublisher struct {
	events []entity.IncidentRealtimeEvent
}

func (m *mockPublisher) PublishIncidentEvent(ctx context.Context, event entity.IncidentRealtimeEvent) error {
	m.events = append(m.events, event)
	return nil
}

func TestIncidentRealtimeEventsPublishing(t *testing.T) {
	houseID := int64(10)
	nID := int64(1)

	userRepo := &mockUserRepo{
		users: map[int64]*entity.User{
			1: {ID: 1, Name: "Warga", RoleName: string(entity.RoleResident), Status: string(entity.UserStatusActive), HouseID: &houseID},
			3: {ID: 3, Name: "Satpam", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusActive)},
		},
	}
	houseRepo := &mockHouseRepo{
		houses: map[int64]*entity.House{
			10: {ID: 10, NeighborhoodID: &nID},
		},
	}
	secRepo := &mockSecurityRepo{
		activeAssignments: map[int64][]int64{3: {1}},
	}
	incRepo := newMockIncidentRepo()
	uc := incident.NewIncidentUseCase(incRepo, secRepo, userRepo, houseRepo)

	pub := &mockPublisher{}
	uc.SetPublisher(pub)

	// 1. Report Incident publishes INCIDENT_CREATED
	inc, err := uc.ReportIncident(context.Background(), 1, incident.ReportIncidentInput{
		Category:    "KEJAHATAN",
		Description: "Ada motor mencurigakan",
	})
	if err != nil {
		t.Fatalf("failed reporting incident: %v", err)
	}

	if len(pub.events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(pub.events))
	}
	e1 := pub.events[0]
	if e1.EventType != entity.IncidentEventTypeCreated {
		t.Errorf("expected INCIDENT_CREATED, got %s", e1.EventType)
	}
	if e1.Version != "1.0" {
		t.Errorf("expected version 1.0, got %s", e1.Version)
	}
	if e1.NeighborhoodID != 1 {
		t.Errorf("expected neighborhood 1, got %d", e1.NeighborhoodID)
	}
	if e1.Data.IncidentID != inc.ID {
		t.Errorf("expected incident ID %d, got %d", inc.ID, e1.Data.IncidentID)
	}

	// 2. Acknowledge Incident publishes INCIDENT_ACKNOWLEDGED
	_, err = uc.AcknowledgeIncident(context.Background(), 3, inc.ID, "Menuju lokasi")
	if err != nil {
		t.Fatalf("failed acknowledging incident: %v", err)
	}

	if len(pub.events) != 2 {
		t.Fatalf("expected 2 events, got %d", len(pub.events))
	}
	e2 := pub.events[1]
	if e2.EventType != entity.IncidentEventTypeAcknowledged {
		t.Errorf("expected INCIDENT_ACKNOWLEDGED, got %s", e2.EventType)
	}

	// 3. Resolve Incident publishes INCIDENT_RESOLVED
	_, err = uc.ResolveIncident(context.Background(), 3, string(entity.RoleSecurity), inc.ID, "Terkendali aman")
	if err != nil {
		t.Fatalf("failed resolving incident: %v", err)
	}

	if len(pub.events) != 3 {
		t.Fatalf("expected 3 events, got %d", len(pub.events))
	}
	e3 := pub.events[2]
	if e3.EventType != entity.IncidentEventTypeResolved {
		t.Errorf("expected INCIDENT_RESOLVED, got %s", e3.EventType)
	}
	if e3.Data.ResolutionNotes == nil || *e3.Data.ResolutionNotes != "Terkendali aman" {
		t.Errorf("expected resolution notes in event data")
	}
}

func TestEmergencyEnhancementAndAdminCorrection(t *testing.T) {
	houseID1 := int64(10)
	nID1 := int64(1)

	userRepo := &mockUserRepo{
		users: map[int64]*entity.User{
			1: {ID: 1, Name: "Warga Pelapor", RoleName: string(entity.RoleResident), Status: string(entity.UserStatusActive), HouseID: &houseID1},
			2: {ID: 2, Name: "Warga Tetangga", RoleName: string(entity.RoleResident), Status: string(entity.UserStatusActive), HouseID: &houseID1},
			3: {ID: 3, Name: "Pak Satpam", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusActive)},
			4: {ID: 4, Name: "Admin Cluster", RoleName: string(entity.RoleAdmin), Status: string(entity.UserStatusActive)},
			5: {ID: 5, Name: "Bendahara Cluster", RoleName: string(entity.RoleTreasurer), Status: string(entity.UserStatusActive), HouseID: &houseID1},
			6: {ID: 6, Name: "Sekretaris Cluster", RoleName: string(entity.RoleSecretary), Status: string(entity.UserStatusActive), HouseID: &houseID1},
		},
	}
	houseRepo := &mockHouseRepo{
		houses: map[int64]*entity.House{
			10: {ID: 10, NeighborhoodID: &nID1},
		},
	}
	secRepo := &mockSecurityRepo{
		activeAssignments: map[int64][]int64{
			3: {1},
		},
	}
	incRepo := newMockIncidentRepo()

	uc := incident.NewIncidentUseCase(incRepo, secRepo, userRepo, houseRepo)
	pub := &mockPublisher{}
	uc.SetPublisher(pub)

	ctx := context.Background()

	// 1. Report emergency incident
	inc, err := uc.ReportIncident(ctx, 1, incident.ReportIncidentInput{
		Category:    "MEDIS",
		Description: "Warga sakit sesak nafas butuh bantuan segera",
	})
	if err != nil {
		t.Fatalf("failed reporting incident: %v", err)
	}

	// 2. Active count check: 1 active incident
	count, err := uc.GetActiveIncidentCount(ctx, 4, string(entity.RoleAdmin))
	if err != nil {
		t.Fatalf("failed getting active incident count: %v", err)
	}
	if count != 1 {
		t.Fatalf("expected active count 1, got %d", count)
	}

	// 3. Admin Correction: Non-admin must be forbidden
	newTitle := "Darurat Medis Blok A"
	_, err = uc.CorrectIncident(ctx, 1, string(entity.RoleResident), inc.ID, incident.CorrectIncidentInput{
		Title: &newTitle,
		Notes: "Mencoba edit bukan admin",
	})
	if err != incident.ErrIncidentAccessForbidden {
		t.Fatalf("expected ErrIncidentAccessForbidden for resident attempting admin correction, got %v", err)
	}

	// 4. Admin Correction: Valid admin updates title, category, status to RESOLVED
	resolvedStatus := "RESOLVED"
	correctedCat := "MEDIS"
	corrected, err := uc.CorrectIncident(ctx, 4, string(entity.RoleAdmin), inc.ID, incident.CorrectIncidentInput{
		Title:    &newTitle,
		Category: &correctedCat,
		Status:   &resolvedStatus,
		Notes:    "Koreksi status oleh Admin: Satpam mengonfirmasi situasi sudah terkendali via telepon",
	})
	if err != nil {
		t.Fatalf("admin correction failed: %v", err)
	}
	if corrected.Status != "RESOLVED" || corrected.Title != newTitle {
		t.Fatalf("correction did not apply expected fields: status=%s, title=%s", corrected.Status, corrected.Title)
	}

	// 5. Verify Audit Log was recorded
	logs, err := incRepo.GetIncidentLogs(ctx, inc.ID)
	if err != nil {
		t.Fatalf("failed getting incident logs: %v", err)
	}
	var foundCorrectionLog bool
	for _, l := range logs {
		if l.Action == "CORRECTED" {
			foundCorrectionLog = true
			if l.UserID != 4 {
				t.Errorf("expected user_id 4 in correction log, got %d", l.UserID)
			}
			if l.NewStatus != "RESOLVED" {
				t.Errorf("expected new_status RESOLVED in correction log, got %s", l.NewStatus)
			}
			break
		}
	}
	if !foundCorrectionLog {
		t.Errorf("expected audit log with action CORRECTED")
	}

	// 6. Active count now drops to 0 (all resolved)
	countAfter, err := uc.GetActiveIncidentCount(ctx, 4, string(entity.RoleAdmin))
	if err != nil {
		t.Fatalf("failed getting active incident count: %v", err)
	}
	if countAfter != 0 {
		t.Fatalf("expected active count 0, got %d", countAfter)
	}

	// 7. Visibility check:
	// - Pengurus (Bendahara ID 5) can view resolved in list/history
	resPengurus, err := uc.GetIncidents(ctx, 5, string(entity.RoleTreasurer), entity.IncidentFilter{})
	if err != nil {
		t.Fatalf("pengurus should be able to get incidents: %v", err)
	}
	if len(resPengurus.Incidents) != 1 {
		t.Errorf("expected pengurus to see 1 incident in history, got %d", len(resPengurus.Incidents))
	}

	// - Resident neighbor (ID 2) gets 0 in list because resolved incident is filtered out
	resWarga, err := uc.GetIncidents(ctx, 2, string(entity.RoleResident), entity.IncidentFilter{})
	if err != nil {
		t.Fatalf("warga should be able to query active incidents: %v", err)
	}
	if len(resWarga.Incidents) != 0 {
		t.Errorf("expected neighbor to see 0 active incidents when all resolved, got %d", len(resWarga.Incidents))
	}

	// - Resident neighbor (ID 2) cannot access resolved detail
	_, err = uc.GetIncidentDetail(ctx, 2, string(entity.RoleResident), inc.ID)
	if err != incident.ErrIncidentAccessForbidden {
		t.Fatalf("expected neighbor forbidden from viewing resolved detail, got %v", err)
	}
}

func TestIncidentSortingAndPriorityPagination(t *testing.T) {
	ctx := context.Background()

	// Seed users: Admin (ID 4), Security (ID 6)
	userRepo := &mockUserRepo{
		users: map[int64]*entity.User{
			4: {ID: 4, Name: "Admin Test", RoleName: string(entity.RoleAdmin), Status: string(entity.UserStatusActive)},
			6: {ID: 6, Name: "Satpam Test", RoleName: string(entity.RoleSecurity), Status: string(entity.UserStatusActive)},
		},
	}
	secRepo := &mockSecurityRepo{
		activeAssignments: map[int64][]int64{
			6: {1}, // Security actively assigned to neighborhood 1
		},
	}

	incRepo := newMockIncidentRepo()
	uc := incident.NewIncidentUseCase(incRepo, secRepo, userRepo, nil)

	// Sample timestamps from user requirement
	t24_1600 := time.Date(2026, 10, 24, 16, 0, 0, 0, time.UTC)
	t24_2110 := time.Date(2026, 10, 24, 21, 10, 0, 0, time.UTC)
	t25_1720 := time.Date(2026, 10, 25, 17, 20, 0, 0, time.UTC)
	t25_1830 := time.Date(2026, 10, 25, 18, 30, 0, 0, time.UTC)
	t25_1900 := time.Date(2026, 10, 25, 19, 0, 0, 0, time.UTC)
	t25_1945 := time.Date(2026, 10, 25, 19, 45, 0, 0, time.UTC)
	t25_2000 := time.Date(2026, 10, 25, 20, 0, 0, 0, time.UTC)
	t25_2200 := time.Date(2026, 10, 25, 22, 0, 0, 0, time.UTC)

	// Seed incidents
	incRepo.incidents[1] = &entity.Incident{ID: 1, NeighborhoodID: 1, Status: "ACTIVE", ReportedAt: t25_1945, Description: "Dilaporkan 1"}
	incRepo.incidents[2] = &entity.Incident{ID: 2, NeighborhoodID: 1, Status: "REPORTED", ReportedAt: t25_1830, Description: "Dilaporkan 2"}
	incRepo.incidents[3] = &entity.Incident{ID: 3, NeighborhoodID: 1, Status: "ACTIVE", ReportedAt: t24_2110, Description: "Dilaporkan 3"}
	incRepo.incidents[4] = &entity.Incident{ID: 4, NeighborhoodID: 1, Status: "ACKNOWLEDGED", ReportedAt: t25_2000, Description: "Sedang Ditangani 1"}
	incRepo.incidents[5] = &entity.Incident{ID: 5, NeighborhoodID: 1, Status: "RESPONDING", ReportedAt: t25_1720, Description: "Sedang Ditangani 2"}
	incRepo.incidents[6] = &entity.Incident{ID: 6, NeighborhoodID: 1, Status: "RESOLVED", ReportedAt: t25_1900, Description: "Terkendali 1 (lebih baru dari Dilaporkan 2 & 3)"}
	incRepo.incidents[7] = &entity.Incident{ID: 7, NeighborhoodID: 1, Status: "RESOLVED", ReportedAt: t24_1600, Description: "Terkendali 2"}
	incRepo.incidents[8] = &entity.Incident{ID: 8, NeighborhoodID: 1, Status: "CANCELLED", ReportedAt: t25_2200, Description: "Status lain (Dibatalkan)"}

	// 1. Full list query by Admin
	res, err := uc.GetIncidents(ctx, 4, string(entity.RoleAdmin), entity.IncidentFilter{Limit: 20, Page: 1})
	if err != nil {
		t.Fatalf("failed fetching incidents: %v", err)
	}

	expectedIDs := []int64{1, 2, 3, 4, 5, 6, 7, 8}
	if len(res.Incidents) != len(expectedIDs) {
		t.Fatalf("expected %d incidents, got %d", len(expectedIDs), len(res.Incidents))
	}

	for i, expectedID := range expectedIDs {
		if res.Incidents[i].ID != expectedID {
			t.Errorf("at index %d, expected incident ID %d (status=%s, reported_at=%v), got ID %d (status=%s, reported_at=%v)",
				i, expectedID, incRepo.incidents[expectedID].Status, incRepo.incidents[expectedID].ReportedAt,
				res.Incidents[i].ID, res.Incidents[i].Status, res.Incidents[i].ReportedAt)
		}
	}

	// 2. Pagination check across multiple pages
	// Page 1: limit 3 -> IDs: 1, 2, 3
	p1, err := uc.GetIncidents(ctx, 4, string(entity.RoleAdmin), entity.IncidentFilter{Limit: 3, Page: 1})
	if err != nil {
		t.Fatalf("page 1 failed: %v", err)
	}
	if p1.Total != 8 || p1.TotalPages != 3 || len(p1.Incidents) != 3 {
		t.Fatalf("unexpected p1 meta: total=%d, totalPages=%d, len=%d", p1.Total, p1.TotalPages, len(p1.Incidents))
	}
	if p1.Incidents[0].ID != 1 || p1.Incidents[1].ID != 2 || p1.Incidents[2].ID != 3 {
		t.Errorf("p1 IDs incorrect: got [%d, %d, %d]", p1.Incidents[0].ID, p1.Incidents[1].ID, p1.Incidents[2].ID)
	}

	// Page 2: limit 3 -> IDs: 4, 5, 6
	p2, err := uc.GetIncidents(ctx, 4, string(entity.RoleAdmin), entity.IncidentFilter{Limit: 3, Page: 2})
	if err != nil {
		t.Fatalf("page 2 failed: %v", err)
	}
	if len(p2.Incidents) != 3 {
		t.Fatalf("unexpected p2 len: %d", len(p2.Incidents))
	}
	if p2.Incidents[0].ID != 4 || p2.Incidents[1].ID != 5 || p2.Incidents[2].ID != 6 {
		t.Errorf("p2 IDs incorrect: got [%d, %d, %d]", p2.Incidents[0].ID, p2.Incidents[1].ID, p2.Incidents[2].ID)
	}

	// Page 3: limit 3 -> IDs: 7, 8
	p3, err := uc.GetIncidents(ctx, 4, string(entity.RoleAdmin), entity.IncidentFilter{Limit: 3, Page: 3})
	if err != nil {
		t.Fatalf("page 3 failed: %v", err)
	}
	if len(p3.Incidents) != 2 {
		t.Fatalf("unexpected p3 len: %d", len(p3.Incidents))
	}
	if p3.Incidents[0].ID != 7 || p3.Incidents[1].ID != 8 {
		t.Errorf("p3 IDs incorrect: got [%d, %d]", p3.Incidents[0].ID, p3.Incidents[1].ID)
	}

	// 3. Dynamic status transition: Security acknowledges Incident 1 (Dilaporkan -> Sedang Ditangani)
	_, err = uc.AcknowledgeIncident(ctx, 6, 1, "Satpam 6 merapat ke lokasi 1")
	if err != nil {
		t.Fatalf("failed acknowledging incident 1: %v", err)
	}

	// Re-fetch: Incident 1 should now be grouped into 'Sedang Ditangani' priority (after Dilaporkan 2 and 3)
	// Among Sedang Ditangani: ID 4 (20:00), ID 1 (19:45), ID 5 (17:20)
	resAfterAck, err := uc.GetIncidents(ctx, 4, string(entity.RoleAdmin), entity.IncidentFilter{Limit: 20, Page: 1})
	if err != nil {
		t.Fatalf("failed re-fetching incidents after ack: %v", err)
	}

	expectedAfterAck := []int64{2, 3, 4, 1, 5, 6, 7, 8}
	for i, expectedID := range expectedAfterAck {
		if resAfterAck.Incidents[i].ID != expectedID {
			t.Errorf("after ack index %d: expected ID %d, got %d", i, expectedID, resAfterAck.Incidents[i].ID)
		}
	}
}
