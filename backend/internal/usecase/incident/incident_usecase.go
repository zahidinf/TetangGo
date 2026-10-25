package incident

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
)

var (
	ErrIncidentNotFound             = errors.New("insiden tidak ditemukan")
	ErrInvalidCategory              = errors.New("kategori insiden tidak valid (pilihan: KEJAHATAN, KEBAKARAN, MEDIS)")
	ErrInvalidCoordinates           = errors.New("koordinat lokasi tidak valid")
	ErrUserInactive                 = errors.New("akun pengguna sedang tidak aktif")
	ErrNoActiveSecurityAssignment   = errors.New("akses ditolak: petugas keamanan tidak memiliki penugasan aktif")
	ErrIncidentAccessForbidden      = errors.New("akses ditolak: Anda tidak memiliki akses ke insiden di lingkungan ini")
	ErrIncidentAlreadyAcknowledged  = errors.New("insiden sudah diakui atau sedang ditangani petugas lain")
	ErrIncidentAlreadyResolved      = errors.New("insiden sudah selesai ditangani sebelumnya")
	ErrIncidentAlreadyHandled       = errors.New("insiden sudah selesai atau dibatalkan")
	ErrInvalidStatusTransition      = errors.New("perubahan status insiden tidak valid")
	ErrSecurityNotAssignedToComplex = errors.New("petugas tidak ditugaskan pada lingkungan insiden ini")
	ErrCannotModifyOthersIncident   = errors.New("warga tidak dapat mengubah insiden orang lain")
)

type ReportIncidentInput struct {
	Category         string   `json:"category"`
	Title            string   `json:"title"`
	Description      string   `json:"description"`
	NeighborhoodID   *int64   `json:"neighborhood_id,omitempty"`
	Latitude         *float64 `json:"latitude,omitempty"`
	Longitude        *float64 `json:"longitude,omitempty"`
	LocationSource   *string  `json:"location_source,omitempty"`
	LocationAccuracy *float64 `json:"location_accuracy,omitempty"`
}

type AcknowledgeIncidentInput struct {
	Notes string `json:"notes,omitempty"`
}

type ResolveIncidentInput struct {
	ResolutionNotes string `json:"resolution_notes"`
}

type IncidentUseCase struct {
	incRepo   repository.IncidentRepository
	secRepo   repository.SecurityRepository
	userRepo  repository.UserRepository
	houseRepo repository.HouseRepository
	publisher repository.IncidentEventPublisher
	tokenRepo repository.SecurityDeviceTokenRepository
	pushService repository.PushNotificationService
}

func NewIncidentUseCase(
	incRepo repository.IncidentRepository,
	secRepo repository.SecurityRepository,
	userRepo repository.UserRepository,
	houseRepo repository.HouseRepository,
) *IncidentUseCase {
	return &IncidentUseCase{
		incRepo:   incRepo,
		secRepo:   secRepo,
		userRepo:  userRepo,
		houseRepo: houseRepo,
	}
}

func (uc *IncidentUseCase) SetPushNotification(tokenRepo repository.SecurityDeviceTokenRepository, pushService repository.PushNotificationService) {
	uc.tokenRepo = tokenRepo
	uc.pushService = pushService
}

func (uc *IncidentUseCase) SetPublisher(p repository.IncidentEventPublisher) {
	uc.publisher = p
}

func (uc *IncidentUseCase) isLeadership(role string) bool {
	switch entity.RoleName(role) {
	case entity.RoleAdmin, entity.RoleChairperson, entity.RoleViceChairperson:
		return true
	default:
		return false
	}
}

func (uc *IncidentUseCase) isPengurusOrAdmin(role string) bool {
	switch entity.RoleName(role) {
	case entity.RoleAdmin, entity.RoleChairperson, entity.RoleViceChairperson, entity.RoleTreasurer, entity.RoleSecretary:
		return true
	default:
		return false
	}
}

