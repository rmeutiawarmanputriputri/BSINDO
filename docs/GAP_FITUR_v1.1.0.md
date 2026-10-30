# Pemetaan Daftar Fitur A–L → BISINDO v1.1.0

Sumber: "DAFTAR FITUR APLIKASI BELAJAR BISINDO" dari pemilik (2026-10-30).
Keputusan pemilik pada hari yang sama:
- Admin Panel memakai CMS web yang sudah ada dan dipasang di hosting PHP/Apache.
- Kategori dan topik disamakan dengan daftar, dan 18 contoh kata dibuat sebagai Draft.
- Offline cache dan pengingat belajar dibuat.
- Premium tetap diatur manual di CMS.

Arti kolom **Status**:
- **Ada**: sudah ada di v1.1.0 sebelum daftar ini.
- **Ditambah**: dibuat setelah daftar ini (migrasi 0121, CMS, aplikasi).
- **Butuh materi**: fitur dan struktur siap, isi BISINDO dari pemilik.

## A. Beranda
| # | Fitur | Status | Di mana |
|---|---|---|---|
| 1 | Banner utama | Ada + **Ditambah** | Banner bergambar dari CMS. Bila tidak ada banner aktif, tampil **banner perkenalan aplikasi**; teksnya bisa diubah di CMS → Pengaturan → Konten beranda |
| 2 | Tombol mulai belajar | Ada | Kartu *Mulai Belajar* / materi terakhir |
| 3 | Kategori pembelajaran | Ada | Kartu modul (Alfabet, Angka, Kosakata, Percakapan, Kuis) |
| 4 | Ringkasan progres | Ada | Blok *Ringkasan progres* |
| 5 | Rekomendasi materi | Ada | Materi berikutnya yang belum dipelajari |
| 6 | Materi terakhir | Ada | Dari riwayat belajar lintas modul |
| 7 | Info Premium | Ada | Blok Premium + halaman Info Premium |
| 8 | Navigasi ke semua modul | Ada | Tab bawah + tombol *Lihat semua modul* di banner perkenalan |
| — | Atur bagian beranda dari admin (I.15) | **Ditambah** | CMS → Pengaturan → Konten beranda: tampil/sembunyikan tiap bagian |

## B. Abjad · C. Angka
| Fitur | Status | Catatan |
|---|---|---|
| Daftar A–Z / angka per kelompok (0–9, 10–20, puluhan, 100+) | Ada | Diisi dari CMS |
| Animasi karakter per huruf/angka | **Ditambah** (GIF) | Video MP4/WebM **atau animasi GIF** dari CMS. Animasi = berkas unggahan pemilik, bukan AI |
| Nama + penjelasan | **Ditambah** (wajib) | *Penjelasan gerakan* kini **wajib** sebelum huruf/angka dipublikasikan |
| Putar ulang | Ada | Video: tombol *Ulangi*. GIF: tombol *Putar ulang* |
| Perlambat "jika tersedia" | Ada | 0,5× / 0,75× / 1× untuk MP4/WebM. GIF tidak dapat diperlambat; label *Animasi GIF* |
| Panduan posisi jari & telapak | Ada | *Panduan visual gerakan* (gambar) + teks penjelasan |
| Sebelumnya / berikutnya | Ada | |
| Mode belajar seluruh alfabet | Ada | *Sudah paham, lanjut* |
| Latihan tebak huruf/angka | Ada | Kuis jenis *Tebak huruf* / *Tebak angka* |
| Penanda sudah dipelajari | Ada | |
| Isi materi | **Butuh materi** | Semua huruf/angka belum ada; aplikasi menampilkan *Materi belum tersedia* |

## D. Kosakata
| Fitur | Status | Catatan |
|---|---|---|
| 12 kategori awal | **Ditambah** | Seed `20_v110_struktur.sql`, nama persis seperti daftar |
| Contoh kata (ayah, ibu, … kaki) | **Ditambah** (Draft) | 18 kosakata berisi **nama saja**, status Draft, tidak tampil di aplikasi. Arti, penjelasan, video, dan contoh diisi pemilik di CMS |
| Daftar per kategori, pencarian, favorit, penanda dipelajari | Ada | |
| Nama, arti, penjelasan, contoh penggunaan | Ada | Arti wajib sebelum publish |
| Animasi + putar ulang | Ada / **Ditambah** (GIF) | |

