import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/media_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../video/video_player_view.dart';
import '../data/quiz_bank_repository.dart';
import '../domain/quiz_bank.dart';

/// Soal untuk satu konfigurasi (diambil acak oleh server; tanpa kunci).
final quizQuestionsProvider =
    FutureProvider.autoDispose.family<List<QuizQuestion>, QuizConfig>(
  (ref, config) => ref.watch(quizBankRepositoryProvider).fetch(config),
);

class QuizPlayScreen extends ConsumerWidget {
  const QuizPlayScreen({super.key, required this.config});

  final QuizConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(quizQuestionsProvider(config));
    return Scaffold(
      appBar: AppBar(title: Text(config.title)),
      body: AsyncValueView<List<QuizQuestion>>(
        value: questions,
        onRetry: () => ref.invalidate(quizQuestionsProvider(config)),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyView(
          icon: Icons.quiz_outlined,
          title: config.mode == QuizMode.weak ? 'Belum ada soal untuk diulang' : 'Soal belum tersedia',
          message: config.mode == QuizMode.weak
              ? 'Kerjakan kuis terlebih dahulu. Soal yang dijawab salah akan muncul di sini.'
              : 'Soal untuk pilihan ini sedang disiapkan. Coba pilihan lain.',
          actionLabel: 'Kembali',
          onAction: () => context.pop(),
        ),
        data: (list) => QuizSession(config: config, questions: list),
      ),
    );
  }
}

/// Satu sesi kuis: menjawab soal satu per satu dengan umpan balik langsung,
/// lalu hasil akhir dinilai server.
class QuizSession extends ConsumerStatefulWidget {
  const QuizSession({super.key, required this.config, required this.questions});

  final QuizConfig config;
  final List<QuizQuestion> questions;

  @override
  ConsumerState<QuizSession> createState() => _QuizSessionState();
}

class _QuizSessionState extends ConsumerState<QuizSession> {
  late List<QuizQuestion> _questions = widget.questions;
  int _index = 0;
  final Map<String, QuizAnswer?> _answers = {};
  final Map<String, QuizReveal> _reveals = {};
  DateTime _startedAt = DateTime.now();
  bool _checking = false;
  bool _submitting = false;
  QuizSessionResult? _result;

  QuizQuestion get _current => _questions[_index];

  void _restart(List<QuizQuestion> questions) {
    setState(() {
      _questions = questions;
      _index = 0;
      _answers.clear();
      _reveals.clear();
      _result = null;
      _startedAt = DateTime.now();
    });
  }

