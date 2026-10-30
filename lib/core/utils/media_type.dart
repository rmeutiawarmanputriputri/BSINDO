/// Media animasi GIF dikenali dari ekstensi path di Storage (CMS menyimpan
/// ekstensi asli berkas, mis. `library/video/2026/10/<uuid>.gif`).
bool isGifPath(String? path) =>
    path != null && path.toLowerCase().endsWith('.gif');
