package auth

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
	ErrInvalidCredentials = errors.New("nomor HP/email atau password salah")
	ErrAccountInactive    = errors.New("akun belum aktif atau ditangguhkan")
	ErrUserNotFound       = errors.New("pengguna tidak ditemukan")
	ErrUserExists         = errors.New("email atau nomor HP sudah terdaftar")
	ErrHouseNotFound      = errors.New("rumah yang dipilih tidak ditemukan")
)

type LoginInput struct {
	Identifier string `json:"identifier"` // Email or Phone
	Password   string `json:"password"`
}

type RegisterInput struct {
	Name            string `json:"name"`
	Phone           string `json:"phone"`
	Email           string `json:"email"`
	Password        string `json:"password"`
	HouseID         int64  `json:"house_id"`
	OwnershipStatus string `json:"ownership_status"` // 'pemilik' or 'pengontrak'
}

type AuthResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	User         *entity.User `json:"user"`
}

type RejectInput struct {
	Reason string `json:"reason"`
}

type AdminCreateUserInput struct {
	Name            string `json:"name"`
	Phone           string `json:"phone"`
	Email           string `json:"email"`
	Password        string `json:"password"`
	HouseID         *int64 `json:"house_id"`
	Role            string `json:"role"`   // default: 'warga'
	Status          string `json:"status"` // default: 'active'
	OwnershipStatus string `json:"ownership_status"`
}

type AdminUpdateUserInput struct {
	Name            string `json:"name"`
	Phone           string `json:"phone"`
	Email           string `json:"email"`
	HouseID         *int64 `json:"house_id"`
	Role            string `json:"role"`
	Status          string `json:"status"`
	OwnershipStatus string `json:"ownership_status"`
}

type AdminResetPasswordInput struct {
	NewPassword string `json:"new_password"`
}

type AuthUseCase struct {
	userRepo     repository.UserRepository
	roleRepo     repository.RoleRepository
	houseRepo    repository.HouseRepository
	tokenService *TokenService
}

func NewAuthUseCase(
	userRepo repository.UserRepository,
	roleRepo repository.RoleRepository,
	houseRepo repository.HouseRepository,
	tokenService *TokenService,
) *AuthUseCase {
	return &AuthUseCase{
		userRepo:     userRepo,
		roleRepo:     roleRepo,
		houseRepo:    houseRepo,
		tokenService: tokenService,
	}
}

func (uc *AuthUseCase) Login(ctx context.Context, input LoginInput) (*AuthResponse, error) {
	if strings.TrimSpace(input.Identifier) == "" || strings.TrimSpace(input.Password) == "" {
		return nil, errors.New("email/nomor HP dan password wajib diisi")
	}

	user, err := uc.userRepo.GetByEmailOrPhone(ctx, strings.TrimSpace(input.Identifier))
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrInvalidCredentials
	}

	if !CheckPasswordHash(input.Password, user.PasswordHash) {
		return nil, ErrInvalidCredentials
	}

	if user.Status == string(entity.UserStatusRejected) {
		reason := "Pendaftaran akun Anda ditolak oleh Pengurus RT"
		if user.RejectionReason != nil && *user.RejectionReason != "" {
			reason += fmt.Sprintf(": %s", *user.RejectionReason)
		}
		return nil, errors.New(reason)
	}

	if user.Status == string(entity.UserStatusInactive) {
		return nil, ErrAccountInactive
	}

	accessToken, refreshToken, err := uc.tokenService.GenerateTokenPair(user.ID, user.Email, user.RoleName)
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         user,
	}, nil
}

