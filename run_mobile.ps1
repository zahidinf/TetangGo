Write-Host "=== Menyiapkan Koneksi ke Smartphone TetangGo ===" -ForegroundColor Cyan

# 1. Reverse port 8080 & 8000 ke HP
Write-Host "Mengarahkan port 8080 dan 8000 (adb reverse)..." -ForegroundColor Yellow
adb -s 192.168.18.124:42985 reverse tcp:8080 tcp:8080
adb -s 192.168.18.124:42985 reverse tcp:8000 tcp:8000

# 2. Cek koneksi device dan jalankan aplikasi
$device = flutter devices | Select-String "192.168.18.124:42985|V2427"
if ($device) {
    Write-Host "Smartphone V2427 (192.168.18.124:42985) terdeteksi!" -ForegroundColor Green
    Write-Host "Memulai kompilasi dan menjalankan TetangGo..." -ForegroundColor Cyan
    Set-Location -Path "$PSScriptRoot\frontend" -ErrorAction SilentlyContinue
    flutter run -d 192.168.18.124:42985
} else {
    Write-Host "Perangkat tidak ditemukan di flutter devices." -ForegroundColor Red
    Write-Host "Pastikan Wireless Debugging di HP aktif dan IP/Port sudah sesuai." -ForegroundColor Yellow
}
