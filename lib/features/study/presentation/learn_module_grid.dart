import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../data/study_repository.dart';
import '../domain/study.dart';

/// Kartu modul belajar (Alfabet, Angka, Kosakata, Percakapan, Kuis) dengan
/// progres per modul. Dipakai di Beranda dan tab Belajar.
class LearnModuleGrid extends ConsumerWidget {
  const LearnModuleGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(progressSummaryProvider).value;
    String? caption(String key) {
      final m = summary?.module(key);
      if (m == null || m.total == 0) return null;
      return '${m.learned}/${m.total} dipelajari';
    }

    final items = <_ModuleItem>[
      _ModuleItem(
        Icons.abc_rounded,
        'Alfabet',
        caption('alphabet'),
        summary?.module('alphabet'),
        () => context.push(AppRoutes.alphabet),
      ),
      _ModuleItem(
        Icons.pin_outlined,
        'Angka',
        caption('number'),
        summary?.module('number'),
        () => context.push(AppRoutes.numbers),
      ),
      _ModuleItem(
        Icons.menu_book_outlined,
        'Kosakata',
        caption('vocabulary'),
        summary?.module('vocabulary'),
        () => context.go(AppRoutes.dictionary),
      ),
      _ModuleItem(
        Icons.forum_outlined,
        'Percakapan',
        summary == null || summary.conversationsTotal == 0
            ? null
            : '${summary.conversationsCompleted}/${summary.conversationsTotal} selesai',
        summary == null
            ? null
            : ModuleProgress(
                total: summary.conversationsTotal,
                learned: summary.conversationsCompleted,
              ),
        () => context.go(AppRoutes.conversations),
      ),
      _ModuleItem(
        Icons.quiz_outlined,
        'Latihan & Kuis',
        summary == null || summary.quizSessions == 0
            ? null
            : 'Rata-rata ${summary.quizAverage}',
        null,
        () => context.push(AppRoutes.quizHub),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 118,
      ),
      itemBuilder: (context, i) => _ModuleCard(item: items[i]),
    );
  }
}

class _ModuleItem {
  const _ModuleItem(
    this.icon,
    this.label,
    this.caption,
    this.progress,
    this.onTap,
  );
  final IconData icon;
  final String label;
  final String? caption;
  final ModuleProgress? progress;
  final VoidCallback onTap;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.item});
  final _ModuleItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: [item.label, if (item.caption != null) item.caption!].join(', '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.contentCard),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: AppColors.primary, size: 30),
                const Spacer(),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  item.caption ?? 'Mulai',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (item.progress != null && item.progress!.total > 0) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: item.progress!.ratio,
                      minHeight: 5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
