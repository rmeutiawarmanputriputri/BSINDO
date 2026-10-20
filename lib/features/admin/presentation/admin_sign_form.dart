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
import '../../../core/widgets/state_views.dart';
import '../../dictionary/data/sign_repository.dart';
import '../../dictionary/domain/sign.dart';
import '../../video/video_player_view.dart';
import '../data/admin_repository.dart';
import '../data/media_upload.dart';
import 'admin_widgets.dart';

const _signColumns =
    'id, term, entry_type, category_id, meaning, movement_description, '
    'usage_example, source_note, validated_by, verified_at, status, '
    'video_asset_id, thumbnail_asset_id, '
    'video:media_assets!video_asset_id(id, path), thumb:media_assets!thumbnail_asset_id(id, path)';

final _adminSignProvider = FutureProvider.autoDispose.family<Json?, String>((ref, id) {
  if (id == 'new') return Future.value(null);
  return ref.watch(adminRepositoryProvider).get('signs', id, columns: _signColumns);
});

final _allSignCategoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(signRepositoryProvider).categories(),
);

/// S26 Form Kosakata (buat/ubah) + unggah/ganti video & thumbnail.
class AdminSignFormScreen extends ConsumerWidget {
  const AdminSignFormScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_adminSignProvider(id));
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(id == 'new' ? 'Kosakata baru' : 'Ubah kosakata')),
        body: data.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: errorMessageOf(e),
            onRetry: () => ref.invalidate(_adminSignProvider(id)),
          ),
          data: (row) => _SignForm(row: row),
        ),
      ),
    );
  }
}

class _SignForm extends ConsumerStatefulWidget {
  const _SignForm({required this.row});
  final Json? row;

  @override
  ConsumerState<_SignForm> createState() => _SignFormState();
}

