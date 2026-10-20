# UI_UX_SPECIFICATION — BISINDO

Memakai token dan komponen di `DESIGN_SYSTEM.md`. Visual Splash/Login/Register: `AUTH_UI_DESIGN_SPEC.md`. Layar lain **tidak** memakai layout kartu-di-atas-gradien; gunakan `AppScaffold` standar Material 3.

## 1. Prinsip global

- Mobile-first; `SafeArea`; edge-to-edge; konten scroll; tidak ada tinggi tetap pada wadah teks.
- Navigasi bawah (`NavigationBar`, 5 tab): **Beranda · Kamus · Percakapan · Belajar · Profil**. Tab disembunyikan pada layar penuh (video fullscreen, kuis berjalan).
- Tombol kembali konsisten; setiap aksi penting memberi feedback (snackbar/ikon/dialog).
- Teks Indonesia sederhana; istilah "isyarat" dipakai konsisten.
- Semua layar daftar mengikuti pola 4 state di §2.

## 2. Pola state bersama

| State | Tampilan |
|---|---|
| Loading | Skeleton sesuai bentuk daftar/kartu (bukan spinner kosong); `Semantics` "Memuat" |
| Empty | Ikon/ilustrasi + judul + penjelasan + aksi (mis. "Jelajahi Kamus") |
| Error | Ikon + pesan ramah + tombol "Coba Lagi"; offline → `OfflineBanner` |
| Success | Konten; aksi tulis → snackbar konfirmasi singkat |
Pagination: 20 item/halaman, muat berikutnya saat mendekati ujung; indikator di akhir daftar.

## 3. Struktur navigasi

```
/splash → /login ⇄ /register (→ /verify-email)   /forgot-password → /reset-password
/home (shell dengan NavigationBar)
 ├─ /home                    Beranda (S07)
 ├─ /dictionary              Kamus (S08) → /dictionary/sign/:id (S09) → video fullscreen (S10)
 │                            → /report/new?type=sign&id=… (S22)
 ├─ /conversations           Daftar modul (S11) → /conversations/:id (S12)
 ├─ /learn                   Pelajaran (S14) → /learn/:id (S15) → /learn/:id/quiz (S16) → hasil (S17)
 │                            /learn/progress (S18)
 └─ /profile                 Profil & pengaturan (S24)
      ├─ /favorites (S19), /difficult (S20) → /difficult/review/:signId (S21)
      ├─ /reports (S23)
      └─ /admin (S25) [guard role=admin] → /admin/:entity (S26), /admin/reports (S27)
/transcribe (S13)  — dari Beranda
```

## 4. Spesifikasi per layar

Format: **Tujuan · Layout/Komponen · Interaksi/Navigasi · Data · State**.

### S01 Splash
Tujuan: inisialisasi + cek sesi. Layout: lihat AUTH spec §5.1. Data: sesi Supabase. State: error init → Login + snackbar "Tidak dapat terhubung ke server." Bila tak ada internet tetapi sesi lokal ada → tetap masuk `/home` (data akan menampilkan state offline).

### S02 Login · S03 Register
Lihat `AUTH_UI_DESIGN_SPEC.md` §5.3–5.4 dan §6–7.

### S04 Lupa Kata Sandi
Tujuan: minta tautan reset. Komponen: `AuthScaffold`, field email, tombol "Kirim Tautan". Aksi: `resetPasswordForEmail(redirectTo: bisindo://auth-callback)`. State: success → pesan netral "Jika email terdaftar, tautan telah dikirim" + jeda kirim ulang 60 s; error jaringan.

### S05 Atur Kata Sandi Baru
Dibuka dari deep link recovery (event `AuthChangeEvent.passwordRecovery`). Field sandi + konfirmasi (aturan sama), `updateUser(password)`. Success → `/home` + snackbar. Link kedaluwarsa → pesan + tombol minta tautan baru.

