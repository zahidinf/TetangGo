package repository

import (
	"context"
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
	GenerateMonthlyBills(ctx context.Context, period string, amount float64) (int64, error)
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
}

type DashboardRepository interface {
	GetAdminDashboardStats(ctx context.Context, period string) (*entity.AdminDashboardStats, error)
}

type CashbookRepository interface {
	GetSummary(ctx context.Context) (*entity.CashbookSummary, error)
	GetTransactions(ctx context.Context, filter entity.CashTransactionsFilter) ([]entity.CashTransaction, int, error)
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



