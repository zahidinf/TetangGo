# Panduan Konfigurasi & Integrasi Firebase Cloud Messaging (FCM) untuk Pos Satpam TetangGo (US-4.7)

Dokumen ini menjelaskan arsitektur fallback push notification FCM, manajemen token perangkat Security, tata cara konfigurasi manual Firebase di backend dan frontend, serta batasan teknis platform OS.

---

## 1. Arsitektur Fallback Push Notification

1. **Dual-Channel Alerting (WebSocket + FCM Push)**:
   - **Kanal Utama**: WebSocket terautentikasi (`/api/v1/ws/security/alarms`) untuk transmisi instan sub-detik saat layar pos satpam aktif.
   - **Kanal Fallback**: Firebase Cloud Messaging (FCM) v1 HTTP API dengan prioritas `HIGH` (`priority: HIGH` pada Android, `apns-priority: 10` dan `content-available: 1` pada iOS/APNs).
   - Pengiriman FCM berjalan secara asinkron (*goroutine*) saat insiden darurat baru (`INCIDENT_CREATED`) dibuat melalui endpoint `POST /api/v1/incidents`.
   - **Non-blocking Fault Isolation**: Kegagalan koneksi ke server FCM atau ketiadaan credential Firebase **tidak pernah** membatalkan atau me-rollback transaksi penyimpanan insiden di database.

2. **Isolasi Data & RBAC Perangkat**:
   - Token perangkat disimpan dalam tabel `security_device_tokens` dan terikat murni ke identitas pengguna satpam (`user_id`) serta ID perangkat fisik (`device_id`), **bukan** ke data hunian (`houses`).
   - Query token push dilakukan melalui `GetActiveTokensForNeighborhood(neighborhood_id)`: hanya perangkat milik satpam dengan akun `active` dan surat tugas aktif (`security_assignments.is_active = true`) di lingkungan tersebut yang menerima notifikasi.
   - Satpam dari lingkungan/perumahan lain tidak menerima push insiden tersebut.

3. **Minimal Safe Payload**:
   - Payload FCM hanya membawa metadata non-sensitif:
     ```json
     {
       "type": "EMERGENCY_INCIDENT",
       "incident_id": "88",
       "category": "KEJAHATAN",
       "neighborhood_id": "1",
       "status": "ACTIVE",
       "priority": "HIGH"
     }
     ```
   - Data sensitif seperti nama warga pelapor, blok/nomor rumah, koordinat GPS akurat, dan nomor telepon darurat **wajib** diambil kembali via API terautentikasi `GET /api/v1/incidents/:id`.

4. **Penanganan Token Invalid & Deduplikasi**:
   - Token FCM yang kadaluarsa atau di-uninstall (`UNREGISTERED`, `NOT_FOUND`, `INVALID_REGISTRATION`) secara otomatis dinonaktifkan (`is_active = false`) dari database PostgreSQL untuk mencegah traffic sia-sia.
   - Frontend memverifikasi ID notifikasi dan tidak membuat dialog atau entri insiden ganda jika notifikasi yang sama diterima berulang.

---

## 2. Konfigurasi Manual Firebase di Backend (Go)

Backend TetangGo tidak menyertakan credential Firebase palsu atau file service account JSON di git repository demi mematuhi standar keamanan rahasia.

Untuk mengaktifkan pengiriman nyata:
1. Buka [Firebase Console](https://console.firebase.google.com/) dan buat/pilih project TetangGo.
2. Masuk ke **Project Settings** > **Service accounts**.
3. Generate private key baru (format JSON).
4. Di file `.env` backend atau environment server production, tambahkan variabel berikut:
   ```env
   # Project ID dari Firebase Console
   FIREBASE_PROJECT_ID=tetanggo-production-project-id
   
   # Server API Key atau OAuth2 access token
   FIREBASE_SERVER_KEY=ya29.c.b0...your-access-token...
   ```
5. Jika variabel `FIREBASE_PROJECT_ID` tidak diatur (atau disetel `mock`), backend otomatis berjalan dalam mode aman (mock delivery) tanpa crash dan seluruh test unit tetap lulus.

---

## 3. Konfigurasi Manual Firebase di Flutter (Android & iOS)

Saat aplikasi mobile Android/iOS di-build ke perangkat nyata:

### Android
1. Download file `google-services.json` dari Firebase Console.
2. Tempatkan di direktori `frontend/android/app/google-services.json`.
3. Tambahkan plugin `com.google.gms.google-services` di `android/build.gradle` dan `android/app/build.gradle`.
4. Konfigurasikan Notification Channel berprioritas tinggi pada Android:
   - Channel ID: `tetanggo_emergency_alarms`
   - Importance: `Importance.max`
   - Sound: File audio sirene darurat di `android/app/src/main/res/raw/emergency_siren.wav`

### iOS
1. Download `GoogleService-Info.plist` dan letakkan di `frontend/ios/Runner/GoogleService-Info.plist`.
2. Aktifkan **Push Notifications** dan **Background Modes** (Remote notifications) pada Xcode Signing & Capabilities.
3. Upload APNs Authentication Key (.p8) ke Firebase Console di bawah Project Settings > Cloud Messaging.

---

## 4. Keterbatasan Platform: DND, Silent Mode, & Background Execution

1. **Do Not Disturb (DND) / Mode Jangan Ganggu**:
   - Di Android, notifikasi standar tidak akan membunyikan suara saat DND aktif kecuali aplikasi mendapatkan izin khusus **DND Policy Access** (`android.permission.ACCESS_NOTIFICATION_POLICY`) atau pengguna secara eksplisit memasukkan TetangGo ke dalam daftar aplikasi prioritas (*Priority Exceptions*).
   - Di iOS, membunyikan suara sirene menembus mode Silent/DND memerlukan sertifikat entitlement khusus dari Apple yaitu **Critical Alerts Entitlement** (`com.apple.developer.usernotifications.critical-alerts`). Tanpa izin resmi dari Apple Developer Program, notifikasi hanya akan bergetar dan muncul di notification center tanpa suara jika ponsel di-mute.

2. **Aggressive Battery Optimization & OEM Background Killer**:
   - Produsen smartphone (seperti Xiaomi/MIUI, Samsung, Oppo/ColorOS) memiliki manajemen RAM agresif yang dapat membekukan (*freeze*) atau mematikan proses background aplikasi pos satpam jika tidak dibuka dalam beberapa jam.
   - **Rekomendasi Operasional Satpam**:
     - Atur opsi baterai TetangGo ke **"No restrictions"** / **"Tidak ada batasan"** pada pengaturan aplikasi Android.
     - Kunci aplikasi (*lock app*) pada tampilan Recent Apps agar tidak ter-kill oleh pembersih memori otomatis.
     - Nyalakan opsi **Autostart** / **Mulai otomatis**.

3. **Background Audio & Siren Restriction**:
   - Sistem operasi seluler modern membatasi pemutaran file audio panjang saat aplikasi berada di latar belakang (*backgrounded*). Oleh karena itu, suara sirene looping utama dijalankan saat layar pos satpam aktif (foreground / standby) atau saat petugas menekan notifikasi push untuk membuka aplikasi.
