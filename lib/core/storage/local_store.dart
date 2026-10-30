import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Penyimpanan JSON kecil di folder dokumen aplikasi (pengaturan pengingat,
/// daftar materi offline). Bukan untuk rahasia. Gagal baca → data kosong.
class LocalStore {
  LocalStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file(String name) async {
    final dir = await _directory();
    final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}/bisindo_$safe.json');
  }

  Future<Map<String, dynamic>> read(String name) async {
    try {
      final file = await _file(name);
      if (!await file.exists()) return <String, dynamic>{};
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> write(String name, Map<String, dynamic> value) async {
    final file = await _file(name);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(value), flush: true);
    await tmp.rename(file.path); // tulis atomik
  }

  Future<void> delete(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore());
