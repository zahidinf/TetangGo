package profile

import (
	"context"
	"errors"
	"strings"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

var (
	ErrUserNoHouse      = errors.New("profil Anda belum terhubung dengan hunian manapun")
	ErrInvalidPlateNum  = errors.New("nomor plat kendaraan wajib diisi")
	ErrInvalidVehicleType = errors.New("tipe kendaraan harus 'mobil' atau 'motor'")
	ErrInvalidRelation  = errors.New("hubungan keluarga wajib diisi (istri, suami, anak, orang_tua, famili, lainnya)")
)

type UpdateProfileInput struct {
	Name            string  `json:"name"`
	Phone           string  `json:"phone"`
	ProfilePhotoURL *string `json:"profile_photo_url"`
}

type AddFamilyMemberInput struct {
	Name     string  `json:"name"`
	Relation string  `json:"relation"` // 'istri', 'suami', 'anak', 'orang_tua', 'famili', 'lainnya'
	Phone    *string `json:"phone"`
}

type AddVehicleInput struct {
	PlateNumber string  `json:"plate_number"` // contoh: 'B 1234 ABC'
	VehicleType string  `json:"vehicle_type"` // 'mobil', 'motor'
	BrandModel  *string `json:"brand_model"`  // 'Avanza Hitam'
}

type ProfileUseCase struct {
	userRepo    repository.UserRepository
	houseRepo   repository.HouseRepository
	familyRepo  repository.FamilyRepository
	vehicleRepo repository.VehicleRepository
}

func NewProfileUseCase(
	userRepo repository.UserRepository,
	houseRepo repository.HouseRepository,
	familyRepo repository.FamilyRepository,
	vehicleRepo repository.VehicleRepository,
) *ProfileUseCase {
	return &ProfileUseCase{
		userRepo:    userRepo,
		houseRepo:   houseRepo,
		familyRepo:  familyRepo,
		vehicleRepo: vehicleRepo,
	}
}

func (uc *ProfileUseCase) GetProfile(ctx context.Context, userID int64) (*entity.UserProfileData, error) {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("pengguna tidak ditemukan")
	}

	var house *entity.House
	var familyMembers []entity.FamilyMember = []entity.FamilyMember{}
	var vehicles []entity.Vehicle = []entity.Vehicle{}

	if user.HouseID != nil {
		house, _ = uc.houseRepo.GetByID(ctx, *user.HouseID)
		fm, err := uc.familyRepo.GetByHouseID(ctx, *user.HouseID)
		if err == nil && fm != nil {
			familyMembers = fm
		}
		vh, err := uc.vehicleRepo.GetByHouseID(ctx, *user.HouseID)
		if err == nil && vh != nil {
			vehicles = vh
		}
	}

	return &entity.UserProfileData{
		User:          user,
		House:         house,
		FamilyMembers: familyMembers,
		Vehicles:      vehicles,
	}, nil
}

func (uc *ProfileUseCase) UpdateProfile(ctx context.Context, userID int64, input UpdateProfileInput) (*entity.User, error) {
	name := strings.TrimSpace(input.Name)
	phone := strings.TrimSpace(input.Phone)
	if name == "" || phone == "" {
		return nil, errors.New("nama dan nomor telepon wajib diisi")
	}

	if err := uc.userRepo.UpdateProfile(ctx, userID, name, phone, input.ProfilePhotoURL); err != nil {
		return nil, err
	}

	return uc.userRepo.GetByID(ctx, userID)
}

func (uc *ProfileUseCase) AddFamilyMember(ctx context.Context, userID int64, input AddFamilyMemberInput) (*entity.FamilyMember, error) {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil || user.HouseID == nil {
		return nil, ErrUserNoHouse
	}

	name := strings.TrimSpace(input.Name)
	relation := strings.ToLower(strings.TrimSpace(input.Relation))
	if name == "" || relation == "" {
		return nil, errors.New("nama dan hubungan keluarga wajib diisi")
	}

	member := &entity.FamilyMember{
		HouseID:  *user.HouseID,
		Name:     name,
		Relation: relation,
		Phone:    input.Phone,
	}

	if err := uc.familyRepo.Create(ctx, member); err != nil {
		return nil, err
	}

	return member, nil
}

func (uc *ProfileUseCase) DeleteFamilyMember(ctx context.Context, userID int64, memberID int64) error {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil || user.HouseID == nil {
		return ErrUserNoHouse
	}

	return uc.familyRepo.Delete(ctx, memberID, *user.HouseID)
}

func (uc *ProfileUseCase) AddVehicle(ctx context.Context, userID int64, input AddVehicleInput) (*entity.Vehicle, error) {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	if user == nil || user.HouseID == nil {
		return nil, ErrUserNoHouse
	}

	plate := strings.ToUpper(strings.TrimSpace(input.PlateNumber))
	vType := strings.ToLower(strings.TrimSpace(input.VehicleType))

	if plate == "" {
		return nil, ErrInvalidPlateNum
	}
	if vType != "mobil" && vType != "motor" {
		return nil, ErrInvalidVehicleType
	}

	vehicle := &entity.Vehicle{
		HouseID:     *user.HouseID,
		PlateNumber: plate,
		VehicleType: vType,
		BrandModel:  input.BrandModel,
	}

	if err := uc.vehicleRepo.Create(ctx, vehicle); err != nil {
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique") {
			return nil, errors.New("plat nomor kendaraan sudah terdaftar dalam sistem")
		}
		return nil, err
	}

	return vehicle, nil
}

func (uc *ProfileUseCase) DeleteVehicle(ctx context.Context, userID int64, vehicleID int64) error {
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil || user.HouseID == nil {
		return ErrUserNoHouse
	}

	return uc.vehicleRepo.Delete(ctx, vehicleID, *user.HouseID)
}
