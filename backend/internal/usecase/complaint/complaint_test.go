package complaint_test

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/usecase/complaint"
)

// Mock Repositories
type mockComplaintRepo struct {
	complaints  map[int64]*entity.Complaint
	byTicket    map[string]*entity.Complaint
	assignments map[int64][]entity.ComplaintAssignment
	nextID      int64
	nextAssignID int64
}

func newMockComplaintRepo() *mockComplaintRepo {
	return &mockComplaintRepo{
		complaints:  make(map[int64]*entity.Complaint),
		byTicket:    make(map[string]*entity.Complaint),
		assignments: make(map[int64][]entity.ComplaintAssignment),
		nextID:      1,
		nextAssignID: 1,
	}
}

func (m *mockComplaintRepo) Create(ctx context.Context, c *entity.Complaint) error {
	c.ID = m.nextID
	m.nextID++
	c.CreatedAt = time.Now()
	c.UpdatedAt = time.Now()
	cp := *c
	m.complaints[c.ID] = &cp
	m.byTicket[c.TicketNumber] = &cp
	return nil
}

func (m *mockComplaintRepo) GetByID(ctx context.Context, id int64) (*entity.Complaint, error) {
	if c, ok := m.complaints[id]; ok {
		cp := *c
		return &cp, nil
	}
	return nil, nil
}

func (m *mockComplaintRepo) GetByTicketNumber(ctx context.Context, ticket string) (*entity.Complaint, error) {
	if c, ok := m.byTicket[ticket]; ok {
		cp := *c
		return &cp, nil
	}
	return nil, nil
}

func (m *mockComplaintRepo) GetByPhotoFilename(ctx context.Context, filename string) (*entity.Complaint, error) {
	for _, c := range m.complaints {
		if c.PhotoURL != nil && strings.Contains(*c.PhotoURL, filename) {
			cp := *c
			return &cp, nil
		}
	}
	return nil, nil
}

func (m *mockComplaintRepo) ListByUser(ctx context.Context, userID int64, limit, offset int) ([]entity.Complaint, int, error) {
	var userComps []entity.Complaint
	for _, c := range m.complaints {
		if c.UserID == userID {
			userComps = append(userComps, *c)
		}
	}
	total := len(userComps)
	if offset >= total {
		return []entity.Complaint{}, total, nil
	}
	end := offset + limit
	if end > total {
		end = total
	}
	return userComps[offset:end], total, nil
}

func (m *mockComplaintRepo) ListAdmin(ctx context.Context, filter entity.AdminComplaintFilter) ([]entity.Complaint, int, error) {
	var list []entity.Complaint
	for _, c := range m.complaints {
		if filter.Status != "" && string(c.Status) != filter.Status {
			continue
		}
		if filter.Category != "" && string(c.Category) != filter.Category {
			continue
		}
		if filter.Officer != "" && (c.AssignedOfficer == nil || !strings.Contains(*c.AssignedOfficer, filter.Officer)) {
			continue
		}
		if filter.Search != "" && !strings.Contains(c.Title, filter.Search) && !strings.Contains(c.Description, filter.Search) && !strings.Contains(c.TicketNumber, filter.Search) {
			continue
		}
		list = append(list, *c)
	}
	total := len(list)
	if filter.Limit <= 0 {
		filter.Limit = 10
	}
	offset := (filter.Page - 1) * filter.Limit
	if offset < 0 {
		offset = 0
	}
	if offset >= total {
		return []entity.Complaint{}, total, nil
	}
	end := offset + filter.Limit
	if end > total {
		end = total
	}
	return list[offset:end], total, nil
}

func (m *mockComplaintRepo) GetKanban(ctx context.Context, filter entity.AdminComplaintFilter) (*entity.KanbanComplaintsResult, error) {
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
	for _, c := range m.complaints {
		res.Counts[string(c.Status)]++
		switch c.Status {
		case entity.ComplaintStatusMenunggu:
			res.Menunggu = append(res.Menunggu, *c)
		case entity.ComplaintStatusDiproses:
			res.Diproses = append(res.Diproses, *c)
		case entity.ComplaintStatusSelesai:
			res.Selesai = append(res.Selesai, *c)
		}
	}
	return res, nil
}

