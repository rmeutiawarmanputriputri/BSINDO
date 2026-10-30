import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/signed_url_cache.dart';

/// Cache berkas media di perangkat (H.5 Offline Cache). Kunci = path objek di
/// bucket privat (bukan signed URL yang berubah-ubah), sehingga berkas yang
/// sudah diunduh dapat diputar tanpa koneksi.
///
/// Semua operasi gagal dengan aman: bila cache tidak tersedia (mis. di tes),
/// pemutar kembali ke streaming biasa.
class MediaCache {
  MediaCache(this._signed, {BaseCacheManager? manager}) : _injected = manager;

  static const cacheKey = 'bisindoMedia';

  final SignedUrlCache _signed;
  final BaseCacheManager? _injected;

  late final BaseCacheManager _m =
      _injected ??
      CacheManager(
        Config(
          cacheKey,
          // Materi offline jarang dibuka ulang → masa simpan panjang.
          stalePeriod: const Duration(days: 365),
          maxNrOfCacheObjects: 1000,
        ),
      );

  /// Berkas lokal bila sudah pernah diunduh; null bila belum/gagal.
  Future<File?> cached(String path) async {
    try {
      final info = await _m.getFileFromCache(path);
      final file = info?.file;
      if (file != null && await file.exists()) return file;
    } catch (_) {}
    return null;
  }

  /// Ambil dari cache, atau unduh lewat signed URL lalu simpan.
  Future<File> fetch(String path) async {
    final local = await cached(path);
    if (local != null) return local;
    final url = await _signed.get(path);
    final info = await _m.downloadFile(url, key: path);
    return info.file;
  }

  Future<void> remove(String path) async {
    try {
      await _m.removeFile(path);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      await _m.emptyCache();
    } catch (_) {}
  }
}

final mediaCacheProvider = Provider<MediaCache>(
  (ref) => MediaCache(ref.watch(signedUrlCacheProvider)),
);
