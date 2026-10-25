package security_test

import (
	"context"
	"testing"
	"time"

	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
	"tetanggo-backend/internal/usecase/security"
)

type mockRoleRepo struct {
	roles map[string]*entity.Role
}

func (m *mockRoleRepo) GetByName(ctx context.Context, name string) (*entity.Role, error) {
	if r, ok := m.roles[name]; ok {
		return r, nil
	}
	return nil, nil
}

func (m *mockRoleRepo) GetAll(ctx context.Context) ([]entity.Role, error) {
	var list []entity.Role
	for _, r := range m.roles {
		list = append(list, *r)
	}
	return list, nil
}

type mockUserRepo struct {
	users  map[int64]*entity.User
	nextID int64
}

func newMockUserRepo() *mockUserRepo {
	return &mockUserRepo{
		users:  make(map[int64]*entity.User),
		nextID: 100,
	}
}

func (m *mockUserRepo) Create(ctx context.Context, u *entity.User) error {
	m.nextID++
	u.ID = m.nextID
	m.users[u.ID] = u
	return nil
}

func (m *mockUserRepo) GetByID(ctx context.Context, id int64) (*entity.User, error) {
	return m.users[id], nil
}

func (m *mockUserRepo) GetByEmailOrPhone(ctx context.Context, identifier string) (*entity.User, error) {
	for _, u := range m.users {
		if u.Email == identifier || u.Phone == identifier {
			return u, nil
		}
	}
	return nil, nil
}

func (m *mockUserRepo) Update(ctx context.Context, u *entity.User) error {
	m.users[u.ID] = u
	return nil
}

func (m *mockUserRepo) Delete(ctx context.Context, id int64) error {
	delete(m.users, id)
	return nil
}

func (m *mockUserRepo) UpdateProfile(ctx context.Context, id int64, name, phone string, photoURL *string) error {
	return nil
}

func (m *mockUserRepo) GetPendingUsers(ctx context.Context) ([]entity.PendingUser, error) {
	return nil, nil
}

func (m *mockUserRepo) UpdateStatus(ctx context.Context, id int64, status string, rejectionReason *string) error {
	if u, ok := m.users[id]; ok {
		u.Status = status
		u.RejectionReason = rejectionReason
	}
	return nil
}

func (m *mockUserRepo) CountPending(ctx context.Context) (int, error) {
	return 0, nil
}

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
	var list []entity.User
	for _, u := range m.users {
		list = append(list, *u)
	}
	return list, nil
}

func (m *mockUserRepo) UpdatePassword(ctx context.Context, id int64, passwordHash string) error {
	return nil
}

type mockSecurityRepo struct {
	neighborhoods map[int64]*entity.Neighborhood
	assignments   map[int64]*entity.SecurityAssignment
	nextAssignID  int64
}

func newMockSecurityRepo() *mockSecurityRepo {
	return &mockSecurityRepo{
		neighborhoods: map[int64]*entity.Neighborhood{
			1: {ID: 1, Name: "Lingkungan Blok A-B", Code: "BLOK-AB"},
			2: {ID: 2, Name: "Lingkungan Blok C-D", Code: "BLOK-CD"},
		},
		assignments:  make(map[int64]*entity.SecurityAssignment),
		nextAssignID: 10,
	}
}

func (m *mockSecurityRepo) GetNeighborhoodByID(ctx context.Context, id int64) (*entity.Neighborhood, error) {
	return m.neighborhoods[id], nil
}

func (m *mockSecurityRepo) GetAllNeighborhoods(ctx context.Context) ([]entity.Neighborhood, error) {
	var list []entity.Neighborhood
	for _, n := range m.neighborhoods {
		list = append(list, *n)
	}
	return list, nil
}

func (m *mockSecurityRepo) CreateNeighborhood(ctx context.Context, n *entity.Neighborhood) error {
	n.ID = int64(len(m.neighborhoods) + 1)
	m.neighborhoods[n.ID] = n
	return nil
}

