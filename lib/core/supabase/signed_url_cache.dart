import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/failure_mapper.dart';
import 'supabase_providers.dart';

/// Pengambil signed URL; dipisah agar dapat diganti di tes.
typedef SignedUrlFetcher = Future<String> Function(String path, int expiresIn);

/// Cache signed URL `path → (url, expiresAt)` (FLUTTER_ARCHITECTURE §8).
/// TTL 2 jam; diambil ulang bila sisa < 10 menit; `invalidate` saat gagal putar.
class SignedUrlCache {
  SignedUrlCache(this._fetch, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  static const ttl = Duration(hours: 2);
  static const refreshMargin = Duration(minutes: 10);

  final SignedUrlFetcher _fetch;
  final DateTime Function() _now;
  final Map<String, ({String url, DateTime expiresAt})> _entries = {};

  Future<String> get(String path) async {
    final entry = _entries[path];
    if (entry != null && entry.expiresAt.difference(_now()) > refreshMargin) {
      return entry.url;
    }
    final url = await guardRequest(() => _fetch(path, ttl.inSeconds));
    _entries[path] = (url: url, expiresAt: _now().add(ttl));
    return url;
  }

  void invalidate(String path) => _entries.remove(path);

  void clear() => _entries.clear();
}

final signedUrlCacheProvider = Provider<SignedUrlCache>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SignedUrlCache(
    (path, expiresIn) =>
        client.storage.from(kMediaBucket).createSignedUrl(path, expiresIn),
  );
});
