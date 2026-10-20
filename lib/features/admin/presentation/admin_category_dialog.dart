import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../data/admin_repository.dart';
import 'admin_entities.dart';

/// Form kategori (buat/ubah) dalam dialog.
Future<void> showCategoryDialog(
  BuildContext context,
  WidgetRef ref, {
  Json? existing,
}) async {
  final name = TextEditingController(text: optString(existing ?? const {}, 'name'));
  final slug = TextEditingController(text: optString(existing ?? const {}, 'slug'));
  final sort = TextEditingController(
      text: '${optInt(existing ?? const {}, 'sort_order')}');
  var kind = optString(existing ?? const {}, 'kind') ?? 'sign';
  var active = optBool(existing ?? const {}, 'is_active', true);
  final formKey = GlobalKey<FormState>();
  // Dibaca sebelum `await`: WidgetRef tidak boleh dipakai setelah unmount.
  final repo = ref.read(adminRepositoryProvider);

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Kategori baru' : 'Ubah kategori'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  onChanged: (v) {
                    if (existing == null) slug.text = slugify(v);
                  },
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi.' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: slug,
                  decoration: const InputDecoration(labelText: 'Slug'),
                  validator: (v) =>
                      isValidSlug(v ?? '') ? null : 'Huruf kecil, angka, tanda hubung.',
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Jenis'),
                  items: const [
                    DropdownMenuItem(value: 'sign', child: Text('Kosakata')),
                    DropdownMenuItem(value: 'conversation', child: Text('Percakapan')),
                  ],
                  onChanged: (v) => setState(() => kind = v ?? kind),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: sort,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Urutan'),
                  validator: (v) => int.tryParse(v ?? '') == null ? 'Angka.' : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
  if (saved != true) return;
  final values = {
    'name': name.text.trim(),
    'slug': slug.text.trim(),
    'kind': kind,
    'sort_order': int.parse(sort.text),
    'is_active': active,
  };
  try {
    if (existing == null) {
      await repo.insert('categories', values);
    } else {
      await repo.update('categories', reqString(existing, 'id'), values);
    }
    if (context.mounted) showAppSnackBar(context, 'Kategori disimpan');
  } catch (error) {
    if (context.mounted) showErrorSnackBar(context, error);
  }
}
