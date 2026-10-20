# DESIGN_SYSTEM — BISINDO

> **Status nilai warna/ukuran:** *estimasi visual dari 3 gambar referensi*, bukan nilai resmi. Wajib diverifikasi (K-04) dengan color picker/file sumber. Claude Work menaruh semua nilai di satu tempat (`lib/app/theme/tokens.dart`) agar mudah dikoreksi. Hitung ulang kontras setelah nilai final.

Sistem ini dipakai seluruh aplikasi. **Layout khas Login (kartu putih di atas gradien) tidak boleh dipaksakan ke halaman lain.**

## 1. Warna

### 1.1 Brand (dari gambar)
| Token | Estimasi | Pemakaian |
|---|---|---|
| `brandDeep` | ≈ `#1C44B7` | Latar Splash |
| `primary` | ≈ `#1B57CF` | Tombol utama, tautan, judul "BISINDO" |
| `accent` | ≈ `#F4A62A` (oranye ikon) | Aksen ilustrasi/ikon saja, bukan teks kecil |
| `bgGradientTop` | ≈ `#DCE8FF` | Latar halaman auth (atas) |
| `bgGradientBottom` | ≈ `#F8FAFF` | Latar halaman auth (bawah) |
| `surface` | `#FFFFFF` | Kartu |
| `inputFill` | ≈ `#EEF2F7` | Isi kolom input & tombol sosial |
| `textPrimary` | ≈ `#0F172A` | Judul, label |
| `textSecondary` | ≈ `#475569` | Subjudul (disarankan lebih gelap dari gambar, yang ≈ `#64748B`) |
| `textPlaceholder` | ≈ `#5A6A82` | Placeholder (gambar ≈ `#9AA5B5` kontras sekitar 2,2:1 → **tidak lolos**) |
| `outline` | ≈ `#CBD5E1` | Garis pembatas, border fokus non-aktif |

### 1.2 Semantic
`success` ≈ `#15803D`, `onSuccess` putih · `warning` ≈ `#B45309` · `error` ≈ `#B3261B` (+ container `#FDECEA`) · `info` = `primary`.
Status konten: `draft` abu, `in_review` amber, `verified` biru, `published` hijau, `archived` abu gelap. **Selalu** disertai ikon/teks, tidak hanya warna.

### 1.3 Aturan kontras
Teks normal ≥ 4,5:1; teks besar & komponen UI ≥ 3:1. Ikuti perhitungan nyata (jangan percaya tabel ini). Contoh estimasi: putih di atas `primary` ≈ 6,3:1 (lolos).
Siapkan **ColorScheme terang** untuk MVP. Mode gelap: di luar MVP; pakai token semantik agar bisa ditambah.

## 2. Tipografi
Font: Inter (default sementara, dibundel; K-04). Wordmark "BISINDO" memakai aset logo, bukan font.

| Peran | Ukuran / berat | Dipakai |
|---|---|---|
| `displaySmall` | 28 / 700 | Judul besar jarang |
| `headlineSmall` | 24 / 700 | Judul layar auth ("Buat Akun Baru") |
| `titleLarge` | 20 / 700 | Judul app bar, kartu besar |
| `titleMedium` | 16 / 600 | Judul kartu/list |
| `bodyLarge` | 16 / 400 | Teks utama |
| `bodyMedium` | 14 / 400 | Teks sekunder, input |
| `labelLarge` | 14 / 600–700 | Label form, tombol |
| `labelSmall` | 12 / 500 | Keterangan (minimum 12sp) |

Semua dalam `sp`; layout wajib tahan skala teks sampai 200%. Jangan memakai tinggi tetap untuk wadah teks.

## 3. Spasi, radius, elevasi
- Grid 4dp: `xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32`. Padding halaman horizontal 20–24dp.
- Radius (estimasi dari gambar): input 14, tombol utama **pill** (full), kartu auth 24, kartu konten 16, chip 999, video 16.
- Elevasi: kartu auth bayangan lembut (blur 24, y 8, opacity ≈ 8%); tombol utama bayangan biru halus; konten biasa 0–1 (tonal M3).