### S06 Verifikasi Email
Menjelaskan "Kami mengirim tautan ke {email}". Tombol "Kirim Ulang" (jeda 60 s), "Kembali ke Masuk". Setelah deep link konfirmasi terbuka → otomatis ke `/home`.

### S07 Beranda
Tujuan: titik awal belajar. Layout (scroll): sapaan ("Halo, {nama}!") → kartu **Lanjutkan belajar** (materi terakhir) → grid **Akses cepat** (Kamus, Percakapan, Transkripsi, Kosakata Sulit) → **Ringkasan progres** (persen pelajaran selesai, jumlah kosakata sulit) → **Latihan ulang** (maks 5 kosakata sulit; "Lihat semua").
Data: `profiles.full_name`; `user_progress` terbaru (`last_accessed_at desc limit 1`); hitungan progres; `difficult_vocabulary` status `learning`.
State: pengguna baru → kartu "Mulai belajar" dan empty state; tiap blok memuat/gagal **terpisah** (satu blok gagal tidak merusak layar).

### S08 Kamus & Pencarian
Layout: `SearchBar` (debounce 350 ms), chip filter kategori (scroll horizontal) + filter jenis (Kata/Frasa), daftar `SignTile` (kata, kategori, ikon favorit, indikator ada video), tombol aksi ke Favorit.
Interaksi: ketik → cari; ketuk tile → S09; ikon hati → toggle favorit (optimistik, rollback bila gagal); karakter `%` `_` pada input di-escape.
Data: `signs` (published) + kategori; urut abjad.
State: empty awal ("Cari kata atau pilih kategori"), tidak ada hasil ("Tidak menemukan '{q}'" + saran memeriksa ejaan atau memilih kategori; permintaan kata baru tidak ada di MVP), error + retry, loading skeleton.

### S09 Detail Kosakata
Layout: `VideoPlayerView` di atas (poster dulu), judul kata + lencana jenis, kategori, **Arti**, **Petunjuk gerakan** (teks, bila ada), **Contoh penggunaan**, kartu **Sumber & validasi** ("Divalidasi oleh … · tanggal · sumber"), aksi: Favorit, **Tandai Sulit**, **Laporkan**.
Interaksi: tandai sulit → `upsert` (tanpa duplikat; toggle jadi "Dihapus dari daftar sulit" bila sudah ada); laporkan → S22.
State: video belum ada → placeholder "Video belum tersedia" (bukan error); teks kosong → bagian disembunyikan, bukan dibiarkan kosong; materi contoh → lencana "Materi contoh".

### S10 Pemutar Video (komponen + layar penuh)
Kontrol: Play/Pause, **Ulangi** (loop toggle), kecepatan 0.5×/1×, fullscreen, seekbar. Tanpa autoplay; ketuk poster untuk mulai. Buffering: indikator + teks "Memuat video…". Gagal: pesan + "Coba Lagi" (ambil signed URL baru). Orientasi: fullscreen mengizinkan landscape; keluar mengembalikan portrait. Deskripsi gerakan tetap tersedia sebagai alternatif teks. Dispose controller saat keluar layar.

### S11 Daftar Modul Percakapan
Layout: chip kategori percakapan (Salam, Perkenalan, Keluarga & Teman, Sekolah, Berbelanja, Meminta Bantuan, Bertanya Arah, Lainnya) + daftar `ModuleCard` (judul, jumlah dialog, progres %).
Data: `conversation_modules` published + `user_progress`. State: empty "Modul akan segera hadir" (konten belum divalidasi).

### S12 Detail Percakapan
Layout: judul + **konteks penggunaan**; daftar dialog berurutan (pembicara A/B, kalimat Indonesia, tombol putar video per baris atau pemutar sticky); sumber/validasi; tombol "Tandai selesai"; aksi Laporkan; "Tandai sulit" per baris bila `sign_id` ada.
Interaksi: ketuk baris → memutar videonya; "Putar semua berurutan" (opsional bila waktu); progres `last_position` tersimpan.
State: baris tanpa video → label "Video belum tersedia".

