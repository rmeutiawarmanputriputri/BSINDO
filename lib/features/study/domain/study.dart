import '../../../core/utils/json.dart';

/// Ringkasan progres pengguna (RPC `my_progress_summary`).
class ProgressSummary {
  const ProgressSummary({
    this.modules = const {},
    this.categories = const [],
    this.conversationsTotal = 0,
    this.conversationsCompleted = 0,
    this.quizSessions = 0,
    this.quizAverage = 0,
    this.quizBest = 0,
    this.totalLearned = 0,
  });

  factory ProgressSummary.fromJson(Json json) {
    final modules = <String, ModuleProgress>{};
    final raw = json['modules'];
    if (raw is Map<String, dynamic>) {
      raw.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          modules[key] = ModuleProgress(
            total: optInt(value, 'total'),
            learned: optInt(value, 'learned'),
          );
        }
      });
    }
    final conv = optObject(json, 'conversations') ?? const <String, dynamic>{};
    final quiz = optObject(json, 'quizzes') ?? const <String, dynamic>{};
    return ProgressSummary(
      modules: modules,
      categories: optList(json, 'categories').map(CategoryProgress.fromJson).toList(),
      conversationsTotal: optInt(conv, 'total'),
      conversationsCompleted: optInt(conv, 'completed'),
      quizSessions: optInt(quiz, 'sessions'),
      quizAverage: optInt(quiz, 'average_score'),
      quizBest: optInt(quiz, 'best_score'),
      totalLearned: optInt(json, 'total_learned'),
    );
  }

  final Map<String, ModuleProgress> modules;
  final List<CategoryProgress> categories;
  final int conversationsTotal;
  final int conversationsCompleted;
  final int quizSessions;
  final int quizAverage;
  final int quizBest;
  final int totalLearned;

  ModuleProgress module(String key) => modules[key] ?? const ModuleProgress();

  /// Total materi published (huruf + angka + kosakata).
  int get totalMaterials => modules.values.fold(0, (s, m) => s + m.total);

  /// Persentase keseluruhan 0–100.
  int get overallPercent =>
      totalMaterials == 0 ? 0 : ((totalLearned / totalMaterials) * 100).round().clamp(0, 100);
}

class ModuleProgress {
  const ModuleProgress({this.total = 0, this.learned = 0});
  final int total;
  final int learned;

  double get ratio => total == 0 ? 0 : (learned / total).clamp(0, 1).toDouble();
}

class CategoryProgress {
  const CategoryProgress({
    required this.categoryId,
    required this.name,
    required this.total,
    required this.learned,
  });

  factory CategoryProgress.fromJson(Json json) => CategoryProgress(
        categoryId: reqString(json, 'category_id'),
        name: optString(json, 'name') ?? '-',
        total: optInt(json, 'total'),
        learned: optInt(json, 'learned'),
      );

  final String categoryId;
  final String name;
  final int total;
  final int learned;

  double get ratio => total == 0 ? 0 : (learned / total).clamp(0, 1).toDouble();
}

/// Baris riwayat belajar (view `my_learning_history`).
class HistoryEntry {
  const HistoryEntry({
    required this.itemType,
    required this.module,
    required this.itemId,
    required this.title,
    required this.lastAccessedAt,
    required this.completed,
    this.symbol,
  });

  factory HistoryEntry.fromJson(Json json) => HistoryEntry(
        itemType: optString(json, 'item_type') ?? 'sign',
        module: optString(json, 'module') ?? 'vocabulary',
        itemId: reqString(json, 'item_id'),
        title: optString(json, 'title') ?? '-',
        symbol: optString(json, 'symbol'),
        completed: optBool(json, 'completed'),
        lastAccessedAt:
            DateTime.tryParse(optString(json, 'last_accessed_at') ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// `sign`, `lesson`, atau `conversation`.
  final String itemType;

  /// `alphabet` / `number` / `vocabulary` untuk sign; selain itu = itemType.
  final String module;
  final String itemId;
  final String title;
  final String? symbol;
  final bool completed;
  final DateTime lastAccessedAt;

  String get moduleLabel => switch (module) {
        'alphabet' => 'Alfabet',
        'number' => 'Angka',
        'vocabulary' => 'Kosakata',
        'lesson' => 'Pelajaran',
        'conversation' => 'Percakapan',
        _ => module,
      };
}

/// Status progres satu materi milik pengguna (tabel `sign_progress`).
class SignProgress {
  const SignProgress({required this.signId, required this.learned, this.viewCount = 0});

  factory SignProgress.fromJson(Json json) => SignProgress(
        signId: reqString(json, 'sign_id'),
        learned: json['learned_at'] != null || optBool(json, 'learned'),
        viewCount: optInt(json, 'view_count'),
      );

  final String signId;
  final bool learned;
  final int viewCount;
}

/// Indeks materi berikutnya yang belum dipelajari (mode belajar berurutan).
/// Mengembalikan 0 bila semua sudah dipelajari atau daftar kosong.
int nextUnlearnedIndex(List<String> orderedIds, Set<String> learned) {
  for (var i = 0; i < orderedIds.length; i++) {
    if (!learned.contains(orderedIds[i])) return i;
  }
  return 0;
}