func (m *mockComplaintRepo) AssignOfficer(ctx context.Context, assignment *entity.ComplaintAssignment, newStatus *string) error {
	assignment.ID = m.nextAssignID
	m.nextAssignID++
	assignment.CreatedAt = time.Now()
	m.assignments[assignment.ComplaintID] = append([]entity.ComplaintAssignment{*assignment}, m.assignments[assignment.ComplaintID]...)

	if c, ok := m.complaints[assignment.ComplaintID]; ok {
		c.AssignedOfficer = &assignment.OfficerName
		c.AssignedOfficerID = assignment.OfficerUserID
		c.AssignedAt = &assignment.AssignedAt
		if newStatus != nil && *newStatus != "" {
			c.Status = entity.ComplaintStatus(*newStatus)
		}
	}
	return nil
}

func (m *mockComplaintRepo) UpdateStatus(ctx context.Context, id int64, status entity.ComplaintStatus) error {
	if c, ok := m.complaints[id]; ok {
		c.Status = status
		c.UpdatedAt = time.Now()
		return nil
	}
	return errors.New("complaint not found")
}

func (m *mockComplaintRepo) GetAssignmentsByComplaintID(ctx context.Context, complaintID int64) ([]entity.ComplaintAssignment, error) {
	return m.assignments[complaintID], nil
}

type mockUserRepo struct {
	users map[int64]*entity.User
}

func (m *mockUserRepo) GetByID(ctx context.Context, id int64) (*entity.User, error) {
	if u, ok := m.users[id]; ok {
		return u, nil
	}
	return nil, nil
}
func (m *mockUserRepo) GetByEmailOrPhone(ctx context.Context, identifier string) (*entity.User, error) {
	return nil, nil
}
func (m *mockUserRepo) Create(ctx context.Context, user *entity.User) error                 { return nil }
func (m *mockUserRepo) Update(ctx context.Context, user *entity.User) error                 { return nil }
func (m *mockUserRepo) Delete(ctx context.Context, id int64) error                          { return nil }
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

type mockHouseRepo struct{}

func (m *mockHouseRepo) GetAll(ctx context.Context, block, status, search string) ([]entity.House, error) {
	return nil, nil
}
func (m *mockHouseRepo) GetAvailable(ctx context.Context) ([]entity.House, error)     { return nil, nil }
func (m *mockHouseRepo) GetDistinctBlocks(ctx context.Context) ([]string, error)    { return nil, nil }
func (m *mockHouseRepo) GetByID(ctx context.Context, id int64) (*entity.House, error) { return nil, nil }
func (m *mockHouseRepo) Create(ctx context.Context, house *entity.House) error       { return nil }
func (m *mockHouseRepo) Update(ctx context.Context, house *entity.House) error       { return nil }
func (m *mockHouseRepo) Delete(ctx context.Context, id int64) error                  { return nil }
func (m *mockHouseRepo) BulkDelete(ctx context.Context, ids []int64) (int64, error)  { return 0, nil }


func setupFixture() (*complaint.ComplaintUseCase, *mockComplaintRepo) {
	cRepo := newMockComplaintRepo()
	houseID := int64(10)
	uRepo := &mockUserRepo{
		users: map[int64]*entity.User{
			1: {
				ID:      1,
				Name:    "Warga Boni",
				Status:  string(entity.UserStatusActive),
				HouseID: &houseID,
				House:   &entity.House{ID: 10, Block: "B1", HouseNumber: "01"},
			},
			2: {
				ID:      2,
				Name:    "Warga Martha",
				Status:  string(entity.UserStatusActive),
				HouseID: &houseID,
				House:   &entity.House{ID: 10, Block: "B1", HouseNumber: "02"},
			},
			3: {
				ID:      3,
				Name:    "User Tanpa Hunian",
				Status:  string(entity.UserStatusActive),
				HouseID: nil,
			},
			4: {
				ID:      4,
				Name:    "User Inactive",
				Status:  "inactive",
				HouseID: &houseID,
			},
		},
	}
	hRepo := &mockHouseRepo{}

	uc := complaint.NewComplaintUseCase(cRepo, uRepo, hRepo)
	return uc, cRepo
}

