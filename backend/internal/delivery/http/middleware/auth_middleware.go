package middleware

import (
	"strings"
	"tetanggo-backend/internal/domain/entity"
	"tetanggo-backend/internal/domain/repository"
	"tetanggo-backend/internal/usecase/auth"

	"github.com/gofiber/fiber/v2"
)

type AuthMiddleware struct {
	tokenService *auth.TokenService
	userRepo     repository.UserRepository
}

func NewAuthMiddleware(tokenService *auth.TokenService, userRepo ...repository.UserRepository) *AuthMiddleware {
	var repo repository.UserRepository
	if len(userRepo) > 0 {
		repo = userRepo[0]
	}
	return &AuthMiddleware{
		tokenService: tokenService,
		userRepo:     repo,
	}
}

func (m *AuthMiddleware) RequireAuth() fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := c.Get("Authorization")
		if authHeader == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Authorization header missing",
			})
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Format Authorization header tidak valid (Bearer token)",
			})
		}

		claims, err := m.tokenService.ValidateToken(parts[1])
		if err != nil || claims.Type != "access" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Token tidak valid atau kedaluwarsa",
			})
		}

		c.Locals("user_id", claims.UserID)
		c.Locals("email", claims.Email)
		c.Locals("role", claims.Role)

		return c.Next()
	}
}

func (m *AuthMiddleware) RequireRole(roles ...string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userRole, ok := c.Locals("role").(string)
		if !ok {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"success": false,
				"message": "Akses ditolak: role tidak ditemukan dalam token",
			})
		}

		userRoleClean := strings.ToUpper(strings.TrimSpace(userRole))
		for _, r := range roles {
			if strings.EqualFold(r, userRoleClean) {
				return c.Next()
			}
		}

		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"message": "Akses ditolak: otorisasi role tidak mencukupi",
		})
	}
}

// RequireHouseMapping enforces that the authenticated caller has a valid, active housing mapping.
// Valid for any role (Resident, Chairperson, Vice Chairperson, Treasurer, Secretary, Admin, Security) with a house.
func (m *AuthMiddleware) RequireHouseMapping() fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID, ok := c.Locals("user_id").(int64)
		if !ok || userID <= 0 {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Identitas pengguna tidak ditemukan dalam sesi",
			})
		}

		if m.userRepo == nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "User repository tidak terkonfigurasi pada middleware",
			})
		}

		user, err := m.userRepo.GetByID(c.Context(), userID)
		if err != nil || user == nil {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
				"success": false,
				"message": "User tidak ditemukan",
			})
		}

		if user.Status != string(entity.UserStatusActive) {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"success": false,
				"message": "Akses ditolak: akun tidak aktif",
			})
		}

		if user.HouseID == nil || *user.HouseID <= 0 {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"success": false,
				"message": "akses ditolak: akun belum terdaftar pada hunian manapun",
			})
		}

		c.Locals("house_id", *user.HouseID)
		return c.Next()
	}
}

// RequireHouseOrRole allows access if the caller either has an authorized role OR has a valid housing mapping.
func (m *AuthMiddleware) RequireHouseOrRole(roles ...string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID, ok := c.Locals("user_id").(int64)
		if !ok || userID <= 0 {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Identitas pengguna tidak ditemukan dalam sesi",
			})
		}

		userRole, _ := c.Locals("role").(string)
		userRoleClean := strings.ToUpper(strings.TrimSpace(userRole))
		for _, r := range roles {
			if strings.EqualFold(r, userRoleClean) {
				return c.Next()
			}
		}

		if m.userRepo == nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "User repository tidak terkonfigurasi pada middleware",
			})
		}

		user, err := m.userRepo.GetByID(c.Context(), userID)
		if err != nil || user == nil {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
				"success": false,
				"message": "User tidak ditemukan",
			})
		}

		if user.Status != string(entity.UserStatusActive) {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"success": false,
				"message": "Akses ditolak: akun tidak aktif",
			})
		}

		if user.HouseID == nil || *user.HouseID <= 0 {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"success": false,
				"message": "Akses ditolak: aksi ini mensyaratkan mapping hunian atau izin administratif",
			})
		}

		c.Locals("house_id", *user.HouseID)
		return c.Next()
	}
}
