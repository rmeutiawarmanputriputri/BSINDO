import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/source_card.dart';
import '../../../core/widgets/state_views.dart';
import '../data/learning_repository.dart';
import '../data/progress_repository.dart';
import '../domain/learning.dart';

/// S14 Daftar Pelajaran.
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
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.learnProgress),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Progres'),
          ),
        ],
      ),
      body: AsyncValueView<List<Lesson>>(
        value: lessons,
        onRetry: () => ref.invalidate(lessonsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const EmptyView(
          icon: Icons.school_outlined,
          title: 'Pelajaran akan segera hadir',
          message: 'Materi pelajaran sedang divalidasi.',
        ),
        data: (list) {
          final done = list.where((l) => byLesson[l.id]?.completed ?? false).length;
          return ContentListView(
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
