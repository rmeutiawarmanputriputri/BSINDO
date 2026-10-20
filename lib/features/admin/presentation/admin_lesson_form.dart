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
import '../../learning/data/learning_repository.dart';
import '../data/admin_repository.dart';
import 'admin_entities.dart';
import 'admin_quiz_editor.dart';
import 'admin_sign_picker.dart';
import 'admin_widgets.dart';

const _lessonColumns =
    'id, slug, title, description, sort_order, status, source_note, validated_by, verified_at';

const _lessonItemColumns =
    'id, lesson_id, position, item_type, body_text, sign_id, conversation_module_id, '
    'sign:signs(term), module:conversation_modules(title)';

final _adminLessonProvider = FutureProvider.autoDispose.family<Json?, String>((ref, id) {
  if (id == 'new') return Future.value(null);
  return ref.watch(adminRepositoryProvider).get('lessons', id, columns: _lessonColumns);
});

final lessonItemsAdminProvider = FutureProvider.autoDispose.family<List<Json>, String>(
  (ref, lessonId) => ref.watch(adminRepositoryProvider).list(
        'lesson_items',
        columns: _lessonItemColumns,
        orderBy: 'position',
        ascending: true,
        equals: {'lesson_id': lessonId},
      ),
);

/// S26 Form Pelajaran + item + kuis.
class AdminLessonFormScreen extends ConsumerWidget {
  const AdminLessonFormScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_adminLessonProvider(id));
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(id == 'new' ? 'Pelajaran baru' : 'Ubah pelajaran')),
        body: data.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: errorMessageOf(e),
            onRetry: () => ref.invalidate(_adminLessonProvider(id)),
          ),
          data: (row) => _LessonForm(row: row),
        ),
      ),
    );
  }
}

class _LessonForm extends ConsumerStatefulWidget {
  const _LessonForm({required this.row});
  final Json? row;

  @override
  ConsumerState<_LessonForm> createState() => _LessonFormState();
}

class _LessonFormState extends ConsumerState<_LessonForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _slug;
  late final TextEditingController _description;
  late final TextEditingController _sort;
  late final TextEditingController _validatedBy;
  late final TextEditingController _source;
  late String _status;
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
    _sort = TextEditingController(text: '${optInt(r, 'sort_order')}');
    _validatedBy = TextEditingController(text: optString(r, 'validated_by'));
    _source = TextEditingController(text: optString(r, 'source_note'));
    _status = optString(r, 'status') ?? 'draft';
    _verifiedAt = parseDate(r['verified_at']);
  }

  @override
  void dispose() {
    for (final c in [_title, _slug, _description, _sort, _validatedBy, _source]) {
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
      'sort_order': int.tryParse(_sort.text) ?? 0,
      'status': _status,
      'validated_by': _opt(_validatedBy),
      'source_note': _opt(_source),
      'verified_at': _verifiedAt?.toUtc().toIso8601String(),
    };
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (_id == null) {
        final newId = await repo.insert('lessons', values);
        if (!mounted) return;
        setState(() => _id = newId);
      } else {
        await repo.update('lessons', _id!, values);
        if (!mounted) return;
      }
      ref.invalidate(lessonsProvider);
      ref.invalidate(lessonDetailProvider);
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
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Deskripsi'),
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
          if (_id == null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: _saving ? null : () => _save(popAfter: false),
              child: const Text('Simpan dulu untuk menambah materi & kuis'),
            ),
          ] else ...[
            const SectionHeader(title: 'Materi pelajaran'),
            _LessonItemsEditor(lessonId: _id!),
            const SectionHeader(title: 'Kuis'),
            QuizEditor(lessonId: _id!),
          ],
        ],
      ),
    );
  }
}

class _LessonItemsEditor extends ConsumerWidget {
  const _LessonItemsEditor({required this.lessonId});
  final String lessonId;

