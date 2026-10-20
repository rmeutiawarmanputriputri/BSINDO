/// Format tanggal Indonesia tanpa data locale (aman di tes & offline).
const _months = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
  'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Contoh: `20 Oktober 2026`.
String formatDateId(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1]} ${local.year}';
}

/// Contoh: `20 Okt 2026, 14.05`.
String formatDateTimeId(DateTime date) {
  final local = date.toLocal();
  final month = _months[local.month - 1].substring(0, 3);
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} $month ${local.year}, $hh.$mm';
}

/// `DateTime.tryParse` untuk nilai JSON nullable.
DateTime? parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
