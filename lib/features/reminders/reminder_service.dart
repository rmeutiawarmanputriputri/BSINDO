import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/storage/local_store.dart';
import 'reminder_settings.dart';

export 'reminder_settings.dart';

/// Notifikasi lokal "pengingat belajar" harian (H.6). Tidak memakai server.
class ReminderService {
  ReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 7001;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'pengingat_belajar',
      'Pengingat belajar',
      channelDescription: 'Pengingat harian untuk belajar BISINDO',
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final now = DateTime.now();
    final sameOffset = tz.timeZoneDatabase.locations.entries
        .where((e) => e.value.currentTimeZone.offset == now.timeZoneOffset)
        .map((e) => e.key);
    final name = guessTimeZoneName(now.timeZoneOffset, sameOffset);
    tz.setLocalLocation(tz.getLocation(name));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Minta izin notifikasi (Android 13+). `false` bila ditolak.
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> scheduleDaily(int hour, int minute) async {
    await _init();
    await _plugin.cancel(id: _notificationId);
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Waktunya belajar BISINDO',
      body: 'Luangkan beberapa menit untuk mengulang materi hari ini.',
      scheduledDate: at,
      notificationDetails: _details,
      // Tidak butuh izin alarm tepat waktu; jadwal bisa bergeser beberapa menit.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: _notificationId);
  }
}

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);

/// Pengaturan pengingat + aksi ubah (menjadwalkan/membatalkan notifikasi).
class ReminderSettingsNotifier extends AsyncNotifier<ReminderSettings> {
  static const storeName = 'settings';

  @override
  Future<ReminderSettings> build() async => ReminderSettings.fromJson(
    await ref.watch(localStoreProvider).read(storeName),
  );

  /// Mengaktifkan/mengubah jam. Melempar [ReminderPermissionDenied] bila izin
  /// notifikasi ditolak.
  Future<void> save(ReminderSettings next) async {
    final service = ref.read(reminderServiceProvider);
    if (next.enabled) {
      final granted = await service.requestPermission();
      if (!granted) throw const ReminderPermissionDenied();
      await service.scheduleDaily(next.hour, next.minute);
    } else {
      await service.cancel();
    }
    final store = ref.read(localStoreProvider);
    final data = await store.read(storeName);
    await store.write(storeName, {...data, ...next.toJson()});
    if (ref.mounted) state = AsyncData(next);
  }
}

final reminderSettingsProvider =
    AsyncNotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );

class ReminderPermissionDenied implements Exception {
  const ReminderPermissionDenied();
  @override
  String toString() =>
      'Izin notifikasi ditolak. Aktifkan notifikasi BISINDO di Pengaturan perangkat.';
}

/// Dipanggil saat aplikasi dibuka: jadwal ulang pengingat yang aktif (mis.
/// setelah update aplikasi). Gagal diam-diam.
Future<void> restoreReminder(LocalStore store, ReminderService service) async {
  try {
    final s = ReminderSettings.fromJson(
      await store.read(ReminderSettingsNotifier.storeName),
    );
    if (s.enabled) await service.scheduleDaily(s.hour, s.minute);
  } catch (_) {}
}
