package auth_test

import (
	"context"
	"testing"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
	"tetanggo-backend/internal/usecase/auth"
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
	users map[int64]*entity.User
}

func (m *mockUserRepo) Create(ctx context.Context, user *entity.User) error {
	m.users[user.ID] = user
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

func (m *mockUserRepo) Update(ctx context.Context, user *entity.User) error {
	m.users[user.ID] = user
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
	return 1, nil
}

func (m *mockUserRepo) GetAllUsers(ctx context.Context, search, status, role string, houseID *int64) ([]entity.User, error) {
	var list []entity.User
	for _, u := range m.users {
		list = append(list, *u)
	}
	return list, nil
}

func (m *mockUserRepo) UpdatePassword(ctx context.Context, id int64, passwordHash string) error {
	if u, ok := m.users[id]; ok {
		u.PasswordHash = passwordHash
	}
	return nil
}

var _ repository.UserRepository = (*mockUserRepo)(nil)
var _ repository.RoleRepository = (*mockRoleRepo)(nil)

func TestAdminAssignRoleAuthorization(t *testing.T) {
	roleRepo := &mockRoleRepo{
		roles: map[string]*entity.Role{
			"ADMIN":            {ID: 1, Name: "ADMIN"},
			"CHAIRPERSON":      {ID: 2, Name: "CHAIRPERSON"},
			"VICE_CHAIRPERSON": {ID: 3, Name: "VICE_CHAIRPERSON"},
			"TREASURER":        {ID: 4, Name: "TREASURER"},
			"SECRETARY":        {ID: 5, Name: "SECRETARY"},
			"RESIDENT":         {ID: 6, Name: "RESIDENT"},
		},
	}

	userRepo := &mockUserRepo{
		users: map[int64]*entity.User{
			1: {ID: 1, Name: "Admin User", RoleID: 1, RoleName: "ADMIN"},
			2: {ID: 2, Name: "Ketua RT", RoleID: 2, RoleName: "CHAIRPERSON"},
			3: {ID: 3, Name: "Bendahara", RoleID: 4, RoleName: "TREASURER"},
			4: {ID: 4, Name: "Warga Biasa", RoleID: 6, RoleName: "RESIDENT"},
		},
	}

	tokenService := auth.NewTokenService("testsecret_123456789012345678901234", 1, 2)
	uc := auth.NewAuthUseCase(userRepo, roleRepo, nil, tokenService)
	ctx := context.Background()

	// 1. Authorized assigner (ADMIN) assigns TREASURER to resident
	res, err := uc.AdminAssignRole(ctx, 1, "ADMIN", 4, "TREASURER")
	if err != nil {
		t.Fatalf("expected success, got error: %v", err)
	}
	if res.RoleName != "TREASURER" {
		t.Errorf("expected role TREASURER, got %s", res.RoleName)
	}

	// 2. Chairperson revokes role back to RESIDENT
	res, err = uc.AdminAssignRole(ctx, 2, "CHAIRPERSON", 4, "RESIDENT")
	if err != nil {
		t.Fatalf("expected success on revocation, got error: %v", err)
	}
	if res.RoleName != "RESIDENT" {
		t.Errorf("expected role RESIDENT, got %s", res.RoleName)
	}

	// 3. Unauthorized assigner (TREASURER) tries to assign role -> Must fail
	_, err = uc.AdminAssignRole(ctx, 3, "TREASURER", 4, "SECRETARY")
	if err == nil {
		t.Fatal("expected unauthorized error for TREASURER trying to assign role")
	}

	// 4. Self-role modification -> Must fail
	_, err = uc.AdminAssignRole(ctx, 2, "CHAIRPERSON", 2, "RESIDENT")
	if err == nil {
		t.Fatal("expected error on self-role modification")
	}

	// 5. Attempting to assign ADMIN role -> Must fail
	_, err = uc.AdminAssignRole(ctx, 2, "CHAIRPERSON", 4, "ADMIN")
	if err == nil {
		t.Fatal("expected error on attempting to assign ADMIN role")
	}

	// 6. Non-admin attempting to touch ADMIN account -> Must fail
	_, err = uc.AdminAssignRole(ctx, 2, "CHAIRPERSON", 1, "RESIDENT")
	if err == nil {
		t.Fatal("expected error when non-admin attempts to modify ADMIN account")
	}
}
