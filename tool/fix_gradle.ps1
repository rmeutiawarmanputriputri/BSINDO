# Memperbaiki cache Gradle yang rusak ("Could not read workspace metadata").
#   powershell -ExecutionPolicy Bypass -File tool\fix_gradle.ps1
if (Test-Path android\gradlew.bat) { Push-Location android; .\gradlew.bat --stop; Pop-Location }
$cache = Join-Path $env:USERPROFILE ".gradle\caches"
Get-ChildItem $cache -Directory -ErrorAction SilentlyContinue |
  ForEach-Object { $t = Join-Path $_.FullName "transforms"; if (Test-Path $t) { Remove-Item -Recurse -Force $t } }
flutter clean
flutter pub get
Write-Host "Cache dibersihkan. Jalankan lagi tool\check.ps1"
