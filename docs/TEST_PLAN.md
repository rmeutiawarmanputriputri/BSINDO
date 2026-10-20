# TEST_PLAN — BISINDO

**Aturan bukti:** sebuah tes hanya boleh dilaporkan "lulus" bila **benar-benar dijalankan** dan keluarannya dilampirkan/diringkas. Status yang diizinkan: `LULUS (dijalankan)`, `GAGAL`, `TIDAK DIJALANKAN (alasan)`, `MANUAL — menunggu pengguna`. Dilarang menulis "seharusnya berfungsi".

## 1. Perintah validasi dasar

```
flutter doctor -v
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=env/dev.json
```
Opsional bila CLI/Docker tersedia: `supabase db reset` (lokal), `supabase test db` (pgTAP).
Instal: `adb install -r build/app/outputs/flutter-apk/app-debug.apk` (butuh perangkat/emulator). Bila tidak tersedia, laporkan **"APK dibuat, belum terpasang/teruji"**.

## 2. Lingkungan uji

| Item | Minimum |
|---|---|
| Perangkat/emulator | 1 emulator + 1 perangkat Android nyata (wajib untuk STT & video) |
| Ukuran layar | 360×640, 360×800, 411×891, tablet 600×960 |
| Skala teks | 100%, 130%, 200% |
| Orientasi | Portrait (wajib), landscape (video fullscreen) |
| Jaringan | Normal, lambat (throttle), offline, putus di tengah |
| Akun | tamu, user A, user B, admin |

## 3. Pengujian per area

Tipe: **U**nit, **W**idget, **I**ntegrasi, **M**anual, **DB** (SQL/pgTAP).

### Autentikasi
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| AUTH-01 | U | Validator email/sandi/nama/konfirmasi | Sesuai tabel AUTH spec §6 |
| AUTH-02 | W | Form Register menampilkan error per field setelah submit; fokus ke field error pertama | Pesan tepat, tanpa overflow |
| AUTH-03 | W | Tombol loading tidak bisa diklik ganda | `signUp` dipanggil sekali |
| AUTH-04 | W | Toggle sandi mengubah `obscureText`; punya tooltip/semantics | Terdeteksi |
| AUTH-05 | U | Mapper error Supabase → pesan Indonesia | Semua kategori tercakup |
| AUTH-06 | I/M | Register → profil terbentuk (`role='user'`) | Baris `profiles` ada |
| AUTH-07 | I/M | Login benar/salah; email belum diverifikasi | Pesan sesuai |
| AUTH-08 | I/M | Tutup & buka ulang aplikasi → sesi pulih | Masuk `/home` |
| AUTH-09 | I/M | Logout → Login; tombol back tidak kembali ke layar terautentikasi | Terpenuhi |
| AUTH-10 | M | Lupa/reset sandi lewat deep link | Berhasil/ pesan kedaluwarsa |
| AUTH-11 | W | Golden Login & Register pada 2 ukuran | Cocok referensi (toleransi dicatat) |

### Pencarian & kamus
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| DICT-01 | U | Escape `%` `_` pada query | Tidak menjadi wildcard |
| DICT-02 | W | Loading/empty/error+retry/hasil | Keempat state tampil |
| DICT-03 | W | Debounce: 5 ketikan cepat → 1 permintaan | Terverifikasi dengan fake |
| DICT-04 | I | Filter kategori + jenis + pagination | Data benar, tidak duplikat |
| DICT-05 | I | Hanya `published` tampil | Draft tidak muncul |
| FAV-01 | W/I | Toggle favorit optimistik + rollback saat gagal | Konsisten dengan DB |

### Video
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| VID-01 | W | Poster → play → pause → loop → 0.5× | Kontrol bekerja |
| VID-02 | W | Placeholder saat `video_asset_id` null | Pesan "Video belum tersedia" |
| VID-03 | M | Jaringan lambat: indikator buffering, bisa dibatalkan | Tidak freeze UI |
| VID-04 | M | URL kedaluwarsa/404 → "Coba Lagi" mengambil URL baru | Pulih atau pesan jelas |
| VID-05 | U | `SignedUrlCache` refresh bila sisa < 10 menit | Benar |
| VID-06 | M | Keluar layar → controller di-dispose (tak ada suara tertinggal) | Terpenuhi |

### Percakapan
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| CONV-01 | W | Daftar dialog berurutan; baris tanpa video berlabel | Benar |
| CONV-02 | I | Tandai selesai; `last_position` tersimpan & dipulihkan | Benar |
| CONV-03 | I | Hanya modul `published` | Benar |

### Transkripsi (perangkat nyata)
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| STT-01 | U | State machine controller (idle→listening→done/error) dengan fake | Transisi benar |
| STT-02 | M | Izin diberikan → ucapan Indonesia → teks tampil | Teks muncul; akurasi dicatat apa adanya |
| STT-03 | M | Izin ditolak, lalu ditolak permanen | Dialog + "Buka Pengaturan" |
| STT-04 | M | Mode pesawat | Pesan jaringan jelas, tidak crash |
| STT-05 | M | Diam/ucapan tak dikenali | Pesan "tidak terdengar jelas" |
| STT-06 | W/M | Salin, edit, hapus teks | Berfungsi |
| STT-07 | M | Ke latar belakang saat mendengarkan | Mikrofon berhenti |
| STT-08 | review | Tidak ada penyimpanan audio/teks (periksa kode, DB, log) | Nol penulisan |
| STT-09 | M | Banner "tidak menerjemahkan isyarat" selalu tampak | Terpenuhi |

