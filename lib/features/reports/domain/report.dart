import '../../../core/utils/date_format.dart';
import '../../../core/utils/json.dart';

enum ReportTargetType {
  sign('sign', 'sign_id'),
  conversationModule('conversation_module', 'conversation_module_id'),
  lesson('lesson', 'lesson_id');

  const ReportTargetType(this.value, this.column);
  final String value;
  final String column;

  static ReportTargetType? parse(String? value) {
    for (final t in values) {
      if (t.value == value) return t;
    }
    return null;
  }
}

enum ReportCategory {
  wrongSign('wrong_sign', 'Gerakan diduga keliru'),
  wrongMeaning('wrong_meaning', 'Arti tidak sesuai'),
  videoProblem('video_problem', 'Video bermasalah'),
  wrongExample('wrong_example', 'Contoh penggunaan tidak tepat'),
  other('other', 'Lainnya');

  const ReportCategory(this.value, this.label);
  final String value;
  final String label;

  static ReportCategory parse(String? value) => values.firstWhere(
        (c) => c.value == value,
        orElse: () => ReportCategory.other,
      );
}

class ContentReport {
  const ContentReport({
    required this.id,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.targetType,
    this.targetId,
    this.targetTitle,
    this.description,
    this.resolutionMessage,
    this.reporterId,
  });

  static const columns =
      'id, category, status, description, resolution_message, created_at, '
      'reporter_id, sign_id, conversation_module_id, lesson_id, '
      'sign:signs(term), module:conversation_modules(title), lesson:lessons(title)';

  factory ContentReport.fromJson(Json json) {
    final ReportTargetType type;
    final String? targetId;
    final String? title;
    if (optString(json, 'sign_id') != null) {
      type = ReportTargetType.sign;
      targetId = optString(json, 'sign_id');
      title = optObject(json, 'sign')?['term'] as String?;
    } else if (optString(json, 'conversation_module_id') != null) {
      type = ReportTargetType.conversationModule;
      targetId = optString(json, 'conversation_module_id');
      title = optObject(json, 'module')?['title'] as String?;
    } else {
      type = ReportTargetType.lesson;
      targetId = optString(json, 'lesson_id');
      title = optObject(json, 'lesson')?['title'] as String?;
    }
    return ContentReport(
      id: reqString(json, 'id'),
      category: ReportCategory.parse(optString(json, 'category')),
      status: optString(json, 'status') ?? 'open',
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      targetType: type,
      targetId: targetId,
      targetTitle: title,
      description: optString(json, 'description'),
      resolutionMessage: optString(json, 'resolution_message'),
      reporterId: optString(json, 'reporter_id'),
    );
  }

  final String id;
  final ReportCategory category;
  final String status;
  final DateTime createdAt;
  final ReportTargetType targetType;
  final String? targetId;
  final String? targetTitle;
  final String? description;
  final String? resolutionMessage;
  final String? reporterId;
}

/// Validasi form laporan (S22 / REP-01).
String? validateReportDescription(ReportCategory category, String text) {
  final trimmed = text.trim();
  if (trimmed.length > 1000) return 'Keterangan maksimal 1000 karakter.';
  if (category == ReportCategory.other && trimmed.length < 5) {
    return 'Jelaskan masalahnya minimal 5 karakter.';
  }
  return null;
}