func TestComplaintUseCase_CreateComplaint_Success(t *testing.T) {
	uc, _ := setupFixture()
	ctx := context.Background()

	categories := []string{"Lampu Jalan", "Sampah", "Ketertiban", "Jalanan"}
	photoURL := "/api/v1/complaints/photo/test.jpg"

	for _, cat := range categories {
		comp, err := uc.CreateComplaint(ctx, 1, "Judul Laporan "+cat, "Deskripsi masalah "+cat, cat, &photoURL)
		if err != nil {
			t.Fatalf("expected success for category %s, got error: %v", cat, err)
		}
		if comp.ID == 0 {
			t.Errorf("expected non-zero ID")
		}
		if comp.TicketNumber == "" || len(comp.TicketNumber) < 10 {
			t.Errorf("expected valid ticket number, got: %s", comp.TicketNumber)
		}
		if comp.Status != entity.ComplaintStatusMenunggu {
			t.Errorf("expected status Menunggu, got: %s", comp.Status)
		}
		if comp.Category != entity.ComplaintCategory(cat) {
			t.Errorf("expected category %s, got: %s", cat, comp.Category)
		}
		if comp.PhotoURL == nil || *comp.PhotoURL != photoURL {
			t.Errorf("expected photoURL %s, got %v", photoURL, comp.PhotoURL)
		}
	}
}

func TestComplaintUseCase_CreateComplaint_ValidationErrors(t *testing.T) {
	uc, _ := setupFixture()
	ctx := context.Background()

	// 1. Empty title
	_, err := uc.CreateComplaint(ctx, 1, "", "Deskripsi", "Sampah", nil)
	if err != complaint.ErrEmptyTitle {
		t.Errorf("expected ErrEmptyTitle, got %v", err)
	}

	// 2. Empty description
	_, err = uc.CreateComplaint(ctx, 1, "Judul", "", "Sampah", nil)
	if err != complaint.ErrEmptyDescription {
		t.Errorf("expected ErrEmptyDescription, got %v", err)
	}

	// 3. Invalid category
	_, err = uc.CreateComplaint(ctx, 1, "Judul", "Deskripsi", "Keamanan", nil)
	if err != complaint.ErrInvalidCategory {
		t.Errorf("expected ErrInvalidCategory, got %v", err)
	}

	// 4. User without house
	_, err = uc.CreateComplaint(ctx, 3, "Judul", "Deskripsi", "Sampah", nil)
	if err != complaint.ErrNoHouseAssociation {
		t.Errorf("expected ErrNoHouseAssociation, got %v", err)
	}

	// 5. Inactive user
	_, err = uc.CreateComplaint(ctx, 4, "Judul", "Deskripsi", "Sampah", nil)
	if err != complaint.ErrUserInactive {
		t.Errorf("expected ErrUserInactive, got %v", err)
	}

	// 6. Non-existent user
	_, err = uc.CreateComplaint(ctx, 999, "Judul", "Deskripsi", "Sampah", nil)
	if err != complaint.ErrUserNotFound {
		t.Errorf("expected ErrUserNotFound, got %v", err)
	}
}

func TestComplaintUseCase_Authorization_And_List(t *testing.T) {
	uc, _ := setupFixture()
	ctx := context.Background()

	// User 1 creates 3 complaints
	_, err := uc.CreateComplaint(ctx, 1, "Laporan 1", "Desc 1", "Lampu Jalan", nil)
	if err != nil {
		t.Fatal(err)
	}
	_, err = uc.CreateComplaint(ctx, 1, "Laporan 2", "Desc 2", "Sampah", nil)
	if err != nil {
		t.Fatal(err)
	}
	c3, err := uc.CreateComplaint(ctx, 1, "Laporan 3", "Desc 3", "Jalanan", nil)
	if err != nil {
		t.Fatal(err)
	}

	// User 2 creates 1 complaint
	c4, err := uc.CreateComplaint(ctx, 2, "Laporan User 2", "Desc user 2", "Ketertiban", nil)
	if err != nil {
		t.Fatal(err)
	}

	// List user 1 complaints
	list1, err := uc.GetMyComplaints(ctx, 1, 1, 10)
	if err != nil {
		t.Fatal(err)
	}
	if list1.Total != 3 {
		t.Errorf("expected 3 complaints for user 1, got %d", list1.Total)
	}

	// List user 2 complaints
	list2, err := uc.GetMyComplaints(ctx, 2, 1, 10)
	if err != nil {
		t.Fatal(err)
	}
	if list2.Total != 1 {
		t.Errorf("expected 1 complaint for user 2, got %d", list2.Total)
	}

	// Detail access by owner (User 1 access c3)
	detail, err := uc.GetComplaintDetail(ctx, c3.ID, 1)
	if err != nil {
		t.Fatalf("expected owner can access complaint detail: %v", err)
	}
	if detail.ID != c3.ID {
		t.Errorf("expected complaint ID %d, got %d", c3.ID, detail.ID)
	}

	// Access denied: User 1 try to access c4 (owned by User 2)
	_, err = uc.GetComplaintDetail(ctx, c4.ID, 1)
	if err != complaint.ErrUnauthorizedAccess {
		t.Errorf("expected ErrUnauthorizedAccess for other user complaint, got %v", err)
	}

	// Non-existent complaint
	_, err = uc.GetComplaintDetail(ctx, 9999, 1)
	if err != complaint.ErrComplaintNotFound {
		t.Errorf("expected ErrComplaintNotFound, got %v", err)
	}
}

