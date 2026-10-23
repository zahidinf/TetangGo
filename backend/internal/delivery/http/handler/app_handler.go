package handler

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/usecase/announcement"
	"tetanggo-backend/internal/usecase/auth"
	"tetanggo-backend/internal/usecase/billing"
	"tetanggo-backend/internal/usecase/cashbook"
	"tetanggo-backend/internal/usecase/dashboard"
	"tetanggo-backend/internal/usecase/house"
	"tetanggo-backend/internal/usecase/profile"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type AppHandler struct {
	db                  *sql.DB
	authUseCase         *auth.AuthUseCase
	houseUseCase        *house.HouseUseCase
	profileUseCase      *profile.ProfileUseCase
	billingUseCase      *billing.BillingUseCase
	dashboardUseCase    *dashboard.DashboardUseCase
	cashbookUseCase     *cashbook.CashbookUseCase
	announcementUseCase *announcement.AnnouncementUseCase
}

func NewAppHandler(
	db *sql.DB,
	authUseCase *auth.AuthUseCase,
	houseUseCase *house.HouseUseCase,
	profileUseCase *profile.ProfileUseCase,
	billingUseCase *billing.BillingUseCase,
	dashboardUseCase *dashboard.DashboardUseCase,
	cashbookUseCase *cashbook.CashbookUseCase,
	announcementUseCase *announcement.AnnouncementUseCase,
) *AppHandler {
	return &AppHandler{
		db:                  db,
		authUseCase:         authUseCase,
		houseUseCase:        houseUseCase,
		profileUseCase:      profileUseCase,
		billingUseCase:      billingUseCase,
		dashboardUseCase:    dashboardUseCase,
		cashbookUseCase:     cashbookUseCase,
		announcementUseCase: announcementUseCase,
	}
}

// GET /health
func (h *AppHandler) HealthCheck(c *fiber.Ctx) error {
	dbStatus := "connected"
	if err := h.db.Ping(); err != nil {
		dbStatus = "disconnected: " + err.Error()
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"app":      "TetangGo API",
		"tagline":  "Tetangga Kompak, Lingkungan Terjaga",
		"status":   "healthy",
		"database": dbStatus,
	})
}

// ----------------------------------------------------
// AUTH ENDPOINTS
// ----------------------------------------------------

// POST /api/v1/auth/login
func (h *AppHandler) Login(c *fiber.Ctx) error {
	var input auth.LoginInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload JSON tidak valid",
		})
	}

	res, err := h.authUseCase.Login(c.Context(), input)
	if err != nil {
		status := fiber.StatusUnauthorized
		if err == auth.ErrAccountInactive {
			status = fiber.StatusForbidden
		}
		return c.Status(status).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Login berhasil",
		"data":    res,
	})
}

// POST /api/v1/auth/register
func (h *AppHandler) Register(c *fiber.Ctx) error {
	var input auth.RegisterInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload JSON pendaftaran tidak valid",
		})
	}

	user, err := h.authUseCase.Register(c.Context(), input)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Pendaftaran berhasil, menunggu verifikasi pengurus RT",
		"data":    user,
	})
}

// ----------------------------------------------------
// PUBLIC ENDPOINTS
// ----------------------------------------------------

// GET /api/v1/public/houses-available
func (h *AppHandler) GetAvailableHouses(c *fiber.Ctx) error {
	houses, err := h.houseUseCase.GetAvailableHouses(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal mengambil daftar rumah tersedia",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Daftar rumah berhasil dimuat",
		"data":    houses,
	})
}

// ----------------------------------------------------
// ADMIN RT ENDPOINTS
// ----------------------------------------------------

// GET /api/v1/admin/pending-users
func (h *AppHandler) GetPendingUsers(c *fiber.Ctx) error {
	users, err := h.authUseCase.GetPendingUsers(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal memuat antrean verifikasi warga",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Antrean verifikasi warga berhasil dimuat",
		"data":    users,
	})
}

// POST /api/v1/admin/users/:id/approve
func (h *AppHandler) ApproveUser(c *fiber.Ctx) error {
	idParam := c.Params("id")
	userID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID pengguna tidak valid",
		})
	}

	if err := h.authUseCase.ApproveUser(c.Context(), userID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Warga berhasil diverifikasi dan disetujui",
	})
}

// POST /api/v1/admin/users/:id/reject
func (h *AppHandler) RejectUser(c *fiber.Ctx) error {
	idParam := c.Params("id")
	userID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID pengguna tidak valid",
		})
	}

	var input auth.RejectInput
	_ = c.BodyParser(&input)

	if err := h.authUseCase.RejectUser(c.Context(), userID, input.Reason); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Pendaftaran warga berhasil ditolak",
	})
}

// GET /api/v1/admin/users
func (h *AppHandler) AdminGetAllUsers(c *fiber.Ctx) error {
	search := c.Query("search")
	status := c.Query("status")
	role := c.Query("role")
	houseIDParam := c.Query("house_id")

	var houseID *int64
	if houseIDParam != "" {
		if id, err := strconv.ParseInt(houseIDParam, 10, 64); err == nil {
			houseID = &id
		}
	}

	users, err := h.authUseCase.AdminGetAllUsers(c.Context(), search, status, role, houseID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal memuat data warga: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Daftar warga berhasil dimuat",
		"data":    users,
	})
}

