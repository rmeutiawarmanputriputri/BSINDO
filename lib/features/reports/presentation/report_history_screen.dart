import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';

/// S23 Riwayat Laporan (baca saja).
class ReportHistoryScreen extends ConsumerWidget {
  const ReportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Laporan')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myReportsProvider.future),
        child: AsyncValueView<List<ContentReport>>(
          value: reports,
          onRetry: () => ref.invalidate(myReportsProvider),
          isEmpty: (list) => list.isEmpty,
          empty: const EmptyView(
            icon: Icons.outlined_flag,
            title: 'Belum ada laporan',
            message: 'Gunakan tombol "Laporkan" pada materi bila menemukan kekeliruan.',
          ),
          data: (list) => ContentListView(
            children: [for (final r in list) ReportCard(report: r)],
          ),
        ),
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, this.onTap, this.trailing});

  final ContentReport report;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.targetTitle ?? 'Materi tidak tersedia',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  StatusBadge.report(report.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${report.category.label} · ${formatDateTimeId(report.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
              if (report.description != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(report.description!, style: theme.textTheme.bodyMedium),
              ],
              if (report.resolutionMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text('Tanggapan: ${report.resolutionMessage}',
                        style: theme.textTheme.bodyMedium),
                  ),
                ),
              ],
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
