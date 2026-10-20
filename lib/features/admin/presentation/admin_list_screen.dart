import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/source_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/admin_repository.dart';
import 'admin_category_dialog.dart';
import 'admin_entities.dart';
import 'admin_widgets.dart';

typedef AdminListArgs = ({String entity, String? status, String search});

final adminListProvider =
    FutureProvider.autoDispose.family<List<Json>, AdminListArgs>((ref, args) {
  final e = AdminEntity.byKey(args.entity)!;
  return ref.watch(adminRepositoryProvider).list(
        e.table,
        columns: e.listColumns,
        status: e.hasStatus ? args.status : null,
        orderBy: e.orderBy,
        ascending: e.ascending,
        search: args.search,
        searchColumn: e.titleColumn,
      );
});

/// S26 Daftar konten per entitas dengan filter status.
class AdminListScreen extends ConsumerStatefulWidget {
  const AdminListScreen({super.key, required this.entity});
  final AdminEntity entity;

  @override
  ConsumerState<AdminListScreen> createState() => _AdminListScreenState();
}

class _AdminListScreenState extends ConsumerState<AdminListScreen> {
  String? _status;
  String _search = '';

  AdminListArgs get _args => (entity: widget.entity.key, status: _status, search: _search);

  Future<void> _open(String id) async {
    if (widget.entity.key == 'categories') {
      final row = ref.read(adminListProvider(_args)).value?.firstWhere((r) => r['id'] == id);
      await showCategoryDialog(context, ref, existing: row);
    } else {
      await context.push(AppRoutes.adminEdit(widget.entity.key, id));
    }
    // WidgetRef melempar StateError bila dipakai setelah unmount.
    if (mounted) ref.invalidate(adminListProvider);
  }

  Future<void> _create() async {
    if (widget.entity.key == 'categories') {
      await showCategoryDialog(context, ref);
    } else {
      await context.push(AppRoutes.adminEdit(widget.entity.key, 'new'));
    }
    if (mounted) ref.invalidate(adminListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entity;
    final list = ref.watch(adminListProvider(_args));
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: Text(e.title)),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: const Text('Tambah'),
        ),
        body: Column(
          children: [
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (v) => setState(() => _search = v),
                  textInputAction: TextInputAction.search,
                ),
              ),
            ),
            if (e.hasStatus)
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: const Text('Semua'),
                        selected: _status == null,
                        onSelected: (_) => setState(() => _status = null),
                      ),
                    ),
                    for (final s in kContentStatuses)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(contentStatusLabel(s)),
                          selected: _status == s,
                          onSelected: (_) => setState(() => _status = s),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: AsyncValueView<List<Json>>(
                value: list,
                onRetry: () => ref.invalidate(adminListProvider(_args)),
                isEmpty: (rows) => rows.isEmpty,
                empty: const EmptyView(icon: Icons.inbox_outlined, title: 'Belum ada data'),
                data: (rows) => ContentListView(
                  children: [
                    for (final row in rows)
                      Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.contentCard),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: ListTile(
                          onTap: () => _open(reqString(row, 'id')),
                          title: Text(optString(row, e.titleColumn) ?? '-'),
                          subtitle: Text(_subtitle(row)),
                          trailing: e.hasStatus
                              ? StatusBadge.content(optString(row, 'status') ?? 'draft')
                              : Icon(optBool(row, 'is_active', true)
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                        ),
                      ),
                    const SizedBox(height: 72),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Json row) {
    final parts = <String>[
      if (optObject(row, 'category')?['name'] is String)
        optObject(row, 'category')!['name'] as String,
      if (optString(row, 'slug') != null) optString(row, 'slug')!,
      if (optString(row, 'kind') != null)
        optString(row, 'kind') == 'conversation' ? 'Percakapan' : 'Kosakata',
      if (isSampleValidator(optString(row, 'validated_by'))) 'Materi contoh',
    ];
    return parts.isEmpty ? ' ' : parts.join(' · ');
  }
}