// POST /api/v1/admin/users
func (h *AppHandler) AdminCreateUser(c *fiber.Ctx) error {
	callerRole := getUserRoleFromLocals(c)
	var input auth.AdminCreateUserInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload pendaftaran warga tidak valid",
		})
	}

	user, err := h.authUseCase.AdminCreateUser(c.Context(), callerRole, input)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Warga baru berhasil ditambahkan",
		"data":    user,
	})
}

// PUT /api/v1/admin/users/:id
func (h *AppHandler) AdminUpdateUser(c *fiber.Ctx) error {
	callerID, _ := getUserIDFromLocals(c)
	callerRole := getUserRoleFromLocals(c)

	idParam := c.Params("id")
	userID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID pengguna tidak valid",
		})
	}

	var input auth.AdminUpdateUserInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload pembaruan warga tidak valid",
		})
	}

	user, err := h.authUseCase.AdminUpdateUser(c.Context(), callerID, callerRole, userID, input)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Data warga berhasil diperbarui",
		"data":    user,
	})
}

// DELETE /api/v1/admin/users/:id
func (h *AppHandler) AdminDeleteUser(c *fiber.Ctx) error {
	callerID, _ := getUserIDFromLocals(c)
	callerRole := getUserRoleFromLocals(c)

	idParam := c.Params("id")
	userID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID pengguna tidak valid",
		})
	}

	if err := h.authUseCase.AdminDeleteUser(c.Context(), callerID, callerRole, userID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Akun warga berhasil dihapus",
	})
}

// POST /api/v1/admin/users/:id/reset-password
func (h *AppHandler) AdminResetPassword(c *fiber.Ctx) error {
	callerRole := getUserRoleFromLocals(c)

	idParam := c.Params("id")
	userID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID pengguna tidak valid",
		})
	}

	var input auth.AdminResetPasswordInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload reset password tidak valid",
		})
	}

	if err := h.authUseCase.AdminResetPassword(c.Context(), callerRole, userID, input.NewPassword); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Kata sandi warga berhasil direset",
	})
}

type AssignRoleInput struct {
	Role string `json:"role"`
}

// PUT /api/v1/admin/users/:id/role
func (h *AppHandler) AdminAssignRole(c *fiber.Ctx) error {
	callerID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Sesi tidak valid",
		})
	}
	callerRole := getUserRoleFromLocals(c)

	idParam := c.Params("id")
	targetUserID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID pengguna tidak valid",
		})
	}

	var input AssignRoleInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload penugasan peran tidak valid",
		})
	}

	updatedUser, err := h.authUseCase.AdminAssignRole(c.Context(), callerID, callerRole, targetUserID, input.Role)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	displayRole := entity.RoleDisplayName(updatedUser.RoleName)
	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": fmt.Sprintf("Peran warga berhasil diperbarui menjadi %s", displayRole),
		"data":    updatedUser,
	})
}

// GET /api/v1/admin/houses/:id/occupants
func (h *AppHandler) GetHouseOccupants(c *fiber.Ctx) error {
	idParam := c.Params("id")
	houseID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID rumah tidak valid",
		})
	}

	data, err := h.houseUseCase.GetHouseOccupants(c.Context(), houseID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Data penghuni rumah berhasil dimuat",
		"data":    data,
	})
}

// GET /api/v1/admin/unassigned-residents
func (h *AppHandler) GetUnassignedResidents(c *fiber.Ctx) error {
	search := c.Query("search")
	residents, err := h.houseUseCase.GetUnassignedResidents(c.Context(), search)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal memuat daftar warga belum terpetakan",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Daftar warga belum terpetakan berhasil dimuat",
		"data":    residents,
	})
}

// POST /api/v1/admin/houses/:id/assign-resident
func (h *AppHandler) AssignResident(c *fiber.Ctx) error {
	idParam := c.Params("id")
	houseID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID rumah tidak valid",
		})
	}

	var input house.AssignResidentInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload penugasan warga tidak valid",
		})
	}

	if err := h.houseUseCase.AssignResident(c.Context(), houseID, input.UserID, input.OccupantType); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Warga berhasil dipetakan ke rumah ini",
	})
}

// DELETE /api/v1/admin/houses/:id/remove-resident/:user_id
func (h *AppHandler) RemoveResident(c *fiber.Ctx) error {
	houseID, err := strconv.ParseInt(c.Params("id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID rumah tidak valid",
		})
	}

	userID, err := strconv.ParseInt(c.Params("user_id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID warga tidak valid",
		})
	}

	if err := h.houseUseCase.RemoveResident(c.Context(), houseID, userID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Warga berhasil dilepas dari rumah ini",
	})
}

// POST /api/v1/admin/users/:user_id/transfer-house
func (h *AppHandler) TransferHouse(c *fiber.Ctx) error {
	userID, err := strconv.ParseInt(c.Params("user_id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID warga tidak valid",
		})
	}

	var input house.TransferHouseInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload perpindahan rumah tidak valid",
		})
	}

	if err := h.houseUseCase.TransferHouse(c.Context(), userID, input.NewHouseID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Warga berhasil dipindahkan ke rumah baru",
	})
}

// GET /api/v1/admin/houses/:id/details
func (h *AppHandler) GetHouseDetails(c *fiber.Ctx) error {
	idParam := c.Params("id")
	houseID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID rumah tidak valid",
		})
	}

	data, err := h.houseUseCase.GetHouseDetails(c.Context(), houseID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Detail hunian berhasil dimuat",
		"data":    data,
	})
}

