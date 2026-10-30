import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/content_page.dart';
import '../../core/widgets/section_header.dart';
import 'reminder_service.dart';

/// G.9 Pengaturan notifikasi: pengingat belajar harian (notifikasi lokal) dan
/// pengumuman dari admin (notifikasi dalam aplikasi).
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _busy = false;

  Future<void> _apply(ReminderSettings next, {String? done}) async {
    setState(() => _busy = true);
    try {
      await ref.read(reminderSettingsProvider.notifier).save(next);
      if (mounted && done != null) showAppSnackBar(context, done);
    } on ReminderPermissionDenied catch (e) {
      if (mounted) showAppSnackBar(context, e.toString());
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime(ReminderSettings current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: 'Jam pengingat belajar',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final next = current.copyWith(hour: picked.hour, minute: picked.minute);
    await _apply(
      next,
      done: next.enabled ? 'Pengingat diatur pukul ${next.label}' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(reminderSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Notifikasi')),
      body: AsyncValueView<ReminderSettings>(
        value: settings,
        onRetry: () => ref.invalidate(reminderSettingsProvider),
        data: (s) => ContentListView(
          children: [
            const SectionHeader(title: 'Pengingat belajar'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pengingat belajar harian'),
              subtitle: Text(
                s.enabled ? 'Aktif setiap hari pukul ${s.label}' : 'Nonaktif',
              ),
              value: s.enabled,
              onChanged: _busy
                  ? null
                  : (v) => _apply(
                      s.copyWith(enabled: v),
                      done: v
                          ? 'Pengingat aktif pukul ${s.label}'
                          : 'Pengingat dimatikan',
                    ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: !_busy,
              leading: const Icon(Icons.schedule),
              title: const Text('Jam pengingat'),
              subtitle: Text(s.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTime(s),
            ),
            Text(
              'Pengingat dikirim oleh perangkat ini (tidak butuh internet). '
              'Waktunya bisa bergeser beberapa menit karena penghematan baterai.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SectionHeader(title: 'Pengumuman'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('Pengumuman dari admin'),
              subtitle: const Text('Ditampilkan di ikon lonceng beranda'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.notifications),
            ),
          ],
        ),
      ),
    );
  }
}
