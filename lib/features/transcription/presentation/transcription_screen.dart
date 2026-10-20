import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_page.dart';
import 'transcription_controller.dart';

/// S13 Transkripsi Suara → Teks. Alat bantu; TIDAK menerjemahkan isyarat.
class TranscriptionScreen extends ConsumerStatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  ConsumerState<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends ConsumerState<TranscriptionScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(transcriptionControllerProvider.notifier).pause();
    }
  }

  Future<bool> _explainPermission() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Izin mikrofon',
      message: 'Transkripsi memakai mikrofon. Suara Anda diproses oleh layanan '
          'pengenal ucapan di perangkat (umumnya Google) dan dapat membutuhkan '
          'internet. Aplikasi BISINDO tidak menyimpan audio maupun teks.',
      confirmLabel: 'Lanjutkan',
    );
    return ok;
  }

  Future<bool> _askFallback() => showConfirmDialog(
        context,
        title: 'Bahasa Indonesia tidak tersedia',
        message: 'Pengenalan suara Bahasa Indonesia tidak tersedia di perangkat ini. '
            'Gunakan bahasa bawaan perangkat? Hasilnya mungkin kurang akurat.',
        confirmLabel: 'Gunakan bahasa perangkat',
      );

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptionControllerProvider);
    final controller = ref.read(transcriptionControllerProvider.notifier);
    final theme = Theme.of(context);

    ref.listen<TranscriptionState>(transcriptionControllerProvider, (prev, next) {
      if (next.text != _text.text) {
        _text.value = TextEditingValue(
          text: next.text,
          selection: TextSelection.collapsed(offset: next.text.length),
        );
      }
      if (prev?.status != next.status) _announce(_statusLabel(next.status));
    });

    final (icon, label) = switch (state.status) {
      SttStatus.idle => (Icons.mic_none, 'Siap'),
      SttStatus.listening => (Icons.graphic_eq, 'Mendengarkan…'),
      SttStatus.processing => (Icons.hourglass_top, 'Memproses'),
      SttStatus.stopped => (Icons.stop_circle_outlined, 'Berhenti'),
      SttStatus.error => (Icons.error_outline, 'Terjadi masalah'),
    };

    return PopScope(
      canPop: state.text.isEmpty && state.partial.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showConfirmDialog(
          context,
          title: 'Keluar dari transkripsi?',
          message: 'Teks akan dihapus karena tidak disimpan.',
          confirmLabel: 'Keluar',
          destructive: true,
        );
        if (leave && context.mounted) {
          controller.clear();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Transkripsi Suara')),
        body: ContentListView(
          children: [
            Semantics(
              container: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.input),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const ExcludeSemantics(
                        child: Icon(Icons.info_outline, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Fitur ini mengubah ucapan menjadi teks. Tidak menerjemahkan isyarat.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 12,
              onChanged: controller.setText,
              decoration: const InputDecoration(
                hintText: 'Hasil transkripsi muncul di sini. Anda dapat mengeditnya.',
              ),
            ),
            if (state.partial.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                state.partial,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              liveRegion: true,
              label: 'Status: $label',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: state.status == SttStatus.error
                      ? AppColors.error : AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(label, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            if (state.usingFallbackLocale && state.isListening)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text('Memakai bahasa perangkat',
                    textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              ),
            if (state.error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                sttErrorMessage(state.error!),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
              ),
              if (state.error == SttError.permissionPermanentlyDenied ||
                  state.error == SttError.permissionDenied)
                Center(
                  child: TextButton(
                    onPressed: controller.openSettings,
                    child: const Text('Buka Pengaturan'),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: SizedBox(
                width: 96,
                height: 96,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                    backgroundColor:
                        state.isListening ? AppColors.error : AppColors.primary,
                  ),
                  onPressed: state.status == SttStatus.processing
                      ? null
                      : () => state.isListening
                          ? controller.stop()
                          : controller.start(
                              explainPermission: _explainPermission,
                              askFallback: _askFallback,
                            ),
                  child: Semantics(
                    label: state.isListening ? 'Berhenti mendengarkan' : 'Mulai mendengarkan',
                    excludeSemantics: true,
                    child: Icon(state.isListening ? Icons.stop : Icons.mic, size: 44),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.isListening ? 'Berhenti' : 'Mulai',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: state.text.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: state.text));
                          if (context.mounted) showAppSnackBar(context, 'Teks disalin');
                        },
                  icon: const Icon(Icons.copy),
                  label: const Text('Salin'),
                ),
                const SizedBox(width: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: state.text.isEmpty && state.partial.isEmpty
                      ? null
                      : controller.clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(SttStatus status) => switch (status) {
        SttStatus.idle => 'Siap',
        SttStatus.listening => 'Mendengarkan',
        SttStatus.processing => 'Memproses',
        SttStatus.stopped => 'Berhenti',
        SttStatus.error => 'Terjadi masalah',
      };
}
