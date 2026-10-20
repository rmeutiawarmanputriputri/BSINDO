import '../../../core/utils/date_format.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/source_card.dart';

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

/// Kosakata atau frasa BISINDO (tabel `signs`, D-04).
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
  });

  /// Kolom select untuk daftar & detail.
  static const selectColumns =
      'id, term, entry_type, category_id, meaning, movement_description, '
      'usage_example, source_note, validated_by, verified_at, status, '
      'category:categories(name), '
      'video:media_assets!video_asset_id(path), '
      'thumb:media_assets!thumbnail_asset_id(path)';

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

  bool get hasVideo => videoPath != null;
  bool get isSample => isSampleValidator(validatedBy);
}
