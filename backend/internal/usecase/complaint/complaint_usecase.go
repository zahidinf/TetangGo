package complaint

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"strings"
	"time"

	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

var (
	ErrEmptyTitle         = errors.New("judul pengaduan tidak boleh kosong")
	ErrEmptyDescription   = errors.New("deskripsi pengaduan tidak boleh kosong")
	ErrInvalidCategory    = errors.New("kategori pengaduan tidak valid. Kategori yang diizinkan: Lampu Jalan, Sampah, Ketertiban, Jalanan")
	ErrUserNotFound       = errors.New("pengguna tidak ditemukan")
	ErrUserInactive       = errors.New("akun tidak aktif")
	ErrNoHouseAssociation = errors.New("pengguna belum terdaftar pada hunian manapun")
	ErrComplaintNotFound  = errors.New("pengaduan tidak ditemukan")
	ErrUnauthorizedAccess = errors.New("akses ditolak: Anda tidak memiliki akses ke pengaduan ini")
)

type ComplaintUseCase struct {
	complaintRepo repository.ComplaintRepository
	userRepo      repository.UserRepository
	houseRepo     repository.HouseRepository
}

func NewComplaintUseCase(
	complaintRepo repository.ComplaintRepository,
	userRepo repository.UserRepository,
	houseRepo repository.HouseRepository,
) *ComplaintUseCase {
	return &ComplaintUseCase{
		complaintRepo: complaintRepo,
		userRepo:      userRepo,
		houseRepo:     houseRepo,
	}
}

// GenerateTicketNumber formats: TKT-YYYYMMDD-XXXX (4 alphanumeric random)
func (uc *ComplaintUseCase) GenerateTicketNumber() (string, error) {
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	datePart := time.Now().Format("20060102")

	b := make([]byte, 4)
	for i := range b {
		idx, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			return "", err
		}
		b[i] = charset[idx.Int64()]
	}

	return fmt.Sprintf("TKT-%s-%s", datePart, string(b)), nil
}

func (uc *ComplaintUseCase) CreateComplaint(
	ctx context.Context,
	userID int64,
	title, description, category string,
	photoURL *string,
) (*entity.Complaint, error) {
	title = strings.TrimSpace(title)
	if title == "" {
		return nil, ErrEmptyTitle
	}
	if len(title) > 200 {
		return nil, errors.New("judul pengaduan maksimal 200 karakter")
	}

	description = strings.TrimSpace(description)
	if description == "" {
		return nil, ErrEmptyDescription
	}

	cat := entity.ComplaintCategory(strings.TrimSpace(category))
	if !cat.IsValid() {
		return nil, ErrInvalidCategory
	}

	// Validate user & house association from DB (server authority)
	user, err := uc.userRepo.GetByID(ctx, userID)
	if err != nil || user == nil {
		return nil, ErrUserNotFound
	}
	if user.Status != string(entity.UserStatusActive) {
		return nil, ErrUserInactive
	}
	if user.HouseID == nil || *user.HouseID <= 0 {
		return nil, ErrNoHouseAssociation
	}

	// Generate unique ticket number with collision avoidance
	var ticket string
	for attempts := 0; attempts < 5; attempts++ {
		t, genErr := uc.GenerateTicketNumber()
		if genErr != nil {
			return nil, fmt.Errorf("gagal menghasilkan nomor tiket: %w", genErr)
		}
		existing, checkErr := uc.complaintRepo.GetByTicketNumber(ctx, t)
		if checkErr == nil && existing == nil {
			ticket = t
			break
		}
	}
	if ticket == "" {
		// Fallback with nano suffix
		ticket = fmt.Sprintf("TKT-%s-%d", time.Now().Format("20060102"), time.Now().UnixNano()%10000)
	}

	complaint := &entity.Complaint{
		TicketNumber: ticket,
		UserID:       userID,
		HouseID:      *user.HouseID,
		Title:        title,
		Description:  description,
		Category:     cat,
		PhotoURL:     photoURL,
		Status:       entity.ComplaintStatusMenunggu,
	}

	if err := uc.complaintRepo.Create(ctx, complaint); err != nil {
		return nil, fmt.Errorf("gagal menyimpan data pengaduan: %w", err)
	}

	complaint.ReporterName = user.Name
	if user.House != nil {
		complaint.HouseBlock = user.House.Block
		complaint.HouseNumber = user.House.HouseNumber
	}

	return complaint, nil
}

func (uc *ComplaintUseCase) GetMyComplaints(
	ctx context.Context,
	userID int64,
	page, limit int,
) (*entity.ComplaintListResult, error) {
	if page <= 0 {
		page = 1
	}
	if limit <= 0 {
		limit = 10
	}
	offset := (page - 1) * limit

	complaints, total, err := uc.complaintRepo.ListByUser(ctx, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("gagal mengambil daftar pengaduan: %w", err)
	}

	totalPages := 0
	if total > 0 {
		totalPages = (total + limit - 1) / limit
	}

	return &entity.ComplaintListResult{
		Complaints: complaints,
		Total:      total,
		Page:       page,
		Limit:      limit,
		TotalPages: totalPages,
	}, nil
}

