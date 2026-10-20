import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/source_card.dart';
import '../../reports/domain/report.dart';
import '../data/learning_repository.dart';
import '../data/progress_repository.dart';
import '../domain/learning.dart';

/// S15 Detail Pelajaran.
class LessonDetailScreen extends ConsumerWidget {
  const LessonDetailScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonDetailProvider(lessonId));
    return Scaffold(
      appBar: AppBar(title: const Text('Pelajaran')),
      body: AsyncValueView<Lesson>(
        value: lesson,
        onRetry: () => ref.invalidate(lessonDetailProvider(lessonId)),
        data: (l) => _LessonBody(lesson: l),
      ),
    );
  }
}

class _LessonBody extends ConsumerStatefulWidget {
  const _LessonBody({required this.lesson});
  final Lesson lesson;

  @override
  ConsumerState<_LessonBody> createState() => _LessonBodyState();
}

class _LessonBodyState extends ConsumerState<_LessonBody> {
  /// Item yang sudah dibuka di sesi ini (penanda selesai lokal; progres
  /// persen disimpan ke server, D-16).
  final Set<int> _opened = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final entry = (ref.read(progressListProvider).value ?? const <ProgressEntry>[])
        .where((p) => p.lessonId == widget.lesson.id)
        .firstOrNull;
    if (entry != null) {
      for (var i = 0; i <= entry.lastPosition && i < widget.lesson.items.length; i++) {
        if (entry.completed || i < entry.lastPosition) _opened.add(i);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _touch());
  }

  int get _percent {
    final count = widget.lesson.items.length;
    return count == 0 ? 0 : ((_opened.length / count) * 100).round();
  }

  Future<void> _touch({int? position, bool completed = false}) async {
    try {
      await ref.read(progressRepositoryProvider).touch(
            lessonId: widget.lesson.id,
            percent: _percent,
            lastPosition: position,
            completed: completed,
          );
      ref.invalidate(progressListProvider);
    } catch (_) {
      // Progres self-reported: kegagalan tidak memblokir.
    }
  }

  void _openItem(int index, LessonItem item) {
    setState(() => _opened.add(index));
    _touch(position: index + 1);
    switch (item.type) {
      case LessonItemType.sign:
        if (item.signId != null && item.signTerm != null) {
          context.push(AppRoutes.sign(item.signId!));
        }
      case LessonItemType.conversationModule:
        if (item.moduleId != null && item.moduleTitle != null) {
          context.push(AppRoutes.conversation(item.moduleId!));
        }
      case LessonItemType.text:
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: Text(item.bodyText ?? '', style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        );
    }
  }

  Future<void> _markDone() async {
    setState(() => _saving = true);
    try {
      await ref.read(progressRepositoryProvider).touch(
            lessonId: widget.lesson.id,
            completed: true,
          );
      ref.invalidate(progressListProvider);
      if (mounted) showAppSnackBar(context, 'Pelajaran ditandai selesai');
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final theme = Theme.of(context);
    final entry = (ref.watch(progressListProvider).value ?? const <ProgressEntry>[])
        .where((p) => p.lessonId == l.id)
        .firstOrNull;
    final completed = entry?.completed ?? false;
    return ContentListView(
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(l.title, style: theme.textTheme.headlineSmall),
              ),
            ),
            if (l.isSample) const SampleBadge(),
          ],
        ),
        if (l.description != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l.description!, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.md),
        Semantics(
          label: completed ? 'Pelajaran selesai' : 'Progres $_percent persen',
          excludeSemantics: true,
          child: LinearProgressIndicator(
            value: completed ? 1 : _percent / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < l.items.length; i++)
          _ItemTile(
            index: i,
            item: l.items[i],
            opened: completed || _opened.contains(i),
            onTap: () => _openItem(i, l.items[i]),
          ),
        const SizedBox(height: AppSpacing.lg),
        if (l.quizId != null)
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.quiz(l.id)),
            icon: const Icon(Icons.quiz_outlined),
            label: Text('Mulai Kuis${l.quizTitle != null ? ': ${l.quizTitle}' : ''}'),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: completed || _saving ? null : _markDone,
          icon: Icon(completed ? Icons.check_circle : Icons.check),
          label: Text(completed ? 'Sudah selesai' : 'Tandai selesai'),
        ),
        const SizedBox(height: AppSpacing.lg),
        SourceCard(sourceNote: l.sourceNote, validatedBy: l.validatedBy, verifiedAt: l.verifiedAt),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () => context.push(
            AppRoutes.newReport(type: ReportTargetType.lesson.value, id: l.id, title: l.title),
          ),
          icon: const Icon(Icons.report_outlined),
          label: const Text('Laporkan'),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.index,
    required this.item,
    required this.opened,
    required this.onTap,
  });

  final int index;
  final LessonItem item;
  final bool opened;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.displayTitle;
    final available = title != null;
    final (icon, kind) = switch (item.type) {
      LessonItemType.sign => (Icons.sign_language, 'Kosakata'),
      LessonItemType.conversationModule => (Icons.forum_outlined, 'Percakapan'),
      LessonItemType.text => (Icons.article_outlined, 'Bacaan'),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.contentCard),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        enabled: available,
        onTap: available ? onTap : null,
        leading: CircleAvatar(
          backgroundColor: AppColors.inputFill,
          child: ExcludeSemantics(child: Icon(icon, color: AppColors.primary)),
        ),
        title: Text(
          title ?? 'Materi tidak tersedia',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${index + 1}. $kind${opened ? ' · sudah dibuka' : ''}'),
        trailing: opened
            ? const Icon(Icons.check_circle, color: AppColors.success, semanticLabel: 'Sudah dibuka')
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
