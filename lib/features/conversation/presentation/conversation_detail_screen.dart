import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/media_widgets.dart';
import '../../../core/widgets/source_card.dart';
import '../../difficult_vocab/data/difficult_repository.dart';
import '../../home_content/data/home_content_repository.dart';
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

  /// Mode simulasi: kalimat muncul satu per satu sesuai urutan dari CMS.
  bool _simulate = false;
  int _revealed = 0;

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
    final locked = m.isPremium && !ref.watch(isPremiumProvider);

    if (locked) {
      return ContentListView(
        children: [
          Text(m.title, style: theme.textTheme.headlineSmall),
          if (m.description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(m.description!, style: theme.textTheme.bodyLarge),
          ],
          const SizedBox(height: AppSpacing.lg),
          const PremiumLockCard(message: 'Topik percakapan ini khusus pengguna Premium.'),
        ],
      );
    }

    if (_simulate && items.isNotEmpty) {
      return _Simulation(
        module: m,
        revealed: _revealed,
        onNext: () {
          setState(() {
            _revealed = (_revealed + 1).clamp(0, items.length - 1);
            _selected = _revealed;
          });
          _touch(completed: _revealed == items.length - 1);
        },
        onRestart: () => setState(() {
          _revealed = 0;
          _selected = 0;
        }),
        onExit: () => setState(() => _simulate = false),
      );
    }

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
        if (items.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: FilledButton.tonalIcon(
              onPressed: () => setState(() {
                _simulate = true;
                _revealed = 0;
                _selected = 0;
              }),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Mulai simulasi percakapan'),
            ),
          ),
        if (current != null)
          VideoPlayerView(
            key: ValueKey(current.id),
            videoPath: current.videoPath,
            semanticTitle: 'Video dialog: ${current.text}',
          ),
        if (current != null) _ItemDetails(item: current),
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

/// Terjemahan, penjelasan, dan audio kalimat terpilih.
class _ItemDetails extends StatelessWidget {
  const _ItemDetails({required this.item});
  final ConversationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = (item.translation?.isNotEmpty ?? false) || (item.explanation?.isNotEmpty ?? false);
    if (!hasText && item.audioPath == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(AppRadius.contentCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.translation?.isNotEmpty ?? false) ...[
              Text('Terjemahan / susunan isyarat', style: theme.textTheme.labelLarge),
              Text(item.translation!, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (item.explanation?.isNotEmpty ?? false) ...[
              Text('Penjelasan makna', style: theme.textTheme.labelLarge),
              Text(item.explanation!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (item.audioPath != null) AudioPlayButton(key: ValueKey('au${item.id}'), path: item.audioPath!),
          ],
        ),
      ),
    );
  }
}

/// Simulasi percakapan: gelembung dialog muncul bertahap, video kalimat aktif di atas.
class _Simulation extends StatelessWidget {
  const _Simulation({
    required this.module,
    required this.revealed,
    required this.onNext,
    required this.onRestart,
    required this.onExit,
  });

  final ConversationModule module;
  final int revealed;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = module.items;
    final current = items[revealed];
    final speakers = <String>[];
    for (final i in items) {
      if (!speakers.contains(i.speaker)) speakers.add(i.speaker);
    }
    final done = revealed >= items.length - 1;
    return ContentListView(
      children: [
        Row(
          children: [
            Expanded(child: Text('Simulasi: ${module.title}', style: theme.textTheme.titleMedium)),
            TextButton(onPressed: onExit, child: const Text('Keluar simulasi')),
          ],
        ),
        LinearProgressIndicator(value: (revealed + 1) / items.length),
        const SizedBox(height: AppSpacing.md),
        VideoPlayerView(
          key: ValueKey('sim${current.id}'),
          videoPath: current.videoPath,
          semanticTitle: 'Video kalimat: ${current.text}',
        ),
        const SizedBox(height: AppSpacing.md),
        for (var i = 0; i <= revealed; i++)
          _Bubble(item: items[i], right: speakers.indexOf(items[i].speaker).isOdd, active: i == revealed),
        const SizedBox(height: AppSpacing.md),
        if (!done)
          FilledButton.icon(
            onPressed: onNext,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Kalimat berikutnya'),
          )
        else ...[
          Semantics(
            liveRegion: true,
            child: Text('Percakapan selesai! 🎉', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(onPressed: onRestart, icon: const Icon(Icons.replay), label: const Text('Ulangi simulasi')),
        ],
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.item, required this.right, required this.active});
  final ConversationItem item;
  final bool right;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: right ? AppColors.primary : AppColors.inputFill,
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        border: active ? Border.all(color: AppColors.accent, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.speaker,
              style: theme.textTheme.labelMedium?.copyWith(color: right ? Colors.white70 : AppColors.textSecondary)),
          Text(item.text, style: theme.textTheme.bodyLarge?.copyWith(color: right ? Colors.white : null)),
          if (item.translation?.isNotEmpty ?? false)
            Text(item.translation!,
                style: theme.textTheme.bodySmall?.copyWith(color: right ? Colors.white70 : AppColors.textSecondary)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: right ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [Flexible(child: bubble)],
      ),
    );
  }
}
