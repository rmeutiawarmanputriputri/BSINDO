import 'package:bisindo_app/core/supabase/signed_url_cache.dart';
import 'package:flutter_test/flutter_test.dart';

/// VID-05: cache signed URL, refresh bila sisa < 10 menit.
void main() {
  test('memakai cache sampai sisa < 10 menit, lalu ambil ulang', () async {
    var now = DateTime(2026, 1, 1, 10);
    var calls = 0;
    final cache = SignedUrlCache(
      (path, expiresIn) async {
        calls++;
        expect(expiresIn, 7200);
        return 'https://cdn/$path?v=$calls';
      },
      clock: () => now,
    );

    expect(await cache.get('a.mp4'), 'https://cdn/a.mp4?v=1');
    now = now.add(const Duration(minutes: 100));
    expect(await cache.get('a.mp4'), 'https://cdn/a.mp4?v=1');
    expect(calls, 1);

    now = now.add(const Duration(minutes: 11)); // sisa 9 menit
    expect(await cache.get('a.mp4'), 'https://cdn/a.mp4?v=2');
    expect(calls, 2);

    cache.invalidate('a.mp4');
    expect(await cache.get('a.mp4'), 'https://cdn/a.mp4?v=3');
  });
}
