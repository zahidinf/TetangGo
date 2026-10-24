package database

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"
	"tetanggo-backend/internal/infrastructure/config"

	_ "github.com/jackc/pgx/v5/stdlib"
	"golang.org/x/crypto/bcrypt"
)

func EnsureDatabaseAndMigrate(cfg *config.Config, migrationsDir string) (*sql.DB, error) {
	// 1. Initial maintenance connection to default database (postgres)
	maintenanceDSN := fmt.Sprintf(
		"postgres://%s:%s@%s:%s/postgres?sslmode=%s",
		cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort, cfg.DBSSLMode,
	)

	log.Printf("[DB Init] Connecting to maintenance database 'postgres' at %s:%s...", cfg.DBHost, cfg.DBPort)
	maintDB, err := sql.Open("pgx", maintenanceDSN)
	if err != nil {
		return nil, fmt.Errorf("failed to open maintenance DB connection: %w", err)
	}
	defer maintDB.Close()

	if err := maintDB.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping maintenance DB: %w", err)
	}

	// 2. Query check if target database exists
	var exists bool
	checkQuery := "SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = $1);"
	err = maintDB.QueryRow(checkQuery, cfg.DBName).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("failed checking database existence: %w", err)
	}

	// 3. If not exists, CREATE DATABASE
	if !exists {
		log.Printf("[DB Init] Database '%s' not found. Creating database...", cfg.DBName)
		// datname cannot be parameterized in CREATE DATABASE
		_, err = maintDB.Exec(fmt.Sprintf("CREATE DATABASE %s;", cfg.DBName))
		if err != nil {
			return nil, fmt.Errorf("failed creating database %s: %w", cfg.DBName, err)
		}
		log.Printf("[DB Init] Database '%s' successfully created!", cfg.DBName)
	} else {
		log.Printf("[DB Init] Database '%s' already exists.", cfg.DBName)
	}

	// 4. Close maintenance connection (deferred) and connect directly to tetanggo_db
	appDSN := fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=%s",
		cfg.DBUser, cfg.DBPassword, cfg.DBHost, cfg.DBPort, cfg.DBName, cfg.DBSSLMode,
	)

	log.Printf("[DB Init] Connecting to target database '%s'...", cfg.DBName)
	appDB, err := sql.Open("pgx", appDSN)
	if err != nil {
		return nil, fmt.Errorf("failed opening target DB connection: %w", err)
	}

	if err := appDB.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping target DB: %w", err)
	}

	// 5. Configure connection pool
	appDB.SetMaxOpenConns(25)
	appDB.SetMaxIdleConns(10)
	appDB.SetConnMaxLifetime(15 * time.Minute)
	appDB.SetConnMaxIdleTime(5 * time.Minute)

	// 6. Run SQL migrations
	if err := RunMigrations(appDB, migrationsDir); err != nil {
		return nil, fmt.Errorf("failed running migrations: %w", err)
	}

	// 7. Seed initial data
	if err := SeedInitialData(appDB); err != nil {
		return nil, fmt.Errorf("failed seeding initial data: %w", err)
	}

	return appDB, nil
}

func RunMigrations(db *sql.DB, migrationsDir string) error {
	log.Printf("[DB Migration] Scanning migration files in '%s'...", migrationsDir)
	entries, err := os.ReadDir(migrationsDir)
	if err != nil {
		return fmt.Errorf("cannot read migrations dir: %w", err)
	}

	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
		version VARCHAR(255) PRIMARY KEY,
		applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
	);`)
	if err != nil {
		return fmt.Errorf("failed creating schema_migrations table: %w", err)
	}

	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".up.sql") {
			version := entry.Name()
			var alreadyApplied bool
			err := db.QueryRow("SELECT EXISTS(SELECT 1 FROM schema_migrations WHERE version = $1)", version).Scan(&alreadyApplied)
			if err != nil {
				return fmt.Errorf("failed checking migration status for %s: %w", version, err)
			}
			if alreadyApplied {
				continue
			}

			fullPath := filepath.Join(migrationsDir, entry.Name())
			log.Printf("[DB Migration] Executing %s...", entry.Name())
			sqlBytes, err := os.ReadFile(fullPath)
			if err != nil {
				return fmt.Errorf("error reading %s: %w", fullPath, err)
			}

			if _, err := db.Exec(string(sqlBytes)); err != nil {
				return fmt.Errorf("error executing %s: %w", entry.Name(), err)
			}

			if _, err := db.Exec("INSERT INTO schema_migrations (version) VALUES ($1)", version); err != nil {
				return fmt.Errorf("error recording migration %s: %w", version, err)
			}
		}
	}

	log.Printf("[DB Migration] Migrations applied successfully.")
	return nil
}

func SeedInitialData(db *sql.DB) error {
	// Roles: ADMIN, CHAIRPERSON, VICE_CHAIRPERSON, TREASURER, SECRETARY, RESIDENT
	roles := []string{"ADMIN", "CHAIRPERSON", "VICE_CHAIRPERSON", "TREASURER", "SECRETARY", "RESIDENT"}
	for _, role := range roles {
		_, err := db.Exec("INSERT INTO roles (name) VALUES ($1) ON CONFLICT (name) DO NOTHING;", role)
		if err != nil {
			return fmt.Errorf("failed inserting role %s: %w", role, err)
		}
	}

	// Default Admin user check & seed
	var adminCount int
	err := db.QueryRow("SELECT COUNT(*) FROM users WHERE email = $1", "admin@tetanggo.id").Scan(&adminCount)
	if err != nil {
		return fmt.Errorf("failed checking admin user: %w", err)
	}

	if adminCount == 0 {
		var roleID int64
		err := db.QueryRow("SELECT id FROM roles WHERE name = 'ADMIN'").Scan(&roleID)
		if err != nil {
			return fmt.Errorf("failed resolving ADMIN role ID: %w", err)
		}

		hash, err := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
		if err != nil {
			return fmt.Errorf("failed hashing admin password: %w", err)
		}

		insertUser := `
			INSERT INTO users (name, phone, email, password_hash, role_id, house_id, status, created_at, updated_at)
			VALUES ($1, $2, $3, $4, $5, NULL, 'active', NOW(), NOW())
			ON CONFLICT (email) DO NOTHING;
		`
		_, err = db.Exec(insertUser, "Admin RT TetangGo", "081234567890", "admin@tetanggo.id", string(hash), roleID)
		if err != nil {
			return fmt.Errorf("failed seeding admin user: %w", err)
		}
		log.Println("[DB Seed] Seeded default Admin: admin@tetanggo.id (password: password123)")
	} else {
		log.Println("[DB Seed] Default Admin already exists.")
	}

	return nil
}
