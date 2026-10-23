# TetangGo (Sprint 0)
> *"Tetangga Kompak, Lingkungan Terjaga"*

Platform digitalisasi lingkungan perumahan/cluster yang mengedepankan kekompakan warga dan keamanan lingkungan:
- Transparansi buku kas RT
- Iuran bulanan praktis (transfer bank manual + upload bukti struk)
- Tombol siaga darurat (*Panic Button*)
- Papan pengumuman resmi terpadu
- Buku tamu digital pos satpam

---

## 1. Arsitektur & Teknologi

### Backend (Go 1.22+ & Clean Architecture)
- **Framework:** Fiber v2 (`github.com/gofiber/fiber/v2`)
- **Driver Database:** `pgx/v5` (`github.com/jackc/pgx/v5`)
- **Keamanan:** JWT (`github.com/golang-jwt/jwt/v5`), Bcrypt (`golang.org/x/crypto/bcrypt`)
- **Database Engine:** PostgreSQL lokal pada port 5432 (Database: `tetanggo_db`)
- **Automated Bootstrap:** Auto-detect / Auto-create `tetanggo_db` via maintenance DB `postgres`, auto-migration SQL schema, dan seeding user admin default.

### Frontend (Flutter 3.x - Feature-First)
- **State Management:** BLoC (`flutter_bloc`)
- **Routing:** `go_router`
- **HTTP Client:** `dio` dengan custom `AuthInterceptor` (Bearer Token)
- **Secure Storage:** `flutter_secure_storage`
- **Platform Support:** Android, iOS, Web

---

## 2. Struktur Direktori Proyek

```
TetangGo/
├── backend/
│   ├── cmd/
│   │   ├── api/
│   │   │   └── main.go                 # Entrypoint server API TetangGo
│   │   └── migrate/
│   │       └── main.go                 # Standalone migration CLI runner
│   ├── internal/
│   │   ├── domain/
│   │   │   ├── entity/models.go        # Entity User, Role, House
│   │   │   └── repository/interfaces.go# Interface UserRepository, RoleRepository
│   │   ├── usecase/
│   │   │   └── auth/
│   │   │       ├── auth_usecase.go     # Logika bisnis autentikasi
│   │   │       └── jwt_service.go      # Generate & validasi JWT, Bcrypt
│   │   ├── infrastructure/
│   │   │   ├── config/config.go        # Parser .env
│   │   │   ├── database/
│   │   │   │   ├── database.go         # Auto-create DB, migration & seed runner
│   │   │   │   └── migrations/
│   │   │   │       ├── 000001_init_schema.up.sql
│   │   │   │       └── 000002_seed_initial_data.up.sql
│   │   │   └── repository/
│   │   │       ├── user_repository.go
│   │   │       └── role_repository.go
│   │   └── delivery/
│   │       └── http/
│   │           ├── handler/app_handler.go
│   │           ├── middleware/auth_middleware.go
│   │           └── router.go
│   ├── .env
│   ├── .env.example
│   └── go.mod
└── frontend/
    ├── lib/
    │   ├── core/
    │   │   ├── constants/api_constants.dart
    │   │   ├── network/
    │   │   │   ├── auth_interceptor.dart
    │   │   │   └── dio_client.dart
    │   │   ├── router/app_router.dart
    │   │   ├── storage/secure_storage_service.dart
    │   │   └── theme/app_theme.dart
    │   ├── features/
    │   │   └── auth/
    │   │       ├── domain/models/user_model.dart
    │   │       ├── data/auth_repository.dart
    │   │       └── presentation/
    │   │           ├── bloc/
    │   │           │   ├── auth_bloc.dart
    │   │           │   ├── auth_event.dart
    │   │           │   └── auth_state.dart
    │   │           └── screens/
    │   │               ├── splash_screen.dart
    │   │               ├── login_screen.dart
    │   │               └── dashboard_screen.dart
    │   └── main.dart
    └── pubspec.yaml
```

---

## 3. Akun Bawaan (Seed Data Sprint 0)

| Role | Email | No HP | Password |
|---|---|---|---|
| **Admin RT** | `admin@tetanggo.id` | `081234567890` | `password123` |

---

## 4. Cara Menjalankan Backend (Go)

1. Pastikan PostgreSQL lokal aktif di port `5432` dengan user/password sesuai `.env` (default: `postgres`/`postgres`).
2. Masuk ke direktori backend:
   ```bash
   cd backend
   ```
3. Unduh dependensi:
   ```bash
   go mod download
   # atau go mod tidy
   ```
4. Jalankan server API (skrip otomatis membuat database `tetanggo_db`, migrasi tabel, dan seed admin):
   ```bash
   go run cmd/api/main.go
   ```
   *Atau jika hanya ingin menjalankan migrasi:*
   ```bash
   go run cmd/migrate/main.go
   ```
5. Endpoint pengujian:
   - `GET http://localhost:8080/health`
   - `POST http://localhost:8080/api/v1/auth/login`
   - `GET http://localhost:8080/api/v1/profile` (dengan header `Authorization: Bearer <token>`)

---

## 5. Cara Menjalankan Frontend (Flutter)

1. Masuk ke direktori frontend:
   ```bash
   cd frontend
   ```
2. Ambil paket:
   ```bash
   flutter pub get
   ```
3. Jalankan di platform target:
   ```bash
   # Jalankan di Chrome / Web
   flutter run -d chrome

   # Jalankan di Android Emulator
   flutter run -d android
   ```

---

## 6. Lisensi / License

TetangGo is publicly available for viewing, learning, modification, and sharing under the terms of the [PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0/).

- **Noncommercial use only:** Commercial use is not permitted under this license.
- **Full terms:** Users must read the [`LICENSE`](LICENSE) file to understand permitted uses and restrictions.
