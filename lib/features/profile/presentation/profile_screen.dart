import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../home_content/data/home_content_repository.dart';
import '../../study/data/study_repository.dart';
import '../../study/domain/study.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Versi aplikasi (sinkron dengan pubspec.yaml).
const kAppVersion = '1.1.0';

/// S24 Profil & Pengaturan.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    // Dibaca sebelum await: `ref` tidak boleh dipakai setelah widget unmount.
    final repo = ref.read(profileRepositoryProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    // Controller dimiliki dialog (State) agar baru di-dispose setelah animasi
    // tutup dialog selesai — bukan tepat setelah `showDialog` selesai.
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _EditNameDialog(initialName: profile.fullName),
    );
    if (name == null || name == profile.fullName) return;
    try {
      await repo.updateFullName(name);
      container.invalidate(currentProfileProvider);
      if (context.mounted) showAppSnackBar(context, 'Nama diperbarui');
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authRepositoryProvider);
    final ok = await showConfirmDialog(
      context,
      title: 'Keluar?',
      message: 'Anda perlu masuk lagi untuk melanjutkan belajar.',
      confirmLabel: 'Keluar',
      destructive: true,
    );
    if (!ok) return;
    // Router mengarah ke /login lewat event signedOut; provider data pribadi
    // dimuat ulang karena currentUserIdProvider berubah.
    await auth.signOut();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(profileRepositoryProvider);
    final auth = ref.read(authRepositoryProvider);
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus akun?',
      message:
          'Akun, progres belajar, favorit, riwayat kuis, dan semua data pribadi Anda '
          'akan dihapus permanen dan tidak dapat dikembalikan.',
      confirmLabel: 'Hapus permanen',
      destructive: true,
    );
    if (!ok) return;
    try {
      await repo.deleteMyAccount();
      await auth.signOut();
    } catch (error) {
      if (context.mounted) showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final unread = ref.watch(unreadAnnouncementsProvider);
    final email = ref.watch(authRepositoryProvider).currentEmail;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: AsyncValueView<Profile?>(
        value: profile,
        onRetry: () => ref.invalidate(currentProfileProvider),
        data: (p) => ContentListView(
          children: [
            Card(
              margin: EdgeInsets.zero,
              color: AppColors.inputFill,
              child: ListTile(
                contentPadding: const EdgeInsets.all(AppSpacing.lg),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (p?.fullName.isNotEmpty ?? false)
                        ? p!.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ),
                title: Text(
                  p?.fullName ?? '-',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  [email ?? '-', if (isPremium) 'Premium'].join(' · '),
                ),
                trailing: p == null
                    ? null
                    : IconButton(
                        tooltip: 'Ubah nama',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editName(context, ref, p),
                      ),
              ),
            ),
            const SectionHeader(title: 'Statistik belajar'),
            const _StatsCard(),
            const SectionHeader(title: 'Belajar saya'),
            _MenuTile(
              icon: Icons.favorite_border,
              label: 'Favorit',
              onTap: () => context.push(AppRoutes.favorites),
            ),
            _MenuTile(
              icon: Icons.flag_outlined,
              label: 'Kosakata Sulit',
              onTap: () => context.push(AppRoutes.difficult),
            ),
            _MenuTile(
              icon: Icons.history_edu_outlined,
              label: 'Riwayat Belajar',
              onTap: () => context.push(AppRoutes.history),
            ),
            _MenuTile(
              icon: Icons.quiz_outlined,
              label: 'Riwayat Kuis',
              onTap: () => context.push(AppRoutes.quizHistory),
            ),
            _MenuTile(
              icon: Icons.insights_outlined,
              label: 'Progres Pelajaran',
              onTap: () => context.push(AppRoutes.learnProgress),
            ),
            _MenuTile(
              icon: Icons.outlined_flag,
              label: 'Riwayat Laporan',
              onTap: () => context.push(AppRoutes.reports),
            ),
            const SectionHeader(title: 'Aplikasi'),
            _MenuTile(
              icon: Icons.notifications_none,
              label: unread > 0 ? 'Notifikasi ($unread baru)' : 'Notifikasi',
              onTap: () => context.push(AppRoutes.notifications),
            ),
            _MenuTile(
              icon: Icons.workspace_premium_outlined,
              label: isPremium ? 'Premium (aktif)' : 'Info Premium',
              onTap: () => context.push(AppRoutes.premium),
            ),
            _MenuTile(
              icon: Icons.help_outline,
              label: 'FAQ & Bantuan',
              onTap: () => context.push(AppRoutes.faq),
            ),
            if (p?.isAdmin ?? false) ...[
              const SectionHeader(title: 'Pengelola'),
              _MenuTile(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Admin',
                onTap: () => context.push(AppRoutes.admin),
              ),
            ],
            const SectionHeader(title: 'Tentang'),
            const _InfoTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privasi transkripsi',
              body:
                  'Transkripsi memakai layanan pengenal ucapan perangkat (umumnya '
                  'Google) dan dapat membutuhkan internet. Aplikasi tidak menyimpan '
                  'audio maupun teks transkripsi.',
            ),
            const _InfoTile(
              icon: Icons.info_outline,
              title: 'Tentang aplikasi',
              body:
                  'BISINDO — belajar Bahasa Isyarat Indonesia. Versi $kAppVersion. '
                  'Materi ditampilkan hanya setelah divalidasi; sumber dan validator '
                  'tercantum di setiap materi.',
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => _logout(context, ref),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              icon: const Icon(Icons.logout),
              label: const Text('Keluar'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => _deleteAccount(context, ref),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Hapus akun'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Statistik: keseluruhan, per modul, per kategori, kuis.
class _StatsCard extends ConsumerWidget {
  const _StatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(progressSummaryProvider);
    final theme = Theme.of(context);
    return summary.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Row(
        children: [
          Expanded(child: Text(errorMessageOf(e))),
          TextButton(
            onPressed: () => ref.invalidate(progressSummaryProvider),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
      data: (s) {
        Widget bar(String label, ModuleProgress m) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Semantics(
            label: '$label: ${m.learned} dari ${m.total}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      '${m.learned}/${m.total}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(value: m.ratio, minHeight: 6),
                ),
              ],
            ),
          ),
        );
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.overallPercent}% materi dipelajari',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${s.totalLearned} dari ${s.totalMaterials} materi · '
                  '${s.quizSessions} kuis${s.quizSessions > 0 ? ' · terbaik ${s.quizBest}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                bar('Alfabet', s.module('alphabet')),
                bar('Angka', s.module('number')),
                bar('Kosakata', s.module('vocabulary')),
                bar(
                  'Percakapan',
                  ModuleProgress(
                    total: s.conversationsTotal,
                    learned: s.conversationsCompleted,
                  ),
                ),
                if (s.categories.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Progres per kategori'),
                    children: [
                      for (final c in s.categories)
                        bar(
                          c.name,
                          ModuleProgress(total: c.total, learned: c.learned),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ubah Nama'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nama lengkap'),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.length < 2) return 'Nama lengkap minimal 2 karakter.';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
      expandedAlignment: Alignment.centerLeft,
      children: [Text(body, style: Theme.of(context).textTheme.bodyMedium)],
    );
  }
}