### S13 Transkripsi Suara → Teks
Layout: banner kecil permanen: **"Fitur ini mengubah ucapan menjadi teks. Tidak menerjemahkan isyarat."**; area teks (`TextField` multi-baris, dapat diedit); tombol mikrofon besar (label "Mulai"/"Berhenti"); indikator status (Siap / Mendengarkan… / Memproses / Berhenti) berupa **ikon + teks**; tombol Salin, Hapus.
Alur: tap Mulai → bila izin belum ada: dialog penjelasan (audio diproses layanan pengenal ucapan di perangkat/Google, aplikasi tidak menyimpan audio) → izin sistem. Hasil sementara tampil real-time; hasil akhir ditambahkan ke area teks.
Error: izin ditolak → penjelasan + tombol "Buka Pengaturan"; ditolak permanen → arahkan ke pengaturan; tanpa internet → "Pengenalan suara membutuhkan koneksi pada perangkat ini"; ucapan tak dikenali → "Suara tidak terdengar jelas. Coba lagi."; layanan tak tersedia → pesan perangkat tidak didukung; bahasa `id_ID` tidak tersedia → pesan + fallback ke bahasa perangkat **hanya jika** pengguna setuju.
Privasi: teks hanya di memori (hilang saat keluar layar; dialog konfirmasi bila ada teks); tidak ada tabel DB; tidak dicatat di log.
Lifecycle: hentikan mendengarkan saat app ke latar/`dispose`.

### S14 Daftar Pelajaran
Header ringkas progres (link S18); daftar `LessonCard` (judul, deskripsi singkat, jumlah materi, status: belum/berjalan/selesai ikon+teks). Data: `lessons` published + `user_progress`.

### S15 Detail Pelajaran
Deskripsi; daftar urut item (kosakata/modul percakapan/teks) dengan penanda selesai; ketuk item → S09/S12/teks; tombol "Mulai Kuis" (bila ada kuis aktif); progres. Menandai pelajaran selesai manual atau otomatis setelah lulus kuis (D-16). Update `last_accessed_at`.

### S16 Kuis
Satu pertanyaan per layar; bilah progres "Soal 3 dari 10"; pertanyaan dapat memuat video (pemutar) atau teks; opsi (radio, kartu besar, sentuh ≥ 48dp); tombol Lanjut/Selesai. Keluar di tengah → dialog konfirmasi (jawaban tidak disimpan). Submit → RPC `submit_quiz_attempt`. State: loading submit; gagal → "Kirim ulang" (jawaban tetap di memori).

### S17 Hasil Kuis
Skor, lulus/tidak (ikon+teks), jumlah benar, tinjauan per soal (jawaban Anda, jawaban benar, penjelasan — dari respons RPC), tombol "Ulangi", "Kembali ke pelajaran", riwayat percobaan (`quiz_attempts`).

### S18 Progres
Ringkasan: pelajaran selesai/total, modul percakapan selesai/total, rata-rata & skor terbaik kuis, jumlah kosakata sulit vs sudah dipelajari ulang; daftar riwayat percobaan. Tanpa grafik rumit (bar sederhana bila ada).

### S19 Favorit
Daftar kosakata favorit (urut terbaru); hapus favorit (geser/ikon dengan undo snackbar); empty → "Belum ada favorit".

### S20 Daftar Kosakata Sulit
Tab: **Perlu dilatih** (`learning`) / **Sudah dipelajari ulang** (`relearned`); item menampilkan kata, kategori, jumlah latihan; aksi per item: buka latihan (S21), hapus dari daftar. Empty: "Tandai kosakata sulit dari halaman detail."

