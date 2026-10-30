import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/media_widgets.dart';
import '../../../core/widgets/state_views.dart';
import '../../dictionary/domain/sign.dart';
import '../data/study_repository.dart';
import '../domain/study.dart';

/// Membuka item riwayat belajar.
void openHistoryEntry(BuildContext context, HistoryEntry e) {
  switch (e.itemType) {
    case 'lesson':
      context.push(AppRoutes.lesson(e.itemId));
    case 'conversation':
      context.push(AppRoutes.conversation(e.itemId));
    default:
      context.push(AppRoutes.study(ContentModule.parse(e.module), e.itemId));
  }
}

/// Riwayat belajar (materi yang pernah dibuka, terbaru dulu).
class LearningHistoryScreen extends ConsumerWidget {
  const LearningHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(learningHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Belajar')),
      body: AsyncValueView<List<HistoryEntry>>(
        value: history,
        onRetry: () => ref.invalidate(learningHistoryProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(
          icon: Icons.history_edu_outlined,
          title: 'Belum ada riwayat belajar',
          message: 'Materi yang Anda buka akan tercatat di sini.',
        ),
        data: (items) => ContentListView(
          children: [
            for (final e in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.inputFill,
                  child: Text(
                    (e.symbol ?? e.title).characters.take(2).toString(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(e.title),
                subtitle: Text('${e.moduleLabel} · ${formatDateTimeId(e.lastAccessedAt)}'),
                trailing: e.completed
                    ? const Icon(Icons.check_circle, color: AppColors.success, semanticLabel: 'Selesai')
                    : const Icon(Icons.chevron_right),
                onTap: () => openHistoryEntry(context, e),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pencarian global: huruf, angka, dan kosakata (published).
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer();
  String _query = '';
  Future<List<Sign>>? _future;

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debouncer.run(() {
      if (!mounted) return;
      final q = value.trim();
      setState(() {
        _query = q;
        _future = q.isEmpty ? null : ref.read(studyRepositoryProvider).searchAll(q);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Cari huruf, angka, atau kosakata…',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Hapus',
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _future == null
          ? const EmptyView(
              icon: Icons.search,
              title: 'Cari materi',
              message: 'Ketik huruf, angka, atau kata yang ingin dipelajari.',
            )
          : FutureBuilder<List<Sign>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) {
                  return ErrorView(
                    message: errorMessageOf(snap.error!),
                    onRetry: () => _onChanged(_controller.text),
                  );
                }
                final list = snap.data ?? const <Sign>[];
                if (list.isEmpty) {
                  return EmptyView(
                    icon: Icons.search_off,
                    title: 'Tidak ditemukan',
                    message: 'Tidak ada materi untuk "$_query".',
                  );
                }
                return ContentListView(
                  children: [
                    for (final s in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.inputFill,
                          child: Text(s.displayTitle.characters.take(2).toString(),
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ),
                        title: Text(s.term),
                        subtitle: Text([s.contentModule.label, if (s.categoryName != null) s.categoryName!].join(' · ')),
                        trailing: s.isPremium ? const PremiumBadge() : const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.study(s.contentModule, s.id)),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
