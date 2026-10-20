import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/section_header.dart';
import '../../difficult_vocab/data/difficult_repository.dart';
import '../../difficult_vocab/domain/difficult_item.dart';
import '../data/learning_repository.dart';
import '../data/progress_repository.dart';
import '../domain/learning.dart';

class ProgressSummary {
  const ProgressSummary({
    required this.lessonsDone,
    required this.lessonsTotal,
    required this.modulesDone,
    required this.modulesTotal,
    required this.attempts,
    required this.difficultLearning,
    required this.difficultRelearned,
  });

  final int lessonsDone;
  final int lessonsTotal;
  final int modulesDone;
  final int modulesTotal;
  final List<QuizAttempt> attempts;
  final int difficultLearning;
  final int difficultRelearned;

  int? get averageScore => attempts.isEmpty
      ? null
      : (attempts.map((a) => a.scorePercent).reduce((a, b) => a + b) / attempts.length)
          .round();

  int? get bestScore => attempts.isEmpty
      ? null
      : attempts.map((a) => a.scorePercent).reduce((a, b) => a > b ? a : b);
}

final progressSummaryProvider = FutureProvider.autoDispose<ProgressSummary>((ref) async {
  final learning = ref.watch(learningRepositoryProvider);
  final difficult = ref.watch(difficultRepositoryProvider);
  final results = await Future.wait([
    ref.watch(progressListProvider.future),
    learning.publishedLessonCount(),
    learning.publishedModuleCount(),
    learning.attempts(),
    difficult.list(),
  ]);
  final progress = results[0] as List<ProgressEntry>;
  final difficultItems = results[4] as List<DifficultItem>;
  return ProgressSummary(
    lessonsDone: progress.where((p) => p.lessonId != null && p.completed && p.title != null).length,
    lessonsTotal: results[1] as int,
    modulesDone: progress.where((p) => p.moduleId != null && p.completed && p.title != null).length,
    modulesTotal: results[2] as int,
    attempts: results[3] as List<QuizAttempt>,
    difficultLearning: difficultItems.where((d) => d.status == DifficultStatus.learning).length,
    difficultRelearned: difficultItems.where((d) => d.status == DifficultStatus.relearned).length,
  );
});

/// S18 Progres.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(progressSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Progres Belajar')),
      body: AsyncValueView<ProgressSummary>(
        value: summary,
        onRetry: () => ref.invalidate(progressSummaryProvider),
        data: (s) => ContentListView(
          children: [
            _StatBar(label: 'Pelajaran selesai', done: s.lessonsDone, total: s.lessonsTotal),
            _StatBar(label: 'Modul percakapan selesai', done: s.modulesDone, total: s.modulesTotal),
            _StatBar(
              label: 'Kosakata sulit sudah dipelajari ulang',
              done: s.difficultRelearned,
              total: s.difficultRelearned + s.difficultLearning,
            ),
            const SectionHeader(title: 'Kuis'),
            Text(
              s.attempts.isEmpty
                  ? 'Belum ada percobaan kuis.'
                  : 'Rata-rata ${s.averageScore}% · Terbaik ${s.bestScore}% · ${s.attempts.length} percobaan',
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final a in s.attempts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(a.passed ? Icons.check_circle : Icons.cancel_outlined,
                    color: a.passed ? AppColors.success : AppColors.error),
                title: Text('${a.quizTitle ?? 'Kuis'} · ${a.scorePercent}%'),
                subtitle: Text(
                    '${a.passed ? 'Lulus' : 'Belum lulus'} · ${formatDateTimeId(a.submittedAt)}'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.label, required this.done, required this.total});
  final String label;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = total == 0 ? 0.0 : done / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Semantics(
        label: '$label: $done dari $total',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
                Text('$done / $total', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            LinearProgressIndicator(
              value: value,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}