func (uc *IncidentUseCase) ReportIncident(ctx context.Context, reporterID int64, input ReportIncidentInput) (*entity.Incident, error) {
	user, err := uc.userRepo.GetByID(ctx, reporterID)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, errors.New("pelapor tidak ditemukan")
	}
	if user.Status != string(entity.UserStatusActive) {
		return nil, ErrUserInactive
	}

	categoryUpper := strings.ToUpper(strings.TrimSpace(input.Category))
	if !entity.IsValidIncidentCategory(categoryUpper) {
		return nil, ErrInvalidCategory
	}

	description := strings.TrimSpace(input.Description)
	if description == "" {
		return nil, errors.New("deskripsi insiden wajib diisi")
	}

	if input.Latitude != nil {
		lat := *input.Latitude
		if lat < -90 || lat > 90 {
			return nil, ErrInvalidCoordinates
		}
	}
	if input.Longitude != nil {
		lon := *input.Longitude
		if lon < -180 || lon > 180 {
			return nil, ErrInvalidCoordinates
		}
	}
	if input.LocationAccuracy != nil && *input.LocationAccuracy < 0 {
		return nil, errors.New("akurasi lokasi tidak valid")
	}

	title := strings.TrimSpace(input.Title)
	if title == "" {
		title = fmt.Sprintf("Laporan %s", categoryUpper)
	}

	// Resolve neighborhood and house from user profile or house
	var neighborhoodID int64 = 1 // Default neighborhood ID
	var houseID *int64 = user.HouseID

	if input.NeighborhoodID != nil && *input.NeighborhoodID > 0 {
		n, err := uc.secRepo.GetNeighborhoodByID(ctx, *input.NeighborhoodID)
		if err == nil && n != nil {
			neighborhoodID = n.ID
		}
	} else if houseID != nil {
		house, err := uc.houseRepo.GetByID(ctx, *houseID)
		if err == nil && house != nil && house.NeighborhoodID != nil {
			neighborhoodID = *house.NeighborhoodID
		}
	}

	inc := &entity.Incident{
		Category:         categoryUpper,
		ReporterID:       reporterID,
		HouseID:          houseID,
		NeighborhoodID:   neighborhoodID,
		Title:            title,
		Description:      description,
		Latitude:         input.Latitude,
		Longitude:        input.Longitude,
		LocationSource:   input.LocationSource,
		LocationAccuracy: input.LocationAccuracy,
		Status:           string(entity.IncidentStatusActive),
	}

	incidentLog := &entity.IncidentLog{
		UserID:    reporterID,
		Action:    "CREATED",
		NewStatus: string(entity.IncidentStatusActive),
		Notes:     "Laporan insiden darurat dibuat oleh pelapor",
	}

	if err := uc.incRepo.CreateIncidentTx(ctx, inc, incidentLog); err != nil {
		return nil, fmt.Errorf("gagal membuat insiden: %w", err)
	}

	created, err := uc.incRepo.GetIncidentByID(ctx, inc.ID)
	if err != nil {
		return nil, err
	}

	if uc.publisher != nil && created != nil {
		event := entity.NewIncidentRealtimeEvent(entity.IncidentEventTypeCreated, created, "")
		_ = uc.publisher.PublishIncidentEvent(ctx, event)
	}

	// Fallback Push Notification via FCM to authorized security devices in this neighborhood
	if uc.pushService != nil && uc.tokenRepo != nil && created != nil {
		go func(inc *entity.Incident) {
			tokens, err := uc.tokenRepo.GetActiveTokensForNeighborhood(context.Background(), inc.NeighborhoodID)
			if err != nil {
				log.Printf("[FCM] Failed fetching active security tokens for neighborhood %d: %v", inc.NeighborhoodID, err)
				return
			}
			if len(tokens) > 0 {
				_ = uc.pushService.SendIncidentPush(context.Background(), tokens, inc)
			}
		}(created)
	}

	return created, nil
}

func (uc *IncidentUseCase) GetActiveIncidentsForSecurity(ctx context.Context, securityID int64) ([]entity.Incident, error) {
	user, err := uc.userRepo.GetByID(ctx, securityID)
	if err != nil {
		return nil, err
	}
	if user == nil || user.Status != string(entity.UserStatusActive) {
		return nil, ErrUserInactive
	}
	if user.RoleName != string(entity.RoleSecurity) {
		return nil, ErrIncidentAccessForbidden
	}

	activeNIDs, err := uc.secRepo.GetActiveNeighborhoodIDsForUser(ctx, securityID)
	if err != nil {
		return nil, err
	}
	if len(activeNIDs) == 0 {
		return nil, ErrNoActiveSecurityAssignment
	}

	return uc.incRepo.GetActiveIncidents(ctx, activeNIDs)
}