// POST /api/v1/admin/houses/:house_id/family
func (h *AppHandler) AdminAddFamilyMember(c *fiber.Ctx) error {
	houseID, err := strconv.ParseInt(c.Params("house_id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID rumah tidak valid",
		})
	}

	var input house.AdminAddFamilyInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload anggota keluarga tidak valid",
		})
	}

	member, err := h.houseUseCase.AdminAddFamilyMember(c.Context(), houseID, input)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Anggota keluarga berhasil ditambahkan oleh Admin",
		"data":    member,
	})
}

// DELETE /api/v1/admin/houses/:house_id/family/:family_id
func (h *AppHandler) AdminDeleteFamilyMember(c *fiber.Ctx) error {
	houseID, err := strconv.ParseInt(c.Params("house_id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID rumah tidak valid",
		})
	}

	familyID, err := strconv.ParseInt(c.Params("family_id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID anggota keluarga tidak valid",
		})
	}

	if err := h.houseUseCase.AdminDeleteFamilyMember(c.Context(), houseID, familyID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Anggota keluarga berhasil dihapus oleh Admin",
	})
}

// POST /api/v1/admin/houses/:house_id/vehicles
func (h *AppHandler) AdminAddVehicle(c *fiber.Ctx) error {
	houseID, err := strconv.ParseInt(c.Params("house_id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID rumah tidak valid",
		})
	}

	var input house.AdminAddVehicleInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload kendaraan tidak valid",
		})
	}

	vehicle, err := h.houseUseCase.AdminAddVehicle(c.Context(), houseID, input)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Kendaraan berhasil didaftarkan oleh Admin",
		"data":    vehicle,
	})
}

// DELETE /api/v1/admin/houses/:house_id/vehicles/:vehicle_id
func (h *AppHandler) AdminDeleteVehicle(c *fiber.Ctx) error {
	houseID, err := strconv.ParseInt(c.Params("house_id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID rumah tidak valid",
		})
	}

	vehicleID, err := strconv.ParseInt(c.Params("vehicle_id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID kendaraan tidak valid",
		})
	}

	if err := h.houseUseCase.AdminDeleteVehicle(c.Context(), houseID, vehicleID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Kendaraan berhasil dihapus oleh Admin",
	})
}

// GET /api/v1/houses
func (h *AppHandler) GetAllHouses(c *fiber.Ctx) error {
	block := c.Query("block")
	status := c.Query("status")
	search := c.Query("search")

	houses, err := h.houseUseCase.GetAllHouses(c.Context(), block, status, search)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal memuat master data rumah",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Master data rumah berhasil dimuat",
		"data":    houses,
	})
}

// GET /api/v1/houses/blocks
func (h *AppHandler) GetDistinctBlocks(c *fiber.Ctx) error {
	blocks, err := h.houseUseCase.GetDistinctBlocks(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal memuat daftar blok hunian",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Daftar blok berhasil dimuat",
		"data":    blocks,
	})
}

// POST /api/v1/houses
func (h *AppHandler) CreateHouse(c *fiber.Ctx) error {
	var input house.CreateHouseInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload rumah tidak valid",
		})
	}

	created, err := h.houseUseCase.CreateHouse(c.Context(), input)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Data rumah berhasil ditambahkan",
		"data":    created,
	})
}

// PUT /api/v1/houses/:id
func (h *AppHandler) UpdateHouse(c *fiber.Ctx) error {
	idParam := c.Params("id")
	houseID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID rumah tidak valid",
		})
	}

	var input house.UpdateHouseInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload update rumah tidak valid",
		})
	}

	updated, err := h.houseUseCase.UpdateHouse(c.Context(), houseID, input)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Data rumah berhasil diperbarui",
		"data":    updated,
	})
}

// DELETE /api/v1/houses/:id
func (h *AppHandler) DeleteHouse(c *fiber.Ctx) error {
	idParam := c.Params("id")
	houseID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID rumah tidak valid",
		})
	}

	if err := h.houseUseCase.DeleteHouse(c.Context(), houseID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Gagal menghapus data rumah (masih terikat penghuni atau data lain)",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Data rumah berhasil dihapus",
	})
}

// POST /api/v1/admin/houses/bulk-delete
func (h *AppHandler) BulkDeleteHouses(c *fiber.Ctx) error {
	var input house.BulkDeleteHousesInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload bulk delete tidak valid",
		})
	}

	if len(input.HouseIDs) == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Daftar ID hunian tidak boleh kosong",
		})
	}

	deletedCount, err := h.houseUseCase.BulkDeleteHouses(c.Context(), input.HouseIDs)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal menghapus data hunian massal: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": fmt.Sprintf("%d data hunian berhasil dihapus", deletedCount),
		"data": fiber.Map{
			"deleted_count": deletedCount,
		},
	})
}

// ----------------------------------------------------
// PROFILE, FAMILY & VEHICLE ENDPOINTS
// ----------------------------------------------------

func getUserIDFromLocals(c *fiber.Ctx) (int64, bool) {
	val := c.Locals("user_id")
	switch v := val.(type) {
	case int64:
		return v, true
	case float64:
		return int64(v), true
	case int:
		return int64(v), true
	default:
		return 0, false
	}
}

func getUserRoleFromLocals(c *fiber.Ctx) string {
	r, _ := c.Locals("role").(string)
	return strings.ToUpper(strings.TrimSpace(r))
}

// GET /api/v1/profile
func (h *AppHandler) GetProfile(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	data, err := h.profileUseCase.GetProfile(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Profil berhasil dimuat",
		"data":    data,
	})
}

