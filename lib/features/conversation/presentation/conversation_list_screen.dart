import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/source_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../learning/data/progress_repository.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation.dart';

/// S11 Daftar Modul Percakapan.
class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState extends ConsumerState<ConversationListScreen> {
  String? _categoryId;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(conversationCategoriesProvider);
    final modules = ref.watch(conversationModulesProvider(_categoryId));
    final progress = ref.watch(progressListProvider).value ?? const [];
    final byModule = {for (final p in progress) if (p.moduleId != null) p.moduleId!: p};

    return Scaffold(
      appBar: AppBar(title: const Text('Percakapan')),
      body: Column(
        children: [
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
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() => _categoryId = null),
                  ),
                ),
                ...categories.maybeWhen(
                  data: (list) => [
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: _categoryId == c.id,
                          onSelected: (_) => setState(() => _categoryId = c.id),
                        ),
                      ),
                  ],
                  orElse: () => const <Widget>[],
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<ConversationModule>>(
              value: modules,
              onRetry: () => ref.invalidate(conversationModulesProvider(_categoryId)),
              isEmpty: (list) => list.isEmpty,
              empty: const EmptyView(
                icon: Icons.forum_outlined,
                title: 'Modul akan segera hadir',
                message: 'Materi percakapan sedang divalidasi oleh penutur BISINDO.',
              ),
              data: (list) => ContentListView(
                children: [
                  for (final m in list)
                    _ModuleCard(
                      module: m,
                      progress: byModule[m.id],
                      onTap: () => context.push(AppRoutes.conversation(m.id)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap, this.progress});

  final ConversationModule module;
  final ProgressEntry? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = progress?.completed ?? false;
    final percent = done ? 100 : (progress?.percent ?? 0);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(module.title, style: theme.textTheme.titleMedium)),
                  if (module.isSample) const SampleBadge(),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  if (module.categoryName != null) module.categoryName!,
                  '${module.itemCount} dialog',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                label: done ? 'Selesai' : 'Progres $percent persen',
                excludeSemantics: true,
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      done ? Icons.check_circle : Icons.timelapse,
                      size: 16,
                      color: done ? AppColors.success : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(done ? 'Selesai' : '$percent%', style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
