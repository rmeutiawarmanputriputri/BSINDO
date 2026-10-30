import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/state_views.dart';
import '../data/quiz_bank_repository.dart';
import '../domain/quiz_bank.dart';

class QuizHistoryScreen extends ConsumerWidget {
  const QuizHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(quizHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Kuis')),
      body: AsyncValueView<List<QuizHistoryEntry>>(
        value: history,
        onRetry: () => ref.invalidate(quizHistoryProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(
          icon: Icons.history,
          title: 'Belum ada riwayat kuis',
          message: 'Kerjakan kuis pertama Anda dari menu Latihan & Kuis.',
        ),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(quizHistoryProvider),
          child: ContentListView(
            children: [
              for (final e in list)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          (e.scorePercent >= 70
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withValues(alpha: 0.12),
                      child: Text(
                        '${e.scorePercent}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: e.scorePercent >= 70
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),
                    title: Text(e.title),
                    subtitle: Text(
                      [
                        formatDateTimeId(e.submittedAt),
                        if (e.totalCount != null)
                          '${e.correctCount}/${e.totalCount} benar',
                      ].join(' · '),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