// PUT /api/v1/profile
func (h *AppHandler) UpdateProfile(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	var input profile.UpdateProfileInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload profil tidak valid",
		})
	}

	user, err := h.profileUseCase.UpdateProfile(c.Context(), userID, input)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Profil berhasil diperbarui",
		"data":    user,
	})
}

// POST /api/v1/profile/family
func (h *AppHandler) AddFamilyMember(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	var input profile.AddFamilyMemberInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload data keluarga tidak valid",
		})
	}

	member, err := h.profileUseCase.AddFamilyMember(c.Context(), userID, input)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Anggota keluarga berhasil ditambahkan",
		"data":    member,
	})
}

// DELETE /api/v1/profile/family/:id
func (h *AppHandler) DeleteFamilyMember(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	idParam := c.Params("id")
	memberID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID anggota keluarga tidak valid",
		})
	}

	if err := h.profileUseCase.DeleteFamilyMember(c.Context(), userID, memberID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Anggota keluarga berhasil dihapus",
	})
}

// POST /api/v1/profile/vehicles
func (h *AppHandler) AddVehicle(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	var input profile.AddVehicleInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload kendaraan tidak valid",
		})
	}

	vehicle, err := h.profileUseCase.AddVehicle(c.Context(), userID, input)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Kendaraan berhasil didaftarkan",
		"data":    vehicle,
	})
}

// DELETE /api/v1/profile/vehicles/:id
func (h *AppHandler) DeleteVehicle(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	idParam := c.Params("id")
	vehicleID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID kendaraan tidak valid",
		})
	}

	if err := h.profileUseCase.DeleteVehicle(c.Context(), userID, vehicleID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Kendaraan berhasil dihapus",
	})
}

// ----------------------------------------------------
// SPRINT 2: BILLING & PAYMENT ENDPOINTS
// ----------------------------------------------------

// GET /api/v1/payment-settings
func (h *AppHandler) GetPaymentSettings(c *fiber.Ctx) error {
	settings, err := h.billingUseCase.GetPaymentSettings(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal memuat pengaturan pembayaran: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Pengaturan rekening dan iuran berhasil dimuat",
		"data":    settings,
	})
}

type UpdatePaymentSettingsInput struct {
	BankName      string      `json:"bank_name"`
	AccountNumber string      `json:"account_number"`
	AccountHolder string      `json:"account_holder"`
	MonthlyFee    interface{} `json:"monthly_fee"`
}

// PUT /api/v1/admin/payment-settings
func (h *AppHandler) AdminUpdatePaymentSettings(c *fiber.Ctx) error {
	var input UpdatePaymentSettingsInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload pengaturan pembayaran tidak valid",
		})
	}

	var monthlyFee float64
	switch v := input.MonthlyFee.(type) {
	case float64:
		monthlyFee = v
	case int:
		monthlyFee = float64(v)
	case string:
		monthlyFee, _ = strconv.ParseFloat(v, 64)
	}

	updated, err := h.billingUseCase.UpdatePaymentSettings(
		c.Context(),
		input.BankName,
		input.AccountNumber,
		input.AccountHolder,
		monthlyFee,
	)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Pengaturan rekening dan iuran berhasil diperbarui",
		"data":    updated,
	})
}

type GenerateBillsInput struct {
	Period  string `json:"period"` // 'YYYY-MM'
	HouseID *int64 `json:"house_id,omitempty"`
}

type GenerateIndividualBillInput struct {
	HouseID int64  `json:"house_id"`
	Period  string `json:"period"` // 'YYYY-MM'
}

// POST /api/v1/admin/bills/generate
func (h *AppHandler) AdminGenerateBills(c *fiber.Ctx) error {
	var input GenerateBillsInput
	_ = c.BodyParser(&input) // optional body

	if input.HouseID != nil && *input.HouseID > 0 {
		bill, err := h.billingUseCase.GenerateIndividualBill(c.Context(), *input.HouseID, input.Period)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"success": false,
				"message": err.Error(),
			})
		}
		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"success": true,
			"message": "Berhasil menerbitkan tagihan individual",
			"data": fiber.Map{
				"generated_count": 1,
				"bill":            bill,
			},
		})
	}

	count, err := h.billingUseCase.GenerateMonthlyBills(c.Context(), input.Period)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": fmt.Sprintf("Berhasil menerbitkan %d tagihan baru", count),
		"data": fiber.Map{
			"generated_count": count,
		},
	})
}

// POST /api/v1/admin/bills/generate-individual
func (h *AppHandler) AdminGenerateIndividualBill(c *fiber.Ctx) error {
	var input GenerateIndividualBillInput
	if err := c.BodyParser(&input); err != nil || input.HouseID <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Unit rumah wajib dipilih",
		})
	}

	bill, err := h.billingUseCase.GenerateIndividualBill(c.Context(), input.HouseID, input.Period)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Berhasil menerbitkan tagihan individual",
		"data": fiber.Map{
			"generated_count": 1,
			"bill":            bill,
		},
	})
}

// GET /api/v1/resident/bills
func (h *AppHandler) GetResidentBills(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	period := c.Query("period")

	bills, err := h.billingUseCase.GetResidentBills(c.Context(), userID, period)
	if err != nil {
		status := fiber.StatusBadRequest
		if strings.Contains(err.Error(), "akses ditolak") || strings.Contains(err.Error(), "belum") {
			status = fiber.StatusForbidden
		}
		return c.Status(status).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Daftar tagihan berhasil dimuat",
		"data":    bills,
	})
}

type InitiateBillInput struct {
	Period string `json:"period"`
}

