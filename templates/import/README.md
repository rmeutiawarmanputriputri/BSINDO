# Template impor massal (KOSONG)

Template ini **hanya berisi struktur kolom**, tanpa materi. Isi dengan materi BISINDO Anda sendiri,
lalu impor di CMS → **Impor massal**. Template yang sama juga bisa diunduh langsung dari halaman tersebut.

| Berkas | Untuk | Kolom wajib |
|---|---|---|
| `template_vocabulary.csv/json` | Kosakata | `term`, `category` (slug/nama kategori) |
| `template_alphabet.csv/json` | Alfabet | `symbol` (huruf) |
| `template_number.csv/json` | Angka | `symbol`, `number_group` (`0-9`, `10-20`, `tens`, `100+`) |
| `template_conversation.csv/json` | Percakapan | `topic`, `text` |
| `template_quiz.csv/json` | Soal kuis | `module`, `question_type`, `prompt` (+ `options`/`correct` atau `pairs`) |

Aturan:
- Semua baris masuk sebagai **Draft**. Tidak ada yang tampil di aplikasi sebelum Anda melengkapi dan mempublikasikannya.
- Kolom `*_file` diisi **nama berkas / judul media yang sudah diunggah** di menu Media. Jika belum ada, baris tetap masuk tanpa media dan muncul peringatan.
- CSV boleh memakai pemisah koma atau titik koma (Excel Indonesia). Simpan sebagai UTF-8.
- `verified_at` format `YYYY-MM-DD`; `is_premium` `true`/`false`.
- Kuis: `options` dipisah `|`; `correct` = teks pilihan atau nomornya (1, 2, …).
  `arrange_word`: `correct` = ubin urutan benar dipisah `|`.
  `match_image`: `pairs` = `gambar1.png=Arti 1|gambar2.png=Arti 2`.
- Maksimum 2000 baris per berkas. Selalu jalankan **Validasi** dulu (tidak menyimpan apa pun).
