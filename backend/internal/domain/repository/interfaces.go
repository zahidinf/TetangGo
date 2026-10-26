package repository

import (
	"context"
	"errors"
	"time"
	"tetanggo-backend/internal/domain/entity"
)

type UserRepository interface {
	GetByID(ctx context.Context, id int64) (*entity.User, error)
	GetByEmailOrPhone(ctx context.Context, identifier string) (*entity.User, error)
	Create(ctx context.Context, user *entity.User) error
	Update(ctx context.Context, user *entity.User) error
	Delete(ctx context.Context, id int64) error
	UpdateProfile(ctx context.Context, id int64, name, phone string, photoURL *string) error
	GetPendingUsers(ctx context.Context) ([]entity.PendingUser, error)
	UpdateStatus(ctx context.Context, id int64, status string, rejectionReason *string) error
	CountPending(ctx context.Context) (int, error)
	GetUnassignedResidents(ctx context.Context, search string) ([]entity.UnassignedResident, error)
	AssignHouse(ctx context.Context, userID int64, houseID int64, occupantType string) error
	UnassignHouse(ctx context.Context, userID int64, houseID int64) error
	GetOccupantsByHouseID(ctx context.Context, houseID int64) ([]entity.HouseOccupant, error)
	CountOccupantsByHouseID(ctx context.Context, houseID int64) (int, error)
	GetAllUsers(ctx context.Context, search, status, role string, houseID *int64) ([]entity.User, error)
	UpdatePassword(ctx context.Context, id int64, passwordHash string) error
}

type RoleRepository interface {
	GetByName(ctx context.Context, name string) (*entity.Role, error)
	GetAll(ctx context.Context) ([]entity.Role, error)
}

type HouseRepository interface {
	GetAll(ctx context.Context, block, status, search string) ([]entity.House, error)
	GetAvailable(ctx context.Context) ([]entity.House, error)
	GetDistinctBlocks(ctx context.Context) ([]string, error)
	GetByID(ctx context.Context, id int64) (*entity.House, error)
	Create(ctx context.Context, house *entity.House) error
	Update(ctx context.Context, house *entity.House) error
	Delete(ctx context.Context, id int64) error
	BulkDelete(ctx context.Context, ids []int64) (int64, error)
}

type FamilyRepository interface {
	GetByHouseID(ctx context.Context, houseID int64) ([]entity.FamilyMember, error)
	Create(ctx context.Context, member *entity.FamilyMember) error
	Delete(ctx context.Context, id int64, houseID int64) error
}

type VehicleRepository interface {
	GetByHouseID(ctx context.Context, houseID int64) ([]entity.Vehicle, error)
	Create(ctx context.Context, vehicle *entity.Vehicle) error
	Delete(ctx context.Context, id int64, houseID int64) error
}

type BillingRepository interface {
	GetPaymentSettings(ctx context.Context) (*entity.PaymentSetting, error)
	UpdatePaymentSettings(ctx context.Context, s *entity.PaymentSetting) error
	CountPaidOrPendingBillsByPeriod(ctx context.Context, period string) (int, error)
	CountTotalBillsByPeriod(ctx context.Context, period string) (int, error)
	CountAnyPaymentsByPeriod(ctx context.Context, period string) (int, error)
	GetDistinctPaymentAmountsByPeriod(ctx context.Context, period string) ([]float64, error)
	GenerateMonthlyBills(ctx context.Context, period string, amount float64) (int64, error)
	GenerateIndividualBill(ctx context.Context, houseID int64, period string, amount float64) (*entity.Bill, error)
	GetBillsByHouseID(ctx context.Context, houseID int64) ([]entity.Bill, error)
	GetBillsByHouseIDAndPeriod(ctx context.Context, houseID int64, period string) ([]entity.Bill, error)
	GetBillByHouseAndPeriod(ctx context.Context, houseID int64, period string) (*entity.Bill, error)
	CreateBill(ctx context.Context, bill *entity.Bill) error
	GetBillByID(ctx context.Context, billID int64) (*entity.Bill, error)
	CreatePayment(ctx context.Context, p *entity.Payment) error
	UpdateBillStatus(ctx context.Context, billID int64, status string) error
	VerifyPayment(ctx context.Context, billID int64, action string, rejectionReason *string, verifiedBy int64) error
	GetPendingPayments(ctx context.Context) ([]entity.PendingPaymentItem, error)
	GetBillingSummary(ctx context.Context, period string, block string) (*entity.BillingSummaryResponse, error)
	RecordDirectCashPayment(ctx context.Context, billID int64, adminID int64, residentUserID *int64, amount float64, paymentDate time.Time, notes *string) (*entity.Payment, error)
	GetEligiblePeriodsByHouseID(ctx context.Context, houseID int64) ([]entity.EligibleDuesPeriod, error)
	GetEligibleResidentsForBilling(ctx context.Context) ([]entity.ResidentBillingOption, error)
}

type DashboardRepository interface {
	GetAdminDashboardStats(ctx context.Context, period string) (*entity.AdminDashboardStats, error)
}

type CashbookRepository interface {
	GetSummary(ctx context.Context) (*entity.CashbookSummary, error)
	GetTransactions(ctx context.Context, filter entity.CashTransactionsFilter) (*entity.CashTransactionsResult, error)
	GetTransactionByID(ctx context.Context, id int64) (*entity.CashTransaction, error)
	CreateTransaction(ctx context.Context, tx *entity.CashTransaction) error
	DeleteManualTransaction(ctx context.Context, id int64) error
}

