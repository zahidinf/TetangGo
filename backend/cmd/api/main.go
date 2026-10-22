package main

import (
	"log"
	"path/filepath"
	"tetanggo-backend/internal/delivery/http"
	"tetanggo-backend/internal/delivery/http/handler"
	"tetanggo-backend/internal/delivery/http/middleware"
	"tetanggo-backend/internal/infrastructure/config"
	"tetanggo-backend/internal/infrastructure/database"
	"tetanggo-backend/internal/infrastructure/repository"
	"tetanggo-backend/internal/usecase/announcement"
	"tetanggo-backend/internal/usecase/auth"
	"tetanggo-backend/internal/usecase/billing"
	"tetanggo-backend/internal/usecase/cashbook"
	"tetanggo-backend/internal/usecase/dashboard"
	"tetanggo-backend/internal/usecase/house"
	"tetanggo-backend/internal/usecase/profile"
)

func main() {
	log.Println("============================================")
	log.Println(" Starting TetangGo API Server (Sprint 3)")
	log.Println(" 'Tetangga Kompak, Lingkungan Terjaga'")
	log.Println("============================================")

	// 1. Config
	cfg := config.LoadConfig()

	// 2. Automated Database Init & Migration
	migrationsDir := filepath.Join("internal", "infrastructure", "database", "migrations")
	db, err := database.EnsureDatabaseAndMigrate(cfg, migrationsDir)
	if err != nil {
		log.Fatalf("Database initialization failed: %v", err)
	}
	defer db.Close()

	// 3. Dependency Injection
	userRepo := repository.NewPostgresUserRepository(db)
	roleRepo := repository.NewPostgresRoleRepository(db)
	houseRepo := repository.NewPostgresHouseRepository(db)
	familyRepo := repository.NewPostgresFamilyRepository(db)
	vehicleRepo := repository.NewPostgresVehicleRepository(db)
	billingRepo := repository.NewPostgresBillingRepository(db)
	dashboardRepo := repository.NewPostgresDashboardRepository(db)
	cashbookRepo := repository.NewPostgresCashbookRepository(db)
	announcementRepo := repository.NewPostgresAnnouncementRepository(db)

	tokenService := auth.NewTokenService(cfg.JWTSecret, cfg.JWTExpirationMinutes, cfg.RefreshTokenExpDays)
	authUseCase := auth.NewAuthUseCase(userRepo, roleRepo, houseRepo, tokenService)
	houseUseCase := house.NewHouseUseCase(houseRepo, userRepo, familyRepo, vehicleRepo)
	profileUseCase := profile.NewProfileUseCase(userRepo, houseRepo, familyRepo, vehicleRepo)
	billingUseCase := billing.NewBillingUseCase(billingRepo, userRepo, houseRepo)
	dashboardUseCase := dashboard.NewDashboardUseCase(dashboardRepo)
	cashbookUseCase := cashbook.NewCashbookUseCase(cashbookRepo)
	announcementUseCase := announcement.NewAnnouncementUseCase(announcementRepo)

	authMiddleware := middleware.NewAuthMiddleware(tokenService)
	appHandler := handler.NewAppHandler(
		db,
		authUseCase,
		houseUseCase,
		profileUseCase,
		billingUseCase,
		dashboardUseCase,
		cashbookUseCase,
		announcementUseCase,
	)

	// 4. Router & Start
	router := http.SetupRouter(appHandler, authMiddleware)

	addr := ":" + cfg.Port
	log.Printf("TetangGo server listening on http://localhost%s\n", addr)
	if err := router.Listen(addr); err != nil {
		log.Fatalf("Server stopped with error: %v", err)
	}
}
