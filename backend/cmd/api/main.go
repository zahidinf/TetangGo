package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"
	"tetanggo-backend/internal/delivery/http"
	"tetanggo-backend/internal/delivery/http/handler"
	"tetanggo-backend/internal/delivery/http/middleware"
	"tetanggo-backend/internal/infrastructure/config"
	"tetanggo-backend/internal/infrastructure/database"
	"tetanggo-backend/internal/infrastructure/fcm"
	"tetanggo-backend/internal/infrastructure/realtime"
	"tetanggo-backend/internal/infrastructure/repository"
	"tetanggo-backend/internal/usecase/announcement"
	"tetanggo-backend/internal/usecase/auth"
	"tetanggo-backend/internal/usecase/billing"
	"tetanggo-backend/internal/usecase/cashbook"
	"tetanggo-backend/internal/usecase/dashboard"
	"tetanggo-backend/internal/usecase/house"
	"tetanggo-backend/internal/usecase/incident"
	"tetanggo-backend/internal/usecase/profile"
	"tetanggo-backend/internal/usecase/security"
)

func main() {
	log.Println("============================================")
	log.Println(" Starting TetangGo API Server (Sprint 4)")
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
	secRepo := repository.NewPostgresSecurityRepository(db)
	incidentRepo := repository.NewPostgresIncidentRepository(db)
	deviceTokenRepo := repository.NewPostgresSecurityDeviceTokenRepository(db)

	tokenService := auth.NewTokenService(cfg.JWTSecret, cfg.JWTExpirationMinutes, cfg.RefreshTokenExpDays)
	authUseCase := auth.NewAuthUseCase(userRepo, roleRepo, houseRepo, tokenService)
	houseUseCase := house.NewHouseUseCase(houseRepo, userRepo, familyRepo, vehicleRepo)
	profileUseCase := profile.NewProfileUseCase(userRepo, houseRepo, familyRepo, vehicleRepo)
	billingUseCase := billing.NewBillingUseCase(billingRepo, userRepo, houseRepo)
	dashboardUseCase := dashboard.NewDashboardUseCase(dashboardRepo)
	cashbookUseCase := cashbook.NewCashbookUseCase(cashbookRepo)
	announcementUseCase := announcement.NewAnnouncementUseCase(announcementRepo)
	securityUseCase := security.NewSecurityUseCase(secRepo, userRepo, roleRepo)
	incidentUseCase := incident.NewIncidentUseCase(incidentRepo, secRepo, userRepo, houseRepo)

	authMiddleware := middleware.NewAuthMiddleware(tokenService, userRepo)
	appHandler := handler.NewAppHandler(
		db,
		authUseCase,
		houseUseCase,
		profileUseCase,
		billingUseCase,
		dashboardUseCase,
		cashbookUseCase,
		announcementUseCase,
		securityUseCase,
		incidentUseCase,
	)

	// 4. Realtime Engine (Sprint 4 US-4.3)
	realtimeHub := realtime.NewHub()
	go realtimeHub.Run()

	publisher := realtime.NewRealtimeEventPublisher(realtimeHub)
	incidentUseCase.SetPublisher(publisher)

	// US-4.7: FCM Push Notification Service
	fcmProjectID, fcmApiKey := fcm.LoadFCMConfigFromEnv()
	fcmService := fcm.NewFCMService(deviceTokenRepo, fcmProjectID, fcmApiKey)
	incidentUseCase.SetPushNotification(deviceTokenRepo, fcmService)

	appHandler.SetRealtime(realtimeHub, tokenService, secRepo, userRepo)
	appHandler.SetDeviceTokenRepo(deviceTokenRepo)

	// 5. Router & Start
	router := http.SetupRouter(appHandler, authMiddleware)

	// Graceful Shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigChan
		log.Println("Gracefully stopping TetangGo API server...")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		_ = realtimeHub.Shutdown(ctx)
		_ = router.ShutdownWithContext(ctx)
	}()

	addr := ":" + cfg.Port
	log.Printf("TetangGo server listening on http://localhost%s\n", addr)
	if err := router.Listen(addr); err != nil {
		log.Printf("Server stopped: %v\n", err)
	}
}
