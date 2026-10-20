# Validasi lengkap + build APK, keluaran disimpan di folder logs\.
#   powershell -ExecutionPolicy Bypass -File tool\check.ps1
$ErrorActionPreference = "Continue"
New-Item -ItemType Directory -Force logs | Out-Null

function Step($name, $cmd) {
  Write-Host "== $name"
  $log = "logs\$name.txt"
  cmd /c "$cmd > $log 2>&1"
  if ($LASTEXITCODE -eq 0) { Write-Host "   LULUS ($log)" -ForegroundColor Green }
  else { Write-Host "   GAGAL ($log)" -ForegroundColor Red; Get-Content $log -Tail 25 }
}

Step "01_format" "dart format lib test"
Step "02_analyze" "flutter analyze"
Step "03_test" "flutter test --exclude-tags golden"
Step "04_golden" "flutter test --update-goldens test/goldens"
Step "05_build" "flutter build apk --debug --dart-define-from-file=env/dev.json"

$apk = "build\app\outputs\flutter-apk\app-debug.apk"
if (Test-Path $apk) {
  $size = [math]::Round((Get-Item $apk).Length / 1MB, 1)
  Write-Host "APK: $((Resolve-Path $apk).Path) ($size MB)" -ForegroundColor Green
} else {
  Write-Host "APK belum ada. Bila error 'Could not read workspace metadata', jalankan tool\fix_gradle.ps1" -ForegroundColor Yellow
}
Write-Host "Kirim isi folder logs\ bila ada yang GAGAL."