class _SignFormState extends ConsumerState<_SignForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _term;
  late final TextEditingController _meaning;
  late final TextEditingController _movement;
  late final TextEditingController _example;
  late final TextEditingController _validatedBy;
  late final TextEditingController _source;
  late String _entryType;
  late String _status;
  String? _categoryId;
  DateTime? _verifiedAt;
  String? _id;
  Json? _video;
  Json? _thumb;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.row ?? const <String, dynamic>{};
    _id = optString(r, 'id');
    _term = TextEditingController(text: optString(r, 'term'));
    _meaning = TextEditingController(text: optString(r, 'meaning'));
    _movement = TextEditingController(text: optString(r, 'movement_description'));
    _example = TextEditingController(text: optString(r, 'usage_example'));
    _validatedBy = TextEditingController(text: optString(r, 'validated_by'));
    _source = TextEditingController(text: optString(r, 'source_note'));
    _entryType = optString(r, 'entry_type') ?? 'word';
    _status = optString(r, 'status') ?? 'draft';
    _categoryId = optString(r, 'category_id');
    _verifiedAt = parseDate(r['verified_at']);
    _video = optObject(r, 'video');
    _thumb = optObject(r, 'thumb');
  }

  @override
  void dispose() {
    for (final c in [_term, _meaning, _movement, _example, _validatedBy, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nullIfEmpty(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Json get _values => {
        'term': _term.text.trim(),
        'entry_type': _entryType,
        'category_id': _categoryId,
        'meaning': _nullIfEmpty(_meaning),
        'movement_description': _nullIfEmpty(_movement),
        'usage_example': _nullIfEmpty(_example),
        'status': _status,
        'validated_by': _nullIfEmpty(_validatedBy),
        'source_note': _nullIfEmpty(_source),
        'verified_at': _verifiedAt?.toUtc().toIso8601String(),
      };

  Future<bool> _save({bool popAfter = true}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    setState(() => _saving = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (_id == null) {
        _id = await repo.insert('signs', _values);
      } else {
        await repo.update('signs', _id!, _values);
      }
      if (!mounted) return true;
      ref.invalidate(signDetailProvider);
      showAppSnackBar(context, 'Tersimpan');
      if (popAfter) context.pop();
      return true;
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Unggah aset baru → tautkan → hapus aset lama (SECURITY §6).
  Future<void> _replaceMedia(MediaKind kind) async {
    // Dibaca sebelum `await`: WidgetRef melempar StateError setelah unmount.
    final repo = ref.read(adminRepositoryProvider);
    if (_id == null) {
      // Butuh id untuk path objek: simpan draf dulu.
      final ok = await _save(popAfter: false);
      if (!ok || _id == null) return;
    }
    if (!mounted) return;
    final asset = await pickAndUploadMedia(
      context,
      ref,
      kind: kind,
      folder: 'signs',
      ownerId: _id!,
      prefix: kind == MediaKind.video ? 'video' : 'thumb',
    );
    if (asset == null) return;
    final column = kind == MediaKind.video ? 'video_asset_id' : 'thumbnail_asset_id';
    final old = kind == MediaKind.video ? _video : _thumb;
    try {
      await repo.update('signs', _id!, {column: asset.id});
    } catch (error) {
      // Tautan gagal: hapus aset baru agar tidak yatim.
      await repo.deleteMedia(assetId: asset.id, path: asset.path).catchError((_) {});
      if (mounted) showErrorSnackBar(context, error);
      return;
    }
    // Aset baru sudah tertaut: jangan dihapus walau langkah berikut gagal.
    if (old != null && optString(old, 'id') != null) {
      try {
        await repo.deleteMedia(assetId: reqString(old, 'id'), path: reqString(old, 'path'));
      } catch (_) {
        // Aset lama yatim dapat dibersihkan manual.
      }
    }
    if (!mounted) return;
    setState(() {
      final json = <String, dynamic>{'id': asset.id, 'path': asset.path};
      if (kind == MediaKind.video) {
        _video = json;
      } else {
        _thumb = json;
      }
    });
    ref.invalidate(signDetailProvider);
    showAppSnackBar(context, 'Media diperbarui');
  }

  Future<void> _archiveOrDelete() async {
    if (_id == null) return;
    final archive = await showConfirmDialog(
      context,
      title: 'Arsipkan kosakata?',
      message: 'Disarankan mengarsipkan daripada menghapus. Materi arsip tidak tampil '
          'ke pengguna.',
      confirmLabel: 'Arsipkan',
    );
    if (!archive || !mounted) return;
    setState(() => _status = 'archived');
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(_allSignCategoriesProvider).value ?? const <Category>[];
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ContentListView(
        children: [
          TextFormField(
            controller: _term,
            decoration: const InputDecoration(labelText: 'Kata / frasa'),
            maxLength: 120,
            validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi.' : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'word', label: Text('Kata')),
              ButtonSegment(value: 'phrase', label: Text('Frasa')),
            ],
            selected: {_entryType},
            onSelectionChanged: (s) => setState(() => _entryType = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String?>(
            initialValue: categories.any((c) => c.id == _categoryId) ? _categoryId : null,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Tanpa kategori')),
              for (final c in categories)
                DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _meaning,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Arti', alignLabelWithHint: true),
          ),
          TextFormField(
            controller: _movement,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Petunjuk gerakan',
              helperText: 'Hanya dari sumber tervalidasi. Jangan diisi AI; kosongkan bila belum ada.',
              alignLabelWithHint: true,
            ),
          ),
          TextFormField(
            controller: _example,
            maxLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Contoh penggunaan'),
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
          Text('Video & thumbnail', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (_video != null)
            VideoPlayerView(
              key: ValueKey(_video!['id']),
              videoPath: optString(_video!, 'path'),
              posterPath: _thumb != null ? optString(_thumb!, 'path') : null,
              semanticTitle: 'Pratinjau video',
            )
          else
            Text('Belum ada video.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _replaceMedia(MediaKind.video),
                icon: const Icon(Icons.video_file_outlined),
                label: Text(_video == null ? 'Unggah video' : 'Ganti video'),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _replaceMedia(MediaKind.image),
                icon: const Icon(Icons.image_outlined),
                label: Text(_thumb == null ? 'Unggah thumbnail' : 'Ganti thumbnail'),
              ),
            ],
          ),
          Text('MP4/WebM ≤ 20 MB (disarankan 480p, faststart). Thumbnail JPG/PNG/WebP.',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Simpan', loading: _saving, onPressed: _save),
          if (_id != null && _status != 'archived') ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: _saving ? null : _archiveOrDelete,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Arsipkan'),
            ),
          ],
        ],
      ),
    );
  }
}
