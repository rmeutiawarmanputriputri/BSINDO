import '../../../core/utils/date_format.dart';
import '../../../core/utils/json.dart';
import '../../dictionary/domain/sign.dart';

enum DifficultStatus { learning, relearned }

class DifficultItem {
  const DifficultItem({
    required this.id,
    required this.signId,
    required this.status,
    required this.reviewCount,
    this.sign,
    this.markedAt,
    this.lastReviewedAt,
  });

  factory DifficultItem.fromJson(Json json) {
    final signJson = optObject(json, 'sign');
    return DifficultItem(
      id: reqString(json, 'id'),
      signId: reqString(json, 'sign_id'),
      status: optString(json, 'status') == 'relearned'
          ? DifficultStatus.relearned
          : DifficultStatus.learning,
      reviewCount: optInt(json, 'review_count'),
      // null bila sign diarsipkan/tidak lagi published (F7 butir 5).
      sign: signJson != null ? Sign.fromJson(signJson) : null,
      markedAt: parseDate(json['marked_at']),
      lastReviewedAt: parseDate(json['last_reviewed_at']),
    );
  }

  final String id;
  final String signId;
  final DifficultStatus status;
  final int reviewCount;
  final Sign? sign;
  final DateTime? markedAt;
  final DateTime? lastReviewedAt;
}
