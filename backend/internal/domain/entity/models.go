package entity

import (
	"strings"
	"time"
)

type RoleName string

const (
	RoleAdmin           RoleName = "ADMIN"
	RoleChairperson     RoleName = "CHAIRPERSON"
	RoleViceChairperson RoleName = "VICE_CHAIRPERSON"
	RoleTreasurer       RoleName = "TREASURER"
	RoleSecretary       RoleName = "SECRETARY"
	RoleResident        RoleName = "RESIDENT"
)

// IsValidOrganizationalRole returns true if the role can be assigned/revoked in the organizational flow
func IsValidOrganizationalRole(role string) bool {
	switch RoleName(role) {
	case RoleChairperson, RoleViceChairperson, RoleTreasurer, RoleSecretary, RoleResident:
		return true
	default:
		return false
	}
}

// RoleDisplayName returns the Indonesian display name for a role
func RoleDisplayName(role string) string {
	switch RoleName(role) {
	case RoleAdmin:
		return "Administrator"
	case RoleChairperson:
		return "Ketua"
	case RoleViceChairperson:
		return "Wakil Ketua"
	case RoleTreasurer:
		return "Bendahara"
	case RoleSecretary:
		return "Sekretaris"
	case RoleResident:
		return "Warga"
	default:
		return role
	}
}

type Role struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
}

type HouseStatus string

const (
	HouseStatusMilik   HouseStatus = "milik"
	HouseStatusKontrak HouseStatus = "kontrak"
	HouseStatusKosong  HouseStatus = "kosong"
)

type House struct {
	ID            int64   `json:"id"`
	Block         string  `json:"block"`
	HouseNumber   string  `json:"house_number"`
	Status        string  `json:"status"`
	ResidentName  *string `json:"resident_name,omitempty"`
	ResidentPhone *string `json:"resident_phone,omitempty"`
	FamilyCount   int     `json:"family_count"`
	TotalOccupants int    `json:"total_occupants"`
	VehicleCount  int     `json:"vehicle_count"`
}

type UserStatus string

const (
	UserStatusPending  UserStatus = "pending_verification"
	UserStatusActive   UserStatus = "active"
	UserStatusRejected UserStatus = "rejected"
	UserStatusInactive UserStatus = "inactive"
)

const (
	SalutationBapak = "Bapak"
	SalutationIbu   = "Ibu"
)

// NormalizeSalutation standardizes raw salutation to either 'Bapak' or 'Ibu'.
// Rule A: Map Mba, Mbak, Mama, Mamah (case-insensitive, trimmed) to 'Ibu'.
// Rule B: Map all other values (Pak, Bp, Mas, Kak, empty, unknown) to 'Bapak'.
func NormalizeSalutation(raw string) string {
	trimmed := strings.ToUpper(strings.TrimSpace(raw))
	switch trimmed {
	case "IBU", "MBA", "MBAK", "MAMA", "MAMAH":
		return SalutationIbu
	default:
		return SalutationBapak
	}
}

