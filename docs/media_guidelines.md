# Pedoman Media Video BISINDO (D-13)

Spesifikasi: MP4 H.264 + AAC (audio boleh dihapus), ≤ 720p (target 480p), ~1–2 Mbps, **faststart**, ≤ 20 MB (target 2–5 MB), satu gerakan per video. Thumbnail WebP/JPEG ≤ 150 KB **wajib**.

Contoh perintah (tidak dijalankan otomatis oleh aplikasi):
```bash
# Video 480p, tanpa audio, faststart
ffmpeg -i masukan.mov -vf "scale=-2:480" -c:v libx264 -profile:v main -preset slow \
  -crf 26 -maxrate 1.5M -bufsize 3M -an -movflags +faststart keluaran.mp4

# Dengan audio (bila perlu)
ffmpeg -i masukan.mov -vf "scale=-2:480" -c:v libx264 -crf 26 -maxrate 1.5M -bufsize 3M \
  -c:a aac -b:a 64k -movflags +faststart keluaran.mp4

# Thumbnail dari detik ke-1
ffmpeg -ss 1 -i keluaran.mp4 -frames:v 1 -vf "scale=-2:360" -q:v 75 thumb.webp
```
Unggah lewat menu Admin → Kosakata → (pilih entri) → Video / Thumbnail. Aplikasi memvalidasi ukuran (≤ 20 MB) dan ekstensi sebelum mengunggah. Penamaan objek otomatis: `signs/{sign_id}/video-{asset_id}.mp4`.

**Konten harus berasal dari sumber tervalidasi** (komunitas Tuli/penutur asli/organisasi kompeten, K-06). Status `published` mewajibkan validator, tanggal, dan sumber (CHECK di database).
