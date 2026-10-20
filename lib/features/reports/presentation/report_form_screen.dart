import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/state_views.dart';
import '../data/report_repository.dart';
import '../domain/report.dart';

/// S22 Form Laporan.
class ReportFormScreen extends ConsumerStatefulWidget {
  const ReportFormScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
  });

  final ReportTargetType? targetType;
  final String? targetId;
  final String targetTitle;

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  ReportCategory? _category;
  final _description = TextEditingController();
  String? _categoryError;
  String? _descriptionError;
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final category = _category;
    setState(() {
      _categoryError = category == null ? 'Pilih kategori masalah.' : null;
      _descriptionError = category == null
          ? null
          : validateReportDescription(category, _description.text);
    });
    if (category == null || _descriptionError != null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(reportRepositoryProvider).create(
            targetType: widget.targetType!,
            targetId: widget.targetId!,
            category: category,
            description: _description.text,
          );
      if (!mounted) return;
      ref.invalidate(myReportsProvider);
      setState(() => _sent = true);
    } on ConflictFailure {
      if (mounted) {
        showAppSnackBar(context, 'Anda sudah melaporkan hal ini dan masih ditinjau.');
      }
    } on RateLimitFailure {
      if (mounted) {
        showAppSnackBar(context, 'Batas laporan harian tercapai. Coba lagi besok.');
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valid = widget.targetType != null && widget.targetId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporkan Konten')),
      body: !valid
          ? const EmptyView(
              icon: Icons.link_off,
              title: 'Materi tidak dikenali',
              message: 'Buka formulir laporan dari halaman materi.',
            )
          : _sent
              ? EmptyView(
                  icon: Icons.check_circle_outline,
                  title: 'Terima kasih, laporan Anda terkirim',
                  message: 'Tim akan meninjau laporan Anda.',
                  actionLabel: 'Lihat riwayat laporan',
                  onAction: () => context.pushReplacement(AppRoutes.reports),
                )
              : ContentListView(
                  children: [
                    Text('Materi', style: theme.textTheme.titleSmall),
                    Text(widget.targetTitle, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      header: true,
                      child: Text('Apa masalahnya?', style: theme.textTheme.titleSmall),
                    ),
                    RadioGroup<ReportCategory>(
                      groupValue: _category,
                      onChanged: (value) => setState(() {
                        _category = value;
                        _categoryError = null;
                      }),
                      child: Column(
                        children: [
                          for (final c in ReportCategory.values)
                            RadioListTile<ReportCategory>(
                              value: c,
                              title: Text(c.label),
                              contentPadding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ),
                    if (_categoryError != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(_categoryError!,
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error)),
                      ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _description,
                      maxLines: 5,
                      maxLength: 1000,
                      onChanged: (_) {
                        if (_descriptionError != null) {
                          setState(() => _descriptionError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: _category == ReportCategory.other
                            ? 'Keterangan (wajib)'
                            : 'Keterangan (opsional)',
                        alignLabelWithHint: true,
                        hintText: 'Jelaskan apa yang keliru',
                        errorText: _descriptionError,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Kirim Laporan',
                      loading: _sending,
                      onPressed: _submit,
                    ),
                  ],
                ),
    );
  }
}
