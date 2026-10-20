import 'dart:typed_data';

/// Jenis media yang diizinkan bucket (SUPABASE_SECURITY_PLAN §4).
enum MediaKind { video, image }

/// Batas ukuran berkas (D-13 / bucket): 20 MB.
const kMaxMediaBytes = 20 * 1024 * 1024;

const _videoMime = {'mp4': 'video/mp4', 'webm': 'video/webm'};
const _imageMime = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

/// Berkas yang sudah dipilih admin (dipisah dari file_picker agar mudah dites).
class PickedMedia {
  const PickedMedia({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// Hasil validasi lokal: MIME bila valid, atau pesan error.
({String? mime, String? error}) validateMedia(PickedMedia file, MediaKind kind) {
  final table = kind == MediaKind.video ? _videoMime : _imageMime;
  final mime = table[file.extension];
  if (mime == null) {
    return (
      mime: null,
      error: kind == MediaKind.video
          ? 'Format video harus MP4 atau WebM.'
          : 'Format gambar harus JPG, PNG, atau WebP.',
    );
  }
  if (file.bytes.isEmpty) return (mime: null, error: 'Berkas kosong.');
  if (file.bytes.length > kMaxMediaBytes) {
    return (mime: null, error: 'Ukuran berkas maksimal 20 MB.');
  }
  return (mime: mime, error: null);
}

/// Nama objek Storage: huruf kecil, tanpa spasi, ekstensi sesuai MIME.
String mediaObjectPath({
  required String folder,
  required String ownerId,
  required String prefix,
  required String assetId,
  required String extension,
}) =>
    '$folder/$ownerId/$prefix-$assetId.${extension == 'jpeg' ? 'jpg' : extension}';
