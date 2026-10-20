import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../conversation/data/conversation_repository.dart';
import '../../dictionary/domain/sign.dart';
import '../data/admin_repository.dart';
import '../data/media_upload.dart';
import 'admin_entities.dart';
import 'admin_sign_picker.dart';
import 'admin_widgets.dart';

const _moduleColumns =
    'id, slug, title, description, context_note, category_id, sort_order, status, '
    'source_note, validated_by, verified_at';

const _itemColumns =
    'id, module_id, position, speaker_label, text_id, context_note, sign_id, '
    'video_asset_id, sign:signs(term), video:media_assets!video_asset_id(id, path)';

final _adminModuleProvider = FutureProvider.autoDispose.family<Json?, String>((ref, id) {
  if (id == 'new') return Future.value(null);
  return ref.watch(adminRepositoryProvider).get('conversation_modules', id, columns: _moduleColumns);
});

final _moduleItemsProvider = FutureProvider.autoDispose.family<List<Json>, String>(
  (ref, moduleId) => ref.watch(adminRepositoryProvider).list(
        'conversation_items',
        columns: _itemColumns,
        orderBy: 'position',
        ascending: true,
        equals: {'module_id': moduleId},
      ),
);

final _convCategoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(conversationRepositoryProvider).categories(),
);

/// S26 Form Modul Percakapan + editor dialog (urutan naik/turun).
class AdminModuleFormScreen extends ConsumerWidget {
  const AdminModuleFormScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_adminModuleProvider(id));
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(id == 'new' ? 'Modul baru' : 'Ubah modul')),
        body: data.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: errorMessageOf(e),
            onRetry: () => ref.invalidate(_adminModuleProvider(id)),
          ),
          data: (row) => _ModuleForm(row: row),
        ),
      ),
    );
  }
}

class _ModuleForm extends ConsumerStatefulWidget {
  const _ModuleForm({required this.row});
  final Json? row;

  @override
  ConsumerState<_ModuleForm> createState() => _ModuleFormState();
}

