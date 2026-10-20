import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/section_header.dart';
import '../data/admin_repository.dart';
import 'admin_widgets.dart';

final adminCountsProvider = FutureProvider.autoDispose<Map<String, int>>(
  (ref) => ref.watch(adminRepositoryProvider).dashboardCounts(),
);

/// S25 Dashboard Admin.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(adminCountsProvider);
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: AsyncValueView<Map<String, int>>(
          value: counts,
          onRetry: () => ref.invalidate(adminCountsProvider),
          data: (c) => ContentListView(
            children: [
              Row(
                children: [
                  _CountTile(label: 'Laporan terbuka', value: c['open_reports'] ?? 0),
                  const SizedBox(width: AppSpacing.sm),
                  _CountTile(label: 'Menunggu tinjauan', value: c['in_review'] ?? 0),
                  const SizedBox(width: AppSpacing.sm),
                  _CountTile(label: 'Draf', value: c['drafts'] ?? 0),
                ],
              ),
              const SectionHeader(title: 'Kelola konten'),
              for (final (entity, icon, label) in const [
                ('signs', Icons.sign_language, 'Kosakata'),
                ('categories', Icons.category_outlined, 'Kategori'),
                ('modules', Icons.forum_outlined, 'Modul Percakapan'),
                ('lessons', Icons.school_outlined, 'Pelajaran & Kuis'),
                ('reports', Icons.outlined_flag, 'Laporan'),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon, color: AppColors.primary),
                  title: Text(label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await context.push(AppRoutes.adminEntity(entity));
                    if (context.mounted) ref.invalidate(adminCountsProvider);
                  },
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Input massal (CSV) dapat dilakukan lewat Supabase Studio. '
                'Materi hanya boleh diterbitkan setelah divalidasi.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Card(
          margin: EdgeInsets.zero,
          color: AppColors.inputFill,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: theme.textTheme.headlineSmall),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
