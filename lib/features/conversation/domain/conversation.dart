import '../../../core/utils/date_format.dart';
import '../../../core/utils/json.dart';
import '../../../core/widgets/source_card.dart';

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
  });

  static const listColumns =
      'id, slug, title, description, category_id, status, validated_by, '
      'category:categories(name), items:conversation_items(count)';

  static const detailColumns =
      'id, slug, title, description, context_note, category_id, status, '
      'source_note, validated_by, verified_at, category:categories(name), '
      'items:conversation_items(id, position, speaker_label, text_id, '
      'context_note, sign_id, video:media_assets!video_asset_id(path), '
      'sign:signs(id, term, sign_video:media_assets!video_asset_id(path)))';

  factory ConversationModule.fromJson(Json json) {
    final items = optList(json, 'items')
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
  });

  factory ConversationItem.fromJson(Json json) {
    final sign = optObject(json, 'sign');
    final ownVideo = optObject(json, 'video')?['path'] as String?;
    final signVideo =
        sign != null ? optObject(sign, 'sign_video')?['path'] as String? : null;
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
}
