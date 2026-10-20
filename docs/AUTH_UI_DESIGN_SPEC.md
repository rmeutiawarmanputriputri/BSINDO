# AUTH_UI_DESIGN_SPEC — Splash, Login, Register

Sumber: tiga gambar referensi milik pemilik proyek (Splash, Register, Login). Disimpan oleh Claude Work di `docs/design/reference/` (nama: `splash.png`, `register.png`, `login.png`).
Semua angka dalam "px gambar" adalah **pengukuran kasar**; skala tiap gambar berbeda. Tidak ada detail yang dikarang: yang tidak terbaca ditandai **[KONFIRMASI]**.

## 1. Analisis gambar

### 1.1 Splash
- Latar biru tua solid penuh (≈ `#1C44B7`), tanpa gradien.
- Wordmark "BISINDO" putih, huruf tebal geometris, di tengah (sedikit di atas tengah vertikal).
- Ikon tangan isyarat (putih) kecil di kanan-atas huruf "O".
- Status bar putih (jam 9:41, sinyal, Wi-Fi, baterai); indikator home di bawah (itu bagian bingkai mockup, **bukan** elemen aplikasi).
- Bingkai ponsel + notch hanya mockup → jangan diimplementasi.

### 1.2 Login
- Latar gradien sangat lembut biru muda → hampir putih (vertikal).
- Atas: ikon logo (tangan biru dengan cincin oranye dan percikan) ± 54px, di bawahnya teks "BISINDO" biru tebal, letter-spacing lebar, rata tengah.
- Kartu putih radius ≈ 24, bayangan lembut, lebar ≈ 348 (margin ±24 kiri-kanan), berisi:
  1. Judul "Masuk ke Akun Anda" (tebal, gelap, rata kiri).
  2. Label tebal "Alamat Email" + input terisi abu-biru muda (≈ `#EEF2F7`), radius ≈ 14, placeholder "Email Anda (contoh: nama@email.com)".
  3. Label "Kata Sandi" + input yang sama, placeholder "Masukkan kata sandi", di kanan **switch geser** (toggle) sebagai kontrol visibilitas.
  4. Tautan "Lupa Kata Sandi?" biru tebal, rata kanan.
  5. Tombol "Masuk →" biru penuh lebar, bentuk pill, bayangan biru; panah berupa karakter di teks.
  6. Pembatas garis + "Atau masuk dengan".
  7. Tiga tombol persegi membulat (Google, Facebook, Apple) latar sama dengan input.
- Bawah, di luar kartu: "Belum punya akun? **Daftar**" (Daftar biru tebal), di dekat dasar layar.

### 1.3 Register
- Latar gradien sama. Panah kembali kiri-atas.
- Ikon logo **versi lain** (lebih kecil ±28px, tangan biru + lengkung oranye) di tengah, "BISINDO" biru tebal.
- Judul "Buat Akun Baru" (tebal, ±22px), subjudul abu "Mari mulai perjalanan belajar isyarat bersama".
- Kartu putih (lebar sama) berisi 4 field berlabel tebal: "Nama Lengkap" (placeholder "Masukkan nama lengkap Anda"), "Alamat Email", "Kata Sandi" ("Buat kata sandi minimal 8 karakter", ikon mata-coret), "Konfirmasi Kata Sandi" ("Ulangi kata sandi Anda", ikon mata-coret).
- Tombol "Daftar →" (teks tebal, panah **ikon**), pembatas "Atau daftar dengan", tiga tombol sosial.
- Bawah: "Sudah punya akun? **Masuk**".

## 2. Elemen yang HARUS dipertahankan

Komposisi vertikal (logo → judul → kartu → tautan bawah), gradien latar, kartu putih radius besar dengan bayangan lembut, input terisi tanpa border, label tebal di atas input, tombol utama biru pill dengan panah, palet biru + aksen oranye pada logo, pembatas "Atau …", footer tautan silang Login↔Register, panah kembali di Register, Splash biru solid dengan wordmark putih.

## 3. Ketidakkonsistenan yang ditemukan di gambar