func (uc *AuthUseCase) Register(ctx context.Context, input RegisterInput) (*entity.User, error) {
	name := strings.TrimSpace(input.Name)
	email := strings.TrimSpace(input.Email)
	phone := strings.TrimSpace(input.Phone)
	password := strings.TrimSpace(input.Password)
	ownershipStatus := strings.TrimSpace(input.OwnershipStatus)

	if name == "" || email == "" || phone == "" || password == "" {
		return nil, errors.New("semua data wajib diisi")
	}
	if input.HouseID <= 0 {
		return nil, errors.New("pilihan rumah wajib dipilih")
	}

	if ownershipStatus == "" {
		ownershipStatus = "pemilik"
	}
	if ownershipStatus != "pemilik" && ownershipStatus != "pengontrak" {
		ownershipStatus = "pemilik"
	}

	// Cek user terdaftar
	existing, err := uc.userRepo.GetByEmailOrPhone(ctx, email)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, ErrUserExists
	}
	existingPhone, err := uc.userRepo.GetByEmailOrPhone(ctx, phone)
	if err != nil {
		return nil, err
	}
	if existingPhone != nil {
		return nil, ErrUserExists
	}

	// Cek house exists
	house, err := uc.houseRepo.GetByID(ctx, input.HouseID)
	if err != nil {
		return nil, err
	}
	if house == nil {
		return nil, ErrHouseNotFound
	}

	// Dapatkan role warga
	role, err := uc.roleRepo.GetByName(ctx, string(entity.RoleWarga))
	if err != nil {
		return nil, err
	}
	if role == nil {
		return nil, errors.New("role warga tidak ditemukan di sistem")
	}

	hashedPassword, err := HashPassword(password)
	if err != nil {
		return nil, err
	}

	newUser := &entity.User{
		Name:            name,
		Phone:           phone,
		Email:           email,
		PasswordHash:    hashedPassword,
		RoleID:          role.ID,
		RoleName:        role.Name,
		HouseID:         &input.HouseID,
		Status:          string(entity.UserStatusPending),
		OwnershipStatus: ownershipStatus,
	}

	if err := uc.userRepo.Create(ctx, newUser); err != nil {
		return nil, err
	}

	newUser.House = house
	return newUser, nil
}

func (uc *AuthUseCase) GetPendingUsers(ctx context.Context) ([]entity.PendingUser, error) {
	return uc.userRepo.GetPendingUsers(ctx)
}

func (uc *AuthUseCase) ApproveUser(ctx context.Context, userID int64) error {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	// Update user status to active
	if err := uc.userRepo.UpdateStatus(ctx, userID, string(entity.UserStatusActive), nil); err != nil {
		return err
	}

	// If user has house, update house status accordingly (if currently kosong)
	if user.HouseID != nil {
		house, err := uc.houseRepo.GetByID(ctx, *user.HouseID)
		if err == nil && house != nil && house.Status == string(entity.HouseStatusKosong) {
			newStatus := entity.HouseStatusMilik
			if user.OwnershipStatus == "pengontrak" {
				newStatus = entity.HouseStatusKontrak
			}
			house.Status = string(newStatus)
			_ = uc.houseRepo.Update(ctx, house)
		}
	}

	return nil
}

func (uc *AuthUseCase) RejectUser(ctx context.Context, userID int64, reason string) error {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	cleanReason := strings.TrimSpace(reason)
	if cleanReason == "" {
		cleanReason = "Data tidak sesuai ketentuan RT"
	}

	return uc.userRepo.UpdateStatus(ctx, userID, string(entity.UserStatusRejected), &cleanReason)
}

func (uc *AuthUseCase) GetProfile(ctx context.Context, userID int64) (*entity.User, error) {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}
	return user, nil
}

func (uc *AuthUseCase) AdminGetAllUsers(ctx context.Context, search, status, role string, houseID *int64) ([]entity.User, error) {
	return uc.userRepo.GetAllUsers(ctx, strings.TrimSpace(search), strings.TrimSpace(status), strings.TrimSpace(role), houseID)
}

func (uc *AuthUseCase) AdminCreateUser(ctx context.Context, input AdminCreateUserInput) (*entity.User, error) {
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

	roleName := strings.ToLower(strings.TrimSpace(input.Role))
	if roleName == "" {
		roleName = "warga"
	}
	role, err := uc.roleRepo.GetByName(ctx, roleName)
	if err != nil || role == nil {
		role, _ = uc.roleRepo.GetByName(ctx, "warga")
	}

	status := strings.ToLower(strings.TrimSpace(input.Status))
	if status == "" {
		status = string(entity.UserStatusActive)
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, errors.New("gagal memproses password")
	}

	ownershipStatus := strings.ToLower(strings.TrimSpace(input.OwnershipStatus))
	if ownershipStatus == "" {
		ownershipStatus = "pemilik"
	}

	newUser := &entity.User{
		Name:            name,
		Phone:           phone,
		Email:           email,
		PasswordHash:    string(hashedPassword),
		RoleID:          role.ID,
		RoleName:        role.Name,
		HouseID:         input.HouseID,
		Status:          status,
		OwnershipStatus: ownershipStatus,
	}

	if err := uc.userRepo.Create(ctx, newUser); err != nil {
		return nil, err
	}

	// Update house status if needed
	if newUser.HouseID != nil && status == string(entity.UserStatusActive) {
		house, err := uc.houseRepo.GetByID(ctx, *newUser.HouseID)
		if err == nil && house != nil && house.Status == string(entity.HouseStatusKosong) {
			newStatus := entity.HouseStatusMilik
			if ownershipStatus == "pengontrak" {
				newStatus = entity.HouseStatusKontrak
			}
			house.Status = string(newStatus)
			_ = uc.houseRepo.Update(ctx, house)
		}
		newUser.House = house
	}

	return newUser, nil
}

