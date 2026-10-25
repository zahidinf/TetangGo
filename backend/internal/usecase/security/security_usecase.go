package security

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"

	"golang.org/x/crypto/bcrypt"
)

var (
	ErrSecurityUserNotFound  = errors.New("pengguna security tidak ditemukan")
	ErrAssignmentNotFound    = errors.New("penugasan security tidak ditemukan")
	ErrNeighborhoodNotFound  = errors.New("lingkungan/perumahan tidak ditemukan")
	ErrUnauthorizedOperation = errors.New("akses ditolak: hanya pengurus yang berwenang")
	ErrDuplicateAssignment   = errors.New("penugasan untuk petugas di lingkungan ini sudah ada")
	ErrNotSecurityUser       = errors.New("akun yang dipilih bukan akun petugas keamanan (SECURITY)")
)

type CreateSecurityUserInput struct {
	Salutation string `json:"salutation"`
	Name       string `json:"name"`
	Phone      string `json:"phone"`
	Email      string `json:"email"`
	Password   string `json:"password"`
}

type AssignSecurityInput struct {
	UserID         int64  `json:"user_id"`
	NeighborhoodID int64  `json:"neighborhood_id"`
	Notes          string `json:"notes"`
}

type SecurityUseCase struct {
	secRepo  repository.SecurityRepository
	userRepo repository.UserRepository
	roleRepo repository.RoleRepository
}

func NewSecurityUseCase(
	secRepo repository.SecurityRepository,
	userRepo repository.UserRepository,
	roleRepo repository.RoleRepository,
) *SecurityUseCase {
	return &SecurityUseCase{
		secRepo:  secRepo,
		userRepo: userRepo,
		roleRepo: roleRepo,
	}
}

func (uc *SecurityUseCase) isAuthorizedLeadership(role string) bool {
	switch entity.RoleName(role) {
	case entity.RoleAdmin, entity.RoleChairperson, entity.RoleViceChairperson:
		return true
	default:
		return false
	}
}

func (uc *SecurityUseCase) AdminCreateSecurityUser(ctx context.Context, callerRole string, input CreateSecurityUserInput) (*entity.User, error) {
	if !uc.isAuthorizedLeadership(callerRole) {
		return nil, ErrUnauthorizedOperation
	}

	name := strings.TrimSpace(input.Name)
	phone := strings.TrimSpace(input.Phone)
	email := strings.ToLower(strings.TrimSpace(input.Email))
	password := strings.TrimSpace(input.Password)

	if name == "" || phone == "" || email == "" || password == "" {
		return nil, errors.New("nama, no. HP, email, dan password wajib diisi")
	}

	existingUser, _ := uc.userRepo.GetByEmailOrPhone(ctx, email)
	if existingUser != nil {
		return nil, errors.New("email sudah terdaftar di sistem")
	}
	existingPhone, _ := uc.userRepo.GetByEmailOrPhone(ctx, phone)
	if existingPhone != nil {
		return nil, errors.New("nomor HP sudah terdaftar di sistem")
	}

	role, err := uc.roleRepo.GetByName(ctx, string(entity.RoleSecurity))
	if err != nil || role == nil {
		return nil, errors.New("role SECURITY belum terdaftar dalam sistem")
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, errors.New("gagal memproses password")
	}

	salutation := entity.NormalizeSalutation(input.Salutation)

	newUser := &entity.User{
		Salutation:      salutation,
		Name:            name,
		Phone:           phone,
		Email:           email,
		PasswordHash:    string(hashedPassword),
		RoleID:          role.ID,
		RoleName:        role.Name,
		HouseID:         nil, // Security akun operasional tanpa kewajiban hunian
		Status:          string(entity.UserStatusActive),
		OwnershipStatus: "",
	}

	if err := uc.userRepo.Create(ctx, newUser); err != nil {
		return nil, fmt.Errorf("gagal membuat akun security: %w", err)
	}

	return newUser, nil
}

func (uc *SecurityUseCase) AdminListSecurityUsers(ctx context.Context) ([]entity.User, error) {
	return uc.secRepo.GetSecurityUsers(ctx)
}

