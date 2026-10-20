import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/state_views.dart';
import '../../learning/data/learning_repository.dart';
import '../data/admin_repository.dart';
import 'admin_sign_picker.dart';

const _quizColumns =
    'id, lesson_id, title, pass_score_percent, is_active, '
    'questions(id, position, prompt, sign_id, sign:signs(term), '
    'options:question_options(id, position, label))';

final _quizAdminProvider = FutureProvider.autoDispose.family<Json?, String>((ref, lessonId) async {
  final rows = await ref.watch(adminRepositoryProvider).list(
        'quizzes',
        columns: _quizColumns,
        orderBy: 'created_at',
        equals: {'lesson_id': lessonId},
      );
  return rows.firstOrNull;
});

/// Editor kuis pelajaran: pengaturan kuis + soal pilihan ganda + kunci jawaban
/// (tabel terpisah, D-07).
class QuizEditor extends ConsumerWidget {
  const QuizEditor({super.key, required this.lessonId});
  final String lessonId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(_quizAdminProvider(lessonId));
    ref.invalidate(quizProvider);
    ref.invalidate(lessonDetailProvider);
  }

  Future<void> _editSettings(BuildContext context, WidgetRef ref, Json? quiz) async {
    final title = TextEditingController(text: optString(quiz ?? const {}, 'title') ?? 'Kuis');
    final pass = TextEditingController(
        text: '${optInt(quiz ?? const {}, 'pass_score_percent', 70)}');
    var active = optBool(quiz ?? const {}, 'is_active', true);
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(quiz == null ? 'Buat kuis' : 'Pengaturan kuis'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Judul kuis'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi.' : null,
                ),
                TextFormField(
                  controller: pass,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Nilai lulus (%)'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 100 ? '1–100.' : null;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.of(context).pop(true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    final values = {
      'title': title.text.trim(),
      'pass_score_percent': int.tryParse(pass.text) ?? 70,
      'is_active': active,
    };
    title.dispose();
    pass.dispose();
    if (ok != true) return;
    try {
      final repo = ref.read(adminRepositoryProvider);
      if (quiz == null) {
        await repo.insert('quizzes', {...values, 'lesson_id': lessonId});
      } else {
        await repo.update('quizzes', reqString(quiz, 'id'), values);
      }
      _refresh(ref);
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  Future<void> _editQuestion(BuildContext context, WidgetRef ref, String quizId,
      List<Json> questions, {Json? question}) async {
    final repo = ref.read(adminRepositoryProvider);
    final existingOptions = question == null
        ? <Json>[]
        : (optList(question, 'options')
          ..sort((a, b) => optInt(a, 'position').compareTo(optInt(b, 'position'))));
    String? correctOptionId;
    String? explanationText;
    if (question != null) {
      try {
        final key = await repo.answerKey(reqString(question, 'id'));
        correctOptionId = key != null ? optString(key, 'correct_option_id') : null;
        explanationText = key != null ? optString(key, 'explanation') : null;
      } catch (_) {
        // Kunci belum ada/gagal dimuat: admin memilih ulang jawaban benar.
      }
    }
    if (!context.mounted) return;
    final prompt = TextEditingController(text: optString(question ?? const {}, 'prompt'));
    final explanation = TextEditingController(text: explanationText);
    final options = [
      for (final o in existingOptions) TextEditingController(text: optString(o, 'label')),
    ];
    while (options.length < 2) {
      options.add(TextEditingController());
    }
    var correct = existingOptions.indexWhere((o) => o['id'] == correctOptionId);
    if (correct < 0) correct = 0;
    String? signId = optString(question ?? const {}, 'sign_id');
    String? signTerm = optObject(question ?? const {}, 'sign')?['term'] as String?;
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(question == null ? 'Soal baru' : 'Ubah soal'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: prompt,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(labelText: 'Pertanyaan'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi.' : null,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(signTerm == null ? 'Tanpa video' : 'Video: $signTerm'),
                      subtitle: const Text('Opsional: soal memakai video kosakata'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Pilih kosakata',
                            icon: const Icon(Icons.link),
                            onPressed: () async {
                              final picked = await pickSign(context, ref);
                              if (picked != null && context.mounted) {
                                setState(() {
                                  signId = picked.id;
                                  signTerm = picked.term;
                                });
                              }
                            },
                          ),
                          if (signId != null)
                            IconButton(
                              tooltip: 'Lepas video',
                              icon: const Icon(Icons.link_off),
                              onPressed: () => setState(() {
                                signId = null;
                                signTerm = null;
                              }),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Pilihan jawaban (tandai yang benar)',
                        style: Theme.of(context).textTheme.titleSmall),
                    RadioGroup<int>(
                      groupValue: correct,
                      onChanged: (v) => setState(() => correct = v ?? correct),
                      child: Column(
                        children: [
                          for (var i = 0; i < options.length; i++)
                            Row(
                              children: [
                                Radio<int>(value: i),
                                Expanded(
                                  child: TextFormField(
                                    controller: options[i],
                                    maxLength: 200,
                                    decoration: InputDecoration(labelText: 'Pilihan ${i + 1}'),
                                    validator: (v) =>
                                        (v ?? '').trim().isEmpty ? 'Wajib diisi.' : null,
                                  ),
                                ),
                                if (options.length > 2)
                                  IconButton(
                                    tooltip: 'Hapus pilihan',
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () => setState(() {
                                      options.removeAt(i).dispose();
                                      if (correct >= options.length) correct = 0;
                                    }),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (options.length < 6)
                      TextButton.icon(
                        onPressed: () => setState(() => options.add(TextEditingController())),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah pilihan'),
                      ),
                    TextFormField(
                      controller: explanation,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Penjelasan (opsional)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.of(context).pop(true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    final labels = options.map((c) => c.text.trim()).toList();
    final promptText = prompt.text.trim();
    final explanationValue = explanation.text.trim().isEmpty ? null : explanation.text.trim();
    for (final c in [prompt, explanation, ...options]) {
      c.dispose();
    }
    if (ok != true) return;

    try {
      String questionId;
      if (question == null) {
        final nextPos = questions.isEmpty
            ? 0
            : questions.map((q) => optInt(q, 'position')).reduce((a, b) => a > b ? a : b) + 1;
        questionId = await repo.insert('questions', {
          'quiz_id': quizId,
          'position': nextPos,
          'prompt': promptText,
          'sign_id': signId,
        });
      } else {
        questionId = reqString(question, 'id');
        await repo.update('questions', questionId, {'prompt': promptText, 'sign_id': signId});
        // Ganti seluruh pilihan: hapus kunci dulu (FK), lalu pilihan lama.
        await repo.deleteWhere('question_answer_keys', 'question_id', questionId);
        await repo.deleteWhere('question_options', 'question_id', questionId);
      }
      String? correctId;
      for (var i = 0; i < labels.length; i++) {
        final id = await repo.insert('question_options', {
          'question_id': questionId,
          'position': i,
          'label': labels[i],
        });
        if (i == correct) correctId = id;
      }
      if (correctId != null) {
        await repo.saveAnswerKey(questionId, correctId, explanationValue);
      }
      _refresh(ref);
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = ref.watch(_quizAdminProvider(lessonId));
    return quiz.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ErrorView(
        message: errorMessageOf(e),
        onRetry: () => ref.invalidate(_quizAdminProvider(lessonId)),
      ),
      data: (q) {
        if (q == null) {
          return OutlinedButton.icon(
            onPressed: () => _editSettings(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Buat kuis'),
          );
        }
        final questions = optList(q, 'questions')
          ..sort((a, b) => optInt(a, 'position').compareTo(optInt(b, 'position')));
        final quizId = reqString(q, 'id');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(optString(q, 'title') ?? 'Kuis'),
              subtitle: Text('Lulus ≥ ${optInt(q, 'pass_score_percent', 70)}% · '
                  '${optBool(q, 'is_active', true) ? 'Aktif' : 'Nonaktif'} · '
                  '${questions.length} soal'),
              trailing: IconButton(
                tooltip: 'Pengaturan kuis',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _editSettings(context, ref, q),
              ),
            ),
            for (var i = 0; i < questions.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(optString(questions[i], 'prompt') ?? ''),
                  subtitle: Text('${optList(questions[i], 'options').length} pilihan'),
                  onTap: () => _editQuestion(context, ref, quizId, questions, question: questions[i]),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Aksi soal',
                    onSelected: (action) async {
                      final repo = ref.read(adminRepositoryProvider);
                      try {
                        switch (action) {
                          case 'up':
                            await repo.swapPositions('questions', questions[i], questions[i - 1]);
                          case 'down':
                            await repo.swapPositions('questions', questions[i], questions[i + 1]);
                          case 'delete':
                            if (!context.mounted) return;
                            final ok = await showConfirmDialog(context,
                                title: 'Hapus soal?',
                                message: 'Soal beserta pilihannya akan dihapus.',
                                confirmLabel: 'Hapus',
                                destructive: true);
                            if (!ok) return;
                            await repo.delete('questions', reqString(questions[i], 'id'));
                        }
                        _refresh(ref);
                      } catch (error) {
                        if (context.mounted) showErrorSnackBar(context, error);
                      }
                    },
                    itemBuilder: (_) => [
                      if (i > 0) const PopupMenuItem(value: 'up', child: Text('Naikkan')),
                      if (i < questions.length - 1)
                        const PopupMenuItem(value: 'down', child: Text('Turunkan')),
                      const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => _editQuestion(context, ref, quizId, questions),
              icon: const Icon(Icons.add),
              label: const Text('Tambah soal'),
            ),
          ],
        );
      },
    );
  }
}
