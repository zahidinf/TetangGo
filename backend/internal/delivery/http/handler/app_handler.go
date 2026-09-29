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
	"tetanggo-backend/internal/usecase/auth"
	"tetanggo-backend/internal/usecase/billing"
	"tetanggo-backend/internal/usecase/dashboard"
	"tetanggo-backend/internal/usecase/house"
	"tetanggo-backend/internal/usecase/profile"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type AppHandler struct {
	db               *sql.DB
	authUseCase      *auth.AuthUseCase
	houseUseCase     *house.HouseUseCase
	profileUseCase   *profile.ProfileUseCase
	billingUseCase   *billing.BillingUseCase
	dashboardUseCase *dashboard.DashboardUseCase
}

func NewAppHandler(
	db *sql.DB,
	authUseCase *auth.AuthUseCase,
	houseUseCase *house.HouseUseCase,
	profileUseCase *profile.ProfileUseCase,
	billingUseCase *billing.BillingUseCase,
	dashboardUseCase *dashboard.DashboardUseCase,
) *AppHandler {
	return &AppHandler{
		db:               db,
		authUseCase:      authUseCase,
		houseUseCase:     houseUseCase,
		profileUseCase:   profileUseCase,
		billingUseCase:   billingUseCase,
		dashboardUseCase: dashboardUseCase,
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
	var input auth.AdminCreateUserInput
	if err := c.BodyParser(&input); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Payload pendaftaran warga tidak valid",
		})
	}

	user, err := h.authUseCase.AdminCreateUser(c.Context(), input)
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

	user, err := h.authUseCase.AdminUpdateUser(c.Context(), userID, input)
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
	idParam := c.Params("id")
	userID, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "ID pengguna tidak valid",
		})
	}

	if err := h.authUseCase.AdminDeleteUser(c.Context(), userID); err != nil {
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

	if err := h.authUseCase.AdminResetPassword(c.Context(), userID, input.NewPassword); err != nil {
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
	Period string `json:"period"` // 'YYYY-MM'
}

// POST /api/v1/admin/bills/generate
func (h *AppHandler) AdminGenerateBills(c *fiber.Ctx) error {
	var input GenerateBillsInput
	_ = c.BodyParser(&input) // optional body

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
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
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
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
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

	role, _ := c.Locals("role").(string)
	isAdmin := role == "admin_rt"

	bill, err := h.billingUseCase.GetBillDetail(c.Context(), billID, userID, isAdmin)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
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

	// 1. Process uploaded proof_image file
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
	savePath := filepath.Join(uploadDir, uniqueFileName)

	if err := c.SaveFile(fileHeader, savePath); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Gagal menyimpan file bukti transfer",
		})
	}

	proofURL := fmt.Sprintf("/uploads/payments/%s", uniqueFileName)

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
		senderBank,
		senderName,
		amountPaid,
		proofURL,
		notes,
	)
	if err != nil {
		// Clean up uploaded file if business logic fails
		_ = os.Remove(savePath)
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Bukti transfer berhasil dikirim. Menunggu verifikasi pengurus RT.",
		"data": fiber.Map{
			"bill_id":         billID,
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
		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"success": true,
			"message": "Rekapitulasi iuran berhasil dimuat",
			"data": fiber.Map{
				"period":              period,
				"block":               block,
				"total_houses":        0,
				"paid_houses":         0,
				"unpaid_houses":       0,
				"total_paid_houses":   0,
				"total_unpaid_houses": 0,
				"total_paid_amount":   0,
				"total_unpaid_amount": 0,
				"house_bills":         []interface{}{},
				"items":               []interface{}{},
			},
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"success": true,
		"message": "Rekapitulasi iuran berhasil dimuat",
		"data":    summary,
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


