# Menyiapkan proyek di Windows (jalankan dari folder bisindo_app):
#   powershell -ExecutionPolicy Bypass -File tool\setup.ps1
$ErrorActionPreference = "Stop"
if (-not (Test-Path pubspec.yaml)) { throw "Jalankan dari folder bisindo_app (yang berisi pubspec.yaml)." }

Write-Host "== flutter create (hanya menambah berkas yang belum ada)"
flutter create . --project-name bisindo_app --org com.example --platforms android
# Hapus MainActivity duplikat buatan templat (yang dipakai: com/example/bisindo).
if (Test-Path android\app\src\main\kotlin\com\example\bisindo_app) {
  Remove-Item -Recurse -Force android\app\src\main\kotlin\com\example\bisindo_app
}

if (-not (Test-Path env\dev.json)) {
  Copy-Item env\example.json env\dev.json
  Write-Host "!! env\dev.json dibuat dari contoh. Isi SUPABASE_URL dan SUPABASE_ANON_KEY proyek DEV."
}

Write-Host "== flutter pub get"
flutter pub get
Write-Host "Selesai. Lanjut: powershell -ExecutionPolicy Bypass -File tool\check.ps1"