// POST /api/v1/resident/bills/initiate
func (h *AppHandler) InitiateResidentBill(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	var input InitiateBillInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Format payload tidak valid",
		})
	}

	bill, err := h.billingUseCase.InitiateResidentBill(c.Context(), userID, input.Period)
	if err != nil {
		status := fiber.StatusBadRequest
		if strings.Contains(err.Error(), "akses ditolak") || strings.Contains(err.Error(), "belum") {
			status = fiber.StatusForbidden
		}
		return c.Status(status).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Tagihan berhasil diinisiasi",
		"data":    bill,
	})
}

// GET /api/v1/resident/bills/:id
func (h *AppHandler) GetResidentBillDetail(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	billID, err := strconv.ParseInt(c.Params("id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID tagihan tidak valid",
		})
	}

	// Resident endpoint strictly verifies caller's house ownership
	bill, err := h.billingUseCase.GetBillDetail(c.Context(), billID, userID, false)
	if err != nil {
		status := fiber.StatusBadRequest
		if strings.Contains(err.Error(), "akses ditolak") || strings.Contains(err.Error(), "belum") {
			status = fiber.StatusForbidden
		}
		return c.Status(status).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Detail tagihan berhasil dimuat",
		"data":    bill,
	})
}

// GET /api/v1/admin/bills/:id
func (h *AppHandler) GetAdminBillDetail(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	billID, err := strconv.ParseInt(c.Params("id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID tagihan tidak valid",
		})
	}

	bill, err := h.billingUseCase.GetBillDetail(c.Context(), billID, userID, true)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Detail tagihan admin berhasil dimuat",
		"data":    bill,
	})
}

// POST /api/v1/resident/bills/:id/pay
func (h *AppHandler) SubmitBillPayment(c *fiber.Ctx) error {
	userID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	billID, err := strconv.ParseInt(c.Params("id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID tagihan tidak valid",
		})
	}

	paymentMethod := strings.ToUpper(strings.TrimSpace(c.FormValue("payment_method")))
	if paymentMethod == "" {
		paymentMethod = string(entity.PaymentMethodTransfer)
	}

	var proofURL string
	var savePath string

	if paymentMethod == string(entity.PaymentMethodTransfer) {
		// 1. Process uploaded proof_image file for transfer
		fileHeader, err := c.FormFile("proof_image")
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"success": false,
				"message": "Bukti transfer (proof_image) wajib dilampirkan",
			})
		}

		// Max 5MB check
		if fileHeader.Size > 5*1024*1024 {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"success": false,
				"message": "Ukuran file bukti transfer maksimal 5MB",
			})
		}

		// Validate file type
		ext := strings.ToLower(filepath.Ext(fileHeader.Filename))
		if ext != ".jpg" && ext != ".jpeg" && ext != ".png" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"success": false,
				"message": "Format file tidak didukung. Harap unggah format JPG, JPEG, atau PNG",
			})
		}

		// Ensure upload directory exists
		uploadDir := filepath.Join("uploads", "payments")
		if err := os.MkdirAll(uploadDir, 0755); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "Gagal menyiapkan direktori penyimpanan bukti pembayaran",
			})
		}

		uniqueFileName := fmt.Sprintf("%s%s", uuid.New().String(), ext)
		savePath = filepath.Join(uploadDir, uniqueFileName)

		if err := c.SaveFile(fileHeader, savePath); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "Gagal menyimpan file bukti transfer",
			})
		}

		proofURL = fmt.Sprintf("/uploads/payments/%s", uniqueFileName)
	}

	// 2. Parse form fields
	senderBank := c.FormValue("sender_bank")
	senderName := c.FormValue("sender_name")
	notes := c.FormValue("notes")
	amountStr := c.FormValue("amount")

	var amountPaid float64
	if amountStr != "" {
		amountPaid, _ = strconv.ParseFloat(amountStr, 64)
	}

	err = h.billingUseCase.SubmitPayment(
		c.Context(),
		billID,
		userID,
		paymentMethod,
		senderBank,
		senderName,
		amountPaid,
		proofURL,
		notes,
	)
	if err != nil {
		// Clean up uploaded file if business logic fails
		if savePath != "" {
			_ = os.Remove(savePath)
		}
		status := fiber.StatusBadRequest
		if strings.Contains(err.Error(), "akses ditolak") || strings.Contains(err.Error(), "belum") {
			status = fiber.StatusForbidden
		} else if strings.Contains(err.Error(), "sudah tercatat lunas") || strings.Contains(err.Error(), "sedang dalam proses verifikasi") {
			status = fiber.StatusConflict
		}
		return c.Status(status).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	successMsg := "Bukti transfer berhasil dikirim. Menunggu verifikasi pengurus RT."
	if paymentMethod == string(entity.PaymentMethodCash) {
		successMsg = "Deklarasi pembayaran tunai berhasil dikirim. Menunggu verifikasi dan konfirmasi pengurus RT."
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": successMsg,
		"data": fiber.Map{
			"bill_id":         billID,
			"payment_method":  paymentMethod,
			"proof_image_url": proofURL,
			"status":          entity.BillStatusPendingVerification,
		},
	})
}

// GET /api/v1/admin/bills/pending
func (h *AppHandler) GetAdminPendingBills(c *fiber.Ctx) error {
	pending, err := h.billingUseCase.GetPendingPayments(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal memuat antrean pembayaran: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Antrean pembayaran berhasil dimuat",
		"data":    pending,
	})
}