type AnnouncementRepository interface {
	GetAll(ctx context.Context, category string, search string) ([]entity.Announcement, error)
	GetByID(ctx context.Context, id int64) (*entity.Announcement, error)
	Create(ctx context.Context, a *entity.Announcement) error
	Update(ctx context.Context, a *entity.Announcement) error
	Delete(ctx context.Context, id int64) error
}

type SecurityRepository interface {
	// Neighborhoods
	GetNeighborhoodByID(ctx context.Context, id int64) (*entity.Neighborhood, error)
	GetAllNeighborhoods(ctx context.Context) ([]entity.Neighborhood, error)
	CreateNeighborhood(ctx context.Context, n *entity.Neighborhood) error

	// Security Users
	GetSecurityUsers(ctx context.Context) ([]entity.User, error)

	// Assignments
	CreateAssignment(ctx context.Context, a *entity.SecurityAssignment) error
	GetAssignmentByID(ctx context.Context, id int64) (*entity.SecurityAssignment, error)
	GetAssignments(ctx context.Context, userID *int64, neighborhoodID *int64, activeOnly *bool) ([]entity.SecurityAssignment, error)
	UpdateAssignmentStatus(ctx context.Context, id int64, isActive bool, notes string) error
	RevokeAssignment(ctx context.Context, id int64, revokedBy int64, notes string) error
	HasActiveAssignmentInNeighborhood(ctx context.Context, userID int64, neighborhoodID int64) (bool, error)
	GetActiveNeighborhoodIDsForUser(ctx context.Context, userID int64) ([]int64, error)
}

var (
	ErrIncidentConflict = errors.New("konflik status insiden: status saat ini tidak mengizinkan aksi ini")
	ErrIncidentNotFound = errors.New("insiden tidak ditemukan")
)

type IncidentRepository interface {
	CreateIncident(ctx context.Context, inc *entity.Incident) error
	CreateIncidentTx(ctx context.Context, inc *entity.Incident, log *entity.IncidentLog) error
	GetIncidentByID(ctx context.Context, id int64) (*entity.Incident, error)
	GetIncidents(ctx context.Context, filter entity.IncidentFilter) (*entity.IncidentListResult, error)
	GetActiveIncidents(ctx context.Context, neighborhoodIDs []int64) ([]entity.Incident, error)
	AcknowledgeIncidentTx(ctx context.Context, incidentID int64, securityID int64, startedAt time.Time, log *entity.IncidentLog) error
	ResolveIncidentTx(ctx context.Context, incidentID int64, actorID int64, resolvedAt time.Time, resolutionNotes string, log *entity.IncidentLog) error
	UpdateIncidentStatus(ctx context.Context, id int64, status string, securityID *int64, startedAt *time.Time, resolvedAt *time.Time, resolutionNotes *string) error
	CreateIncidentLog(ctx context.Context, log *entity.IncidentLog) error
	GetIncidentLogs(ctx context.Context, incidentID int64) ([]entity.IncidentLog, error)
	CountActiveIncidents(ctx context.Context, neighborhoodIDs []int64) (int64, error)
	CorrectIncidentTx(ctx context.Context, incidentID int64, adminID int64, newStatus *string, newCategory *string, newTitle *string, newDescription *string, notes string, log *entity.IncidentLog) (*entity.Incident, error)
}

type IncidentEventPublisher interface {
	PublishIncidentEvent(ctx context.Context, event entity.IncidentRealtimeEvent) error
}

type SecurityDeviceTokenRepository interface {
	UpsertDeviceToken(ctx context.Context, token *entity.SecurityDeviceToken) error
	RevokeDeviceToken(ctx context.Context, userID int64, deviceID string) error
	DeactivateTokenByValue(ctx context.Context, tokenValue string) error
	GetActiveTokensForNeighborhood(ctx context.Context, neighborhoodID int64) ([]entity.SecurityDeviceToken, error)
	GetActiveTokensForUser(ctx context.Context, userID int64) ([]entity.SecurityDeviceToken, error)
}

type PushNotificationService interface {
	SendIncidentPush(ctx context.Context, tokens []entity.SecurityDeviceToken, inc *entity.Incident) error
}

type GuestInvitationRepository interface {
	Create(ctx context.Context, inv *entity.GuestInvitation) error
	GetByID(ctx context.Context, id int64) (*entity.GuestInvitation, error)
	GetByCode(ctx context.Context, code string) (*entity.GuestInvitation, error)
	ListByHostUserID(ctx context.Context, hostUserID int64, limit, offset int) ([]entity.GuestInvitation, int, error)
	Cancel(ctx context.Context, id int64, cancelledBy int64, reason string) error
	ExpireOutdatedInvitations(ctx context.Context) (int64, error)
	CheckIn(ctx context.Context, id int64) error
	Complete(ctx context.Context, id int64) error

	// US-5.2: Visits and Audit Logs
	CreateVisit(ctx context.Context, visit *entity.GuestVisit) error
	GetActiveVisitByInvitationID(ctx context.Context, invitationID int64) (*entity.GuestVisit, error)
	GetVisitByID(ctx context.Context, visitID int64) (*entity.GuestVisit, error)
	CheckOutVisit(ctx context.Context, visitID int64, checkOutBy int64, checkOutAt time.Time, notes *string) error
	ListVisits(ctx context.Context, filter entity.GuestVisitFilter) ([]entity.GuestVisit, int, error)
	ListGroupedVisits(ctx context.Context, filter entity.GuestVisitFilter) ([]entity.GuestVisitGroup, int, error)
	CreateAuditLog(ctx context.Context, log *entity.GuestVisitAuditLog) error
	CountCompletedVisitsByInvitationID(ctx context.Context, invitationID int64) (int, error)
}






