import '../../../core/utils/date_format.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/sample.dart';

enum SignEntryType {
  word('word', 'Kata'),
  phrase('phrase', 'Frasa');

  const SignEntryType(this.value, this.label);
  final String value;
  final String label;

  static SignEntryType parse(String? value) =>
      value == 'phrase' ? SignEntryType.phrase : SignEntryType.word;
}

class Category {
  const Category({required this.id, required this.name, required this.kind});

  factory Category.fromJson(Json json) => Category(
    id: reqString(json, 'id'),
    name: reqString(json, 'name'),
    kind: optString(json, 'kind') ?? 'sign',
  );

  final String id;
  final String name;
  final String kind;
}

/// Modul materi pada tabel `signs` (v1.1.0, kolom `content_module`).
enum ContentModule {
  vocabulary('vocabulary', 'Kosakata'),
  alphabet('alphabet', 'Alfabet'),
  number('number', 'Angka');

  const ContentModule(this.value, this.label);
  final String value;
  final String label;

  static ContentModule parse(String? value) => switch (value) {
    'alphabet' => ContentModule.alphabet,
    'number' => ContentModule.number,
    _ => ContentModule.vocabulary,
  };
}

/// Kelompok angka (kolom `number_group`).
enum NumberGroup {
  zeroToNine('0-9', '0–9'),
  tenToTwenty('10-20', '10–20'),
  tens('tens', 'Puluhan'),
  hundredPlus('100+', '100 ke atas');

  const NumberGroup(this.value, this.label);
  final String value;
  final String label;

  static NumberGroup? parse(String? value) {
    for (final g in values) {
      if (g.value == value) return g;
    }
    return null;
  }
}

/// Materi isyarat BISINDO (tabel `signs`, D-04): kosakata, huruf, atau angka.
class Sign {
  const Sign({
    required this.id,
    required this.term,
    required this.entryType,
    this.categoryId,
    this.categoryName,
    this.meaning,
    this.movementDescription,
    this.usageExample,
    this.videoPath,
    this.thumbnailPath,
    this.sourceNote,
    this.validatedBy,
    this.verifiedAt,
    this.status = 'published',
    this.contentModule = ContentModule.vocabulary,
    this.symbol,
    this.numberGroup,
    this.sortOrder = 0,
    this.imagePath,
    this.audioPath,
    this.isPremium = false,
  });

  /// Kolom select untuk daftar & detail. Relasi media yang tidak boleh dibaca
  /// pengguna (mis. konten Premium) dikembalikan `null` oleh RLS.
  static const selectColumns =
      'id, term, entry_type, category_id, meaning, movement_description, '
      'usage_example, source_note, validated_by, verified_at, status, '
      'content_module, symbol, number_group, sort_order, is_premium, '
      'category:categories(name), '
      'video:media_assets!video_asset_id(path), '
      'thumb:media_assets!thumbnail_asset_id(path), '
      'image:media_assets!image_asset_id(path), '
      'audio:media_assets!audio_asset_id(path)';

  factory Sign.fromJson(Json json) => Sign(
    id: reqString(json, 'id'),
    term: reqString(json, 'term'),
    entryType: SignEntryType.parse(optString(json, 'entry_type')),
    categoryId: optString(json, 'category_id'),
    categoryName: optObject(json, 'category')?['name'] as String?,
    meaning: optString(json, 'meaning'),
    movementDescription: optString(json, 'movement_description'),
    usageExample: optString(json, 'usage_example'),
    videoPath: optObject(json, 'video')?['path'] as String?,
    thumbnailPath: optObject(json, 'thumb')?['path'] as String?,
    sourceNote: optString(json, 'source_note'),
    validatedBy: optString(json, 'validated_by'),
    verifiedAt: parseDate(json['verified_at']),
    status: optString(json, 'status') ?? 'published',
    contentModule: ContentModule.parse(optString(json, 'content_module')),
    symbol: optString(json, 'symbol'),
    numberGroup: NumberGroup.parse(optString(json, 'number_group')),
    sortOrder: optInt(json, 'sort_order'),
    imagePath: optObject(json, 'image')?['path'] as String?,
    audioPath: optObject(json, 'audio')?['path'] as String?,
    isPremium: optBool(json, 'is_premium'),
  );

  final String id;
  final String term;
  final SignEntryType entryType;
  final String? categoryId;
  final String? categoryName;
  final String? meaning;
  final String? movementDescription;
  final String? usageExample;
  final String? videoPath;
  final String? thumbnailPath;
  final String? sourceNote;
  final String? validatedBy;
  final DateTime? verifiedAt;
  final String status;
  final ContentModule contentModule;

  /// Huruf/angka yang ditampilkan besar (Alfabet & Angka).
  final String? symbol;
  final NumberGroup? numberGroup;
  final int sortOrder;

  /// Panduan visual gerakan tangan.
  final String? imagePath;
  final String? audioPath;
  final bool isPremium;

  /// Teks tampilan utama: simbol untuk huruf/angka, istilah untuk kosakata.
  String get displayTitle =>
      contentModule == ContentModule.vocabulary ? term : (symbol ?? term);

  bool get hasVideo => videoPath != null;
  bool get isSample => isSampleValidator(validatedBy);
}
