import 'dart:typed_data';

import 'package:bisindo_app/features/admin/data/media_upload.dart';
import 'package:bisindo_app/features/admin/presentation/admin_entities.dart';
import 'package:flutter_test/flutter_test.dart';

/// ADM-04 (bagian klien): ukuran/tipe tidak sesuai ditolak sebelum unggah.
void main() {
  PickedMedia file(String name, int size) =>
      PickedMedia(name: name, bytes: Uint8List(size));

  test('video MP4 ≤ 20 MB diterima', () {
    final r = validateMedia(file('a.MP4', 1024), MediaKind.video);
    expect(r.error, isNull);
    expect(r.mime, 'video/mp4');
  });

  test('ekstensi salah / terlalu besar / kosong ditolak', () {
    expect(validateMedia(file('a.mov', 10), MediaKind.video).error, isNotNull);
    expect(
      validateMedia(file('a.mp4', kMaxMediaBytes + 1), MediaKind.video).error,
      isNotNull,
    );
    expect(validateMedia(file('a.mp4', 0), MediaKind.video).error, isNotNull);
    expect(validateMedia(file('a.gif', 10), MediaKind.image).error, isNotNull);
    expect(
      validateMedia(file('a.jpeg', 10), MediaKind.image).mime,
      'image/jpeg',
    );
  });

  test('path objek huruf kecil, id aset, ekstensi sesuai MIME', () {
    expect(
      mediaObjectPath(
        folder: 'signs',
        ownerId: 'S1',
        prefix: 'thumb',
        assetId: 'A1',
        extension: 'jpeg',
      ),
      'signs/S1/thumb-A1.jpg',
    );
  });

  test('slug sesuai CHECK DB', () {
    expect(slugify('  Salam & Perkenalan! '), 'salam-perkenalan');
    expect(isValidSlug('salam-perkenalan'), isTrue);
    expect(isValidSlug('Salam'), isFalse);
    expect(isValidSlug('-a'), isFalse);
  });
}