func (uc *ComplaintUseCase) GetComplaintDetail(
	ctx context.Context,
	complaintID, userID int64,
) (*entity.Complaint, error) {
	complaint, err := uc.complaintRepo.GetByID(ctx, complaintID)
	if err != nil {
		return nil, fmt.Errorf("gagal mengambil detail pengaduan: %w", err)
	}
	if complaint == nil {
		return nil, ErrComplaintNotFound
	}

	// US-5.3: Warga hanya boleh mengakses pengaduan miliknya sendiri
	if complaint.UserID != userID {
		return nil, ErrUnauthorizedAccess
	}

	return complaint, nil
}

func (uc *ComplaintUseCase) VerifyPhotoAccess(
	ctx context.Context,
	filename string,
	callerID int64,
	callerRole string,
) (*entity.Complaint, error) {
	filename = strings.TrimSpace(filename)
	if filename == "" {
		return nil, errors.New("nama file tidak valid")
	}

	comp, err := uc.complaintRepo.GetByPhotoFilename(ctx, filename)
	if err != nil {
		return nil, fmt.Errorf("gagal memverifikasi kepemilikan foto: %w", err)
	}
	if comp == nil {
		return nil, ErrComplaintNotFound
	}

	isOwner := (callerID == comp.UserID)
	rClean := strings.ToUpper(strings.TrimSpace(callerRole))
	isLeadership := (rClean == string(entity.RoleAdmin) ||
		rClean == string(entity.RoleChairperson) ||
		rClean == string(entity.RoleViceChairperson) ||
		rClean == string(entity.RoleTreasurer) ||
		rClean == string(entity.RoleSecretary))

	if !isOwner && !isLeadership {
		return nil, ErrUnauthorizedAccess
	}

	return comp, nil
}

// US-5.4 Helper Functions
func isManagementRole(role string) bool {
	r := strings.ToUpper(strings.TrimSpace(role))
	return r == string(entity.RoleAdmin) ||
		r == string(entity.RoleChairperson) ||
		r == string(entity.RoleViceChairperson) ||
		r == string(entity.RoleTreasurer) ||
		r == string(entity.RoleSecretary)
}

func isLeadershipRole(role string) bool {
	r := strings.ToUpper(strings.TrimSpace(role))
	return r == string(entity.RoleAdmin) ||
		r == string(entity.RoleChairperson) ||
		r == string(entity.RoleViceChairperson)
}

// US-5.4: List complaints for management
func (uc *ComplaintUseCase) ListAdminComplaints(
	ctx context.Context,
	callerRole string,
	filter entity.AdminComplaintFilter,
) (*entity.ComplaintListResult, error) {
	if !isManagementRole(callerRole) {
		return nil, ErrUnauthorizedAccess
	}

	if filter.Limit <= 0 {
		filter.Limit = 10
	}
	if filter.Page <= 0 {
		filter.Page = 1
	}

	complaints, total, err := uc.complaintRepo.ListAdmin(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("gagal memuat daftar pengaduan pengelola: %w", err)
	}

	totalPages := 0
	if total > 0 {
		totalPages = (total + filter.Limit - 1) / filter.Limit
	}

	return &entity.ComplaintListResult{
		Complaints: complaints,
		Total:      total,
		Page:       filter.Page,
		Limit:      filter.Limit,
		TotalPages: totalPages,
	}, nil
}

// US-5.4: Kanban board data
func (uc *ComplaintUseCase) GetKanbanComplaints(
	ctx context.Context,
	callerRole string,
	filter entity.AdminComplaintFilter,
) (*entity.KanbanComplaintsResult, error) {
	if !isManagementRole(callerRole) {
		return nil, ErrUnauthorizedAccess
	}

	res, err := uc.complaintRepo.GetKanban(ctx, filter)
	if err != nil {
		return nil, fmt.Errorf("gagal memuat kanban pengaduan: %w", err)
	}
	return res, nil
}

// US-5.4: Detail complaint with assignments for management
func (uc *ComplaintUseCase) GetAdminComplaintDetail(
	ctx context.Context,
	callerRole string,
	id int64,
) (*entity.ComplaintDetailResponse, error) {
	if !isManagementRole(callerRole) {
		return nil, ErrUnauthorizedAccess
	}

	comp, err := uc.complaintRepo.GetByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("gagal memuat detail pengaduan: %w", err)
	}
	if comp == nil {
		return nil, ErrComplaintNotFound
	}

	assignments, err := uc.complaintRepo.GetAssignmentsByComplaintID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("gagal memuat riwayat penugasan: %w", err)
	}

	return &entity.ComplaintDetailResponse{
		Complaint:   *comp,
		Assignments: assignments,
	}, nil
}