class _ModuleFormState extends ConsumerState<_ModuleForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _description;
  late final TextEditingController _context;
  late final TextEditingController _sort;
  late final TextEditingController _validatedBy;
  late final TextEditingController _source;
  late String _status;
  String? _categoryId;
  DateTime? _verifiedAt;
  String? _id;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.row ?? const <String, dynamic>{};
    _id = optString(r, 'id');
    _title = TextEditingController(text: optString(r, 'title'));
    _slug = TextEditingController(text: optString(r, 'slug'));
    _description = TextEditingController(text: optString(r, 'description'));
    _context = TextEditingController(text: optString(r, 'context_note'));
    _sort = TextEditingController(text: '${optInt(r, 'sort_order')}');
    _validatedBy = TextEditingController(text: optString(r, 'validated_by'));
    _source = TextEditingController(text: optString(r, 'source_note'));
    _status = optString(r, 'status') ?? 'draft';
    _categoryId = optString(r, 'category_id');
    _verifiedAt = parseDate(r['verified_at']);
  }

  @override
  void dispose() {
    for (final c in [_title, _slug, _description, _context, _sort, _validatedBy, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save({bool popAfter = true}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final values = {
      'title': _title.text.trim(),
      'slug': _slug.text.trim(),
      'description': _opt(_description),
      'context_note': _opt(_context),
      'category_id': _categoryId,
      'sort_order': int.tryParse(_sort.text) ?? 0,
      'status': _status,
      'validated_by': _opt(_validatedBy),
      'source_note': _opt(_source),
      'verified_at': _verifiedAt?.toUtc().toIso8601String(),
    };
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (_id == null) {
        final newId = await repo.insert('conversation_modules', values);
        if (!mounted) return;
        setState(() => _id = newId);
      } else {
        await repo.update('conversation_modules', _id!, values);
        if (!mounted) return;
      }
      ref.invalidate(conversationModulesProvider);
      ref.invalidate(conversationDetailProvider);
      showAppSnackBar(context, 'Tersimpan');
      if (popAfter) context.pop();
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(_convCategoriesProvider).value ?? const <Category>[];
    return Form(
      key: _formKey,
      child: ContentListView(
        children: [
          TextFormField(
            controller: _title,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Judul'),
            onChanged: (v) {
              if (_id == null) _slug.text = slugify(v);
            },
            validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi.' : null,
          ),
          TextFormField(
            controller: _slug,
            decoration: const InputDecoration(labelText: 'Slug'),
            validator: (v) => isValidSlug(v ?? '') ? null : 'Huruf kecil, angka, tanda hubung.',
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String?>(
            initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
            decoration: const InputDecoration(labelText: 'Kategori percakapan'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Tanpa kategori')),
              for (final c in categories)
                DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _description,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Deskripsi'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _context,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Konteks penggunaan'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _sort,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Urutan tampil'),
          ),
          const SizedBox(height: AppSpacing.md),
          ValidationSection(
            status: _status,
            onStatusChanged: (s) => setState(() => _status = s),
            validatedBy: _validatedBy,
            sourceNote: _source,
            verifiedAt: _verifiedAt,
            onVerifiedAtChanged: (d) => setState(() => _verifiedAt = d),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Simpan', loading: _saving, onPressed: _save),
          const SectionHeader(title: 'Dialog'),
          if (_id == null)
            OutlinedButton(
              onPressed: _saving ? null : () => _save(popAfter: false),
              child: const Text('Simpan modul dulu untuk menambah dialog'),
            )
          else
            _ItemsEditor(moduleId: _id!),
        ],
      ),
    );
  }
}

class _ItemsEditor extends ConsumerWidget {
  const _ItemsEditor({required this.moduleId});
  final String moduleId;

  Future<void> _editItem(BuildContext context, WidgetRef ref, List<Json> items,
      {Json? item}) async {
    final speaker = TextEditingController(text: optString(item ?? const {}, 'speaker_label') ?? 'A');
    final text = TextEditingController(text: optString(item ?? const {}, 'text_id'));
    final note = TextEditingController(text: optString(item ?? const {}, 'context_note'));
    String? signId = optString(item ?? const {}, 'sign_id');
    String? signTerm = optObject(item ?? const {}, 'sign')?['term'] as String?;
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'Dialog baru' : 'Ubah dialog'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: speaker,
                    maxLength: 30,
                    decoration: const InputDecoration(labelText: 'Pembicara (mis. A/B)'),
                  ),
                  TextFormField(
                    controller: text,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: 'Kalimat (Bahasa Indonesia)'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi.' : null,
                  ),
                  TextFormField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Catatan konteks (opsional)'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(signTerm ?? 'Tanpa kosakata tertaut'),
                    subtitle: const Text('Video kosakata dipakai bila dialog tak punya video'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Pilih kosakata',
                          icon: const Icon(Icons.link),
                          onPressed: () async {
                            final picked = await pickSign(context, ref);
                            if (picked != null && context.mounted) {
                              setState(() {
                                signId = picked.id;
                                signTerm = picked.term;
                              });
                            }
                          },
                        ),
                        if (signId != null)
                          IconButton(
                            tooltip: 'Lepas kosakata',
                            icon: const Icon(Icons.link_off),
                            onPressed: () => setState(() {
                              signId = null;
                              signTerm = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.of(context).pop(true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    final values = {
      'speaker_label': speaker.text.trim().isEmpty ? 'A' : speaker.text.trim(),
      'text_id': text.text.trim(),
      'context_note': note.text.trim().isEmpty ? null : note.text.trim(),
      'sign_id': signId,
    };
    speaker.dispose();
    text.dispose();
    note.dispose();
    if (saved != true) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (item == null) {
        final nextPos = items.isEmpty
            ? 0
            : items.map((i) => optInt(i, 'position')).reduce((a, b) => a > b ? a : b) + 1;
        await repo.insert('conversation_items', {...values, 'module_id': moduleId, 'position': nextPos});
      } else {
        await repo.update('conversation_items', reqString(item, 'id'), values);
      }
      ref.invalidate(_moduleItemsProvider(moduleId));
      ref.invalidate(conversationDetailProvider);
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  Future<void> _uploadVideo(BuildContext context, WidgetRef ref, Json item) async {
    final itemId = reqString(item, 'id');
    // Dibaca sebelum `await`: WidgetRef melempar StateError setelah unmount.
    final repo = ref.read(adminRepositoryProvider);
    final asset = await pickAndUploadMedia(context, ref,
        kind: MediaKind.video, folder: 'conversations/$moduleId/items', ownerId: itemId, prefix: 'video');
    if (asset == null) return;
    final old = optObject(item, 'video');
    try {
      await repo.update('conversation_items', itemId, {'video_asset_id': asset.id});
    } catch (error) {
      // Tautan gagal: hapus aset baru agar tidak yatim.
      await repo.deleteMedia(assetId: asset.id, path: asset.path).catchError((_) {});
      if (context.mounted) showErrorSnackBar(context, error);
      return;
    }
    // Aset baru sudah tertaut: jangan dihapus walau penghapusan aset lama gagal.
    if (old != null && optString(old, 'id') != null) {
      try {
        await repo.deleteMedia(assetId: reqString(old, 'id'), path: reqString(old, 'path'));
      } catch (_) {
        // Aset lama yatim dapat dibersihkan manual.
      }
    }
    if (!context.mounted) return;
    ref.invalidate(_moduleItemsProvider(moduleId));
    ref.invalidate(conversationDetailProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(_moduleItemsProvider(moduleId));
    return items.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorView(
        message: errorMessageOf(e),
        onRetry: () => ref.invalidate(_moduleItemsProvider(moduleId)),
      ),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < list.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: CircleAvatar(child: Text(optString(list[i], 'speaker_label') ?? 'A')),
                title: Text(optString(list[i], 'text_id') ?? ''),
                subtitle: Text([
                  if (optObject(list[i], 'sign') != null)
                    'Kosakata: ${optObject(list[i], 'sign')!['term']}',
                  optObject(list[i], 'video') != null ? 'ada video' : 'tanpa video sendiri',
                ].join(' · ')),
                onTap: () => _editItem(context, ref, list, item: list[i]),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Aksi dialog',
                  onSelected: (action) async {
                    final repo = ref.read(adminRepositoryProvider);
                    try {
                      switch (action) {
                        case 'up':
                          await repo.swapPositions('conversation_items', list[i], list[i - 1]);
                        case 'down':
                          await repo.swapPositions('conversation_items', list[i], list[i + 1]);
                        case 'video':
                          if (context.mounted) await _uploadVideo(context, ref, list[i]);
                          return;
                        case 'delete':
                          if (!context.mounted) return;
                          final ok = await showConfirmDialog(context,
                              title: 'Hapus dialog?',
                              message: 'Baris ini akan dihapus.',
                              confirmLabel: 'Hapus',
                              destructive: true);
                          if (!ok) return;
                          await repo.delete('conversation_items', reqString(list[i], 'id'));
                      }
                      ref.invalidate(_moduleItemsProvider(moduleId));
                      ref.invalidate(conversationDetailProvider);
                    } catch (error) {
                      if (context.mounted) showErrorSnackBar(context, error);
                    }
                  },
                  itemBuilder: (_) => [
                    if (i > 0) const PopupMenuItem(value: 'up', child: Text('Naikkan')),
                    if (i < list.length - 1)
                      const PopupMenuItem(value: 'down', child: Text('Turunkan')),
                    const PopupMenuItem(value: 'video', child: Text('Unggah/ganti video')),
                    const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _editItem(context, ref, list),
            icon: const Icon(Icons.add),
            label: const Text('Tambah dialog'),
          ),
        ],
      ),
    );
  }
}