type User struct {
	ID              int64      `json:"id"`
	Salutation      string     `json:"salutation"`
	Name            string     `json:"name"`
	Phone           string     `json:"phone"`
	Email           string     `json:"email"`
	PasswordHash    string     `json:"-"`
	RoleID          int64      `json:"role_id"`
	RoleName        string     `json:"role"`
	HouseID         *int64     `json:"house_id,omitempty"`
	Status          string     `json:"status"`
	OwnershipStatus string     `json:"ownership_status"`
	RejectionReason *string    `json:"rejection_reason,omitempty"`
	ProfilePhotoURL *string    `json:"profile_photo_url,omitempty"`
	House           *House     `json:"house,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

func (u *User) FullName() string {
	salutation := NormalizeSalutation(u.Salutation)
	trimmedName := strings.TrimSpace(u.Name)
	if trimmedName != "" {
		return salutation + " " + trimmedName
	}
	return salutation
}

type PendingUser struct {
	ID              int64     `json:"id"`
	Salutation      string    `json:"salutation"`
	Name            string    `json:"name"`
	Phone           string    `json:"phone"`
	Email           string    `json:"email"`
	RoleName        string    `json:"role"`
	HouseID         *int64    `json:"house_id,omitempty"`
	HouseBlock      string    `json:"house_block,omitempty"`
	HouseNumber     string    `json:"house_number,omitempty"`
	OwnershipStatus string    `json:"ownership_status"`
	Status          string    `json:"status"`
	CreatedAt       time.Time `json:"created_at"`
}

type FamilyMember struct {
	ID        int64     `json:"id"`
	HouseID   int64     `json:"house_id"`
	Name      string    `json:"name"`
	Relation  string    `json:"relation"` // 'istri', 'anak', 'orang_tua', 'famili', 'lainnya'
	Phone     *string   `json:"phone,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type Vehicle struct {
	ID          int64     `json:"id"`
	HouseID     int64     `json:"house_id"`
	PlateNumber string    `json:"plate_number"`
	VehicleType string    `json:"vehicle_type"` // 'mobil', 'motor'
	BrandModel  *string   `json:"brand_model,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

type UserProfileData struct {
	User          *User          `json:"user"`
	House         *House         `json:"house,omitempty"`
	FamilyMembers []FamilyMember `json:"family_members"`
	Vehicles      []Vehicle      `json:"vehicles"`
}

type HouseOccupant struct {
	ID              int64     `json:"id"`
	Salutation      string    `json:"salutation"`
	Name            string    `json:"name"`
	Phone           string    `json:"phone"`
	Email           string    `json:"email"`
	Role            string    `json:"role"`
	OwnershipStatus string    `json:"ownership_status"`
	CreatedAt       time.Time `json:"created_at"`
}

type HouseOccupantsResponse struct {
	House     *House          `json:"house"`
	Occupants []HouseOccupant `json:"occupants"`
}

type HouseDetailData struct {
	House         *House         `json:"house"`
	HeadOfFamily  *User          `json:"head_of_family,omitempty"`
	TotalMembers  int            `json:"total_members"`
	FamilyMembers []FamilyMember `json:"family_members"`
	Vehicles      []Vehicle      `json:"vehicles"`
}

type UnassignedResident struct {
	ID         int64     `json:"id"`
	Salutation string    `json:"salutation"`
	Name       string    `json:"name"`
	Phone     string    `json:"phone"`
	Email     string    `json:"email"`
	Role      string    `json:"role"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

// Sprint 2: Billing & Payments Entity

type BillStatus string

const (
	BillStatusUnpaid              BillStatus = "unpaid"
	BillStatusPendingVerification BillStatus = "pending_verification"
	BillStatusPaid                BillStatus = "paid"
	BillStatusRejected            BillStatus = "rejected"
)

type PaymentSetting struct {
	ID            int64     `json:"id"`
	BankName      string    `json:"bank_name"`
	AccountNumber string    `json:"account_number"`
	AccountHolder string    `json:"account_holder"`
	MonthlyFee    float64   `json:"monthly_fee"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type Bill struct {
	ID            int64      `json:"id"`
	HouseID       int64      `json:"house_id"`
	BillingPeriod string     `json:"billing_period"` // 'YYYY-MM'
	Amount        float64    `json:"amount"`
	Status        string     `json:"status"`
	CreatedAt     time.Time  `json:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at"`
	House         *House     `json:"house,omitempty"`
	Payment       *Payment   `json:"payment,omitempty"`
}

type Payment struct {
	ID              int64      `json:"id"`
	BillID          int64      `json:"bill_id"`
	UserID          *int64     `json:"user_id,omitempty"`
	SenderBank      *string    `json:"sender_bank,omitempty"`
	SenderName      *string    `json:"sender_name,omitempty"`
	AmountPaid      float64    `json:"amount_paid"`
	ProofImageURL   string     `json:"proof_image_url"`
	Notes           *string    `json:"notes,omitempty"`
	RejectionReason *string    `json:"rejection_reason,omitempty"`
	VerifiedBy      *int64     `json:"verified_by,omitempty"`
	VerifiedByName  *string    `json:"verified_by_name,omitempty"`
	VerifiedAt      *time.Time `json:"verified_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

type PendingPaymentItem struct {
	BillID        int64      `json:"bill_id"`
	PaymentID     int64      `json:"payment_id"`
	HouseID       int64      `json:"house_id"`
	HouseBlock    string     `json:"house_block"`
	HouseNumber   string     `json:"house_number"`
	ResidentName  string     `json:"resident_name"`
	ResidentPhone string     `json:"resident_phone"`
	BillingPeriod string     `json:"billing_period"`
	BillAmount    float64    `json:"bill_amount"`
	AmountPaid    float64    `json:"amount_paid"`
	SenderBank    string     `json:"sender_bank"`
	SenderName    string     `json:"sender_name"`
	ProofImageURL string     `json:"proof_image_url"`
	Notes         string     `json:"notes"`
	CreatedAt     time.Time  `json:"created_at"`
}

type HouseBillStatus struct {
	HouseID       int64      `json:"house_id"`
	Block         string     `json:"block"`
	HouseNumber   string     `json:"house_number"`
	ResidentName  string     `json:"resident_name"`
	ResidentPhone string     `json:"resident_phone"`
	Status        string     `json:"status"` // 'unpaid', 'pending_verification', 'paid', 'rejected', 'no_bill'
	BillID        *int64     `json:"bill_id,omitempty"`
	Amount        float64    `json:"amount"`
	PaidAt        *time.Time `json:"paid_at,omitempty"`
	ProofImageURL *string    `json:"proof_image_url,omitempty"`
}

type BillingSummaryResponse struct {
	Period            string            `json:"period"`
	Block             string            `json:"block,omitempty"`
	TotalHouses       int               `json:"total_houses"`
	PaidHouses        int               `json:"paid_houses"`
	UnpaidHouses      int               `json:"unpaid_houses"`
	TotalPaidHouses   int               `json:"total_paid_houses"`
	TotalUnpaidHouses int               `json:"total_unpaid_houses"`
	TotalPaidAmount   float64           `json:"total_paid_amount"`
	TotalUnpaidAmount float64           `json:"total_unpaid_amount"`
	HouseBills        []HouseBillStatus `json:"house_bills"`
	Items             []HouseBillStatus `json:"items"`
}

// Sprint 2: Admin Dashboard Stats Entity
type DashboardRecentActivity struct {
	ID           int64     `json:"id"`
	ResidentName string    `json:"resident_name"`
	Block        string    `json:"block"`
	HouseNumber  string    `json:"house_number"`
	AmountPaid   float64   `json:"amount_paid"`
	Status       string    `json:"status"`
	CreatedAt    time.Time `json:"created_at"`
}

type AdminDashboardStats struct {
	TotalHouses          int                       `json:"total_houses"`
	OccupiedHouses       int                       `json:"occupied_houses"`
	EmptyHouses          int                       `json:"empty_houses"`
	TotalResidents       int                       `json:"total_residents"`
	PendingResidents     int                       `json:"pending_residents"`
	CurrentPeriod        string                    `json:"current_period"`
	CollectedAmount      float64                   `json:"collected_amount"`
	TargetAmount         float64                   `json:"target_amount"`
	PendingPaymentsCount int                       `json:"pending_payments_count"`
	RecentActivities     []DashboardRecentActivity `json:"recent_activities"`
}

// Sprint 3: Cashbook (Buku Kas Lingkungan) & Announcements

type CashTransaction struct {
	ID              int64     `json:"id"`
	Type            string    `json:"type"` // 'income' atau 'expense'
	Category        string    `json:"category"`
	Amount          float64   `json:"amount"`
	TransactionDate string    `json:"transaction_date"` // 'YYYY-MM-DD'
	Description     string    `json:"description"`
	ProofImageURL   *string   `json:"proof_image_url,omitempty"`
	BillID          *int64    `json:"bill_id,omitempty"`
	CreatedBy       *int64    `json:"created_by,omitempty"`
	CreatorName     string    `json:"creator_name,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
}

type MonthlyCashFlow struct {
	Month   string  `json:"month"` // 'YYYY-MM'
	Income  float64 `json:"income"`
	Expense float64 `json:"expense"`
}

type CashbookSummary struct {
	CurrentBalance float64           `json:"current_balance"`
	TotalIncome    float64           `json:"total_income"`
	TotalExpense   float64           `json:"total_expense"`
	MonthlySummary []MonthlyCashFlow `json:"monthly_summary"`
}

type CashTransactionsFilter struct {
	Type      string
	Category  string
	StartDate string
	EndDate   string
	Page      int
	Limit     int
}

type Announcement struct {
	ID         int64     `json:"id"`
	Title      string    `json:"title"`
	Content    string    `json:"content"`
	Category   string    `json:"category"` // 'biasa', 'penting', 'darurat'
	ImageURL   *string   `json:"image_url,omitempty"`
	IsPinned   bool      `json:"is_pinned"`
	AuthorID   *int64    `json:"author_id,omitempty"`
	AuthorName string    `json:"author_name,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}



