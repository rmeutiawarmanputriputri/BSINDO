/// Panjang maksimum kata kunci pencarian (FLUTTER_ARCHITECTURE §8).
const kMaxSearchLength = 80;

/// Menormalkan kata kunci: trim, huruf kecil, dipotong 80 karakter.
String normalizeSearch(String raw) {
  final trimmed = raw.trim().toLowerCase();
  return trimmed.length > kMaxSearchLength
      ? trimmed.substring(0, kMaxSearchLength)
      : trimmed;
}

/// Meng-escape karakter wildcard `ilike` (`\`, `%`, `_`) agar diperlakukan
/// sebagai huruf biasa (DICT-01).
String escapeLike(String input) => input
    .replaceAll(r'\', r'\\')
    .replaceAll('%', r'\%')
    .replaceAll('_', r'\_');

/// Pola `ilike` "mengandung" yang aman.
String containsPattern(String raw) => '%${escapeLike(normalizeSearch(raw))}%';