  Future<void> _check() async {
    final q = _current;
    final answer = _answers[q.id];
    if (answer == null || !answer.isCompleteFor(q)) {
      showAppSnackBar(context, 'Lengkapi jawaban terlebih dahulu.');
      return;
    }
    setState(() => _checking = true);
    try {
      final reveal = await ref.read(quizBankRepositoryProvider).check(q.id, answer);
      if (mounted) setState(() => _reveals[q.id] = reveal);
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _next() async {
    if (_index < _questions.length - 1) {
      setState(() => _index++);
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await ref.read(quizBankRepositoryProvider).submit(
        widget.config,
        {for (final q in _questions) q.id: _answers[q.id]},
        startedAt: _startedAt,
      );
      ref.invalidate(quizHistoryProvider);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (_result != null || (_answers.isEmpty && _reveals.isEmpty)) return true;
    return showConfirmDialog(
      context,
      title: 'Keluar dari kuis?',
      message: 'Jawaban pada sesi ini tidak akan disimpan.',
      confirmLabel: 'Keluar',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return _ResultView(
        questions: _questions,
        result: result,
        onRetryWrong: () {
          final wrong = result.wrongQuestionIds.toSet();
          _restart(_questions.where((q) => wrong.contains(q.id)).toList());
        },
        onAgain: () => ref.invalidate(quizQuestionsProvider(widget.config)),
      );
    }

    final q = _current;
    final reveal = _reveals[q.id];
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) context.pop();
      },
      child: ContentListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Soal ${_index + 1} dari ${_questions.length}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              ),
              Chip(label: Text(q.type.label)),
            ],
          ),
          LinearProgressIndicator(value: (_index + 1) / _questions.length),
          const SizedBox(height: AppSpacing.lg),
          Semantics(header: true, child: Text(q.prompt, style: theme.textTheme.titleLarge)),
          const SizedBox(height: AppSpacing.md),
          if (q.videoPath != null) ...[
            VideoPlayerView(key: ValueKey('v${q.id}'), videoPath: q.videoPath, semanticTitle: 'Video soal'),
            const SizedBox(height: AppSpacing.md),
          ],
          if (q.imagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.contentCard),
              child: SignedImage(path: q.imagePath!, fit: BoxFit.contain, aspectRatio: 4 / 3, semanticLabel: 'Gambar soal'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          KeyedSubtree(
            key: ValueKey('a${q.id}'),
            child: switch (q.type) {
              QuizType.arrangeWord => ArrangeAnswerView(
                  question: q,
                  answer: _answers[q.id] as SequenceAnswer?,
                  reveal: reveal,
                  onChanged: (a) => setState(() => _answers[q.id] = a),
                ),
              QuizType.matchImage => MatchAnswerView(
                  question: q,
                  answer: _answers[q.id] as PairsAnswer?,
                  reveal: reveal,
                  onChanged: (a) => setState(() => _answers[q.id] = a),
                ),
              _ => ChoiceAnswerView(
                  question: q,
                  answer: _answers[q.id] as ChoiceAnswer?,
                  reveal: reveal,
                  onChanged: (a) => setState(() => _answers[q.id] = a),
                ),
            },
          ),
          if (reveal != null) ...[
            const SizedBox(height: AppSpacing.md),
            _FeedbackBox(reveal: reveal),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (reveal == null)
            FilledButton(
              onPressed: _checking ? null : _check,
              child: _checking
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Periksa jawaban'),
            )
          else
            FilledButton.icon(
              onPressed: _submitting ? null : _next,
              iconAlignment: IconAlignment.end,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(_index < _questions.length - 1 ? 'Soal berikutnya' : 'Lihat hasil'),
            ),
          if (reveal == null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _submitting ? null : _next,
              child: Text(_index < _questions.length - 1 ? 'Lewati soal' : 'Selesai & lihat hasil'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackBox extends StatelessWidget {
  const _FeedbackBox({required this.reveal});
  final QuizReveal reveal;

  @override
  Widget build(BuildContext context) {
    final ok = reveal.isCorrect;
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: ok ? const Color(0xFFDCFCE7) : AppColors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.contentCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.check_circle : Icons.cancel, color: ok ? AppColors.success : AppColors.error),
                const SizedBox(width: AppSpacing.sm),
                Text(ok ? 'Benar!' : 'Belum tepat', style: theme.textTheme.titleMedium),
              ],
            ),
            if (reveal.explanation != null && reveal.explanation!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Pembahasan', style: theme.textTheme.labelLarge),
              Text(reveal.explanation!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- jawaban

/// Pilihan tunggal (tebak huruf/angka/gerakan, pilihan ganda).
class ChoiceAnswerView extends StatelessWidget {
  const ChoiceAnswerView({
    super.key,
    required this.question,
    required this.answer,
    required this.reveal,
    required this.onChanged,
  });

  final QuizQuestion question;
  final ChoiceAnswer? answer;
  final QuizReveal? reveal;
  final ValueChanged<QuizAnswer> onChanged;

  @override
  Widget build(BuildContext context) {
    final locked = reveal != null;
    return Column(
      children: [
        for (final o in question.options)
          _OptionTile(
            option: o,
            selected: answer?.optionId == o.id,
            state: !locked
                ? _OptState.normal
                : o.id == reveal!.correctOptionId
                    ? _OptState.correct
                    : answer?.optionId == o.id
                        ? _OptState.wrong
                        : _OptState.normal,
            onTap: locked ? null : () => onChanged(ChoiceAnswer(o.id)),
          ),
      ],
    );
  }
}

enum _OptState { normal, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.selected, required this.state, this.onTap});
  final QuizOption option;
  final bool selected;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _OptState.correct => AppColors.success,
      _OptState.wrong => AppColors.error,
      _OptState.normal => selected ? AppColors.primary : const Color(0xFFE2E8F0),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: selected || state != _OptState.normal ? color.withValues(alpha: 0.08) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        side: BorderSide(color: color, width: selected || state != _OptState.normal ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        onTap: onTap,
        child: Semantics(
          selected: selected,
          button: true,
          label: '${option.label}${state == _OptState.correct ? ', jawaban benar' : state == _OptState.wrong ? ', jawaban Anda salah' : ''}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  state == _OptState.correct
                      ? Icons.check_circle
                      : state == _OptState.wrong
                          ? Icons.cancel
                          : selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                  color: color == const Color(0xFFE2E8F0) ? AppColors.textSecondary : color,
                ),
                const SizedBox(width: AppSpacing.md),
                if (option.imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(width: 72, height: 72, child: SignedImage(path: option.imagePath!)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(child: Text(option.label, style: Theme.of(context).textTheme.bodyLarge)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Susun kosakata: ketuk ubin untuk menyusun; ketuk ubin tersusun untuk mengembalikan.
class ArrangeAnswerView extends StatelessWidget {
  const ArrangeAnswerView({
    super.key,
    required this.question,
    required this.answer,
    required this.reveal,
    required this.onChanged,
  });

  final QuizQuestion question;
  final SequenceAnswer? answer;
  final QuizReveal? reveal;
  final ValueChanged<QuizAnswer> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chosen = answer?.optionIds ?? const <String>[];
    final byId = {for (final o in question.options) o.id: o};
    final pool = question.options.where((o) => !chosen.contains(o.id)).toList();
    final locked = reveal != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Susunan Anda', style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Container(
          constraints: const BoxConstraints(minHeight: 56),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(AppRadius.contentCard),
          ),
          child: chosen.isEmpty
              ? Text('Ketuk ubin di bawah sesuai urutan.', style: theme.textTheme.bodyMedium)
              : Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < chosen.length; i++)
                      InputChip(
                        label: Text(byId[chosen[i]]?.label ?? '?'),
                        onPressed: locked
                            ? null
                            : () => onChanged(SequenceAnswer([...chosen]..removeAt(i))),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final o in pool)
              ActionChip(
                label: Text(o.label, style: theme.textTheme.titleMedium),
                onPressed: locked ? null : () => onChanged(SequenceAnswer([...chosen, o.id])),
              ),
          ],
        ),
        if (locked && !reveal!.isCorrect && reveal!.correctSequence.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Urutan benar: ${reveal!.correctSequence.map((id) => byId[id]?.label ?? '?').join(' ')}',
              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}

/// Cocokkan gambar (kiri) dengan arti (kanan) lewat pilihan per gambar.
class MatchAnswerView extends StatelessWidget {
  const MatchAnswerView({
    super.key,
    required this.question,
    required this.answer,
    required this.reveal,
    required this.onChanged,
  });

  final QuizQuestion question;
  final PairsAnswer? answer;
  final QuizReveal? reveal;
  final ValueChanged<QuizAnswer> onChanged;

  @override
  Widget build(BuildContext context) {
    final pairs = answer?.pairs ?? const <String, String>{};
    final rights = question.rightOptions;
    final locked = reveal != null;
    return Column(
      children: [
        for (final (i, left) in question.leftOptions.indexed)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.contentCard),
              side: BorderSide(
                color: !locked
                    ? const Color(0xFFE2E8F0)
                    : reveal!.correctPairs[left.id] == pairs[left.id]
                        ? AppColors.success
                        : AppColors.error,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: left.imagePath == null
                          ? const ColoredBox(color: AppColors.inputFill, child: Icon(Icons.image_not_supported_outlined))
                          : SignedImage(path: left.imagePath!, semanticLabel: 'Gambar ${i + 1}'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: pairs[left.id],
                          isExpanded: true,
                          decoration: InputDecoration(labelText: 'Arti gambar ${i + 1}'),
                          items: [
                            for (final r in rights)
                              DropdownMenuItem(
                                value: r.id,
                                // Arti yang sudah dipakai gambar lain tetap terlihat (bisa ditukar).
                                child: Text(r.label, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: locked
                              ? null
                              : (v) {
                                  if (v == null) return;
                                  final next = Map<String, String>.from(pairs)
                                    ..removeWhere((k, val) => val == v && k != left.id)
                                    ..[left.id] = v;
                                  onChanged(PairsAnswer(next));
                                },
                        ),
                        if (locked && reveal!.correctPairs[left.id] != pairs[left.id])
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Benar: ${rights.where((r) => r.id == reveal!.correctPairs[left.id]).firstOrNull?.label ?? '-'}',
                              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------- hasil

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.questions,
    required this.result,
    required this.onRetryWrong,
    required this.onAgain,
  });

  final List<QuizQuestion> questions;
  final QuizSessionResult result;
  final VoidCallback onRetryWrong;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byId = {for (final q in questions) q.id: q};
    final wrong = result.wrongQuestionIds;
    return ContentListView(
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                result.scorePercent >= 70 ? Icons.emoji_events_rounded : Icons.auto_awesome_outlined,
                size: 64,
                color: AppColors.accent,
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text('${result.scorePercent}', style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
              Text('${result.correctCount} benar dari ${result.totalCount} soal', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(quizFeedback(result.scorePercent), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (wrong.isNotEmpty)
          FilledButton.icon(
            onPressed: onRetryWrong,
            icon: const Icon(Icons.replay),
            label: Text('Ulangi ${wrong.length} soal yang salah'),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(onPressed: onAgain, icon: const Icon(Icons.refresh), label: const Text('Kuis baru')),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: () => context.pop(), child: const Text('Selesai')),
        const SizedBox(height: AppSpacing.lg),
        Semantics(header: true, child: Text('Ringkasan & pembahasan', style: theme.textTheme.titleMedium)),
        const SizedBox(height: AppSpacing.sm),
        for (final (i, d) in result.details.indexed)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ListTile(
              leading: Icon(d.isCorrect ? Icons.check_circle : Icons.cancel,
                  color: d.isCorrect ? AppColors.success : AppColors.error),
              title: Text('${i + 1}. ${byId[d.questionId]?.prompt ?? 'Soal'}'),
              subtitle: Text(
                [
                  if (!d.isCorrect && byId[d.questionId] != null) 'Jawaban benar: ${_correctText(byId[d.questionId]!, d)}',
                  if (d.explanation != null && d.explanation!.isNotEmpty) d.explanation!,
                ].join('\n').ifEmpty(d.isCorrect ? 'Benar' : 'Belum tepat'),
              ),
            ),
          ),
      ],
    );
  }

  static String _correctText(QuizQuestion q, QuizReveal r) {
    final byId = {for (final o in q.options) o.id: o.label};
    if (r.correctOptionId != null) return byId[r.correctOptionId] ?? '-';
    if (r.correctSequence.isNotEmpty) return r.correctSequence.map((id) => byId[id] ?? '?').join(' ');
    if (r.correctPairs.isNotEmpty) {
      return r.correctPairs.entries.map((e) => '${byId[e.key]} → ${byId[e.value]}').join(', ');
    }
    return '-';
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
