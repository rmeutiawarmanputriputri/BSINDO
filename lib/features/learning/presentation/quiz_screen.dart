import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/state_views.dart';
import '../../video/video_player_view.dart';
import '../data/learning_repository.dart';
import '../data/progress_repository.dart';
import '../domain/learning.dart';

/// S16 Kuis + S17 Hasil. Skor dihitung server (RPC `submit_quiz_attempt`).
class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = ref.watch(quizProvider(lessonId));
    return AsyncValueView<Quiz>(
      value: quiz,
      onRetry: () => ref.invalidate(quizProvider(lessonId)),
      loading: const Scaffold(body: LoadingView()),
      data: (q) => q.questions.isEmpty
          ? Scaffold(
              appBar: AppBar(title: const Text('Kuis')),
              body: const EmptyView(
                icon: Icons.quiz_outlined,
                title: 'Kuis tidak tersedia',
                message: 'Belum ada soal untuk pelajaran ini.',
              ),
            )
          : _QuizRunner(quiz: q),
    );
  }
}

class _QuizRunner extends ConsumerStatefulWidget {
  const _QuizRunner({required this.quiz});
  final Quiz quiz;

  @override
  ConsumerState<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends ConsumerState<_QuizRunner> {
  int _index = 0;
  final Map<String, String> _answers = {};
  bool _submitting = false;
  bool _submitFailed = false;
  QuizResult? _result;

  Quiz get quiz => widget.quiz;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _submitFailed = false;
    });
    try {
      final result =
          await ref.read(learningRepositoryProvider).submitQuiz(quiz.id, _answers);
      ref.invalidate(progressListProvider);
      ref.invalidate(attemptsProvider);
      if (!mounted) return;
      setState(() => _result = result);
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Skor ${result.scorePercent} persen, ${result.passed ? 'lulus' : 'belum lulus'}',
        Directionality.of(context),
      );
    } catch (error) {
      if (!mounted) return;
      // Jawaban tetap di memori; tombol "Kirim ulang".
      setState(() => _submitFailed = true);
      showAppSnackBar(
        context,
        error is NotFoundFailure ? 'Kuis tidak tersedia.' : errorMessageOf(error),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _restart() => setState(() {
        _index = 0;
        _answers.clear();
        _result = null;
      });

  Future<bool> _confirmExit() => showConfirmDialog(
        context,
        title: 'Keluar dari kuis?',
        message: 'Jawaban Anda tidak akan disimpan.',
        confirmLabel: 'Keluar',
        destructive: true,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final inProgress = result == null && _answers.isNotEmpty;
    return PopScope<Object?>(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(result == null ? quiz.title : 'Hasil Kuis')),
        body: result == null ? _buildQuestion(context) : _buildResult(context, result),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final theme = Theme.of(context);
    final q = quiz.questions[_index];
    final total = quiz.questions.length;
    final isLast = _index == total - 1;
    final selected = _answers[q.id];
    return ContentListView(
      children: [
        Semantics(
          label: 'Soal ${_index + 1} dari $total',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Soal ${_index + 1} dari $total', style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: (_index + 1) / total,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (q.videoPath != null || q.signTerm != null) ...[
          VideoPlayerView(
            key: ValueKey(q.id),
            videoPath: q.videoPath,
            semanticTitle: 'Video soal ${_index + 1}',
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Semantics(header: true, child: Text(q.prompt, style: theme.textTheme.titleLarge)),
        const SizedBox(height: AppSpacing.lg),
        RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) {
            if (value != null) setState(() => _answers[q.id] = value);
          },
          child: Column(
            children: [
              for (final option in q.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Material(
                    color: selected == option.id
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.contentCard),
                      side: BorderSide(
                        color: selected == option.id
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0),
                        width: selected == option.id ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RadioListTile<String>(
                      value: option.id,
                      title: Text(option.label, style: theme.textTheme.bodyLarge),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            if (_index > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => setState(() => _index--),
                  child: const Text('Sebelumnya'),
                ),
              ),
            if (_index > 0) const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: AppButton(
                label: isLast ? (_submitFailed ? 'Kirim ulang' : 'Selesai') : 'Lanjut',
                trailingArrow: !isLast,
                loading: _submitting,
                onPressed: selected == null
                    ? null
                    : () => isLast ? _submit() : setState(() => _index++),
              ),
            ),
          ],
        ),
        if (isLast && _answers.length < total)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              '${total - _answers.length} soal belum dijawab (dihitung salah).',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, QuizResult result) {
    final theme = Theme.of(context);
    final attempts = ref.watch(attemptsProvider(quiz.id));
    return ContentListView(
      children: [
        Semantics(
          liveRegion: true,
          child: Column(
            children: [
              Icon(
                result.passed ? Icons.emoji_events_outlined : Icons.refresh,
                size: 56,
                color: result.passed ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('${result.scorePercent}%', style: theme.textTheme.displaySmall),
              Text(
                result.passed
                    ? 'Lulus (batas ${quiz.passScorePercent}%)'
                    : 'Belum lulus (batas ${quiz.passScorePercent}%)',
                style: theme.textTheme.titleMedium,
              ),
              Text('${result.correctCount} dari ${result.totalCount} benar',
                  style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Tinjauan soal', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final review in result.details) _ReviewTile(quiz: quiz, review: review),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: _restart, child: const Text('Ulangi')),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Kembali ke pelajaran'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Riwayat percobaan', style: theme.textTheme.titleMedium),
        attempts.maybeWhen(
          data: (list) => Column(
            children: [
              for (final a in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(a.passed ? Icons.check_circle : Icons.cancel_outlined,
                      color: a.passed ? AppColors.success : AppColors.error),
                  title: Text('${a.scorePercent}% · ${a.passed ? 'Lulus' : 'Belum lulus'}'),
                  subtitle: Text(formatDateTimeId(a.submittedAt)),
                ),
            ],
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.quiz, required this.review});
  final Quiz quiz;
  final QuestionReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = quiz.questions.where((q) => q.id == review.questionId).firstOrNull;
    String labelOf(String? optionId) =>
        question?.options.where((o) => o.id == optionId).firstOrNull?.label ?? '—';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: review.isCorrect ? const Color(0xFFEAF7EE) : AppColors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(review.isCorrect ? Icons.check_circle : Icons.cancel,
                    color: review.isCorrect ? AppColors.success : AppColors.error,
                    size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(review.isCorrect ? 'Benar' : 'Salah', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(question?.prompt ?? '', style: theme.textTheme.bodyMedium),
            Text('Jawaban Anda: ${labelOf(review.selectedOptionId)}'),
            if (!review.isCorrect) Text('Jawaban benar: ${labelOf(review.correctOptionId)}'),
            if (review.explanation != null && review.explanation!.isNotEmpty)
              Text('Penjelasan: ${review.explanation}', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
