import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/state_views.dart';
import '../../reports/data/report_repository.dart';
import '../../reports/domain/report.dart';
import '../../reports/presentation/report_history_screen.dart';
import '../data/admin_repository.dart';
import 'admin_widgets.dart';

const _reportStatuses = ['open', 'in_review', 'resolved', 'rejected'];

String reportStatusLabel(String s) => switch (s) {
      'open' => 'Menunggu',
      'in_review' => 'Ditinjau',
      'resolved' => 'Selesai',
      'rejected' => 'Ditolak',
      _ => s,
    };

final adminReportsProvider =
    FutureProvider.autoDispose.family<List<ContentReport>, String?>((ref, status) async {
  final rows = await ref.watch(adminRepositoryProvider).list(
        'content_reports',
        columns: ContentReport.columns,
        status: status,
      );
  return rows.map(ContentReport.fromJson).toList();
});

/// S27 Tinjau Laporan (Admin).
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  String? _status = 'open';

  Future<void> _review(ContentReport report) async {
    var status = report.status;
    final message = TextEditingController(text: report.resolutionMessage);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(report.targetTitle ?? 'Materi tidak tersedia',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('${report.category.label} · pelapor: '
                    '${report.reporterId == null ? 'anonim (akun dihapus)' : 'ID ${report.reporterId!.substring(0, 8)}…'}'),
                if (report.description != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(report.description!),
                ],
                if (report.targetId != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        final id = report.targetId!;
                        final route = switch (report.targetType) {
                          ReportTargetType.sign => AppRoutes.adminEdit('signs', id),
                          ReportTargetType.conversationModule => AppRoutes.adminEdit('modules', id),
                          ReportTargetType.lesson => AppRoutes.adminEdit('lessons', id),
                        };
                        Navigator.of(context).pop(false);
                        this.context.push(route);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Buka materi'),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final s in _reportStatuses)
                      DropdownMenuItem(value: s, child: Text(reportStatusLabel(s))),
                  ],
                  onChanged: (v) => setState(() => status = v ?? status),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: message,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Tanggapan untuk pelapor',
                    helperText: 'Pesan ini TERLIHAT oleh pelapor.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Simpan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final text = message.text.trim();
    message.dispose();
    if (ok != true) return;
    final closed = status == 'resolved' || status == 'rejected';
    try {
      await ref.read(adminRepositoryProvider).update('content_reports', report.id, {
        'status': status,
        'resolution_message': text.isEmpty ? null : text,
        'resolved_by': closed ? ref.read(adminCurrentUserIdProvider) : null,
        'resolved_at': closed ? DateTime.now().toUtc().toIso8601String() : null,
      });
      ref.invalidate(adminReportsProvider);
      ref.invalidate(myReportsProvider);
      if (mounted) showAppSnackBar(context, 'Laporan diperbarui');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(adminReportsProvider(_status));
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: const Text('Laporan')),
        body: Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                children: [
                  for (final s in [null, ..._reportStatuses])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(s == null ? 'Semua' : reportStatusLabel(s)),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AsyncValueView<List<ContentReport>>(
                value: reports,
                onRetry: () => ref.invalidate(adminReportsProvider(_status)),
                isEmpty: (list) => list.isEmpty,
                empty: const EmptyView(icon: Icons.inbox_outlined, title: 'Tidak ada laporan'),
                data: (list) => ContentListView(
                  children: [
                    for (final r in list) ReportCard(report: r, onTap: () => _review(r)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ID admin aktif untuk kolom `resolved_by`.
final adminCurrentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(adminRepositoryProvider).currentUserId,
);
