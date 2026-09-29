package house

import (
	"context"
	"errors"
	"strings"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

var (
	ErrHouseNotFound = errors.New("data rumah tidak ditemukan")
	ErrUserNotFound  = errors.New("data warga tidak ditemukan")
	ErrInvalidStatus = errors.New("status rumah harus 'milik', 'kontrak', atau 'kosong'")
)

type CreateHouseInput struct {
	Block       string `json:"block"`
	HouseNumber string `json:"house_number"`
	Status      string `json:"status"`
}

type UpdateHouseInput struct {
	Block       string `json:"block"`
	HouseNumber string `json:"house_number"`
	Status      string `json:"status"`
}

type AssignResidentInput struct {
	UserID       int64  `json:"user_id"`
	OccupantType string `json:"occupant_type"` // 'pemilik' or 'pengontrak'
}

type TransferHouseInput struct {
	NewHouseID int64 `json:"new_house_id"`
}

type AdminAddFamilyInput struct {
	Name     string  `json:"name"`
	Relation string  `json:"relation"` // 'istri', 'suami', 'anak', 'orang_tua', 'famili', 'lainnya'
	Phone    *string `json:"phone"`
}

type AdminAddVehicleInput struct {
	PlateNumber string  `json:"plate_number"`
	VehicleType string  `json:"vehicle_type"` // 'mobil', 'motor'
	BrandModel  *string `json:"brand_model"`
}

type HouseUseCase struct {
	houseRepo   repository.HouseRepository
	userRepo    repository.UserRepository
	familyRepo  repository.FamilyRepository
	vehicleRepo repository.VehicleRepository
}

func NewHouseUseCase(
	houseRepo repository.HouseRepository,
	userRepo repository.UserRepository,
	familyRepo repository.FamilyRepository,
	vehicleRepo repository.VehicleRepository,
) *HouseUseCase {
	return &HouseUseCase{
		houseRepo:   houseRepo,
		userRepo:    userRepo,
		familyRepo:  familyRepo,
		vehicleRepo: vehicleRepo,
	}
}

func (uc *HouseUseCase) GetAllHouses(ctx context.Context, block, status, search string) ([]entity.House, error) {
	return uc.houseRepo.GetAll(ctx, block, status, search)
}

func (uc *HouseUseCase) GetAvailableHouses(ctx context.Context) ([]entity.House, error) {
	return uc.houseRepo.GetAvailable(ctx)
}

func (uc *HouseUseCase) GetDistinctBlocks(ctx context.Context) ([]string, error) {
	return uc.houseRepo.GetDistinctBlocks(ctx)
}

func (uc *HouseUseCase) CreateHouse(ctx context.Context, input CreateHouseInput) (*entity.House, error) {
	block := strings.TrimSpace(input.Block)
	number := strings.TrimSpace(input.HouseNumber)
	status := strings.ToLower(strings.TrimSpace(input.Status))

	if block == "" || number == "" {
		return nil, errors.New("blok dan nomor rumah wajib diisi")
	}

	if status != string(entity.HouseStatusMilik) &&
		status != string(entity.HouseStatusKontrak) &&
		status != string(entity.HouseStatusKosong) {
		status = string(entity.HouseStatusKosong)
	}

	h := &entity.House{
		Block:       strings.ToUpper(block),
		HouseNumber: number,
		Status:      status,
	}

	if err := uc.houseRepo.Create(ctx, h); err != nil {
		return nil, err
	}

	return h, nil
}

func (uc *HouseUseCase) UpdateHouse(ctx context.Context, id int64, input UpdateHouseInput) (*entity.House, error) {
	existing, err := uc.houseRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if existing == nil {
		return nil, ErrHouseNotFound
	}

	block := strings.TrimSpace(input.Block)
	number := strings.TrimSpace(input.HouseNumber)
	status := strings.ToLower(strings.TrimSpace(input.Status))

	if block != "" {
		existing.Block = strings.ToUpper(block)
	}
	if number != "" {
		existing.HouseNumber = number
	}
	if status != "" {
		if status != string(entity.HouseStatusMilik) &&
			status != string(entity.HouseStatusKontrak) &&
			status != string(entity.HouseStatusKosong) {
			return nil, ErrInvalidStatus
		}
		existing.Status = status
	}

	if err := uc.houseRepo.Update(ctx, existing); err != nil {
		return nil, err
	}

	return existing, nil
}

type BulkDeleteHousesInput struct {
	HouseIDs []int64 `json:"house_ids"`
}

func (uc *HouseUseCase) DeleteHouse(ctx context.Context, id int64) error {
	return uc.houseRepo.Delete(ctx, id)
}

func (uc *HouseUseCase) BulkDeleteHouses(ctx context.Context, ids []int64) (int64, error) {
	if len(ids) == 0 {
		return 0, errors.New("daftar ID hunian tidak boleh kosong")
	}
	return uc.houseRepo.BulkDelete(ctx, ids)
}

func (uc *HouseUseCase) GetHouseOccupants(ctx context.Context, houseID int64) (*entity.HouseOccupantsResponse, error) {
	house, err := uc.houseRepo.GetByID(ctx, houseID)
	if err != nil {
		return nil, err
	}
	if house == nil {
		return nil, ErrHouseNotFound
	}

	occupants, err := uc.userRepo.GetOccupantsByHouseID(ctx, houseID)
	if err != nil {
		return nil, err
	}

	return &entity.HouseOccupantsResponse{
		House:     house,
		Occupants: occupants,
	}, nil
}

func (uc *HouseUseCase) GetUnassignedResidents(ctx context.Context, search string) ([]entity.UnassignedResident, error) {
	return uc.userRepo.GetUnassignedResidents(ctx, strings.TrimSpace(search))
}

func (uc *HouseUseCase) AssignResident(ctx context.Context, houseID int64, userID int64, occupantType string) error {
	house, err := uc.houseRepo.GetByID(ctx, houseID)
	if err != nil {
		return err
	}
	if house == nil {
		return ErrHouseNotFound
	}

	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	cleanType := strings.ToLower(strings.TrimSpace(occupantType))
	if cleanType == "" || (cleanType != "pemilik" && cleanType != "pengontrak" && cleanType != "anggota_keluarga") {
		cleanType = "pemilik"
	}

	// Simpan houseID lama jika warga sebelumnya sudah punya rumah
	oldHouseID := user.HouseID

	if err := uc.userRepo.AssignHouse(ctx, userID, houseID, cleanType); err != nil {
		return err
	}

	// Jika rumah baru tadinya kosong, ubah statusnya
	if house.Status == string(entity.HouseStatusKosong) {
		newStatus := entity.HouseStatusMilik
		if cleanType == "pengontrak" {
			newStatus = entity.HouseStatusKontrak
		}
		house.Status = string(newStatus)
		_ = uc.houseRepo.Update(ctx, house)
	}

	// Jika warga sebelumnya pindah dari rumah lain, cek apakah rumah lama menjadi kosong
	if oldHouseID != nil && *oldHouseID != houseID {
		remaining, err := uc.userRepo.CountOccupantsByHouseID(ctx, *oldHouseID)
		if err == nil && remaining == 0 {
			oldHouse, err := uc.houseRepo.GetByID(ctx, *oldHouseID)
			if err == nil && oldHouse != nil {
				oldHouse.Status = string(entity.HouseStatusKosong)
				_ = uc.houseRepo.Update(ctx, oldHouse)
			}
		}
	}

	return nil
}

func (uc *HouseUseCase) RemoveResident(ctx context.Context, houseID int64, userID int64) error {
	if err := uc.userRepo.UnassignHouse(ctx, userID, houseID); err != nil {
		return err
	}

	// Cek apakah rumah masih punya penghuni lain
	remaining, err := uc.userRepo.CountOccupantsByHouseID(ctx, houseID)
	if err == nil && remaining == 0 {
		house, err := uc.houseRepo.GetByID(ctx, houseID)
		if err == nil && house != nil {
			house.Status = string(entity.HouseStatusKosong)
			_ = uc.houseRepo.Update(ctx, house)
		}
	}

	return nil
}

func (uc *HouseUseCase) TransferHouse(ctx context.Context, userID int64, newHouseID int64) error {
	newHouse, err := uc.houseRepo.GetByID(ctx, newHouseID)
	if err != nil {
		return err
	}
	if newHouse == nil {
		return ErrHouseNotFound
	}

	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	oldHouseID := user.HouseID
	occupantType := user.OwnershipStatus
	if occupantType == "" {
		occupantType = "pemilik"
	}

	if err := uc.userRepo.AssignHouse(ctx, userID, newHouseID, occupantType); err != nil {
		return err
	}

	// Update status new house jika tadinya kosong
	if newHouse.Status == string(entity.HouseStatusKosong) {
		newStatus := entity.HouseStatusMilik
		if occupantType == "pengontrak" {
			newStatus = entity.HouseStatusKontrak
		}
		newHouse.Status = string(newStatus)
		_ = uc.houseRepo.Update(ctx, newHouse)
	}

	// Update status old house jika sekarang kosong
	if oldHouseID != nil && *oldHouseID != newHouseID {
		remaining, err := uc.userRepo.CountOccupantsByHouseID(ctx, *oldHouseID)
		if err == nil && remaining == 0 {
			oldHouse, err := uc.houseRepo.GetByID(ctx, *oldHouseID)
			if err == nil && oldHouse != nil {
				oldHouse.Status = string(entity.HouseStatusKosong)
				_ = uc.houseRepo.Update(ctx, oldHouse)
			}
		}
	}

	return nil
}

func (uc *HouseUseCase) GetHouseDetails(ctx context.Context, houseID int64) (*entity.HouseDetailData, error) {
	house, err := uc.houseRepo.GetByID(ctx, houseID)
	if err != nil {
		return nil, err
	}
	if house == nil {
		return nil, ErrHouseNotFound
	}

	occupants, _ := uc.userRepo.GetOccupantsByHouseID(ctx, houseID)
	var headOfFamily *entity.User
	if len(occupants) > 0 {
		headUser, err := uc.userRepo.GetByID(ctx, occupants[0].ID)
		if err == nil {
			headOfFamily = headUser
		}
	}

	familyMembers, err := uc.familyRepo.GetByHouseID(ctx, houseID)
	if err != nil || familyMembers == nil {
		familyMembers = []entity.FamilyMember{}
	}

	vehicles, err := uc.vehicleRepo.GetByHouseID(ctx, houseID)
	if err != nil || vehicles == nil {
		vehicles = []entity.Vehicle{}
	}

	totalMembers := len(familyMembers)
	if headOfFamily != nil {
		totalMembers += 1
	}

	return &entity.HouseDetailData{
		House:         house,
		HeadOfFamily:  headOfFamily,
		TotalMembers:  totalMembers,
		FamilyMembers: familyMembers,
		Vehicles:      vehicles,
	}, nil
}

func (uc *HouseUseCase) AdminAddFamilyMember(ctx context.Context, houseID int64, input AdminAddFamilyInput) (*entity.FamilyMember, error) {
	house, err := uc.houseRepo.GetByID(ctx, houseID)
	if err != nil {
		return nil, err
	}
	if house == nil {
		return nil, ErrHouseNotFound
	}

	name := strings.TrimSpace(input.Name)
	relation := strings.ToLower(strings.TrimSpace(input.Relation))
	if name == "" || relation == "" {
		return nil, errors.New("nama dan hubungan keluarga wajib diisi")
	}

	member := &entity.FamilyMember{
		HouseID:  houseID,
		Name:     name,
		Relation: relation,
		Phone:    input.Phone,
	}

	if err := uc.familyRepo.Create(ctx, member); err != nil {
		return nil, err
	}

	return member, nil
}

func (uc *HouseUseCase) AdminDeleteFamilyMember(ctx context.Context, houseID int64, familyID int64) error {
	return uc.familyRepo.Delete(ctx, familyID, houseID)
}

func (uc *HouseUseCase) AdminAddVehicle(ctx context.Context, houseID int64, input AdminAddVehicleInput) (*entity.Vehicle, error) {
	house, err := uc.houseRepo.GetByID(ctx, houseID)
	if err != nil {
		return nil, err
	}
	if house == nil {
		return nil, ErrHouseNotFound
	}

	plate := strings.ToUpper(strings.TrimSpace(input.PlateNumber))
	vType := strings.ToLower(strings.TrimSpace(input.VehicleType))

	if plate == "" {
		return nil, errors.New("nomor plat kendaraan wajib diisi")
	}
	if vType != "mobil" && vType != "motor" {
		return nil, errors.New("tipe kendaraan harus 'mobil' atau 'motor'")
	}

	vehicle := &entity.Vehicle{
		HouseID:     houseID,
		PlateNumber: plate,
		VehicleType: vType,
		BrandModel:  input.BrandModel,
	}

	if err := uc.vehicleRepo.Create(ctx, vehicle); err != nil {
		return nil, err
	}

	return vehicle, nil
}

func (uc *HouseUseCase) AdminDeleteVehicle(ctx context.Context, houseID int64, vehicleID int64) error {
	return uc.vehicleRepo.Delete(ctx, vehicleID, houseID)
}