type VerifyBillInput struct {
	Action          string `json:"action"` // 'approve' | 'reject'
	RejectionReason string `json:"rejection_reason"`
}

// POST /api/v1/admin/bills/:id/verify
func (h *AppHandler) VerifyBillPayment(c *fiber.Ctx) error {
	adminID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas admin tidak ditemukan",
		})
	}

	billID, err := strconv.ParseInt(c.Params("id"), 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID tagihan tidak valid",
		})
	}

	var input VerifyBillInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload verifikasi tidak valid",
		})
	}

	var reason *string
	if input.RejectionReason != "" {
		reason = &input.RejectionReason
	}

	err = h.billingUseCase.VerifyPayment(c.Context(), billID, input.Action, reason, adminID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	actionMessage := "Pembayaran iuran disetujui (Lunas)"
	if input.Action == "reject" {
		actionMessage = "Pembayaran iuran ditolak"
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": actionMessage,
	})
}

// GET /api/v1/admin/bills/summary
func (h *AppHandler) GetAdminBillsSummary(c *fiber.Ctx) error {
	period := strings.TrimSpace(c.Query("period"))
	if period == "" {
		period = time.Now().Format("2006-01")
	}
	block := strings.TrimSpace(c.Query("block"))

	summary, err := h.billingUseCase.GetBillingSummary(c.Context(), period, block)
	if err != nil {
		log.Printf("[ERROR] GetBillingSummary: %v", err)
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Rekapitulasi iuran berhasil dimuat",
		"data":    summary,
	})
}

// GET /api/v1/admin/bills/eligible-residents
func (h *AppHandler) AdminGetEligibleResidents(c *fiber.Ctx) error {
	residents, err := h.billingUseCase.GetEligibleResidentsForBilling(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal memuat daftar warga: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Daftar warga berhasil dimuat",
		"data":    residents,
	})
}

// GET /api/v1/admin/bills/resident-periods
func (h *AppHandler) AdminGetResidentEligiblePeriods(c *fiber.Ctx) error {
	residentID, err := strconv.ParseInt(c.Query("resident_id"), 10, 64)
	if err != nil || residentID <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Parameter resident_id tidak valid",
		})
	}

	periods, err := h.billingUseCase.GetResidentEligiblePeriods(c.Context(), residentID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal memuat periode iuran warga: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Daftar periode iuran berhasil dimuat",
		"data":    periods,
	})
}

type AdminRecordCashPaymentInput struct {
	ResidentID  int64   `json:"resident_id"`
	BillID      int64   `json:"bill_id"`
	Amount      float64 `json:"amount"`
	PaymentDate string  `json:"payment_date"`
	Notes       *string `json:"notes"`
}

// POST /api/v1/admin/bills/record-cash
func (h *AppHandler) AdminRecordCashPayment(c *fiber.Ctx) error {
	adminID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	var input AdminRecordCashPaymentInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Format data tidak valid: " + err.Error(),
		})
	}

	if input.ResidentID <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Warga (resident_id) wajib dipilih",
		})
	}

	if input.BillID <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Periode iuran (bill_id) wajib dipilih",
		})
	}

	parsedDate := time.Now()
	if strings.TrimSpace(input.PaymentDate) != "" {
		formats := []string{
			time.RFC3339Nano,
			time.RFC3339,
			"2006-01-02T15:04:05.999999999",
			"2006-01-02T15:04:05.999",
			"2006-01-02T15:04:05",
			"2006-01-02",
		}
		var parsed bool
		for _, f := range formats {
			if t, err := time.Parse(f, strings.TrimSpace(input.PaymentDate)); err == nil {
				parsedDate = t
				parsed = true
				break
			}
		}
		if !parsed {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"success": false,
				"message": "Format tanggal pembayaran tidak valid",
			})
		}
	}

	payment, err := h.billingUseCase.RecordDirectCashPayment(
		c.Context(),
		adminID,
		billing.DirectCashPaymentInput{
			ResidentID:  input.ResidentID,
			BillID:      input.BillID,
			Amount:      input.Amount,
			PaymentDate: parsedDate,
			Notes:       input.Notes,
		},
	)
	if err != nil {
		status := fiber.StatusBadRequest
		if strings.Contains(err.Error(), "sudah tercatat lunas") || strings.Contains(err.Error(), "sedang dalam antrean verifikasi") {
			status = fiber.StatusConflict
		}
		return c.Status(status).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Pembayaran tunai berhasil dicatat dan disinkronkan ke buku kas",
		"data":    payment,
	})
}

type AdminBulkProcessPaymentsInput struct {
	Period        string  `json:"period"`
	PaymentMethod string  `json:"payment_method"`
	BillIDs       []int64 `json:"bill_ids"`
	Notes         *string `json:"notes,omitempty"`
}

// POST /api/v1/admin/bills/bulk-pay
func (h *AppHandler) AdminBulkProcessPayments(c *fiber.Ctx) error {
	treasurerID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Identitas pengguna tidak ditemukan",
		})
	}

	var input AdminBulkProcessPaymentsInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Format data tidak valid: " + err.Error(),
		})
	}

	result, err := h.billingUseCase.BulkProcessPayments(
		c.Context(),
		treasurerID,
		billing.BulkProcessPaymentsInput{
			Period:        input.Period,
			PaymentMethod: input.PaymentMethod,
			BillIDs:       input.BillIDs,
			Notes:         input.Notes,
		},
	)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": fmt.Sprintf("Bulk process selesai: %d berhasil, %d gagal/dilewati", result.SuccessCount, result.FailedCount),
		"data":    result,
	})
}

