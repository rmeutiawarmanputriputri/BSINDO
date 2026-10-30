# Membuat keystore RELEASE BISINDO (sekali saja) + android\key.properties.
#   powershell -ExecutionPolicy Bypass -File tool\create_keystore.ps1
#
# PENTING:
#  - Keystore disimpan di LUAR folder proyek: %USERPROFILE%\.bisindo\bisindo-release.jks
#  - CADANGKAN file .jks + password di 2 tempat aman (mis. password manager + flashdisk).
#    Jika hilang, aplikasi TIDAK BISA di-update lagi dengan nama paket yang sama.
#  - android\key.properties & *.jks sudah ada di .gitignore — jangan di-commit / dikirim.
$ErrorActionPreference = "Stop"

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool -and $env:JAVA_HOME) { $keytool = Get-Command (Join-Path $env:JAVA_HOME "bin\keytool.exe") -ErrorAction SilentlyContinue }
if (-not $keytool) {
  $studioJbr = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
  if (Test-Path $studioJbr) { $keytool = Get-Command $studioJbr }
}
if (-not $keytool) { throw "keytool tidak ditemukan. Pasang JDK 17 atau Android Studio, lalu ulangi." }

$dir = Join-Path $env:USERPROFILE ".bisindo"
$jks = Join-Path $dir "bisindo-release.jks"
New-Item -ItemType Directory -Force $dir | Out-Null
if (Test-Path $jks) { throw "Keystore sudah ada: $jks. Jangan membuat ulang — pakai yang ada." }

$alias = "bisindo"
$sec = Read-Host "Buat password keystore (min. 8 karakter)" -AsSecureString
$sec2 = Read-Host "Ulangi password" -AsSecureString
$p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec2))
if ($p1 -ne $p2 -or $p1.Length -lt 8) { throw "Password tidak sama atau kurang dari 8 karakter." }
$cn = Read-Host "Nama pemilik/organisasi untuk sertifikat (mis. Idemusistemsinergi)"

& $keytool.Source -genkeypair -v -keystore $jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 `
  -alias $alias -storepass $p1 -keypass $p1 -dname "CN=$cn, O=$cn, C=ID"
if ($LASTEXITCODE -ne 0) { throw "keytool gagal." }

$props = @"
storePassword=$p1
keyPassword=$p1
keyAlias=$alias
storeFile=$($jks -replace '\\','/')
"@
Set-Content -Path "android\key.properties" -Value $props -Encoding ASCII
Write-Host "Keystore: $jks" -ForegroundColor Green
Write-Host "android\key.properties dibuat (JANGAN di-commit)." -ForegroundColor Green
Write-Host "SEKARANG: cadangkan $jks dan password Anda di 2 tempat aman." -ForegroundColor Yellow
& $keytool.Source -list -v -keystore $jks -storepass $p1 | Select-String "SHA256"
