import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/source_card.dart';
import '../../difficult_vocab/data/difficult_repository.dart';
import '../../learning/data/progress_repository.dart';
import '../../reports/domain/report.dart';
import '../../video/video_player_view.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation.dart';

/// S12 Detail Percakapan: konteks, dialog berurutan + video per baris
/// (pemutar di atas), progres `last_position` tersimpan.
class ConversationDetailScreen extends ConsumerWidget {
  const ConversationDetailScreen({super.key, required this.moduleId});

  final String moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final module = ref.watch(conversationDetailProvider(moduleId));
    return Scaffold(
      appBar: AppBar(title: const Text('Percakapan')),
      body: AsyncValueView<ConversationModule>(
        value: module,
        onRetry: () => ref.invalidate(conversationDetailProvider(moduleId)),
        data: (m) => _Body(module: m),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.module});
  final ConversationModule module;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  int _selected = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final progress = (ref.read(progressListProvider).value ?? const <ProgressEntry>[])
        .where((p) => p.moduleId == widget.module.id)
        .firstOrNull;
    final count = widget.module.items.length;
    if (progress != null && count > 0) {
      final last = progress.lastPosition;
      _selected = last < 0 ? 0 : (last >= count ? count - 1 : last);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _touch());
  }

  @override
  void didUpdateWidget(covariant _Body oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Modul dimuat ulang dengan jumlah dialog berbeda → jaga indeks valid.
    final count = widget.module.items.length;
    if (_selected >= count) _selected = count == 0 ? 0 : count - 1;
  }

  Future<void> _touch({bool completed = false}) async {
    if (!mounted) return;
    final count = widget.module.items.length;
    try {
      await ref.read(progressRepositoryProvider).touch(
            moduleId: widget.module.id,
            lastPosition: _selected,
            percent: count == 0 ? 0 : (((_selected + 1) / count) * 100).round(),
            completed: completed,
          );
      if (mounted) ref.invalidate(progressListProvider);
    } catch (_) {
      // Progres self-reported (D-16): gagal simpan tidak memblokir belajar.
    }
  }

  Future<void> _markDone() async {
    setState(() => _saving = true);
    try {
      await ref.read(progressRepositoryProvider).touch(
            moduleId: widget.module.id,
            lastPosition: _selected,
            completed: true,
          );
      if (!mounted) return;
      ref.invalidate(progressListProvider);
      showAppSnackBar(context, 'Modul ditandai selesai');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    final theme = Theme.of(context);
    final items = m.items;
    final current = items.isEmpty ? null : items[_selected];
    final difficult = ref.watch(difficultIdsProvider).value ?? const <String>{};

    return ContentListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(m.title, style: theme.textTheme.headlineSmall),
              ),
            ),
            if (m.isSample) const SampleBadge(),
          ],
        ),
        if (m.contextNote != null && m.contextNote!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Konteks penggunaan', style: theme.textTheme.titleSmall),
          Text(m.contextNote!, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (current != null)
          VideoPlayerView(
            key: ValueKey(current.id),
            videoPath: current.videoPath,
            semanticTitle: 'Video dialog: ${current.text}',
          ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i < items.length; i++)
          _DialogLine(
            item: items[i],
            selected: i == _selected,
            isDifficult: items[i].signId != null && difficult.contains(items[i].signId),
            onTap: () {
              setState(() => _selected = i);
              _touch();
            },
            onToggleDifficult: items[i].signId == null
                ? null
                : () async {
                    try {
                      final marked = await ref
                          .read(difficultIdsProvider.notifier)
                          .toggle(items[i].signId!);
                      if (context.mounted) {
                        showAppSnackBar(context,
                            marked ? 'Ditambahkan ke daftar sulit' : 'Dihapus dari daftar sulit');
                      }
                    } catch (error) {
                      if (context.mounted) showErrorSnackBar(context, error);
                    }
                  },
          ),
        if (items.isEmpty)
          Text('Dialog belum tersedia.', style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        SourceCard(
          sourceNote: m.sourceNote,
          validatedBy: m.validatedBy,
          verifiedAt: m.verifiedAt,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: _saving ? null : _markDone,
          icon: const Icon(Icons.check),
          label: const Text('Tandai selesai'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.push(
            AppRoutes.newReport(
              type: ReportTargetType.conversationModule.value,
              id: m.id,
              title: m.title,
            ),
          ),
          icon: const Icon(Icons.report_outlined),
          label: const Text('Laporkan'),
        ),
      ],
    );
  }
}

class _DialogLine extends StatelessWidget {
  const _DialogLine({
    required this.item,
    required this.selected,
    required this.isDifficult,
    required this.onTap,
    this.onToggleDifficult,
  });

  final ConversationItem item;
  final bool selected;
  final bool isDifficult;
  final VoidCallback onTap;
  final VoidCallback? onToggleDifficult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        side: BorderSide(
          color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        selected: selected,
        leading: CircleAvatar(
          backgroundColor: AppColors.inputFill,
          child: Text(item.speaker, style: theme.textTheme.labelLarge),
        ),
        title: Text(item.text, style: theme.textTheme.bodyLarge),
        subtitle: Text(
          item.videoPath != null ? 'Ketuk untuk memutar video' : 'Video belum tersedia',
        ),
        trailing: onToggleDifficult == null
            ? null
            : IconButton(
                tooltip: isDifficult ? 'Hapus dari daftar sulit' : 'Tandai sulit',
                onPressed: onToggleDifficult,
                icon: Icon(isDifficult ? Icons.flag : Icons.flag_outlined),
              ),
      ),
    );
  }
}