// GET /api/v1/admin/dashboard/stats
func (h *AppHandler) GetAdminDashboardStats(c *fiber.Ctx) error {
	period := strings.TrimSpace(c.Query("period"))
	if period == "" {
		period = time.Now().Format("2006-01")
	}

	stats, err := h.dashboardUseCase.GetAdminDashboardStats(c.Context(), period)
	if err != nil {
		log.Printf("[ERROR] GetAdminDashboardStats: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal mengambil data statistik dashboard: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"data":    stats,
	})
}

// ----------------------------------------------------
// SPRINT 3: CASHBOOK (BUKU KAS RT) HANDLERS
// ----------------------------------------------------

// GET /api/v1/cashbook/summary
func (h *AppHandler) GetCashbookSummary(c *fiber.Ctx) error {
	summary, err := h.cashbookUseCase.GetSummary(c.Context())
	if err != nil {
		log.Printf("[ERROR] GetCashbookSummary: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal mengambil ringkasan buku kas: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"data":    summary,
	})
}

// GET /api/v1/cashbook/transactions
func (h *AppHandler) GetCashbookTransactions(c *fiber.Ctx) error {
	txType := c.Query("type")
	category := c.Query("category")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	period := c.Query("period")
	month, _ := strconv.Atoi(c.Query("month", "0"))
	year, _ := strconv.Atoi(c.Query("year", "0"))
	page, _ := strconv.Atoi(c.Query("page", "1"))
	limit, _ := strconv.Atoi(c.Query("limit", "20"))

	filter := entity.CashTransactionsFilter{
		Type:      txType,
		Category:  category,
		StartDate: startDate,
		EndDate:   endDate,
		Period:    period,
		Month:     month,
		Year:      year,
		Page:      page,
		Limit:     limit,
	}

	result, err := h.cashbookUseCase.GetTransactions(c.Context(), filter)
	if err != nil {
		log.Printf("[ERROR] GetCashbookTransactions: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal mengambil daftar transaksi kas: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success":          true,
		"data":             result.Transactions,
		"total":            result.Total,
		"page":             result.Page,
		"limit":            result.Limit,
		"period":           result.Period,
		"start_date":       result.StartDate,
		"end_date":         result.EndDate,
		"previous_balance": result.PreviousBalance,
		"period_income":    result.PeriodIncome,
		"period_expense":   result.PeriodExpense,
		"ending_balance":   result.EndingBalance,
	})
}

// POST /api/v1/admin/cashbook/transactions
func (h *AppHandler) AdminCreateCashTransaction(c *fiber.Ctx) error {
	adminID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Sesi tidak valid",
		})
	}

	txType := strings.TrimSpace(c.FormValue("type"))
	category := strings.TrimSpace(c.FormValue("category"))
	desc := strings.TrimSpace(c.FormValue("description"))
	txDate := strings.TrimSpace(c.FormValue("transaction_date"))
	amountStr := strings.TrimSpace(c.FormValue("amount"))

	if txDate == "" {
		txDate = time.Now().Format("2006-01-02")
	}

	amount, err := strconv.ParseFloat(amountStr, 64)
	if err != nil || amount <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Nominal transaksi tidak valid",
		})
	}

	var proofURL *string
	fileHeader, err := c.FormFile("proof_image")
	if err == nil && fileHeader != nil {
		ext := strings.ToLower(filepath.Ext(fileHeader.Filename))
		if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp" && ext != ".pdf" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"success": false,
				"message": "Format bukti nota tidak didukung. Harap unggah JPG, PNG, WEBP, atau PDF",
			})
		}

		uploadDir := filepath.Join("uploads", "cashbook")
		if err := os.MkdirAll(uploadDir, 0755); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "Gagal menyiapkan direktori penyimpanan nota",
			})
		}

		uniqueName := fmt.Sprintf("%s%s", uuid.New().String(), ext)
		savePath := filepath.Join(uploadDir, uniqueName)
		if err := c.SaveFile(fileHeader, savePath); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "Gagal menyimpan file bukti nota",
			})
		}

		urlStr := fmt.Sprintf("/uploads/cashbook/%s", uniqueName)
		proofURL = &urlStr
	}

	txItem := &entity.CashTransaction{
		Type:            txType,
		Category:        category,
		Amount:          amount,
		TransactionDate: txDate,
		Description:     desc,
		ProofImageURL:   proofURL,
		CreatedBy:       &adminID,
	}

	if err := h.cashbookUseCase.CreateManualTransaction(c.Context(), txItem); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Transaksi kas berhasil dicatat",
		"data":    txItem,
	})
}

// DELETE /api/v1/admin/cashbook/transactions/:id
func (h *AppHandler) AdminDeleteCashTransaction(c *fiber.Ctx) error {
	idStr := c.Params("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID transaksi tidak valid",
		})
	}

	if err := h.cashbookUseCase.DeleteManualTransaction(c.Context(), id); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Transaksi kas berhasil dihapus",
	})
}

// ----------------------------------------------------
// SPRINT 3: ANNOUNCEMENT (PAPAN PENGUMUMAN) HANDLERS
// ----------------------------------------------------

// GET /api/v1/announcements
func (h *AppHandler) GetAnnouncements(c *fiber.Ctx) error {
	category := c.Query("category")
	search := c.Query("search")

	list, err := h.announcementUseCase.GetAll(c.Context(), category, search)
	if err != nil {
		log.Printf("[ERROR] GetAnnouncements: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal mengambil daftar pengumuman: " + err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"data":    list,
	})
}