func (uc *SecurityUseCase) AdminSetSecurityStatus(ctx context.Context, callerRole string, targetUserID int64, status string) error {
	if !uc.isAuthorizedLeadership(callerRole) {
		return ErrUnauthorizedOperation
	}

	user, err := uc.userRepo.GetByID(ctx, targetUserID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrSecurityUserNotFound
	}

	if user.RoleName != string(entity.RoleSecurity) {
		return ErrNotSecurityUser
	}

	cleanStatus := strings.ToLower(strings.TrimSpace(status))
	if cleanStatus != string(entity.UserStatusActive) && cleanStatus != string(entity.UserStatusInactive) {
		return errors.New("status tidak valid (hanya 'active' atau 'inactive')")
	}

	return uc.userRepo.UpdateStatus(ctx, targetUserID, cleanStatus, nil)
}

// Assignments

func (uc *SecurityUseCase) AssignSecurity(ctx context.Context, callerID int64, callerRole string, input AssignSecurityInput) (*entity.SecurityAssignment, error) {
	if !uc.isAuthorizedLeadership(callerRole) {
		return nil, ErrUnauthorizedOperation
	}

	if input.UserID <= 0 || input.NeighborhoodID <= 0 {
		return nil, errors.New("user_id dan neighborhood_id wajib diisi")
	}

	user, err := uc.userRepo.GetByID(ctx, input.UserID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrSecurityUserNotFound
	}
	if user.RoleName != string(entity.RoleSecurity) {
		return nil, ErrNotSecurityUser
	}

	neighborhood, err := uc.secRepo.GetNeighborhoodByID(ctx, input.NeighborhoodID)
	if err != nil {
		return nil, err
	}
	if neighborhood == nil {
		return nil, ErrNeighborhoodNotFound
	}

	assignment := &entity.SecurityAssignment{
		UserID:         input.UserID,
		NeighborhoodID: input.NeighborhoodID,
		IsActive:       true,
		AssignedBy:     &callerID,
		Notes:          strings.TrimSpace(input.Notes),
	}

	if err := uc.secRepo.CreateAssignment(ctx, assignment); err != nil {
		return nil, fmt.Errorf("gagal membuat penugasan security: %w", err)
	}

	return uc.secRepo.GetAssignmentByID(ctx, assignment.ID)
}

func (uc *SecurityUseCase) UpdateAssignmentStatus(ctx context.Context, callerRole string, assignmentID int64, isActive bool, notes string) error {
	if !uc.isAuthorizedLeadership(callerRole) {
		return ErrUnauthorizedOperation
	}

	existing, err := uc.secRepo.GetAssignmentByID(ctx, assignmentID)
	if err != nil {
		return err
	}
	if existing == nil {
		return ErrAssignmentNotFound
	}

	return uc.secRepo.UpdateAssignmentStatus(ctx, assignmentID, isActive, strings.TrimSpace(notes))
}

func (uc *SecurityUseCase) RevokeAssignment(ctx context.Context, callerID int64, callerRole string, assignmentID int64, notes string) error {
	if !uc.isAuthorizedLeadership(callerRole) {
		return ErrUnauthorizedOperation
	}

	existing, err := uc.secRepo.GetAssignmentByID(ctx, assignmentID)
	if err != nil {
		return err
	}
	if existing == nil {
		return ErrAssignmentNotFound
	}

	return uc.secRepo.RevokeAssignment(ctx, assignmentID, callerID, strings.TrimSpace(notes))
}

func (uc *SecurityUseCase) ListAssignments(ctx context.Context, userID *int64, neighborhoodID *int64, activeOnly *bool) ([]entity.SecurityAssignment, error) {
	return uc.secRepo.GetAssignments(ctx, userID, neighborhoodID, activeOnly)
}

func (uc *SecurityUseCase) ListNeighborhoods(ctx context.Context) ([]entity.Neighborhood, error) {
	return uc.secRepo.GetAllNeighborhoods(ctx)
}