### S21 Detail Latihan Ulang
Pemutar video, tombol "Tampilkan arti" (arti disembunyikan dahulu untuk latihan mandiri), deskripsi gerakan, contoh; tombol **"Sudah paham"** (→ `relearned`, `relearned_at`, `review_count+1`) dan **"Masih sulit"** (`review_count+1`, tetap `learning`); pindah ke berikutnya. Latihan manual — tidak ada penjadwalan otomatis (spaced repetition di luar MVP).

### S22 Form Laporan
Dibuka dari S09/S12/S15; konteks target ditampilkan (nama materi). Field: kategori (radio: Gerakan diduga keliru · Arti tidak sesuai · Video bermasalah · Contoh penggunaan tidak tepat · Lainnya), keterangan (opsional; **wajib ≥ 5 karakter** jika "Lainnya"; maks 1000 + penghitung). Kirim → konfirmasi "Terima kasih, laporan Anda terkirim" + tautan ke riwayat. Error: duplikat laporan terbuka → "Anda sudah melaporkan hal ini dan masih ditinjau."; batas harian → pesan; jaringan.

### S23 Riwayat Laporan
Daftar laporan pengguna (target, kategori, tanggal, `StatusBadge`: Menunggu/Ditinjau/Selesai/Ditolak, pesan tanggapan admin bila ada). Pengguna tidak dapat mengubah/menghapus.

### S24 Profil & Pengaturan
Nama, email (baca saja), tombol Ubah Nama; menu: Favorit, Kosakata Sulit, Riwayat Laporan, Progres, **Admin** (hanya `role=admin`), Tentang aplikasi (versi), **Keluar** (dialog konfirmasi → `signOut` → `/login`, bersihkan state provider). Pengaturan MVP: informasi privasi singkat tentang transkripsi. Hapus akun: lihat K-10.

### S25 Dashboard Admin
Guard UI (`role=admin`) + jaminan nyata di RLS. Kartu hitungan: laporan terbuka, konten menunggu peninjauan, draft. Menu: Kosakata, Kategori, Modul Percakapan, Pelajaran & Kuis, Laporan. Jika non-admin menembus rute → 403 tampilan "Tidak berwenang" (dan RLS menolak data).

### S26 Daftar & Form Pengelolaan Konten (Admin)
Daftar per entitas dengan filter status; form buat/ubah sesuai entitas (field di `DATABASE_SCHEMA.md`). Elemen wajib: pilih status (`draft/in_review/verified/published/archived`); bagian **Validasi** (validator, tanggal, sumber) wajib sebelum `verified/published`; unggah video/thumbnail (pilih berkas → validasi ukuran ≤ 20 MB & ekstensi/MIME → progres unggah → catat `media_assets`); ganti video (alur aman di `SUPABASE_SECURITY_PLAN.md` §6); urutan item (naik/turun); pratinjau seperti pengguna; konfirmasi sebelum hapus (disarankan arsip dibanding hapus). Pesan error dari DB (CHECK) diterjemahkan ("Isi validator, tanggal, dan sumber sebelum menerbitkan.").

### S27 Tinjau Laporan (Admin)
Daftar laporan filter status; detail: kategori, keterangan, target (tombol buka materi), pelapor (ID anonim saja). Aksi: ubah status, tulis `resolution_message` (terlihat oleh pelapor — diberi peringatan di UI). Mencatat `resolved_by/at`.

## 5. Aksesibilitas per pola
- Daftar: `Semantics` item menyatakan nama + status (mis. "Halo, kosakata, ada video, favorit").
- Hasil kuis & status mikrofon diumumkan.
- Dialog: fokus ke judul; tombol destruktif jelas.
- Tidak ada gerak berkedip; animasi singkat dan dapat dimatikan.

## 6. Mikro-copy kunci
"Video belum tersedia" · "Coba Lagi" · "Tidak ada koneksi. Periksa internet Anda." · "Materi ini belum divalidasi" (hanya dev) · "Fitur ini mengubah ucapan menjadi teks. Tidak menerjemahkan isyarat."