| # | Temuan | Gambar | Penanganan |
|---|---|---|---|
| I-1 | **Tiga versi logo/ikon berbeda** (splash putih, register, login) | semua | K-01: minta aset resmi; sementara pakai satu ikon yang sama |
| I-2 | Toggle sandi: **switch** (Login) vs **ikon mata** (Register) | Login/Register | K-02 default: ikon mata. Switch dapat dikembalikan lewat satu widget `PasswordField` |
| I-3 | Tinggi input ≈ 44px (Login) vs ≈ 36px (Register); tombol utama ≈ 45 vs ≈ 40; tombol sosial ≈ 40 vs ≈ 36 | — | Distandarkan: input 52dp, tombol utama 52dp, sosial 48dp (target sentuh) |
| I-4 | Label tombol: "Masuk →" teks biasa vs "Daftar →" tebal + ikon panah | — | Distandarkan: teks tebal + ikon panah (`Icons.arrow_forward`) |
| I-5 | Ukuran logo & posisi judul berbeda; Register punya subjudul & panah kembali, Login tidak | — | Dipertahankan karena beda konteks; ukuran logo mengikuti satu token per layar (Login besar, Register kecil) **[KONFIRMASI]** |
| I-6 | Login: tidak ada pesan error/validasi; tidak ada state loading | — | Didefinisikan di §6 (tidak mengubah visual dasar) |
| I-7 | Font tidak teridentifikasi pasti (terlihat sans-serif geometris/neo-grotesque) | — | K-04; default Inter |

## 4. Perbaikan profesional yang direkomendasikan (menunggu persetujuan)

| ID | Perbaikan | Alasan | Default |
|---|---|---|---|
| A-1 | Warna placeholder lebih gelap (≈ `#5A6A82`) | Kontras ≈ 2,2:1 → ≥ 4,5:1 | Diterapkan |
| A-2 | Subjudul/teks bantu ≥ 12sp dan warna `#475569` | Keterbacaan | Diterapkan |
| A-3 | "Atau masuk/daftar dengan" ≥ 12sp | Teks asli ±11px | Diterapkan |
| A-4 | Tinggi kontrol distandarkan (I-3) | Target sentuh 48dp | Diterapkan |
| A-5 | Ikon mata di Login (K-02) | Konsistensi | Diterapkan, **menunggu persetujuan** |
| A-6 | Tombol sosial disembunyikan (K-03) | Tidak berfungsi di MVP; hindari tombol palsu | Diterapkan, **menunggu persetujuan** |
| A-7 | Tautan footer berukuran sentuh ≥ 48dp (padding), bukan hanya teks | Aksesibilitas | Diterapkan |
| A-8 | Ikon sosial diberi `semanticLabel` ("Masuk dengan Google") bila nanti diaktifkan | Aksesibilitas | Saat aktif |

Setiap deviasi dari gambar **harus** dilaporkan Claude Work pada laporan fase.

## 5. Spesifikasi implementasi

### 5.1 Splash
- Native splash (paket `flutter_native_splash`, dev dependency): latar `brandDeep`, logo putih (aset K-01). Android 12+ memakai Splash API → logo ikon bisa terpotong; terima dan laporkan.
- Layar Flutter `SplashScreen`: tampilan sama; selama `Supabase.initialize` + pemulihan sesi; durasi minimal ±600 ms (hindari kedip), maksimal sampai inisialisasi selesai; timeout 8 s → ke Login dengan pesan jika gagal.
- System UI: ikon status bar terang.
- Rute berikutnya: sesi valid → `/home`, tidak → `/login`.

### 5.2 Layout umum Login/Register (`AuthScaffold`)
- `Scaffold(resizeToAvoidBottomInset: true)` → `SafeArea` → `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight: viewport)` + `IntrinsicHeight`/`Column` dengan footer di bawah bila ruang cukup, mengikuti konten bila layar pendek/keyboard muncul.
- Konten dipusatkan, `maxWidth 480`; padding horizontal 24.
- Gradien: `DecoratedBox` `LinearGradient` atas→bawah (`bgGradientTop`→`bgGradientBottom`).
- Logo: `Image/SvgPicture` dengan `semanticLabel: "Logo BISINDO"`, tinggi mengikuti `clamp` agar mengecil di layar pendek.
- Saat keyboard terbuka, field aktif otomatis terlihat (`scrollPadding`), urutan fokus: field → field → tombol; `TextInputAction.next` / `done`.
- Status bar: ikon gelap (latar terang).

### 5.3 Login
- Field: email (`keyboardType: emailAddress`, `autofillHints: [email]`, `autocorrect: false`), sandi (`autofillHints: [password]`, `obscureText`).
- "Lupa Kata Sandi?" → `/forgot-password`.
- Tombol "Masuk" → `auth.signInWithPassword`.
- Footer: "Belum punya akun? Daftar" → `/register`.

