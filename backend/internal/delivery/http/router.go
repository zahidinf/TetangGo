package http

import (
	"tetanggo-backend/internal/delivery/http/handler"
	"tetanggo-backend/internal/delivery/http/middleware"
	"tetanggo-backend/internal/domain/entity"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/compress"
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
	app.Use(compress.New(compress.Config{
		Level: compress.LevelDefault,
	}))
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization, X-Requested-With, X-Idempotency-Key",
		AllowMethods: "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD",
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

		// Role definition helpers for authorization matrix
		roleLeadership := []string{
			string(entity.RoleAdmin),
			string(entity.RoleChairperson),
			string(entity.RoleViceChairperson),
		}
		roleFinanceManagement := []string{
			string(entity.RoleAdmin),
			string(entity.RoleChairperson),
			string(entity.RoleViceChairperson),
			string(entity.RoleTreasurer),
		}
		roleSecretaryManagement := []string{
			string(entity.RoleAdmin),
			string(entity.RoleChairperson),
			string(entity.RoleViceChairperson),
			string(entity.RoleSecretary),
		}
		roleManagement := []string{
			string(entity.RoleAdmin),
			string(entity.RoleChairperson),
			string(entity.RoleViceChairperson),
			string(entity.RoleTreasurer),
			string(entity.RoleSecretary),
		}
		roleCashbookAccess := []string{
			string(entity.RoleAdmin),
			string(entity.RoleChairperson),
			string(entity.RoleViceChairperson),
			string(entity.RoleTreasurer),
			string(entity.RoleSecretary),
			string(entity.RoleResident),
		}

		// Admin Endpoints with Granular RBAC
		adminGroup := v1.Group("/admin", authMid.RequireAuth())
		{
			// 1. Leadership & Management (ADMIN, CHAIRPERSON, VICE_CHAIRPERSON, TREASURER, SECRETARY)
			adminGroup.Get("/dashboard/stats", authMid.RequireRole(roleManagement...), appHandler.GetAdminDashboardStats)

			// Organizational Role Management (Assign / Revoke)
			adminGroup.Put("/users/:id/role", authMid.RequireRole(roleLeadership...), appHandler.AdminAssignRole)
			adminGroup.Post("/users/:id/role", authMid.RequireRole(roleLeadership...), appHandler.AdminAssignRole)

			// Sprint 3: Pengumuman RT (Admin CRUD)
			adminGroup.Post("/announcements", authMid.RequireRole(roleLeadership...), appHandler.AdminCreateAnnouncement)
			adminGroup.Put("/announcements/:id", authMid.RequireRole(roleLeadership...), appHandler.AdminUpdateAnnouncement)
			adminGroup.Delete("/announcements/:id", authMid.RequireRole(roleLeadership...), appHandler.AdminDeleteAnnouncement)

			// Sprint 4: Security Account & Assignment Management (Leadership)
			adminGroup.Get("/security/users", authMid.RequireRole(roleLeadership...), appHandler.AdminListSecurityUsers)
			adminGroup.Post("/security/users", authMid.RequireRole(roleLeadership...), appHandler.AdminCreateSecurityUser)
			adminGroup.Put("/security/users/:id/status", authMid.RequireRole(roleLeadership...), appHandler.AdminSetSecurityStatus)

			adminGroup.Get("/security/assignments", authMid.RequireRole(roleLeadership...), appHandler.AdminListSecurityAssignments)
			adminGroup.Post("/security/assignments", authMid.RequireRole(roleLeadership...), appHandler.AdminCreateSecurityAssignment)
			adminGroup.Put("/security/assignments/:id/status", authMid.RequireRole(roleLeadership...), appHandler.AdminUpdateSecurityAssignmentStatus)
			adminGroup.Delete("/security/assignments/:id", authMid.RequireRole(roleLeadership...), appHandler.AdminRevokeSecurityAssignment)

			adminGroup.Get("/neighborhoods", authMid.RequireRole(roleLeadership...), appHandler.ListNeighborhoods)

			// 2. Secretary Management (ADMIN, CHAIRPERSON, VICE_CHAIRPERSON, SECRETARY)
			// Verifikasi Warga
			adminGroup.Get("/pending-users", authMid.RequireRole(roleSecretaryManagement...), appHandler.GetPendingUsers)
			adminGroup.Post("/users/:id/approve", authMid.RequireRole(roleSecretaryManagement...), appHandler.ApproveUser)
			adminGroup.Post("/users/:id/reject", authMid.RequireRole(roleSecretaryManagement...), appHandler.RejectUser)

			// Admin Full Resident Management (CRUD)
			adminGroup.Get("/users", authMid.RequireRole(roleSecretaryManagement...), appHandler.AdminGetAllUsers)
			adminGroup.Post("/users", authMid.RequireRole(roleSecretaryManagement...), appHandler.AdminCreateUser)
			adminGroup.Put("/users/:id", authMid.RequireRole(roleSecretaryManagement...), appHandler.AdminUpdateUser)
			adminGroup.Delete("/users/:id", authMid.RequireRole(roleSecretaryManagement...), appHandler.AdminDeleteUser)
			adminGroup.Post("/users/:id/reset-password", authMid.RequireRole(roleSecretaryManagement...), appHandler.AdminResetPassword)

			// Mapping & Occupant Management
			adminGroup.Get("/houses/:id/occupants", authMid.RequireRole(roleSecretaryManagement...), appHandler.GetHouseOccupants)
			adminGroup.Get("/houses/:id/details", authMid.RequireRole(roleSecretaryManagement...), appHandler.GetHouseDetails)
			adminGroup.Get("/unassigned-residents", authMid.RequireRole(roleSecretaryManagement...), appHandler.GetUnassignedResidents)
			adminGroup.Post("/houses/:id/assign-resident", authMid.RequireRole(roleSecretaryManagement...), appHandler.AssignResident)
			adminGroup.Delete("/houses/:id/remove-resident/:user_id", authMid.RequireRole(roleSecretaryManagement...), appHandler.RemoveResident)
			adminGroup.Post("/users/:user_id/transfer-house", authMid.RequireRole(roleSecretaryManagement...), appHandler.TransferHouse)

			// Admin Family & Vehicles Management
			adminGroup.Post("/houses/:house_id/family", authMid.RequireRole(roleSecretaryManagement...), appHandler.AdminAddFamilyMember)
			adminGroup.Delete("/houses/:house_id/family/:family_id", authMid.RequireRole(roleSecretaryManagement...), appHandler.AdminDeleteFamilyMember)
			adminGroup.Post("/houses/:house_id/vehicles", authMid.RequireRole(roleSecretaryManagement...), appHandler.AdminAddVehicle)
			adminGroup.Delete("/houses/:house_id/vehicles/:vehicle_id", authMid.RequireRole(roleSecretaryManagement...), appHandler.AdminDeleteVehicle)

			// Admin Bulk Delete Houses
			adminGroup.Post("/houses/bulk-delete", authMid.RequireRole(roleSecretaryManagement...), appHandler.BulkDeleteHouses)

			// 3. Finance Management (ADMIN, CHAIRPERSON, VICE_CHAIRPERSON, TREASURER)
			// Sprint 2: Admin Billing & Payment Management
			adminGroup.Put("/payment-settings", authMid.RequireRole(roleFinanceManagement...), appHandler.AdminUpdatePaymentSettings)
			adminGroup.Post("/bills/generate", authMid.RequireRole(roleFinanceManagement...), appHandler.AdminGenerateBills)
			adminGroup.Post("/bills/generate-individual", authMid.RequireRole(roleFinanceManagement...), appHandler.AdminGenerateIndividualBill)
			adminGroup.Get("/bills/pending", authMid.RequireRole(roleFinanceManagement...), appHandler.GetAdminPendingBills)
			adminGroup.Get("/bills/summary", authMid.RequireRole(roleFinanceManagement...), appHandler.GetAdminBillsSummary)
			adminGroup.Get("/bills/eligible-residents", authMid.RequireRole(roleFinanceManagement...), appHandler.AdminGetEligibleResidents)
			adminGroup.Get("/bills/resident-periods", authMid.RequireRole(roleFinanceManagement...), appHandler.AdminGetResidentEligiblePeriods)
			adminGroup.Post("/bills/record-cash", authMid.RequireRole(roleFinanceManagement...), appHandler.AdminRecordCashPayment)
			adminGroup.Post("/bills/bulk-pay", authMid.RequireRole(roleFinanceManagement...), appHandler.AdminBulkProcessPayments)
			adminGroup.Get("/bills/:id", authMid.RequireRole(roleFinanceManagement...), appHandler.GetAdminBillDetail)
			adminGroup.Post("/bills/:id/verify", authMid.RequireRole(roleFinanceManagement...), appHandler.VerifyBillPayment)

			// Sprint 3: Admin Cashbook & Announcements
			adminGroup.Post("/cashbook/transactions", authMid.RequireRole(roleFinanceManagement...), appHandler.AdminCreateCashTransaction)
			adminGroup.Delete("/cashbook/transactions/:id", authMid.RequireRole(roleFinanceManagement...), appHandler.AdminDeleteCashTransaction)
		}

		// Sprint 3: Cashbook (Authenticated Users - Warga & Pengurus, Security Excluded)
		cashbookGroup := v1.Group("/cashbook", authMid.RequireAuth(), authMid.RequireRole(roleCashbookAccess...))
		{
			cashbookGroup.Get("/summary", appHandler.GetCashbookSummary)
			cashbookGroup.Get("/transactions", appHandler.GetCashbookTransactions)
		}

		// Sprint 3: Announcements (Authenticated Users - Warga & Admin)
		announcementsGroup := v1.Group("/announcements", authMid.RequireAuth())
		{
			announcementsGroup.Get("/", appHandler.GetAnnouncements)
			announcementsGroup.Get("/:id", appHandler.GetAnnouncementDetail)
		}

		// Houses Management (Protected for Secretary Management)
		housesGroup := v1.Group("/houses", authMid.RequireAuth(), authMid.RequireRole(roleSecretaryManagement...))
		{
			housesGroup.Get("/", appHandler.GetAllHouses)
			housesGroup.Get("/blocks", appHandler.GetDistinctBlocks)
			housesGroup.Post("/", appHandler.CreateHouse)
			housesGroup.Put("/:id", appHandler.UpdateHouse)
			housesGroup.Delete("/:id", appHandler.DeleteHouse)
			housesGroup.Post("/bulk-delete", appHandler.BulkDeleteHouses)
		}

		// Resident Billing & Payments (Sprint 2 & Cumulative Access - Any account with valid housing mapping)
		residentGroup := v1.Group("/resident", authMid.RequireAuth(), authMid.RequireHouseMapping())
		{
			residentGroup.Get("/bills", appHandler.GetResidentBills)
			residentGroup.Post("/bills/initiate", appHandler.InitiateResidentBill)
			residentGroup.Get("/bills/:id", appHandler.GetResidentBillDetail)
			residentGroup.Post("/bills/:id/pay", appHandler.SubmitBillPayment)
		}

		// Sprint 4 (US-4.3): Realtime WebSocket Engine for Security Alarm Distribution
		v1.Get("/incidents/ws", appHandler.HandleSecurityAlarmsWSUpgrade, appHandler.HandleSecurityAlarmsWS())
		v1.Get("/ws/security/alarms", appHandler.HandleSecurityAlarmsWSUpgrade, appHandler.HandleSecurityAlarmsWS())

		// Sprint 4: Emergency Incidents (Laporan Darurat & Penanganan)
		incidentsGroup := v1.Group("/incidents", authMid.RequireAuth())
		{
			// Pelaporan insiden darurat oleh warga terhubung hunian atau pengurus/admin
			incidentsGroup.Post("/", authMid.RequireHouseOrRole(roleManagement...), appHandler.ReportIncident)

			// Monitoring insiden aktif khusus security
			incidentsGroup.Get("/active", authMid.RequireRole(string(entity.RoleSecurity)), appHandler.GetActiveIncidents)

			// Badge counter kejadian aktif
			incidentsGroup.Get("/active-count", appHandler.GetActiveIncidentCount)

			// Monitoring dan riwayat insiden
			incidentsGroup.Get("/", appHandler.GetIncidents)
			incidentsGroup.Get("/:id", appHandler.GetIncidentDetail)
			incidentsGroup.Get("/:id/logs", appHandler.GetIncidentLogs)

			// Koreksi laporan oleh Admin (dengan audit trail)
			incidentsGroup.Patch("/:id/correct", authMid.RequireRole(string(entity.RoleAdmin)), appHandler.CorrectIncident)
			incidentsGroup.Put("/:id/correct", authMid.RequireRole(string(entity.RoleAdmin)), appHandler.CorrectIncident)

			// Respon penanganan oleh petugas security (Acknowledge / Respond)
			incidentsGroup.Post("/:id/acknowledge", authMid.RequireRole(string(entity.RoleSecurity)), appHandler.AcknowledgeIncident)
			incidentsGroup.Post("/:id/respond", authMid.RequireRole(string(entity.RoleSecurity)), appHandler.RespondIncident)

			// Penyelesaian insiden oleh petugas security atau pengurus leadership
			incidentsGroup.Post("/:id/resolve", authMid.RequireRole(string(entity.RoleSecurity), string(entity.RoleAdmin), string(entity.RoleChairperson), string(entity.RoleViceChairperson)), appHandler.ResolveIncident)
		}

		// Sprint 4: Security Operational
		securityGroup := v1.Group("/security", authMid.RequireAuth(), authMid.RequireRole(string(entity.RoleSecurity)))
		{
			securityGroup.Get("/my-assignments", appHandler.GetMySecurityAssignments)
			securityGroup.Post("/device-token", appHandler.RegisterSecurityDeviceToken)
			securityGroup.Post("/device-token/revoke", appHandler.RevokeSecurityDeviceToken)
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