func (uc *AuthUseCase) AdminUpdateUser(ctx context.Context, userID int64, input AdminUpdateUserInput) (*entity.User, error) {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, ErrUserNotFound
	}

	name := strings.TrimSpace(input.Name)
	phone := strings.TrimSpace(input.Phone)
	email := strings.ToLower(strings.TrimSpace(input.Email))

	if name != "" {
		user.Name = name
	}
	if phone != "" {
		user.Phone = phone
	}
	if email != "" {
		user.Email = email
	}

	if input.Role != "" {
		role, err := uc.roleRepo.GetByName(ctx, strings.ToLower(strings.TrimSpace(input.Role)))
		if err == nil && role != nil {
			user.RoleID = role.ID
			user.RoleName = role.Name
		}
	}

	if input.Status != "" {
		user.Status = strings.ToLower(strings.TrimSpace(input.Status))
	}

	if input.OwnershipStatus != "" {
		user.OwnershipStatus = strings.ToLower(strings.TrimSpace(input.OwnershipStatus))
	}

	oldHouseID := user.HouseID
	user.HouseID = input.HouseID

	if err := uc.userRepo.Update(ctx, user); err != nil {
		return nil, err
	}

	// Update status hunian jika terjadi perubahan
	if user.HouseID != nil {
		house, err := uc.houseRepo.GetByID(ctx, *user.HouseID)
		if err == nil && house != nil && house.Status == string(entity.HouseStatusKosong) {
			newStatus := entity.HouseStatusMilik
			if user.OwnershipStatus == "pengontrak" {
				newStatus = entity.HouseStatusKontrak
			}
			house.Status = string(newStatus)
			_ = uc.houseRepo.Update(ctx, house)
		}
	}

	if oldHouseID != nil && (user.HouseID == nil || *oldHouseID != *user.HouseID) {
		count, err := uc.userRepo.CountOccupantsByHouseID(ctx, *oldHouseID)
		if err == nil && count == 0 {
			oldHouse, err := uc.houseRepo.GetByID(ctx, *oldHouseID)
			if err == nil && oldHouse != nil {
				oldHouse.Status = string(entity.HouseStatusKosong)
				_ = uc.houseRepo.Update(ctx, oldHouse)
			}
		}
	}

	return uc.userRepo.GetByID(ctx, userID)
}

func (uc *AuthUseCase) AdminDeleteUser(ctx context.Context, userID int64) error {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	houseID := user.HouseID

	if err := uc.userRepo.Delete(ctx, userID); err != nil {
		return err
	}

	// Cek status rumah setelah user dihapus
	if houseID != nil {
		count, err := uc.userRepo.CountOccupantsByHouseID(ctx, *houseID)
		if err == nil && count == 0 {
			house, err := uc.houseRepo.GetByID(ctx, *houseID)
			if err == nil && house != nil {
				house.Status = string(entity.HouseStatusKosong)
				_ = uc.houseRepo.Update(ctx, house)
			}
		}
	}

	return nil
}

func (uc *AuthUseCase) AdminResetPassword(ctx context.Context, userID int64, newPassword string) error {
	cleanPass := strings.TrimSpace(newPassword)
	if cleanPass == "" {
		return errors.New("password baru wajib diisi")
	}
	if len(cleanPass) < 6 {
		return errors.New("password baru minimal 6 karakter")
	}

	hashed, err := bcrypt.GenerateFromPassword([]byte(cleanPass), bcrypt.DefaultCost)
	if err != nil {
		return errors.New("gagal memproses password")
	}

	return uc.userRepo.UpdatePassword(ctx, userID, string(hashed))
}