### 5.4 Register
- Field: nama lengkap, email, sandi, konfirmasi sandi; panah kembali (`Navigator.pop`/`context.pop`, dengan tooltip "Kembali").
- Tombol "Daftar" → `auth.signUp(email, password, data: {'full_name': nama})`.
- Bila verifikasi email aktif (sesi null) → `/verify-email` (S06); bila sesi langsung ada → `/home`.
- Footer: "Sudah punya akun? Masuk" → `/login`.
- Catatan: tidak menambah checkbox Syarat/Privasi tanpa persetujuan (K-08).

### 5.5 Layar tambahan yang mengikuti gaya yang sama
S04 Lupa Kata Sandi (email + tombol "Kirim Tautan"), S05 Atur Kata Sandi Baru (sandi + konfirmasi), S06 Verifikasi Email (ikon/ilustrasi, teks, tombol "Kirim Ulang" dengan jeda 60 s, tautan "Kembali ke Masuk"). Memakai `AuthScaffold` + `AuthCard`; tidak ada desain di gambar → dibuat dari token yang sama dan ditandai **[BELUM ADA DESAIN ASLI — minta persetujuan]**.

## 6. Validasi & pesan (Bahasa Indonesia)

| Field | Aturan klien | Pesan |
|---|---|---|
| Nama lengkap | trim, 2–80 karakter | "Nama lengkap minimal 2 karakter." |
| Email | wajib, format valid (regex sederhana), trim, huruf kecil | "Masukkan alamat email yang valid." |
| Sandi (daftar) | ≥ 8 karakter | "Kata sandi minimal 8 karakter." |
| Konfirmasi | sama dengan sandi | "Konfirmasi kata sandi tidak sama." |
| Sandi (login) | wajib | "Masukkan kata sandi Anda." |

Validasi tampil setelah blur/submit pertama (bukan saat mengetik pertama kali), teks error di bawah field dengan ikon. Fokus berpindah ke field error pertama.

Pemetaan error Supabase → pesan (kode harus diverifikasi terhadap versi paket saat implementasi):
| Kondisi | Pesan |
|---|---|
| kredensial salah | "Email atau kata sandi salah." |
| email belum dikonfirmasi | "Email belum diverifikasi. Cek kotak masuk Anda." (+ aksi kirim ulang) |
| email sudah terdaftar | "Email ini sudah terdaftar. Silakan masuk." |
| sandi lemah | "Kata sandi terlalu lemah." |
| terlalu banyak percobaan | "Terlalu banyak percobaan. Coba lagi beberapa saat lagi." |
| jaringan | "Tidak ada koneksi. Periksa internet Anda lalu coba lagi." |
| lainnya | "Terjadi kesalahan. Coba lagi." (detail teknis hanya di log debug) |

Jangan membocorkan apakah suatu email terdaftar pada layar "Lupa Kata Sandi": selalu tampilkan "Jika email terdaftar, tautan telah dikirim."

## 7. State

| Elemen | Loading | Disabled | Error | Success |
|---|---|---|---|---|
| Tombol utama | spinner + "Memproses…", klik ganda diblokir | saat form tidak valid **tidak** dinonaktifkan (agar error bisa muncul); hanya saat loading | — | navigasi |
| Field | dinonaktifkan saat submit | — | ikon + teks, border/outline error | — |
| Layar | — | — | banner error di atas kartu (`liveRegion`) untuk error server | snackbar bila relevan |

## 8. Aset yang dibutuhkan dari pemilik
`logo_wordmark_white` (Splash), `logo_icon` (Login/Register, resmi), `app_icon` (launcher), file desain sumber/Figma bila ada (untuk hex & font), ikon Google (resmi, hanya jika K-03 diaktifkan).

## 9. Kriteria penerimaan
1. Perbandingan berdampingan dengan gambar: urutan elemen, label, placeholder, warna, radius, dan alignment sesuai (kecuali deviasi tercatat).
2. Tidak ada overflow pada 360×640dp dan skala teks 200%.
3. Keyboard tidak menutup field aktif atau tombol utama dapat di-scroll.
4. Semua target sentuh ≥ 48dp; TalkBack membaca label field, error, tombol, toggle sandi.
5. Golden/screenshot test untuk Login & Register pada 2 ukuran layar.
6. Login/Register bekerja terhadap Supabase **atau** dinyatakan belum terverifikasi bila backend tak tersedia.