func (m *mockSecurityRepo) GetSecurityUsers(ctx context.Context) ([]entity.User, error) {
	return nil, nil
}

func (m *mockSecurityRepo) CreateAssignment(ctx context.Context, a *entity.SecurityAssignment) error {
	for _, existing := range m.assignments {
		if existing.UserID == a.UserID && existing.NeighborhoodID == a.NeighborhoodID {
			existing.IsActive = a.IsActive
			existing.Notes = a.Notes
			existing.RevokedAt = nil
			existing.RevokedBy = nil
			a.ID = existing.ID
			return nil
		}
	}
	m.nextAssignID++
	a.ID = m.nextAssignID
	a.AssignedAt = time.Now()
	m.assignments[a.ID] = a
	return nil
}

func (m *mockSecurityRepo) GetAssignmentByID(ctx context.Context, id int64) (*entity.SecurityAssignment, error) {
	return m.assignments[id], nil
}

func (m *mockSecurityRepo) GetAssignments(ctx context.Context, userID *int64, neighborhoodID *int64, activeOnly *bool) ([]entity.SecurityAssignment, error) {
	var list []entity.SecurityAssignment
	for _, a := range m.assignments {
		if userID != nil && a.UserID != *userID {
			continue
		}
		if neighborhoodID != nil && a.NeighborhoodID != *neighborhoodID {
			continue
		}
		if activeOnly != nil && a.IsActive != *activeOnly {
			continue
		}
		list = append(list, *a)
	}
	return list, nil
}

func (m *mockSecurityRepo) UpdateAssignmentStatus(ctx context.Context, id int64, isActive bool, notes string) error {
	if a, ok := m.assignments[id]; ok {
		a.IsActive = isActive
		if notes != "" {
			a.Notes = notes
		}
	}
	return nil
}

func (m *mockSecurityRepo) RevokeAssignment(ctx context.Context, id int64, revokedBy int64, notes string) error {
	if a, ok := m.assignments[id]; ok {
		a.IsActive = false
		now := time.Now()
		a.RevokedAt = &now
		a.RevokedBy = &revokedBy
		if notes != "" {
			a.Notes = notes
		}
	}
	return nil
}

func (m *mockSecurityRepo) HasActiveAssignmentInNeighborhood(ctx context.Context, userID int64, neighborhoodID int64) (bool, error) {
	for _, a := range m.assignments {
		if a.UserID == userID && a.NeighborhoodID == neighborhoodID && a.IsActive {
			return true, nil
		}
	}
	return false, nil
}

func (m *mockSecurityRepo) GetActiveNeighborhoodIDsForUser(ctx context.Context, userID int64) ([]int64, error) {
	var ids []int64
	for _, a := range m.assignments {
		if a.UserID == userID && a.IsActive {
			ids = append(ids, a.NeighborhoodID)
		}
	}
	return ids, nil
}

var _ repository.UserRepository = (*mockUserRepo)(nil)
var _ repository.RoleRepository = (*mockRoleRepo)(nil)
var _ repository.SecurityRepository = (*mockSecurityRepo)(nil)

func TestSecurityAccountCreationAndIndependence(t *testing.T) {
	userRepo := newMockUserRepo()
	secRepo := newMockSecurityRepo()
	roleRepo := &mockRoleRepo{
		roles: map[string]*entity.Role{
			"SECURITY": {ID: 10, Name: "SECURITY"},
		},
	}

	uc := security.NewSecurityUseCase(secRepo, userRepo, roleRepo)

	t.Run("Leadership can create security account without house_id", func(t *testing.T) {
		input := security.CreateSecurityUserInput{
			Salutation: "Bapak",
			Name:       "Slamet Security",
			Phone:      "089912345678",
			Email:      "slamet@security.id",
			Password:   "password123",
		}

		user, err := uc.AdminCreateSecurityUser(context.Background(), string(entity.RoleChairperson), input)
		if err != nil {
			t.Fatalf("unexpected error creating security account: %v", err)
		}

		if user.HouseID != nil {
			t.Errorf("expected house_id to be nil for security, got %v", *user.HouseID)
		}
		if user.RoleName != string(entity.RoleSecurity) {
			t.Errorf("expected role SECURITY, got %s", user.RoleName)
		}
		if user.Status != string(entity.UserStatusActive) {
			t.Errorf("expected status active, got %s", user.Status)
		}
	})

	t.Run("Non-leadership cannot create security account", func(t *testing.T) {
		input := security.CreateSecurityUserInput{
			Name:     "Unauthorized Satpam",
			Phone:    "089900000000",
			Email:    "unauth@satpam.id",
			Password: "password123",
		}

		_, err := uc.AdminCreateSecurityUser(context.Background(), string(entity.RoleResident), input)
		if err == nil {
			t.Fatalf("expected error from non-leadership, got nil")
		}
	})
}

