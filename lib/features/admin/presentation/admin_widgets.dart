import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/state_views.dart';
import '../../profile/data/profile_repository.dart';
import '../data/admin_repository.dart';
import '../data/media_upload.dart';

/// Status konten (D-12).
const kContentStatuses = ['draft', 'in_review', 'verified', 'published', 'archived'];

String contentStatusLabel(String status) => switch (status) {
      'draft' => 'Draf',
      'in_review' => 'Ditinjau',
      'verified' => 'Terverifikasi',
      'published' => 'Terbit',
      'archived' => 'Diarsipkan',
      _ => status,
    };

/// Hanya menampilkan [child] untuk admin. Keamanan sejati di RLS (D-11);
/// non-admin yang menembus rute melihat "Tidak berwenang".
class AdminGuard extends ConsumerWidget {
  const AdminGuard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return profile.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: errorMessageOf(e),
          onRetry: () => ref.invalidate(currentProfileProvider),
        ),
      ),
      data: (p) => (p?.isAdmin ?? false)
          ? child
          : Scaffold(
              appBar: AppBar(title: const Text('Admin')),
              body: const EmptyView(
                icon: Icons.lock_outline,
                title: 'Tidak berwenang',
                message: 'Halaman ini hanya untuk pengelola konten.',
              ),
            ),
    );
  }
}

/// Status + bagian "Validasi" (validator, tanggal, sumber) — wajib sebelum
/// verified/published (CHECK di DB).
class ValidationSection extends StatelessWidget {
  const ValidationSection({
    super.key,
    required this.status,
    required this.onStatusChanged,
    required this.validatedBy,
    required this.sourceNote,
    required this.verifiedAt,
    required this.onVerifiedAtChanged,
  });

  final String status;
  final ValueChanged<String> onStatusChanged;
  final TextEditingController validatedBy;
  final TextEditingController sourceNote;
  final DateTime? verifiedAt;
  final ValueChanged<DateTime?> onVerifiedAtChanged;

  bool get _needsValidation => status == 'verified' || status == 'published';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.inputFill,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Status & Validasi', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in kContentStatuses)
                  DropdownMenuItem(value: s, child: Text(contentStatusLabel(s))),
              ],
              onChanged: (v) {
                if (v != null) onStatusChanged(v);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: validatedBy,
              decoration: InputDecoration(
                labelText: 'Divalidasi oleh${_needsValidation ? ' (wajib)' : ''}',
                helperText: 'Nama validator/organisasi Tuli yang memeriksa materi',
              ),
              validator: (v) => _needsValidation && (v ?? '').trim().isEmpty
                  ? 'Isi validator sebelum menerbitkan.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: sourceNote,
              decoration: InputDecoration(
                labelText: 'Sumber${_needsValidation ? ' (wajib)' : ''}',
              ),
              validator: (v) => _needsValidation && (v ?? '').trim().isEmpty
                  ? 'Isi sumber sebelum menerbitkan.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            FormField<DateTime>(
              initialValue: verifiedAt,
              validator: (_) => _needsValidation && verifiedAt == null
                  ? 'Isi tanggal validasi sebelum menerbitkan.'
                  : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(verifiedAt == null
                        ? 'Pilih tanggal validasi${_needsValidation ? ' (wajib)' : ''}'
                        : 'Tanggal validasi: ${formatDateId(verifiedAt!)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: verifiedAt ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        onVerifiedAtChanged(picked);
                        field.didChange(picked);
                      }
                    },
                  ),
                  if (field.hasError)
                    Text(field.errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Memilih berkas media lalu mengunggahnya. Mengembalikan aset baru atau null.
Future<({String id, String path})?> pickAndUploadMedia(
  BuildContext context,
  WidgetRef ref, {
  required MediaKind kind,
  required String folder,
  required String ownerId,
  required String prefix,
}) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions:
        kind == MediaKind.video ? ['mp4', 'webm'] : ['jpg', 'jpeg', 'png', 'webp'],
    withData: true,
  );
  final file = result?.files.firstOrNull;
  if (file == null) return null;
  final bytes = file.bytes;
  if (bytes == null) {
    if (context.mounted) showAppSnackBar(context, 'Berkas tidak dapat dibaca.');
    return null;
  }
  final picked = PickedMedia(name: file.name, bytes: bytes);
  final check = validateMedia(picked, kind);
  if (check.error != null) {
    if (context.mounted) showAppSnackBar(context, check.error!);
    return null;
  }
  if (!context.mounted) return null;
  final progress = showDialog<void>(
    context: context,
    barrierDismissible: false,
    // PopScope: tombol kembali tidak boleh menutup dialog, agar `pop()` di
    // `finally` tidak menutup layar formulir.
    builder: (_) => const PopScope<void>(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: AppSpacing.lg),
            Expanded(child: Text('Mengunggah…')),
          ],
        ),
      ),
    ),
  );
  try {
    final asset = await ref.read(adminRepositoryProvider).uploadMedia(
          file: picked,
          kind: kind,
          folder: folder,
          ownerId: ownerId,
          prefix: prefix,
        );
    return asset;
  } catch (error) {
    if (context.mounted) showErrorSnackBar(context, error);
    return null;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    await progress;
  }
}
