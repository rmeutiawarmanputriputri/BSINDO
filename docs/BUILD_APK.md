# Cara mendapatkan APK BISINDO v1.1.0

> **Wajib sebelum memasang APK 1.1.0:** migrasi database 0110–0120 sudah diterapkan di Supabase (lihat `docs/CMS_SETUP.md` §1).
> Aplikasi 1.1.0 membaca kolom/tabel baru. Tanpa migrasi, halaman materi akan menampilkan error.

## Cara A — GitHub Actions (tanpa Flutter di komputer)

1. Kirim (push) source ini ke repo GitHub Anda.
2. Di repo: **Settings → Secrets and variables → Actions → New repository secret**, lalu isi:
   - `SUPABASE_URL` = URL proyek
   - `SUPABASE_ANON_KEY` = publishable/anon key (**jangan** service_role)
   - *(disarankan)* `KEYSTORE_BASE64` dan `KEYSTORE_PASSWORD`. Lihat bagian Keystore di bawah.
3. Buka tab **Actions → Android APK**. Workflow berjalan otomatis setiap ada push ke `main`, atau jalankan manual lewat **Run workflow**.
4. Setelah selesai (± 10–15 menit), buka run tersebut, lalu di bagian **Artifacts** unduh `bisindo-apk`. Ekstrak ZIP-nya untuk mendapatkan `BISINDO-1.1.0+2-….apk`.
   - Nama berakhiran `-release` berarti ditandatangani keystore Anda (siap dibagikan).
   - Nama berakhiran `-debug-uji` berarti ditandatangani debug key acak milik server GitHub. Ini **khusus uji**: setiap build baru harus di-*uninstall* dulu sebelum dipasang.

Jika langkah **flutter analyze** atau **build** merah, buka langkahnya lalu salin 30 baris terakhir log dan kirim ke pengembang.

## Cara B — Komputer sendiri (Windows)

```
powershell -ExecutionPolicy Bypass -File tool\create_keystore.ps1   # sekali saja
powershell -ExecutionPolicy Bypass -File tool\release.ps1
```
APK: `build\app\outputs\flutter-apk\app-release.apk`. Log setiap langkah tersimpan di folder `logs\`.

## Keystore (sekali, untuk APK resmi)

1. Jalankan `tool\create_keystore.ps1`. Hasilnya adalah `%USERPROFILE%\.bisindo\bisindo-release.jks` dan `android\key.properties`.
2. **Cadangkan** file `.jks` beserta password-nya di dua tempat aman. Jika hilang, aplikasi tidak bisa di-update lagi.
3. Untuk GitHub Actions, salin keystore dalam bentuk base64 ke clipboard dengan PowerShell:
   ```
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.bisindo\bisindo-release.jks")) | Set-Clipboard
   ```
   Tempel hasilnya sebagai secret `KEYSTORE_BASE64`, lalu isi `KEYSTORE_PASSWORD` dengan password-nya.

## Memasang di HP

- APK 1.0.0 lama ditandatangani kunci lain, jadi **uninstall aplikasi lama dulu**. Akun dan progres tetap aman di server.
- Izinkan *Install unknown apps* untuk aplikasi pengelola file atau browser.
- Versi: `1.1.0` (versionCode `2`).
