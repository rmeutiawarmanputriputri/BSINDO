import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/source_card.dart';
import '../../../core/widgets/state_views.dart';
import '../data/learning_repository.dart';
import '../data/progress_repository.dart';
import '../../study/data/study_repository.dart';
import '../../study/presentation/learn_module_grid.dart';
import '../domain/learning.dart';

/// Tab Belajar (v1.1.0): modul Alfabet, Angka, Kosakata, Percakapan, Kuis,
/// lalu daftar Pelajaran (fitur lama tetap ada).
class LessonsScreen extends ConsumerWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(lessonsProvider);
    final progress = ref.watch(progressListProvider).value ?? const <ProgressEntry>[];
    final byLesson = {for (final p in progress) if (p.lessonId != null) p.lessonId!: p};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Belajar'),
        actions: [
          IconButton(
            tooltip: 'Cari materi',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(AppRoutes.search),
          ),
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.learnProgress),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Progres'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lessonsProvider);
          ref.invalidate(progressSummaryProvider);
          ref.invalidate(signProgressProvider);
        },
        child: ContentListView(
          children: [
            const LearnModuleGrid(),
            const SectionHeader(title: 'Pelajaran'),
            lessons.when(
              loading: () => const LoadingView(itemCount: 2),
              error: (e, _) => ErrorView(
                message: errorMessageOf(e),
                onRetry: () => ref.invalidate(lessonsProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Text('Pelajaran belum tersedia.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary));
                }
                final done = list.where((l) => byLesson[l.id]?.completed ?? false).length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('$done dari ${list.length} pelajaran selesai',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    for (final lesson in list)
                      LessonCard(
                        lesson: lesson,
                        progress: byLesson[lesson.id],
                        onTap: () => context.push(AppRoutes.lesson(lesson.id)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LessonCard extends StatelessWidget {
  const LessonCard({super.key, required this.lesson, required this.onTap, this.progress});

  final Lesson lesson;
  final ProgressEntry? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, label, color) = progress == null
        ? (Icons.radio_button_unchecked, 'Belum dimulai', AppColors.textSecondary)
        : progress!.completed
            ? (Icons.check_circle, 'Selesai', AppColors.success)
            : (Icons.timelapse, 'Berjalan', AppColors.primary);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                  Expanded(child: Text(lesson.title, style: theme.textTheme.titleMedium)),
                  if (lesson.isSample) const SampleBadge(),
                ],
              ),
              if (lesson.description != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(lesson.description!,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text('${lesson.itemCount} materi', style: theme.textTheme.bodySmall),
                  const Spacer(),
                  ExcludeSemantics(child: Icon(icon, size: 18, color: color)),
                  const SizedBox(width: 4),
                  Text(label, style: theme.textTheme.labelMedium?.copyWith(color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
