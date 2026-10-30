import '../../../core/utils/json.dart';

/// Banner Beranda (tabel `banners`, dikelola dari CMS).
class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    this.description,
    this.imagePath,
    this.targetType = 'none',
    this.targetValue,
  });

  static const columns =
      'id, title, description, target_type, target_value, sort_order, image:media_assets!image_asset_id(path)';

  factory HomeBanner.fromJson(Json json) => HomeBanner(
    id: reqString(json, 'id'),
    title: optString(json, 'title') ?? '',
    description: optString(json, 'description'),
    imagePath: optObject(json, 'image')?['path'] as String?,
    targetType: optString(json, 'target_type') ?? 'none',
    targetValue: optString(json, 'target_value'),
  );

  final String id;
  final String title;
  final String? description;
  final String? imagePath;

  /// none | route | url | sign | conversation | category
  final String targetType;
  final String? targetValue;

  bool get isTappable =>
      targetType != 'none' && (targetValue?.isNotEmpty ?? false);
}

/// Pengumuman (notifikasi dalam aplikasi).
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    this.isRead = false,
  });

  factory Announcement.fromJson(Json json, {bool isRead = false}) =>
      Announcement(
        id: reqString(json, 'id'),
        title: optString(json, 'title') ?? '',
        body: optString(json, 'body') ?? '',
        isRead: isRead,
        publishedAt:
            DateTime.tryParse(
              optString(json, 'published_at') ?? '',
            )?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;
  final bool isRead;
}

class Faq {
  const Faq({required this.id, required this.question, required this.answer});

  factory Faq.fromJson(Json json) => Faq(
    id: reqString(json, 'id'),
    question: optString(json, 'question') ?? '',
    answer: optString(json, 'answer') ?? '',
  );

  final String id;
  final String question;
  final String answer;
}

/// Status Premium milik pengguna (RPC `my_premium_status`).
class PremiumStatus {
  const PremiumStatus({this.isPremium = false, this.plan, this.expiresAt});

  factory PremiumStatus.fromJson(Json json) => PremiumStatus(
    isPremium: optBool(json, 'is_premium'),
    plan: optString(json, 'plan'),
    expiresAt: DateTime.tryParse(
      optString(json, 'expires_at') ?? '',
    )?.toLocal(),
  );

  final bool isPremium;
  final String? plan;
  final DateTime? expiresAt;
}

/// Info paket Premium (app_settings `premium_info`, teks dari pemilik).
class PremiumInfo {
  const PremiumInfo({
    this.enabled = false,
    this.title,
    this.description,
    this.plans = const [],
  });

  factory PremiumInfo.fromJson(Json json) => PremiumInfo(
    enabled: optBool(json, 'enabled'),
    title: optString(json, 'title'),
    description: optString(json, 'description'),
    plans: optList(json, 'plans')
        .map(
          (p) => PremiumPlan(
            name: optString(p, 'name') ?? '',
            priceLabel: optString(p, 'price_label'),
            description: optString(p, 'description'),
          ),
        )
        .where((p) => p.name.isNotEmpty)
        .toList(),
  );

  final bool enabled;
  final String? title;
  final String? description;
  final List<PremiumPlan> plans;
}

class PremiumPlan {
  const PremiumPlan({required this.name, this.priceLabel, this.description});
  final String name;
  final String? priceLabel;
  final String? description;
}