## 4. Ukuran komponen (standar baru, lihat deviasi di AUTH_UI_DESIGN_SPEC)
Target sentuh ≥ 48×48dp. Input tinggi 52 (min 48). Tombol utama tinggi 52. Tombol sosial 48. Ikon 24.

## 5. Komponen reusable (`lib/core/widgets/`)

| Komponen | Varian / state wajib |
|---|---|
| `AppButton` | primary (pill, panah opsional), secondary (tonal), text; **loading** (spinner + label "Memproses…", tidak bisa diklik ganda), disabled, success sesaat |
| `AppTextField` | label di atas (bold), placeholder, helper, error (ikon + teks), fokus, disabled, suffix (ikon mata), semantics |
| `PasswordField` | `AppTextField` + toggle visibilitas, tooltip "Tampilkan/Sembunyikan kata sandi" |
| `AuthCard` | kartu putih radius 24 + bayangan, lebar maks 480 |
| `AuthScaffold` | gradien, SafeArea, scroll, aman keyboard, maks lebar |
| `SocialButton` / `SocialButtonRow` | hanya jika flag aktif |
| `AppCard`, `SignTile`, `CategoryChip`, `ModuleCard`, `LessonCard`, `ProgressBar` | konten |
| `VideoPlayerView` | poster, loading/buffering, error+retry, play/pause, loop, kecepatan 0.5×/1× |
| `StatusBadge` | status konten / laporan dengan ikon + teks |
| `StateViews` | `LoadingView` (skeleton), `EmptyView`, `ErrorView` (retry), `OfflineBanner` |
| `AppSnackbar` | success / error / info (+ aksi) |
| `ConfirmDialog` | konfirmasi hapus/logout |
| `AppScaffold` | app bar konsisten, SafeArea, `NavigationBar` |

## 6. State komponen
- **Loading:** spinner di tombol atau skeleton; input dinonaktifkan selama submit.
- **Disabled:** opasitas tidak boleh membuat teks gagal kontras; tambahkan konteks (mis. helper).
- **Error:** ikon + teks (bukan hanya warna merah), `Semantics(liveRegion: true)` agar TalkBack membacakan.
- **Success:** snackbar/ikon centang + teks.

## 7. Tema Material 3
`ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(...token eksplisit...), textTheme, inputDecorationTheme (filled, fillColor inputFill, radius 14, border none/outline saat fokus), filledButtonTheme (pill, minimumSize 52 tinggi), navigationBarTheme, cardTheme, snackBarTheme)`.
Gunakan `ColorScheme` eksplisit agar warna persis token, bukan hasil `fromSeed` murni.

## 8. Responsivitas
Breakpoint lebar: compact < 600, medium 600–839, expanded ≥ 840. Form dan konten bacaan dibatasi `maxWidth 480–640` dan dipusatkan. Grid kategori: `SliverGridDelegateWithMaxCrossAxisExtent` (maks ±180dp/kolom), bukan jumlah kolom tetap. Video rasio dari metadata (default 16:9) dengan `AspectRatio`. Gunakan `MediaQuery.viewInsetsOf/paddingOf`, `SafeArea`, edge-to-edge.

## 9. Aksesibilitas
- Semua ikon fungsional punya `semanticLabel`/`tooltip` (bahasa Indonesia).
- Fokus & urutan baca logis; gambar dekoratif `excludeSemantics`.
- Informasi tidak hanya warna (status = ikon + teks).
- Skala teks 100%/130%/200% tidak overflow.
- Pengumuman perubahan penting (error form, hasil kuis, status mikrofon) lewat `SemanticsService.announce`/liveRegion.
- Video: tombol bantuan (play/pause/ulang) dengan label; deskripsi gerakan teks tersedia sebagai alternatif.
- Gerak: hormati `MediaQuery.disableAnimations`.

## 10. Ikonografi & aset
Ikon aplikasi dari Material Symbols (bawaan Flutter). Logo/ilustrasi dari berkas yang disediakan pemilik (K-01) di `assets/brand/`. Jangan menggambar ulang logo.
