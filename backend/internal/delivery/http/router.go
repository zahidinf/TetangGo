package http

import (
	"tetanggo-backend/internal/delivery/http/handler"
	"tetanggo-backend/internal/delivery/http/middleware"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
)

func SetupRouter(appHandler *handler.AppHandler, authMid *middleware.AuthMiddleware) *fiber.App {
	app := fiber.New(fiber.Config{
		AppName: "TetangGo API - Sprint 1",
	})

	// Middlewares
	app.Use(recover.New())
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET, POST, PUT, DELETE, OPTIONS",
	}))

	// Static files serving (payment proofs, profile photos, etc)
	app.Static("/uploads", "./uploads")

	// Health Check
	app.Get("/health", appHandler.HealthCheck)

	// API v1
	v1 := app.Group("/api/v1")
	{
		// Public Auth
		authGroup := v1.Group("/auth")
		{
			authGroup.Post("/login", appHandler.Login)
			authGroup.Post("/register", appHandler.Register)
		}

		// Public Endpoints
		publicGroup := v1.Group("/public")
		{
			publicGroup.Get("/houses-available", appHandler.GetAvailableHouses)
		}

		// Payment Settings (Accessible to authenticated users / residents)
		v1.Get("/payment-settings", appHandler.GetPaymentSettings)

		// Admin RT Only Endpoints
		adminGroup := v1.Group("/admin", authMid.RequireAuth(), authMid.RequireRole("admin_rt"))
		{
			// Dashboard Statistics
			adminGroup.Get("/dashboard/stats", appHandler.GetAdminDashboardStats)

			adminGroup.Get("/pending-users", appHandler.GetPendingUsers)
			adminGroup.Post("/users/:id/approve", appHandler.ApproveUser)
			adminGroup.Post("/users/:id/reject", appHandler.RejectUser)

			// Admin Full Resident Management (CRUD)
			adminGroup.Get("/users", appHandler.AdminGetAllUsers)
			adminGroup.Post("/users", appHandler.AdminCreateUser)
			adminGroup.Put("/users/:id", appHandler.AdminUpdateUser)
			adminGroup.Delete("/users/:id", appHandler.AdminDeleteUser)
			adminGroup.Post("/users/:id/reset-password", appHandler.AdminResetPassword)

			// Mapping & Occupant Management
			adminGroup.Get("/houses/:id/occupants", appHandler.GetHouseOccupants)
			adminGroup.Get("/houses/:id/details", appHandler.GetHouseDetails)
			adminGroup.Get("/unassigned-residents", appHandler.GetUnassignedResidents)
			adminGroup.Post("/houses/:id/assign-resident", appHandler.AssignResident)
			adminGroup.Delete("/houses/:id/remove-resident/:user_id", appHandler.RemoveResident)
			adminGroup.Post("/users/:user_id/transfer-house", appHandler.TransferHouse)

			// Admin Family & Vehicles Management
			adminGroup.Post("/houses/:house_id/family", appHandler.AdminAddFamilyMember)
			adminGroup.Delete("/houses/:house_id/family/:family_id", appHandler.AdminDeleteFamilyMember)
			adminGroup.Post("/houses/:house_id/vehicles", appHandler.AdminAddVehicle)
			adminGroup.Delete("/houses/:house_id/vehicles/:vehicle_id", appHandler.AdminDeleteVehicle)

			// Admin Bulk Delete Houses
			adminGroup.Post("/houses/bulk-delete", appHandler.BulkDeleteHouses)

			// Sprint 2: Admin Billing & Payment Management
			adminGroup.Put("/payment-settings", appHandler.AdminUpdatePaymentSettings)
			adminGroup.Post("/bills/generate", appHandler.AdminGenerateBills)
			adminGroup.Get("/bills/pending", appHandler.GetAdminPendingBills)
			adminGroup.Post("/bills/:id/verify", appHandler.VerifyBillPayment)
			adminGroup.Get("/bills/summary", appHandler.GetAdminBillsSummary)
		}

		// Houses Management (Admin RT)
		housesGroup := v1.Group("/houses", authMid.RequireAuth(), authMid.RequireRole("admin_rt"))
		{
			housesGroup.Get("/", appHandler.GetAllHouses)
			housesGroup.Get("/blocks", appHandler.GetDistinctBlocks)
			housesGroup.Post("/", appHandler.CreateHouse)
			housesGroup.Put("/:id", appHandler.UpdateHouse)
			housesGroup.Delete("/:id", appHandler.DeleteHouse)
			housesGroup.Post("/bulk-delete", appHandler.BulkDeleteHouses)
		}

		// Resident Billing & Payments (Sprint 2)
		residentGroup := v1.Group("/resident", authMid.RequireAuth())
		{
			residentGroup.Get("/bills", appHandler.GetResidentBills)
			residentGroup.Post("/bills/initiate", appHandler.InitiateResidentBill)
			residentGroup.Get("/bills/:id", appHandler.GetResidentBillDetail)
			residentGroup.Post("/bills/:id/pay", appHandler.SubmitBillPayment)
		}

		// Profile, Family & Vehicles (Authenticated User)
		profileGroup := v1.Group("/profile", authMid.RequireAuth())
		{
			profileGroup.Get("/", appHandler.GetProfile)
			profileGroup.Put("/", appHandler.UpdateProfile)

			// Family Members
			profileGroup.Post("/family", appHandler.AddFamilyMember)
			profileGroup.Delete("/family/:id", appHandler.DeleteFamilyMember)

			// Vehicles
			profileGroup.Post("/vehicles", appHandler.AddVehicle)
			profileGroup.Delete("/vehicles/:id", appHandler.DeleteVehicle)
		}
	}

	return app
}
