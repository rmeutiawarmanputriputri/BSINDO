import '../../../core/utils/date_format.dart';
import '../../../core/utils/json.dart';
import '../../../core/utils/sample.dart';

class ConversationModule {
  const ConversationModule({
    required this.id,
    required this.title,
    this.description,
    this.contextNote,
    this.categoryId,
    this.categoryName,
    this.itemCount = 0,
    this.items = const [],
    this.sourceNote,
    this.validatedBy,
    this.verifiedAt,
    this.status = 'published',
    this.slug,
    this.isPremium = false,
  });

  static const listColumns =
      'id, slug, title, description, category_id, status, validated_by, is_premium, '
      'category:categories(name), items:conversation_items(count)';

  static const detailColumns =
      'id, slug, title, description, context_note, category_id, status, is_premium, '
      'source_note, validated_by, verified_at, category:categories(name), '
      'items:conversation_items(id, position, speaker_label, text_id, '
      'context_note, translation, explanation, sign_id, '
      'video:media_assets!video_asset_id(path), audio:media_assets!audio_asset_id(path), '
      'sign:signs(id, term, sign_video:media_assets!video_asset_id(path)), '
      'parts:conversation_item_parts(position, part_text, meaning, sign_id, '
      'part_sign:signs(id, term, meaning, content_module)))';

  factory ConversationModule.fromJson(Json json) {
    final items =
        optList(json, 'items')
            .where((i) => i.containsKey('id'))
            .map(ConversationItem.fromJson)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    return ConversationModule(
      id: reqString(json, 'id'),
      slug: optString(json, 'slug'),
      title: reqString(json, 'title'),
      description: optString(json, 'description'),
      contextNote: optString(json, 'context_note'),
      categoryId: optString(json, 'category_id'),
      categoryName: optObject(json, 'category')?['name'] as String?,
      itemCount: items.isNotEmpty ? items.length : embeddedCount(json, 'items'),
      items: items,
      sourceNote: optString(json, 'source_note'),
      validatedBy: optString(json, 'validated_by'),
      verifiedAt: parseDate(json['verified_at']),
      status: optString(json, 'status') ?? 'published',
      isPremium: optBool(json, 'is_premium'),
    );
  }

  final String id;
  final String? slug;
  final String title;
  final String? description;
  final String? contextNote;
  final String? categoryId;
  final String? categoryName;
  final int itemCount;
  final List<ConversationItem> items;
  final String? sourceNote;
  final String? validatedBy;
  final DateTime? verifiedAt;
  final String status;
  final bool isPremium;

  bool get isSample => isSampleValidator(validatedBy);
}

class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.position,
    required this.speaker,
    required this.text,
    this.contextNote,
    this.signId,
    this.signTerm,
    this.videoPath,
    this.ownVideoPath,
    this.translation,
    this.explanation,
    this.audioPath,
    this.parts = const [],
  });

  factory ConversationItem.fromJson(Json json) {
    final sign = optObject(json, 'sign');
    final ownVideo = optObject(json, 'video')?['path'] as String?;
    final signVideo = sign != null
        ? (optObject(sign, 'sign_video')?['path'] as String?)
        : null;
    return ConversationItem(
      id: reqString(json, 'id'),
      position: optInt(json, 'position'),
      speaker: optString(json, 'speaker_label') ?? 'A',
      text: optString(json, 'text_id') ?? '',
      contextNote: optString(json, 'context_note'),
      signId: optString(json, 'sign_id'),
      signTerm: sign != null ? optString(sign, 'term') : null,
      // Video milik baris diutamakan, lalu video kosakata terkait.
      videoPath: ownVideo ?? signVideo,
      ownVideoPath: ownVideo,
      translation: optString(json, 'translation'),
      explanation: optString(json, 'explanation'),
      audioPath: optObject(json, 'audio')?['path'] as String?,
      parts: optList(json, 'parts').map(ConversationPart.fromJson).toList()
        ..sort((a, b) => a.position.compareTo(b.position)),
    );
  }

  final String id;
  final int position;
  final String speaker;
  final String text;
  final String? contextNote;
  final String? signId;
  final String? signTerm;
  final String? videoPath;
  final String? ownVideoPath;

  /// Terjemahan / susunan isyarat (v1.1.0).
  final String? translation;

  /// Penjelasan makna kalimat (v1.1.0).
  final String? explanation;
  final String? audioPath;

  /// Kalimat dipecah menjadi bagian/kosakata sesuai susunan isyarat (v1.1.0).
  final List<ConversationPart> parts;
}

/// Satu bagian kalimat: kosakata dari kamus dan/atau teks bagian + artinya.
/// Kosakata yang belum Published tidak terbaca (RLS) → hanya teks bagian.
class ConversationPart {
  const ConversationPart({
    required this.position,
    this.partText,
    this.meaning,
    this.signId,
    this.signTerm,
    this.signMeaning,
    this.signModule,
  });

  factory ConversationPart.fromJson(Json json) {
    final sign = optObject(json, 'part_sign');
    return ConversationPart(
      position: optInt(json, 'position'),
      partText: optString(json, 'part_text'),
      meaning: optString(json, 'meaning'),
      signId: sign != null ? optString(sign, 'id') : null,
      signTerm: sign != null ? optString(sign, 'term') : null,
      signMeaning: sign != null ? optString(sign, 'meaning') : null,
      signModule: sign != null ? optString(sign, 'content_module') : null,
    );
  }

  final int position;
  final String? partText;
  final String? meaning;

  /// Terisi hanya bila kosakata terkait dapat dibaca pengguna (Published).
  final String? signId;
  final String? signTerm;
  final String? signMeaning;
  final String? signModule;

  /// Teks yang ditampilkan: teks bagian, atau istilah kosakata.
  String get label => (partText?.trim().isNotEmpty ?? false)
      ? partText!.trim()
      : (signTerm ?? '');

  /// Arti bagian: dari CMS, atau arti kosakata di kamus.
  String? get displayMeaning =>
      (meaning?.trim().isNotEmpty ?? false) ? meaning!.trim() : signMeaning;

  bool get isVisible => label.isNotEmpty;
}