// US-5.4: Assign or reassign officer
func (uc *ComplaintUseCase) AssignOfficer(
	ctx context.Context,
	callerID int64,
	callerRole string,
	complaintID int64,
	req entity.AssignComplaintRequest,
) (*entity.ComplaintDetailResponse, error) {
	if !isLeadershipRole(callerRole) {
		return nil, ErrUnauthorizedAccess
	}

	comp, err := uc.complaintRepo.GetByID(ctx, complaintID)
	if err != nil {
		return nil, fmt.Errorf("gagal memverifikasi pengaduan: %w", err)
	}
	if comp == nil {
		return nil, ErrComplaintNotFound
	}

	req.OfficerName = strings.TrimSpace(req.OfficerName)
	if len(req.OfficerName) < 2 {
		return nil, errors.New("nama petugas minimal 2 karakter")
	}

	if req.OfficerUserID != nil && *req.OfficerUserID > 0 {
		user, err := uc.userRepo.GetByID(ctx, *req.OfficerUserID)
		if err != nil || user == nil {
			return nil, errors.New("petugas tidak ditemukan dalam sistem")
		}
		if strings.ToLower(user.Status) != "active" {
			return nil, errors.New("petugas tidak aktif")
		}
	}

	if req.Status != nil && *req.Status != "" {
		st := strings.TrimSpace(*req.Status)
		if st != string(entity.ComplaintStatusMenunggu) &&
			st != string(entity.ComplaintStatusDiproses) &&
			st != string(entity.ComplaintStatusSelesai) &&
			st != string(entity.ComplaintStatusDitolak) {
			return nil, errors.New("status pengaduan tidak valid")
		}
		req.Status = &st
	}

	assignment := entity.ComplaintAssignment{
		ComplaintID:   complaintID,
		OfficerName:   req.OfficerName,
		OfficerUserID: req.OfficerUserID,
		AssignedBy:    callerID,
		Notes:         strings.TrimSpace(req.Notes),
		AssignedAt:    time.Now(),
	}

	if err := uc.complaintRepo.AssignOfficer(ctx, &assignment, req.Status); err != nil {
		return nil, fmt.Errorf("gagal menugaskan petugas: %w", err)
	}

	return uc.GetAdminComplaintDetail(ctx, callerRole, complaintID)
}

// US-5.4: Update complaint status directly
func (uc *ComplaintUseCase) UpdateComplaintStatus(
	ctx context.Context,
	callerRole string,
	complaintID int64,
	newStatus string,
) (*entity.Complaint, error) {
	if !isLeadershipRole(callerRole) {
		return nil, ErrUnauthorizedAccess
	}

	comp, err := uc.complaintRepo.GetByID(ctx, complaintID)
	if err != nil {
		return nil, fmt.Errorf("gagal memverifikasi pengaduan: %w", err)
	}
	if comp == nil {
		return nil, ErrComplaintNotFound
	}

	st := strings.TrimSpace(newStatus)
	if st != string(entity.ComplaintStatusMenunggu) &&
		st != string(entity.ComplaintStatusDiproses) &&
		st != string(entity.ComplaintStatusSelesai) &&
		st != string(entity.ComplaintStatusDitolak) {
		return nil, errors.New("status pengaduan tidak valid")
	}

	if err := uc.complaintRepo.UpdateStatus(ctx, complaintID, entity.ComplaintStatus(st)); err != nil {
		return nil, fmt.Errorf("gagal memperbarui status pengaduan: %w", err)
	}

	comp.Status = entity.ComplaintStatus(st)
	return comp, nil
}

// US-5.4: Get assignment history for audit
func (uc *ComplaintUseCase) GetAssignmentHistory(
	ctx context.Context,
	callerRole string,
	complaintID int64,
) ([]entity.ComplaintAssignment, error) {
	if !isManagementRole(callerRole) {
		return nil, ErrUnauthorizedAccess
	}

	comp, err := uc.complaintRepo.GetByID(ctx, complaintID)
	if err != nil {
		return nil, err
	}
	if comp == nil {
		return nil, ErrComplaintNotFound
	}

	return uc.complaintRepo.GetAssignmentsByComplaintID(ctx, complaintID)
}

// US-5.4: Get eligible officers (active security or internal users)
func (uc *ComplaintUseCase) GetEligibleOfficers(
	ctx context.Context,
	callerRole string,
) ([]entity.User, error) {
	if !isManagementRole(callerRole) {
		return nil, ErrUnauthorizedAccess
	}

	users, err := uc.userRepo.GetAllUsers(ctx, "", "active", "", nil)
	if err != nil {
		return nil, fmt.Errorf("gagal memuat daftar petugas: %w", err)
	}

	var officers []entity.User
	for _, u := range users {
		// Include security personnel or management
		officers = append(officers, u)
	}

	return officers, nil
}