// GET /api/v1/announcements/:id
func (h *AppHandler) GetAnnouncementDetail(c *fiber.Ctx) error {
	idStr := c.Params("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID pengumuman tidak valid",
		})
	}

	a, err := h.announcementUseCase.GetByID(c.Context(), id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal mengambil detail pengumuman: " + err.Error(),
		})
	}
	if a == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"message": "Pengumuman tidak ditemukan",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"data":    a,
	})
}

// POST /api/v1/admin/announcements
func (h *AppHandler) AdminCreateAnnouncement(c *fiber.Ctx) error {
	adminID, ok := getUserIDFromLocals(c)
	if !ok {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Sesi tidak valid",
		})
	}

	title := strings.TrimSpace(c.FormValue("title"))
	content := strings.TrimSpace(c.FormValue("content"))
	category := strings.TrimSpace(c.FormValue("category"))
	isPinnedStr := strings.TrimSpace(c.FormValue("is_pinned"))
	isPinned := isPinnedStr == "true" || isPinnedStr == "1"

	// Support JSON body fallback if not multipart form
	if title == "" && content == "" {
		type jsonReq struct {
			Title    string `json:"title"`
			Content  string `json:"content"`
			Category string `json:"category"`
			IsPinned bool   `json:"is_pinned"`
		}
		var req jsonReq
		if err := c.BodyParser(&req); err == nil {
			title = req.Title
			content = req.Content
			category = req.Category
			isPinned = req.IsPinned
		}
	}

	var imageURL *string
	fileHeader, err := c.FormFile("image")
	if err == nil && fileHeader != nil {
		ext := strings.ToLower(filepath.Ext(fileHeader.Filename))
		if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"success": false,
				"message": "Format gambar poster tidak didukung. Harap unggah JPG, PNG, atau WEBP",
			})
		}

		uploadDir := filepath.Join("uploads", "announcements")
		if err := os.MkdirAll(uploadDir, 0755); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "Gagal menyiapkan direktori penyimpanan gambar pengumuman",
			})
		}

		uniqueName := fmt.Sprintf("%s%s", uuid.New().String(), ext)
		savePath := filepath.Join(uploadDir, uniqueName)
		if err := c.SaveFile(fileHeader, savePath); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "Gagal menyimpan gambar pengumuman",
			})
		}

		urlStr := fmt.Sprintf("/uploads/announcements/%s", uniqueName)
		imageURL = &urlStr
	}

	item := &entity.Announcement{
		Title:    title,
		Content:  content,
		Category: category,
		ImageURL: imageURL,
		IsPinned: isPinned,
		AuthorID: &adminID,
	}

	if err := h.announcementUseCase.Create(c.Context(), item); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"success": true,
		"message": "Pengumuman berhasil dipublikasikan",
		"data":    item,
	})
}

// PUT /api/v1/admin/announcements/:id
func (h *AppHandler) AdminUpdateAnnouncement(c *fiber.Ctx) error {
	idStr := c.Params("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID pengumuman tidak valid",
		})
	}

	title := strings.TrimSpace(c.FormValue("title"))
	content := strings.TrimSpace(c.FormValue("content"))
	category := strings.TrimSpace(c.FormValue("category"))
	isPinnedStr := strings.TrimSpace(c.FormValue("is_pinned"))
	isPinned := isPinnedStr == "true" || isPinnedStr == "1"

	if title == "" && content == "" {
		type jsonReq struct {
			Title    string `json:"title"`
			Content  string `json:"content"`
			Category string `json:"category"`
			IsPinned bool   `json:"is_pinned"`
		}
		var req jsonReq
		if err := c.BodyParser(&req); err == nil {
			title = req.Title
			content = req.Content
			category = req.Category
			isPinned = req.IsPinned
		}
	}

	var imageURL *string
	fileHeader, err := c.FormFile("image")
	if err == nil && fileHeader != nil {
		ext := strings.ToLower(filepath.Ext(fileHeader.Filename))
		if ext != ".jpg" && ext != ".jpeg" && ext != ".png" && ext != ".webp" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"success": false,
				"message": "Format gambar poster tidak didukung. Harap unggah JPG, PNG, atau WEBP",
			})
		}

		uploadDir := filepath.Join("uploads", "announcements")
		if err := os.MkdirAll(uploadDir, 0755); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "Gagal menyiapkan direktori penyimpanan gambar pengumuman",
			})
		}

		uniqueName := fmt.Sprintf("%s%s", uuid.New().String(), ext)
		savePath := filepath.Join(uploadDir, uniqueName)
		if err := c.SaveFile(fileHeader, savePath); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "Gagal menyimpan gambar pengumuman",
			})
		}

		urlStr := fmt.Sprintf("/uploads/announcements/%s", uniqueName)
		imageURL = &urlStr
	}

	item := &entity.Announcement{
		ID:       id,
		Title:    title,
		Content:  content,
		Category: category,
		ImageURL: imageURL,
		IsPinned: isPinned,
	}

	if err := h.announcementUseCase.Update(c.Context(), item); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Pengumuman berhasil diperbarui",
		"data":    item,
	})
}

// DELETE /api/v1/admin/announcements/:id
func (h *AppHandler) AdminDeleteAnnouncement(c *fiber.Ctx) error {
	idStr := c.Params("id")
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID pengumuman tidak valid",
		})
	}

	if err := h.announcementUseCase.Delete(c.Context(), id); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Pengumuman berhasil dihapus",
	})
}