func TestSecurityAssignmentsLifecycle(t *testing.T) {
	userRepo := newMockUserRepo()
	secRepo := newMockSecurityRepo()
	roleRepo := &mockRoleRepo{
		roles: map[string]*entity.Role{
			"SECURITY": {ID: 10, Name: "SECURITY"},
		},
	}

	// Create a security user
	secUser := &entity.User{
		ID:       50,
		Name:     "Bambang Satpam",
		RoleID:   10,
		RoleName: string(entity.RoleSecurity),
		Status:   string(entity.UserStatusActive),
	}
	_ = userRepo.Create(context.Background(), secUser)

	uc := security.NewSecurityUseCase(secRepo, userRepo, roleRepo)

	t.Run("Assign security to neighborhood 1", func(t *testing.T) {
		assignInput := security.AssignSecurityInput{
			UserID:         secUser.ID,
			NeighborhoodID: 1,
			Notes:          "Shift Pagi Lingkungan 1",
		}

		assign, err := uc.AssignSecurity(context.Background(), 1, string(entity.RoleAdmin), assignInput)
		if err != nil {
			t.Fatalf("unexpected error assigning security: %v", err)
		}

		if !assign.IsActive {
			t.Errorf("expected assignment to be active")
		}

		hasActive, _ := secRepo.HasActiveAssignmentInNeighborhood(context.Background(), secUser.ID, 1)
		if !hasActive {
			t.Errorf("expected active assignment in neighborhood 1")
		}
	})

	t.Run("Multiple assignments without duplicating security account", func(t *testing.T) {
		assignInput := security.AssignSecurityInput{
			UserID:         secUser.ID,
			NeighborhoodID: 2,
			Notes:          "Shift Malam Lingkungan 2",
		}

		_, err := uc.AssignSecurity(context.Background(), 1, string(entity.RoleChairperson), assignInput)
		if err != nil {
			t.Fatalf("unexpected error assigning to second neighborhood: %v", err)
		}

		nIDs, err := secRepo.GetActiveNeighborhoodIDsForUser(context.Background(), secUser.ID)
		if err != nil {
			t.Fatalf("unexpected error getting neighborhoods: %v", err)
		}

		if len(nIDs) != 2 {
			t.Fatalf("expected 2 active assignments, got %d", len(nIDs))
		}
	})

	t.Run("Revoke assignment", func(t *testing.T) {
		list, _ := secRepo.GetAssignments(context.Background(), &secUser.ID, nil, nil)
		if len(list) == 0 {
			t.Fatalf("no assignments found")
		}

		targetID := list[0].ID
		err := uc.RevokeAssignment(context.Background(), 1, string(entity.RoleAdmin), targetID, "Rotasi penugasan")
		if err != nil {
			t.Fatalf("unexpected error revoking assignment: %v", err)
		}

		updated, _ := secRepo.GetAssignmentByID(context.Background(), targetID)
		if updated.IsActive {
			t.Errorf("expected assignment to be revoked (inactive)")
		}
		if updated.RevokedAt == nil {
			t.Errorf("expected revoked_at timestamp to be set")
		}
	})
}