  Future<void> _add(BuildContext context, WidgetRef ref, List<Json> items) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sign_language),
              title: const Text('Kosakata'),
              onTap: () => Navigator.of(context).pop('sign'),
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Modul percakapan'),
              onTap: () => Navigator.of(context).pop('conversation_module'),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Teks bacaan'),
              onTap: () => Navigator.of(context).pop('text'),
            ),
          ],
        ),
      ),
    );
    if (type == null || !context.mounted) return;
    Json? values;
    switch (type) {
      case 'sign':
        final pickedSign = await pickSign(context, ref);
        if (pickedSign != null) {
          values = {'item_type': 'sign', 'sign_id': pickedSign.id};
        }
      case 'conversation_module':
        final pickedModule = await _pickModule(context, ref);
        if (pickedModule != null) {
          values = {'item_type': 'conversation_module', 'conversation_module_id': pickedModule};
        }
      case 'text':
        final bodyText = await _askText(context);
        if (bodyText != null) values = {'item_type': 'text', 'body_text': bodyText};
    }
    if (values == null) return;
    final nextPos = items.isEmpty
        ? 0
        : items.map((i) => optInt(i, 'position')).reduce((a, b) => a > b ? a : b) + 1;
    try {
      await ref
          .read(adminRepositoryProvider)
          .insert('lesson_items', {...values, 'lesson_id': lessonId, 'position': nextPos});
      ref.invalidate(lessonItemsAdminProvider(lessonId));
      ref.invalidate(lessonDetailProvider);
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  Future<String?> _pickModule(BuildContext context, WidgetRef ref) async {
    final modules = await ref.read(adminRepositoryProvider).list(
          'conversation_modules',
          columns: 'id, title, status',
          orderBy: 'title',
          ascending: true,
        );
    if (!context.mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pilih modul'),
        children: [
          for (final m in modules)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(reqString(m, 'id')),
              child: Text('${optString(m, 'title')} (${optString(m, 'status')})'),
            ),
        ],
      ),
    );
  }

  Future<String?> _askText(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Teks bacaan'),
        content: TextField(controller: controller, maxLines: 6, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final t = controller.text.trim();
              if (t.isNotEmpty) Navigator.of(context).pop(t);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  String _label(Json item) => switch (optString(item, 'item_type')) {
        'sign' => 'Kosakata: ${optObject(item, 'sign')?['term'] ?? '-'}',
        'conversation_module' => 'Percakapan: ${optObject(item, 'module')?['title'] ?? '-'}',
        _ => 'Teks: ${optString(item, 'body_text') ?? ''}',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(lessonItemsAdminProvider(lessonId));
    return items.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorView(
        message: errorMessageOf(e),
        onRetry: () => ref.invalidate(lessonItemsAdminProvider(lessonId)),
      ),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < list.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(_label(list[i]), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Aksi materi',
                  onSelected: (action) async {
                    final repo = ref.read(adminRepositoryProvider);
                    try {
                      switch (action) {
                        case 'up':
                          await repo.swapPositions('lesson_items', list[i], list[i - 1]);
                        case 'down':
                          await repo.swapPositions('lesson_items', list[i], list[i + 1]);
                        case 'delete':
                          if (!context.mounted) return;
                          final ok = await showConfirmDialog(context,
                              title: 'Hapus materi?',
                              message: 'Item ini akan dihapus dari pelajaran.',
                              confirmLabel: 'Hapus',
                              destructive: true);
                          if (!ok) return;
                          await repo.delete('lesson_items', reqString(list[i], 'id'));
                      }
                      ref.invalidate(lessonItemsAdminProvider(lessonId));
                      ref.invalidate(lessonDetailProvider);
                    } catch (error) {
                      if (context.mounted) showErrorSnackBar(context, error);
                    }
                  },
                  itemBuilder: (_) => [
                    if (i > 0) const PopupMenuItem(value: 'up', child: Text('Naikkan')),
                    if (i < list.length - 1)
                      const PopupMenuItem(value: 'down', child: Text('Turunkan')),
                    const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _add(context, ref, list),
            icon: const Icon(Icons.add),
            label: const Text('Tambah materi'),
          ),
        ],
      ),
    );
  }
}