## E. Kalimat / Percakapan
| Fitur | Status | Catatan |
|---|---|---|
| 8 topik | **Ditambah** | Topik Draft kosong, nama persis seperti daftar |
| Video/animasi percakapan | Ada / **Ditambah** (GIF) | Per kalimat |
| **Pemisahan kalimat menjadi kosakata** | **Ditambah** | Tabel `conversation_item_parts`. Di CMS: *Bagian kalimat*. Di aplikasi: daftar bagian berurutan; bagian yang terhubung ke kosakata bisa diketuk |
| Penjelasan arti tiap bagian | **Ditambah** | Arti bagian dari CMS, atau arti kosakata di kamus |
| **Latihan memahami percakapan** | **Ditambah** | Soal kuis bisa dikaitkan ke satu topik. Tombol *Latihan memahami percakapan* hanya muncul bila soalnya ada |
| Simulasi percakapan | Ada | |
| Verifikasi oleh orang yang kompeten | Ada (ditegakkan) | Topik tidak bisa dipublikasikan tanpa validator, sumber, dan tanggal verifikasi. Peringatan susunan isyarat ditampilkan di CMS |

## F. Latihan & Kuis
Semua butir **Ada** di v1.1.0: 6 jenis soal, per kategori, campuran, belum dikuasai, skor otomatis, jumlah benar/salah, pembahasan, riwayat, tingkat kesulitan, ulangi soal salah. **Ditambah**: kuis per topik percakapan. Soal: **Butuh materi**.

## G. Profil & Progres
| # | Fitur | Status |
|---|---|---|
| 1–7 | Profil, total materi, % per kategori, riwayat belajar, riwayat kuis, favorit, statistik | Ada |
| 8 | Pengaturan akun | Ada (ubah nama, keluar, hapus akun) |
| 9 | **Pengaturan notifikasi** | **Ditambah**: Profil → Pengaturan Notifikasi |
| 10 | Logout | Ada |
| — | Materi Offline | **Ditambah**: Profil → Materi Offline |

## H. Fitur pendukung
| Fitur | Status | Catatan |
|---|---|---|
| Search, Bookmark, Repeat, Slow motion, Premium, FAQ | Ada | |
| **Offline cache** | **Ditambah** | Tombol *Simpan offline* di detail materi. Video, gambar, dan audio disimpan di perangkat dan dibuka dari *Materi Offline* tanpa internet. Daftar disimpan per akun |
| **Notifikasi pengingat belajar** | **Ditambah** | Notifikasi lokal harian dengan jam yang bisa diatur; izin diminta saat diaktifkan (Android 13+). Pengumuman admin tetap tampil di ikon lonceng |

## I. Admin Panel
Butir 1–14 dan 16 **Ada**. Tambahan:
- 7: unggah **GIF** animasi.
- 15: **Konten beranda**.
- 6: editor bagian kalimat.
- 9: soal per topik percakapan.

Dipasang di hosting PHP/Apache tanpa kode PHP; keamanan dijaga di database (lihat `docs/CMS_SETUP.md` §5).

## J. Standar konten animasi
Aplikasi dan CMS **menyimpan dan memutar** berkas pemilik, dan tidak membuat atau mengubah animasi.
- Standar visual (karakter konsisten, latar, tangan jelas) menjadi daftar periksa di `docs/CMS_SETUP.md` §6.
- Identitas materi: setiap media punya judul; bila kosong, server mengisinya dari nama berkas.
- Gerakan terverifikasi: validator, sumber, dan tanggal wajib sebelum publish.
- Optimasi: batas ukuran per jenis dan saran kompresi.

## K. Teknologi
| Ketentuan | Status |
|---|---|
| Flutter, Supabase (DB + Auth) | Ada |
| Backend & Admin **PHP** | Diputuskan pemilik: CMS web yang ada, dipasang di hosting PHP/Apache. Logika backend tetap di Supabase (RLS + RPC), sehingga tidak ada dua backend |
| RevenueCat | Webhook siap, **nonaktif** sampai kredensial ada. Premium diatur manual di CMS (keputusan pemilik) |
| 1–7 (konten dinamis, tanpa hardcode, gratis/Premium, kategori baru, media terkelola, progres tersimpan) | Ada |

## L. Quality control
| # | Butir | Bukti / status |
|---|---|---|
| 1–2 | Tombol berfungsi, tanpa jalan buntu | Tombol yang bergantung data disembunyikan bila datanya tidak ada (mis. *Latihan memahami percakapan*, *Simpan offline*). Uji UI di HP menunggu APK |
| 3 | Animasi tidak gagal dimuat | Pemutar menampilkan pesan + *Coba Lagi*; berkas offline diutamakan |
| 4 | Tanpa judul/penjelasan tidak bisa publish | Ditegakkan server (uji F-10, V-10) |
| 5 | Responsif | CMS diuji di 390×844; aplikasi menunggu uji HP |
| 6 | Tanpa data dummy | Seed hanya nama dari daftar pemilik, status Draft (uji F-02, F-20) |
| 7 | CRUD admin diuji | CMS E2E 40/40 |
| 8 | Hak gratis/Premium diuji | Uji DB V-2x, F-27 |
| 9 | Akurasi BISINDO terverifikasi | Tanggung jawab validator pemilik; publish tanpa validator ditolak |
| 10 | Tanpa error fatal | `dart analyze` 0 error/0 warning; uji di HP menunggu APK |
