# Build APK RELEASE BISINDO di komputer Anda (Windows).
#   powershell -ExecutionPolicy Bypass -File tool\release.ps1
# Prasyarat: Flutter 3.47+, Android SDK, env\dev.json (URL + anon key), keystore
# (tool\create_keystore.ps1). Log setiap langkah disimpan di folder logs\.
$ErrorActionPreference = "Continue"
New-Item -ItemType Directory -Force logs | Out-Null

if (-not (Test-Path "env\dev.json")) { Write-Host "env\dev.json belum ada. Salin env\example.json lalu isi SUPABASE_URL & SUPABASE_ANON_KEY." -ForegroundColor Red; exit 1 }
if (-not (Test-Path "android\key.properties")) {
  Write-Host "android\key.properties belum ada → jalankan tool\create_keystore.ps1 dulu (atau set BISINDO_ALLOW_DEBUG_SIGNING=true untuk APK uji)." -ForegroundColor Yellow
  if ($env:BISINDO_ALLOW_DEBUG_SIGNING -ne "true") { exit 1 }
}

function Step($name, $cmd, [switch]$Fatal) {
  Write-Host "== $name"
  $log = "logs\$name.txt"
  cmd /c "$cmd > $log 2>&1"
  if ($LASTEXITCODE -eq 0) { Write-Host "   LULUS ($log)" -ForegroundColor Green; return $true }
  Write-Host "   GAGAL ($log)" -ForegroundColor Red; Get-Content $log -Tail 25
  if ($Fatal) { Write-Host "Berhenti. Kirim folder logs\ ke pengembang." -ForegroundColor Red; exit 1 }
  return $false
}

Step "01_pub_get" "flutter pub get" -Fatal | Out-Null
Step "02_format" "dart format --output=none --set-exit-if-changed lib test" | Out-Null
Step "03_analyze" "flutter analyze --no-fatal-infos" -Fatal | Out-Null
Step "04_test" "flutter test --exclude-tags golden" | Out-Null
Step "05_build" "flutter build apk --release --dart-define-from-file=env/dev.json" -Fatal | Out-Null

$apk = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apk) {
  $ver = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value
  $size = [math]::Round((Get-Item $apk).Length / 1MB, 1)
  Write-Host "APK v$ver : $((Resolve-Path $apk).Path) ($size MB)" -ForegroundColor Green
}
