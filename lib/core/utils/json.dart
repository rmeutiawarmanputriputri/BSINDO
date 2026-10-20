/// Helper membaca JSON dari PostgREST tanpa cast dinamis yang berbahaya.
typedef Json = Map<String, dynamic>;

String reqString(Json json, String key) => json[key] as String;

String? optString(Json json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

int optInt(Json json, String key, [int fallback = 0]) {
  final value = json[key];
  return value is num ? value.toInt() : fallback;
}

bool optBool(Json json, String key, [bool fallback = false]) {
  final value = json[key];
  return value is bool ? value : fallback;
}

/// Objek relasi tertanam (embed) PostgREST: `{...}` atau `null`.
Json? optObject(Json json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
    return value.first as Map<String, dynamic>;
  }
  return null;
}

/// Daftar relasi tertanam.
List<Json> optList(Json json, String key) {
  final value = json[key];
  // Selalu list baru yang dapat diubah (aman untuk `..sort`).
  if (value is List) return value.whereType<Map<String, dynamic>>().toList();
  return <Json>[];
}

/// Hasil `select('count')` tertanam: `[{"count": 3}]`.
int embeddedCount(Json json, String key) {
  final list = json[key];
  if (list is List && list.isNotEmpty && list.first is Map) {
    final count = (list.first as Map)['count'];
    if (count is num) return count.toInt();
  }
  return 0;
}

/// Mengubah hasil query (`List<dynamic>`) menjadi `List<Json>`.
List<Json> rows(Object? data) =>
    data is List ? data.whereType<Map<String, dynamic>>().toList() : const [];