func (uc *IncidentUseCase) GetIncidents(ctx context.Context, callerID int64, callerRole string, filter entity.IncidentFilter) (*entity.IncidentListResult, error) {
	user, err := uc.userRepo.GetByID(ctx, callerID)
	if err != nil {
		return nil, err
	}
	if user == nil || user.Status != string(entity.UserStatusActive) {
		return nil, ErrUserInactive
	}

	if callerRole == string(entity.RoleSecurity) {
		activeNIDs, err := uc.secRepo.GetActiveNeighborhoodIDsForUser(ctx, callerID)
		if err != nil {
			return nil, err
		}
		if len(activeNIDs) == 0 {
			return nil, ErrNoActiveSecurityAssignment
		}

		if filter.NeighborhoodID != nil {
			allowed := false
			for _, nid := range activeNIDs {
				if nid == *filter.NeighborhoodID {
					allowed = true
					break
				}
			}
			if !allowed {
				return nil, ErrIncidentAccessForbidden
			}
		} else {
			filter.NeighborhoodIDs = activeNIDs
		}
	} else if uc.isPengurusOrAdmin(callerRole) {
		// Leadership & Pengurus (Admin, Chairperson, Vice Chairperson, Treasurer, Secretary) can monitor all incidents in neighborhood/system
		if filter.NeighborhoodID == nil && user.HouseID != nil {
			house, err := uc.houseRepo.GetByID(ctx, *user.HouseID)
			if err == nil && house != nil && house.NeighborhoodID != nil {
				filter.NeighborhoodID = house.NeighborhoodID
			}
		}
	} else {
		// Non-pengurus resident (Warga):
		// - Only sees ACTIVE or RESPONDING incidents (Dilaporkan & Sedang Ditangani).
		// - Cannot view Terkendali (RESOLVED) even if requested in filter.
		// - Scoped to resident's neighborhood or own reports.
		filter.Statuses = []string{string(entity.IncidentStatusActive), string(entity.IncidentStatusResponding)}
		filter.Status = ""

		if user.HouseID != nil {
			house, err := uc.houseRepo.GetByID(ctx, *user.HouseID)
			if err == nil && house != nil && house.NeighborhoodID != nil {
				filter.NeighborhoodID = house.NeighborhoodID
			}
		} else {
			filter.ReporterID = &callerID
		}
	}

	return uc.incRepo.GetIncidents(ctx, filter)
}

func (uc *IncidentUseCase) GetIncidentDetail(ctx context.Context, callerID int64, callerRole string, incidentID int64) (*entity.Incident, error) {
	user, err := uc.userRepo.GetByID(ctx, callerID)
	if err != nil {
		return nil, err
	}
	if user == nil || user.Status != string(entity.UserStatusActive) {
		return nil, ErrUserInactive
	}

	inc, err := uc.incRepo.GetIncidentByID(ctx, incidentID)
	if err != nil {
		return nil, err
	}
	if inc == nil {
		return nil, ErrIncidentNotFound
	}

	if callerRole == string(entity.RoleSecurity) {
		hasActive, err := uc.secRepo.HasActiveAssignmentInNeighborhood(ctx, callerID, inc.NeighborhoodID)
		if err != nil {
			return nil, err
		}
		if !hasActive {
			return nil, ErrIncidentAccessForbidden
		}
	} else if uc.isPengurusOrAdmin(callerRole) {
		// Leadership & Pengurus has full monitoring access to any incident
	} else {
		// Non-leadership accounts (Resident):
		// Existing capability: reporter can view detail and logs of their own report.
		// Other residents cannot view Terkendali (RESOLVED) incidents, and can only view active incidents in their neighborhood/house.
		isReporter := inc.ReporterID == callerID
		if !isReporter {
			if inc.Status == string(entity.IncidentStatusResolved) {
				return nil, ErrIncidentAccessForbidden
			}

			isHouseMember := user.HouseID != nil && inc.HouseID != nil && *user.HouseID == *inc.HouseID
			isSameNeighborhood := false
			if user.HouseID != nil {
				house, err := uc.houseRepo.GetByID(ctx, *user.HouseID)
				if err == nil && house != nil && house.NeighborhoodID != nil && *house.NeighborhoodID == inc.NeighborhoodID {
					isSameNeighborhood = true
				}
			}

			if !isHouseMember && !isSameNeighborhood {
				return nil, ErrIncidentAccessForbidden
			}
		}
	}

	return inc, nil
}

