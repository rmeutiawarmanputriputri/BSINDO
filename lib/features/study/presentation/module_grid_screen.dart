import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../dictionary/domain/sign.dart';
import '../../quiz/domain/quiz_bank.dart';
import '../data/study_repository.dart';
import '../domain/study.dart';

/// Halaman Alfabet (A–Z) dan Angka (per kelompok). Semua isi dari database
/// (status Published); bila kosong → "Materi belum tersedia".
class ModuleGridScreen extends ConsumerWidget {
  const ModuleGridScreen({super.key, required this.module});

  final ContentModule module;

  QuizModule get _quizModule =>
      module == ContentModule.alphabet ? QuizModule.alphabet : QuizModule.number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(studyListProvider(module));
    final learned = ref.watch(learnedIdsProvider);
    final isAlphabet = module == ContentModule.alphabet;
    return Scaffold(
      appBar: AppBar(title: Text(module.label)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(studyListProvider(module));
          ref.invalidate(signProgressProvider);
          await ref.read(studyListProvider(module).future);
        },
        child: AsyncValueView<List<Sign>>(
          value: list,
          onRetry: () => ref.invalidate(studyListProvider(module)),
          isEmpty: (l) => l.isEmpty,
          empty: EmptyView(
            icon: isAlphabet ? Icons.abc : Icons.pin_outlined,
            title: 'Materi belum tersedia',
            message: 'Materi ${module.label.toLowerCase()} sedang disiapkan. Coba lagi nanti.',
            actionLabel: 'Muat ulang',
            onAction: () => ref.invalidate(studyListProvider(module)),
          ),
          data: (items) {
            final ids = [for (final s in items) s.id];
            final doneCount = ids.where(learned.contains).length;
            final next = nextUnlearnedIndex(ids, learned);
            return ContentListView(
              children: [
                _ProgressHeader(
                  done: doneCount,
                  total: items.length,
                  noun: isAlphabet ? 'huruf' : 'angka',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(
                          AppRoutes.study(module, items[next].id, learnMode: true),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(doneCount == 0
                            ? 'Mulai mode belajar'
                            : doneCount == items.length
                                ? 'Ulangi dari awal'
                                : 'Lanjutkan belajar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.quizPlay(
                          QuizConfig(mode: QuizMode.category, module: _quizModule),
                        )),
                        icon: const Icon(Icons.quiz_outlined),
                        label: Text('Kuis ${module.label}'),
                      ),
                    ),
                  ],
                ),
                if (isAlphabet) ...[
                  const SectionHeader(title: 'Huruf A–Z'),
                  _SymbolGrid(items: items, learned: learned, module: module),
                ] else
                  for (final group in NumberGroup.values)
                    if (items.any((s) => s.numberGroup == group)) ...[
                      SectionHeader(title: 'Angka ${group.label}'),
                      _SymbolGrid(
                        items: items.where((s) => s.numberGroup == group).toList(),
                        learned: learned,
                        module: module,
                      ),
                    ],
                if (!isAlphabet && items.any((s) => s.numberGroup == null)) ...[
                  const SectionHeader(title: 'Lainnya'),
                  _SymbolGrid(
                    items: items.where((s) => s.numberGroup == null).toList(),
                    learned: learned,
                    module: module,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.done, required this.total, required this.noun});
  final int done;
  final int total;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = total == 0 ? 0.0 : done / total;
    return Semantics(
      label: '$done dari $total $noun sudah dipelajari',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.contentCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kemajuan belajar', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white)),
            const SizedBox(height: AppSpacing.xs),
            Text('$done / $total $noun',
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SymbolGrid extends StatelessWidget {
  const _SymbolGrid({required this.items, required this.learned, required this.module});
  final List<Sign> items;
  final Set<String> learned;
  final ContentModule module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 96,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, i) {
        final s = items[i];
        final done = learned.contains(s.id);
        return Semantics(
          button: true,
          label: '${module.label} ${s.displayTitle}${done ? ', sudah dipelajari' : ''}${s.isPremium ? ', Premium' : ''}',
          excludeSemantics: true,
          child: Material(
            color: done ? AppColors.primary.withValues(alpha: 0.10) : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.contentCard),
              side: BorderSide(color: done ? AppColors.primary : const Color(0xFFE2E8F0)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.contentCard),
              onTap: () => context.push(AppRoutes.study(module, s.id)),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: FittedBox(
                        child: Text(
                          s.displayTitle,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (done)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.check_circle, size: 18, color: AppColors.success),
                    ),
                  if (s.isPremium)
                    const Positioned(
                      bottom: 6,
                      right: 6,
                      child: Icon(Icons.lock_outline, size: 16, color: Color(0xFF8A5300)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
