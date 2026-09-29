package main

import (
	"log"
	"path/filepath"
	"tetanggo-backend/internal/infrastructure/config"
	"tetanggo-backend/internal/infrastructure/database"
)

func main() {
	log.Println("--- TetangGo Database Migration CLI ---")
	cfg := config.LoadConfig()

	migrationsDir := filepath.Join("internal", "infrastructure", "database", "migrations")
	db, err := database.EnsureDatabaseAndMigrate(cfg, migrationsDir)
	if err != nil {
		log.Fatalf("Migration failed: %v", err)
	}
	defer db.Close()

	log.Println("Database migration and initial seeding completed successfully!")
}