func (uc *IncidentUseCase) AcknowledgeIncident(ctx context.Context, securityID int64, incidentID int64, notes string) (*entity.Incident, error) {
	user, err := uc.userRepo.GetByID(ctx, securityID)
	if err != nil {
		return nil, err
	}
	if user == nil || user.Status != string(entity.UserStatusActive) {
		return nil, ErrUserInactive
	}
	if user.RoleName != string(entity.RoleSecurity) {
		return nil, errors.New("hanya petugas keamanan yang dapat mengakui atau mengambil penanganan insiden")
	}

	inc, err := uc.incRepo.GetIncidentByID(ctx, incidentID)
	if err != nil {
		return nil, err
	}
	if inc == nil {
		return nil, ErrIncidentNotFound
	}

	// Verify security assignment
	hasActive, err := uc.secRepo.HasActiveAssignmentInNeighborhood(ctx, securityID, inc.NeighborhoodID)
	if err != nil {
		return nil, err
	}
	if !hasActive {
		return nil, ErrSecurityNotAssignedToComplex
	}

	// Validate status transition
	if inc.Status == string(entity.IncidentStatusAcknowledged) || inc.Status == string(entity.IncidentStatusResponding) {
		return nil, ErrIncidentAlreadyAcknowledged
	}
	if inc.Status == string(entity.IncidentStatusResolved) || inc.Status == string(entity.IncidentStatusCancelled) {
		return nil, ErrIncidentAlreadyHandled
	}
	if inc.Status != string(entity.IncidentStatusActive) && inc.Status != string(entity.IncidentStatusReported) {
		return nil, ErrInvalidStatusTransition
	}

	cleanNotes := strings.TrimSpace(notes)
	if cleanNotes == "" {
		cleanNotes = fmt.Sprintf("Petugas keamanan %s mengambil penanganan insiden", user.Name)
	}

	now := time.Now()
	log := &entity.IncidentLog{
		IncidentID: incidentID,
		UserID:     securityID,
		Action:     "ACKNOWLEDGED",
		Notes:      cleanNotes,
	}

	err = uc.incRepo.AcknowledgeIncidentTx(ctx, incidentID, securityID, now, log)
	if err != nil {
		if errors.Is(err, repository.ErrIncidentConflict) {
			return nil, ErrIncidentAlreadyAcknowledged
		}
		return nil, err
	}

	acknowledged, err := uc.incRepo.GetIncidentByID(ctx, incidentID)
	if err != nil {
		return nil, err
	}

	if uc.publisher != nil && acknowledged != nil {
		event := entity.NewIncidentRealtimeEvent(entity.IncidentEventTypeAcknowledged, acknowledged, inc.Status)
		_ = uc.publisher.PublishIncidentEvent(ctx, event)
	}

	return acknowledged, nil
}

// RespondIncident maintains backward compatibility with US-4.1
func (uc *IncidentUseCase) RespondIncident(ctx context.Context, securityID int64, incidentID int64) (*entity.Incident, error) {
	return uc.AcknowledgeIncident(ctx, securityID, incidentID, "")
}

func (uc *IncidentUseCase) ResolveIncident(ctx context.Context, actorID int64, actorRole string, incidentID int64, resolutionNotes string) (*entity.Incident, error) {
	user, err := uc.userRepo.GetByID(ctx, actorID)
	if err != nil {
		return nil, err
	}
	if user == nil || user.Status != string(entity.UserStatusActive) {
		return nil, ErrUserInactive
	}

	inc, err := uc.incRepo.GetIncidentByID(ctx, incidentID)
	if err != nil {
		return nil, err
	}
	if inc == nil {
		return nil, ErrIncidentNotFound
	}

	if actorRole == string(entity.RoleResident) {
		return nil, ErrCannotModifyOthersIncident
	}

	if actorRole == string(entity.RoleSecurity) {
		hasActive, err := uc.secRepo.HasActiveAssignmentInNeighborhood(ctx, actorID, inc.NeighborhoodID)
		if err != nil || !hasActive {
			return nil, ErrIncidentAccessForbidden
		}
	} else if !uc.isLeadership(actorRole) {
		return nil, ErrIncidentAccessForbidden
	}

	if inc.Status == string(entity.IncidentStatusResolved) {
		return nil, ErrIncidentAlreadyResolved
	}
	if inc.Status == string(entity.IncidentStatusCancelled) {
		return nil, ErrIncidentAlreadyHandled
	}

	cleanNotes := strings.TrimSpace(resolutionNotes)
	if cleanNotes == "" {
		return nil, errors.New("catatan akhir penyelesaian wajib diisi")
	}

	now := time.Now()
	log := &entity.IncidentLog{
		IncidentID: incidentID,
		UserID:     actorID,
		Action:     "RESOLVED",
		Notes:      cleanNotes,
	}

	err = uc.incRepo.ResolveIncidentTx(ctx, incidentID, actorID, now, cleanNotes, log)
	if err != nil {
		if errors.Is(err, repository.ErrIncidentConflict) {
			return nil, ErrIncidentAlreadyResolved
		}
		return nil, err
	}

	resolved, err := uc.incRepo.GetIncidentByID(ctx, incidentID)
	if err != nil {
		return nil, err
	}

	if uc.publisher != nil && resolved != nil {
		event := entity.NewIncidentRealtimeEvent(entity.IncidentEventTypeResolved, resolved, inc.Status)
		_ = uc.publisher.PublishIncidentEvent(ctx, event)
	}

	return resolved, nil
}

