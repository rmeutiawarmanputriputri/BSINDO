import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/section_header.dart';
import '../../dictionary/data/sign_repository.dart';
import '../domain/quiz_bank.dart';

/// Pusat Latihan & Kuis: per kategori, campuran, latihan yang belum dikuasai.
class QuizHubScreen extends ConsumerStatefulWidget {
  const QuizHubScreen({super.key});

  @override
  ConsumerState<QuizHubScreen> createState() => _QuizHubScreenState();
}

class _QuizHubScreenState extends ConsumerState<QuizHubScreen> {
  QuizModule _module = QuizModule.alphabet;
  String? _categoryId;
  QuizDifficulty? _difficulty;
  int _limit = 10;

  void _start(QuizConfig config) => context.push(AppRoutes.quizPlay(config));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(signCategoriesProvider).value ?? const [];
    final categoryName = categories.where((c) => c.id == _categoryId).firstOrNull?.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Latihan & Kuis'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.quizHistory),
            icon: const Icon(Icons.history),
            label: const Text('Riwayat'),
          ),
        ],
      ),
      body: ContentListView(
        children: [
          Text('Pilih jenis latihan. Jawaban dinilai langsung dan setiap soal punya pembahasan.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          const SectionHeader(title: 'Pengaturan'),
          Text('Tingkat kesulitan', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: _difficulty == null,
                onSelected: (_) => setState(() => _difficulty = null),
              ),
              for (final d in QuizDifficulty.values)
                ChoiceChip(
                  label: Text(d.label),
                  selected: _difficulty == d,
                  onSelected: (_) => setState(() => _difficulty = d),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Jumlah soal', style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 5, label: Text('5')),
              ButtonSegment(value: 10, label: Text('10')),
              ButtonSegment(value: 20, label: Text('20')),
            ],
            selected: {_limit},
            onSelectionChanged: (s) => setState(() => _limit = s.first),
          ),
          const SectionHeader(title: 'Kuis per kategori'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final m in QuizModule.values)
                ChoiceChip(
                  label: Text(m.label),
                  selected: _module == m,
                  onSelected: (_) => setState(() {
                    _module = m;
                    _categoryId = null;
                  }),
                ),
            ],
          ),
          if (_module == QuizModule.vocabulary && categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kategori kosakata'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Semua kategori')),
                for (final c in categories) DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: () => _start(QuizConfig(
              mode: QuizMode.category,
              module: _module,
              categoryId: _categoryId,
              categoryName: categoryName,
              difficulty: _difficulty,
              limit: _limit,
            )),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Mulai kuis ${categoryName ?? _module.label}'),
          ),
          const SectionHeader(title: 'Mode lain'),
          _ModeCard(
            icon: Icons.shuffle_rounded,
            title: 'Kuis campuran',
            subtitle: 'Soal acak dari semua modul.',
            onTap: () => _start(QuizConfig(mode: QuizMode.mixed, difficulty: _difficulty, limit: _limit)),
          ),
          _ModeCard(
            icon: Icons.replay_circle_filled_outlined,
            title: 'Latihan yang belum dikuasai',
            subtitle: 'Soal yang terakhir dijawab salah dan kosakata yang Anda tandai sulit.',
            onTap: () => _start(QuizConfig(mode: QuizMode.weak, difficulty: _difficulty, limit: _limit)),
          ),
          _ModeCard(
            icon: Icons.history,
            title: 'Riwayat kuis',
            subtitle: 'Lihat skor kuis sebelumnya.',
            onTap: () => context.push(AppRoutes.quizHistory),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