### Kosakata sulit
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| DIFF-01 | DB/I | Tandai dua kali → 1 baris | Tidak duplikat |
| DIFF-02 | I | "Sudah paham" → `relearned`, `relearned_at`, `review_count+1` | Benar |
| DIFF-03 | W | Daftar dua tab, empty state | Benar |
| DIFF-04 | I | Data persisten setelah logout/login & ganti perangkat | Benar |

### Pelaporan
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| REP-01 | W | "Lainnya" wajib keterangan ≥ 5 | Validasi muncul |
| REP-02 | I | Kirim → muncul di riwayat dengan status `open` | Benar |
| REP-03 | DB | Pengguna tak dapat mengubah status/pesan | Ditolak (RLS-14) |
| REP-04 | I | Admin ubah status + pesan → terlihat pelapor | Benar |
| REP-05 | DB | Duplikat terbuka & batas 10/24 jam | Ditolak (RLS-15/16) |

### Kuis & progres
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| QUIZ-01 | DB | RPC: semua benar/sebagian/kosong/option asing | Skor tepat |
| QUIZ-02 | DB | Pengguna tak dapat membaca kunci / insert attempt | Ditolak (RLS-08/09) |
| QUIZ-03 | I | Lulus → pelajaran `completed` | Benar |
| QUIZ-04 | W | Keluar tengah kuis → konfirmasi | Benar |
| QUIZ-05 | W | Gagal submit → kirim ulang tanpa kehilangan jawaban | Benar |
| PROG-01 | I | "Materi terakhir" di Beranda mengikuti `last_accessed_at` | Benar |

### Admin
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| ADM-01 | W | Menu Admin hanya muncul untuk `role=admin` | Benar |
| ADM-02 | DB | Non-admin menulis konten langsung via API | Ditolak (RLS-03) |
| ADM-03 | I | Alur draft → publish dengan data validasi | Berhasil; tanpa validasi ditolak |
| ADM-04 | I | Upload video: ukuran/tipe tidak sesuai ditolak; sukses membuat `media_assets` | Benar |
| ADM-05 | I | Ganti video: aset lama terhapus setelah yang baru terhubung | Benar |

### RLS & Storage
Seluruh `RLS-xx` dan `ST-xx` di `SUPABASE_SECURITY_PLAN.md` §9.

### Responsivitas & aksesibilitas
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| RESP-01 | W/M | Semua layar utama di 360×640 & skala 200% | Tanpa overflow (tidak ada kuning-hitam) |
| RESP-02 | M | Keyboard terbuka di Login/Register/Form laporan/Admin | Field aktif & tombol dapat dijangkau |
| RESP-03 | W | Tablet 600×960: konten dibatasi lebar & terpusat | Benar |
| RESP-04 | M | Notch/gesture bar tidak menutup konten | Benar |
| A11Y-01 | M | TalkBack: Login, Register, Kamus, Detail, Kuis | Label/urutan/hasil dibacakan |
| A11Y-02 | W | Target sentuh ≥ 48dp (`meetsGuideline(androidTapTargetGuideline)`) | Lulus |
| A11Y-03 | W | `labeledTapTargetGuideline` untuk ikon | Lulus |
| A11Y-04 | review | Kontras token dihitung (4,5:1 teks) | Dokumentasi hasil hitung |
| A11Y-05 | M | Status tidak hanya warna | Terpenuhi |

### Koneksi & error
| ID | Tipe | Skenario | Kriteria |
|---|---|---|---|
| NET-01 | M | Offline saat membuka Beranda | Banner + retry per blok |
| NET-02 | M | Putus saat menyimpan favorit/sulit/laporan | Rollback/pesan, tanpa crash |
| NET-03 | W | `ErrorView` retry memanggil ulang | Benar |
| NET-04 | M | Server mengembalikan 500/timeout | Pesan umum |

### Build & instalasi
| ID | Skenario | Kriteria |
|---|---|---|
| BLD-01 | `flutter analyze` | 0 error; peringatan terdokumentasi |
| BLD-02 | `flutter test` | Semua lulus |
| BLD-03 | `flutter build apk --debug` | APK dihasilkan (bukti log + path) |
| BLD-04 | Pasang & buka APK; Splash → Login | Berhasil di perangkat/emulator |
| BLD-05 | Tidak ada rahasia di repo (`git grep` service_role, key) | Nol temuan |

## 4. Data uji
Akun uji: `user.a`, `user.b`, `admin` (dev). Konten uji: seed dev (`DEV-SAMPLE`); **tidak** dianggap materi BISINDO yang benar.

## 5. Laporan uji
Format: ID · hasil · bukti (perintah/ringkasan keluaran/tangkapan layar) · catatan. Kegagalan dilaporkan dengan langkah reproduksi.

## 10. Kriteria penerimaan MVP (dapat diperiksa)

1. Semua `AUTH-*`, `DICT-*`, `VID-*`, `CONV-*`, `DIFF-*`, `REP-*`, `QUIZ-*`, `ADM-*` berstatus `LULUS (dijalankan)`.
2. Semua `RLS-*` dan `ST-*` lulus pada database dev dengan bukti keluaran.
3. `STT-02…STT-09` diuji pada ≥ 1 perangkat Android nyata; hasil akurasi dicatat apa adanya, batasan didokumentasikan.
4. `flutter analyze` 0 error; `flutter test` hijau; APK debug dibuat dan terpasang.
5. `RESP-01…04` dan `A11Y-01…05` terpenuhi atau pengecualiannya dicatat dan disetujui.
6. Tidak ada rahasia di repo; service role key tidak ada di aplikasi.
7. Tidak ada materi `published` dengan `validated_by like 'DEV-SAMPLE%'` di database produksi.
8. Setiap deviasi dari desain Login/Register tercatat dan disetujui pemilik.
9. Daftar masalah terbuka (known issues) disusun jujur.