func (uc *IncidentUseCase) GetIncidentLogs(ctx context.Context, callerID int64, callerRole string, incidentID int64) ([]entity.IncidentLog, error) {
	_, err := uc.GetIncidentDetail(ctx, callerID, callerRole, incidentID)
	if err != nil {
		return nil, err
	}

	return uc.incRepo.GetIncidentLogs(ctx, incidentID)
}

func (uc *IncidentUseCase) GetActiveIncidentCount(ctx context.Context, callerID int64, callerRole string) (int64, error) {
	user, err := uc.userRepo.GetByID(ctx, callerID)
	if err != nil {
		return 0, err
	}
	if user == nil || user.Status != string(entity.UserStatusActive) {
		return 0, ErrUserInactive
	}

	var nIDs []int64
	if callerRole == string(entity.RoleSecurity) {
		activeNIDs, err := uc.secRepo.GetActiveNeighborhoodIDsForUser(ctx, callerID)
		if err != nil {
			return 0, err
		}
		if len(activeNIDs) == 0 {
			return 0, nil
		}
		nIDs = activeNIDs
	} else if user.HouseID != nil {
		house, err := uc.houseRepo.GetByID(ctx, *user.HouseID)
		if err == nil && house != nil && house.NeighborhoodID != nil {
			nIDs = []int64{*house.NeighborhoodID}
		}
	}

	return uc.incRepo.CountActiveIncidents(ctx, nIDs)
}

type CorrectIncidentInput struct {
	Status      *string `json:"status"`
	Category    *string `json:"category"`
	Title       *string `json:"title"`
	Description *string `json:"description"`
	Notes       string  `json:"notes"`
}

func (uc *IncidentUseCase) CorrectIncident(ctx context.Context, adminID int64, callerRole string, incidentID int64, input CorrectIncidentInput) (*entity.Incident, error) {
	if entity.RoleName(callerRole) != entity.RoleAdmin {
		return nil, ErrIncidentAccessForbidden
	}

	user, err := uc.userRepo.GetByID(ctx, adminID)
	if err != nil {
		return nil, err
	}
	if user == nil || user.Status != string(entity.UserStatusActive) {
		return nil, ErrUserInactive
	}

	existing, err := uc.incRepo.GetIncidentByID(ctx, incidentID)
	if err != nil {
		return nil, err
	}
	if existing == nil {
		return nil, ErrIncidentNotFound
	}

	notes := strings.TrimSpace(input.Notes)
	if notes == "" {
		return nil, errors.New("catatan koreksi wajib diisi untuk audit trail")
	}

	if input.Category != nil && strings.TrimSpace(*input.Category) != "" {
		cat := strings.ToUpper(strings.TrimSpace(*input.Category))
		if !entity.IsValidIncidentCategory(cat) {
			return nil, ErrInvalidCategory
		}
	}

	if input.Status != nil && strings.TrimSpace(*input.Status) != "" {
		st := strings.ToUpper(strings.TrimSpace(*input.Status))
		switch st {
		case "ACTIVE", "REPORTED", "DILAPORKAN":
			// ok
		case "RESPONDING", "ACKNOWLEDGED", "SEDANG DITANGANI":
			// ok
		case "RESOLVED", "TERKENDALI":
			// ok
		default:
			return nil, errors.New("status kejadian tidak valid")
		}
	}

	var auditLog entity.IncidentLog
	auditLog.Notes = notes

	updated, err := uc.incRepo.CorrectIncidentTx(
		ctx,
		incidentID,
		adminID,
		input.Status,
		input.Category,
		input.Title,
		input.Description,
		notes,
		&auditLog,
	)
	if err != nil {
		return nil, err
	}

	if uc.publisher != nil && updated != nil {
		evt := entity.NewIncidentRealtimeEvent(entity.IncidentEventTypeCorrected, updated, existing.Status)
		_ = uc.publisher.PublishIncidentEvent(ctx, evt)
	}

	return updated, nil
}