func TestComplaintUseCase_US54_ManagementAndKanban(t *testing.T) {
	uc, _ := setupFixture()
	ctx := context.Background()

	// 1. Create 3 complaints
	c1, err := uc.CreateComplaint(ctx, 1, "Lampu Padam Blok B1", "Lampu padam", "Lampu Jalan", nil)
	if err != nil {
		t.Fatal(err)
	}
	c2, err := uc.CreateComplaint(ctx, 1, "Sampah Menumpuk di Lapangan", "Bau menyengat", "Sampah", nil)
	if err != nil {
		t.Fatal(err)
	}
	c3, err := uc.CreateComplaint(ctx, 2, "Jalan Berlubang Depan Pos", "Bahaya motor", "Jalanan", nil)
	if err != nil {
		t.Fatal(err)
	}

	// 2. Warga (RESIDENT) denied from Admin endpoints
	_, err = uc.ListAdminComplaints(ctx, "RESIDENT", entity.AdminComplaintFilter{})
	if err != complaint.ErrUnauthorizedAccess {
		t.Errorf("expected RESIDENT to get ErrUnauthorizedAccess, got %v", err)
	}
	_, err = uc.GetKanbanComplaints(ctx, "RESIDENT", entity.AdminComplaintFilter{})
	if err != complaint.ErrUnauthorizedAccess {
		t.Errorf("expected RESIDENT to get ErrUnauthorizedAccess, got %v", err)
	}

	// 3. Admin / Chairperson can list all complaints
	adminList, err := uc.ListAdminComplaints(ctx, "ADMIN", entity.AdminComplaintFilter{Page: 1, Limit: 10})
	if err != nil {
		t.Fatalf("expected Admin can list complaints: %v", err)
	}
	if adminList.Total != 3 {
		t.Errorf("expected 3 complaints in admin list, got %d", adminList.Total)
	}

	// Filter by category
	catList, err := uc.ListAdminComplaints(ctx, "CHAIRPERSON", entity.AdminComplaintFilter{Category: "Lampu Jalan"})
	if err != nil {
		t.Fatal(err)
	}
	if len(catList.Complaints) != 1 {
		t.Errorf("expected 1 complaint for Lampu Jalan filter, got %d", len(catList.Complaints))
	}

	// Search filter
	searchList, err := uc.ListAdminComplaints(ctx, "VICE_CHAIRPERSON", entity.AdminComplaintFilter{Search: "Lapangan"})
	if err != nil {
		t.Fatal(err)
	}
	if len(searchList.Complaints) != 1 || searchList.Complaints[0].ID != c2.ID {
		t.Errorf("expected to find complaint c2 by search, got %d results", len(searchList.Complaints))
	}

	// 4. Kanban board grouping initial: all 3 are Menunggu
	kanban, err := uc.GetKanbanComplaints(ctx, "ADMIN", entity.AdminComplaintFilter{})
	if err != nil {
		t.Fatalf("expected kanban success: %v", err)
	}
	if len(kanban.Menunggu) != 3 {
		t.Errorf("expected 3 in Menunggu, got %d", len(kanban.Menunggu))
	}
	if len(kanban.Diproses) != 0 || len(kanban.Selesai) != 0 {
		t.Errorf("expected 0 in Diproses/Selesai initially")
	}

	// 5. Assign officer: Non-leadership (e.g. TREASURER or RESIDENT) rejected
	diprosesStatus := "Diproses"
	_, err = uc.AssignOfficer(ctx, 10, "TREASURER", c1.ID, entity.AssignComplaintRequest{
		OfficerName: "Pak Joko",
		Status:      &diprosesStatus,
	})
	if err != complaint.ErrUnauthorizedAccess {
		t.Errorf("expected non-leadership to get ErrUnauthorizedAccess, got %v", err)
	}

	// 6. Leadership (CHAIRPERSON) assigns officer with status update
	assignedDetail, err := uc.AssignOfficer(ctx, 1, "CHAIRPERSON", c1.ID, entity.AssignComplaintRequest{
		OfficerName: "Pak Joko (Teknisi Listrik)",
		Notes:       "Periksa panel lampu jalan",
		Status:      &diprosesStatus,
	})
	if err != nil {
		t.Fatalf("expected successful officer assignment: %v", err)
	}
	if assignedDetail.Complaint.AssignedOfficer == nil || *assignedDetail.Complaint.AssignedOfficer != "Pak Joko (Teknisi Listrik)" {
		t.Errorf("expected assigned officer to be Pak Joko, got %v", assignedDetail.Complaint.AssignedOfficer)
	}
	if assignedDetail.Complaint.Status != entity.ComplaintStatusDiproses {
		t.Errorf("expected status Diproses, got %v", assignedDetail.Complaint.Status)
	}
	if len(assignedDetail.Assignments) != 1 {
		t.Fatalf("expected 1 assignment record, got %d", len(assignedDetail.Assignments))
	}
	if assignedDetail.Assignments[0].OfficerName != "Pak Joko (Teknisi Listrik)" {
		t.Errorf("expected assignment record officer name match")
	}

	// 7. Reassign officer (audit trail retains previous history)
	reassignedDetail, err := uc.AssignOfficer(ctx, 1, "ADMIN", c1.ID, entity.AssignComplaintRequest{
		OfficerName: "Pak Budi (Teknisi Pengganti)",
		Notes:       "Ganti teknisi karena Pak Joko berhalangan",
	})
	if err != nil {
		t.Fatalf("expected successful reassignment: %v", err)
	}
	if len(reassignedDetail.Assignments) != 2 {
		t.Fatalf("expected 2 assignment history records after reassignment, got %d", len(reassignedDetail.Assignments))
	}
	if reassignedDetail.Assignments[0].OfficerName != "Pak Budi (Teknisi Pengganti)" {
		t.Errorf("expected latest assignment to be Pak Budi")
	}
	if reassignedDetail.Assignments[1].OfficerName != "Pak Joko (Teknisi Listrik)" {
		t.Errorf("expected previous assignment to be preserved in history")
	}

	// 8. Update status directly to Selesai
	updatedComp, err := uc.UpdateComplaintStatus(ctx, "ADMIN", c1.ID, "Selesai")
	if err != nil {
		t.Fatalf("expected status update to Selesai: %v", err)
	}
	if updatedComp.Status != entity.ComplaintStatusSelesai {
		t.Errorf("expected status Selesai, got %v", updatedComp.Status)
	}

	// 9. Verify Kanban grouping updated
	kanbanUpdated, err := uc.GetKanbanComplaints(ctx, "ADMIN", entity.AdminComplaintFilter{})
	if err != nil {
		t.Fatal(err)
	}
	if len(kanbanUpdated.Menunggu) != 2 {
		t.Errorf("expected 2 in Menunggu, got %d", len(kanbanUpdated.Menunggu))
	}
	if len(kanbanUpdated.Selesai) != 1 {
		t.Errorf("expected 1 in Selesai (c1), got %d", len(kanbanUpdated.Selesai))
	}
	if kanbanUpdated.Selesai[0].ID != c1.ID {
		t.Errorf("expected c1 in Selesai")
	}

	// 10. Direct status update by non-leadership rejected
	_, err = uc.UpdateComplaintStatus(ctx, "RESIDENT", c3.ID, "Diproses")
	if err != complaint.ErrUnauthorizedAccess {
		t.Errorf("expected RESIDENT to be denied status update, got %v", err)
	}
}
