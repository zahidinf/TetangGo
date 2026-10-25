package handler

import (
	"fmt"
	"log"
	"strings"

	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
	"tetanggo-backend/internal/infrastructure/realtime"
	"tetanggo-backend/internal/usecase/auth"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/websocket/v2"
	"github.com/google/uuid"
)

func (h *AppHandler) SetRealtime(
	hub *realtime.Hub,
	tokenService *auth.TokenService,
	secRepo repository.SecurityRepository,
	userRepo repository.UserRepository,
) {
	h.realtimeHub = hub
	h.tokenService = tokenService
	h.secRepo = secRepo
	h.userRepo = userRepo
}

func (h *AppHandler) SetDeviceTokenRepo(repo repository.SecurityDeviceTokenRepository) {
	h.deviceTokenRepo = repo
}

// HandleSecurityAlarmsWSUpgrade checks whether the request is a valid WebSocket upgrade
// and verifies that the client is an authenticated, active SECURITY user with assigned neighborhoods.
func (h *AppHandler) HandleSecurityAlarmsWSUpgrade(c *fiber.Ctx) error {
	if !websocket.IsWebSocketUpgrade(c) {
		return fiber.ErrUpgradeRequired
	}

	// 1. Extract token from header or query parameters
	var tokenStr string
	authHeader := c.Get("Authorization")
	if strings.HasPrefix(authHeader, "Bearer ") {
		tokenStr = strings.TrimPrefix(authHeader, "Bearer ")
	}
	if tokenStr == "" {
		tokenStr = c.Query("token")
	}
	if tokenStr == "" {
		tokenStr = c.Query("access_token")
	}

	if tokenStr == "" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Token autentikasi tidak valid atau tidak disediakan",
		})
	}

	if h.tokenService == nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Token service belum terkonfigurasi",
		})
	}

	claims, err := h.tokenService.ValidateToken(tokenStr)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"success": false,
			"message": "Token tidak valid atau kedaluwarsa",
		})
	}

	// 2. Role validation: Must be SECURITY
	if claims.Role != string(entity.RoleSecurity) {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"message": "Akses ditolak: WebSocket alarm darurat khusus untuk akun petugas keamanan",
		})
	}

	// 3. User account status check
	if h.userRepo != nil {
		user, err := h.userRepo.GetByID(c.Context(), claims.UserID)
		if err != nil || user == nil || user.Status != string(entity.UserStatusActive) {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"success": false,
				"message": "Akses ditolak: Akun pengguna tidak aktif",
			})
		}
	}

	// 4. Active neighborhood assignments validation
	if h.secRepo == nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Security repository belum terkonfigurasi",
		})
	}

	nIDs, err := h.secRepo.GetActiveNeighborhoodIDsForUser(c.Context(), claims.UserID)
	if err != nil || len(nIDs) == 0 {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"message": "Akses ditolak: Petugas keamanan tidak memiliki penugasan lingkungan aktif",
		})
	}

	deviceID := strings.TrimSpace(c.Query("device_id"))
	if deviceID == "" {
		deviceID = "default_device"
	}

	c.Locals("ws_user_id", claims.UserID)
	c.Locals("ws_device_id", deviceID)
	c.Locals("ws_neighborhood_ids", nIDs)

	return c.Next()
}

// HandleSecurityAlarmsWS manages the live WebSocket connection lifecycle.
func (h *AppHandler) HandleSecurityAlarmsWS() fiber.Handler {
	return websocket.New(func(c *websocket.Conn) {
		userID, _ := c.Locals("ws_user_id").(int64)
		deviceID, _ := c.Locals("ws_device_id").(string)
		nIDs, _ := c.Locals("ws_neighborhood_ids").([]int64)

		if h.realtimeHub == nil {
			log.Println("[Realtime] Hub is nil in WebSocket handler")
			_ = c.Close()
			return
		}

		connID := fmt.Sprintf("conn_%s_%d", uuid.New().String()[:8], userID)
		client := realtime.NewClient(h.realtimeHub, c, userID, deviceID, connID, nIDs)

		h.realtimeHub.Register(client)

		go client.WritePump()
		client.ReadPump()
	})
}
