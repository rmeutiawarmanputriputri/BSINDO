// Model pengaturan pengingat (tanpa dependensi Flutter → dapat diuji murni).

/// Pengaturan pengingat belajar (disimpan di perangkat, bukan di server).
class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.hour = 19,
    this.minute = 0,
  });

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    final r = json['reminder'];
    if (r is! Map) return const ReminderSettings();
    int clampInt(Object? v, int max, int fallback) =>
        v is int && v >= 0 && v <= max ? v : fallback;
    return ReminderSettings(
      enabled: r['enabled'] == true,
      hour: clampInt(r['hour'], 23, 19),
      minute: clampInt(r['minute'], 59, 0),
    );
  }

  final bool enabled;
  final int hour;
  final int minute;

  /// "19.00" (format jam Indonesia).
  String get label =>
      '${hour.toString().padLeft(2, '0')}.${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'reminder': {'enabled': enabled, 'hour': hour, 'minute': minute},
  };

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute;

  @override
  int get hashCode => Object.hash(enabled, hour, minute);
}

/// Zona waktu lokal dari offset perangkat (WIB/WITA/WIT diutamakan) tanpa
/// paket tambahan.
String guessTimeZoneName(Duration offset, Iterable<String> candidates) {
  switch (offset.inMinutes) {
    case 420:
      return 'Asia/Jakarta';
    case 480:
      return 'Asia/Makassar';
    case 540:
      return 'Asia/Jayapura';
  }
  return candidates.firstOrNull ?? 'UTC';
}
