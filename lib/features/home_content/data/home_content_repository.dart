import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/utils/json.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/home_content.dart';

/// Konten aplikasi yang diatur dari CMS: banner, pengumuman, FAQ, Premium.
abstract interface class HomeContentRepository {
  Future<List<HomeBanner>> banners();
  Future<List<Announcement>> announcements();
  Future<void> markRead(Iterable<String> ids);
  Future<List<Faq>> faqs();
  Future<PremiumStatus> premiumStatus();
  Future<PremiumInfo> premiumInfo();
}

class SupabaseHomeContentRepository implements HomeContentRepository {
  SupabaseHomeContentRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<HomeBanner>> banners() => guardRequest(() async {
    // RLS hanya mengembalikan banner aktif dalam periode tayang.
    final data = await _client
        .from('banners')
        .select(HomeBanner.columns)
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .limit(10);
    return rows(data).map(HomeBanner.fromJson).toList();
  });

  @override
  Future<List<Announcement>> announcements() => guardRequest(() async {
    final data = await _client
        .from('announcements')
        .select('id, title, body, published_at')
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .limit(50);
    final reads = await _client
        .from('announcement_reads')
        .select('announcement_id');
    final readIds = {
      for (final r in rows(reads)) r['announcement_id'] as String,
    };
    return rows(data)
        .map((j) => Announcement.fromJson(j, isRead: readIds.contains(j['id'])))
        .toList();
  });

  @override
  Future<void> markRead(Iterable<String> ids) => guardRequest(() async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await _client
        .from('announcement_reads')
        .upsert(
          [
            for (final id in list) {'announcement_id': id},
          ],
          onConflict: 'user_id,announcement_id',
          ignoreDuplicates: true,
        );
  });

  @override
  Future<List<Faq>> faqs() => guardRequest(() async {
    final data = await _client
        .from('faqs')
        .select('id, question, answer')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return rows(data).map(Faq.fromJson).toList();
  });

  @override
  Future<PremiumStatus> premiumStatus() => guardRequest(() async {
    final result = await _client.rpc('my_premium_status');
    return PremiumStatus.fromJson(Map<String, dynamic>.from(result as Map));
  });

  @override
  Future<PremiumInfo> premiumInfo() => guardRequest(() async {
    final row = await _client
        .from('app_settings')
        .select('value')
        .eq('key', 'premium_info')
        .maybeSingle();
    final value = row?['value'];
    return value is Map<String, dynamic>
        ? PremiumInfo.fromJson(value)
        : const PremiumInfo();
  });
}

final homeContentRepositoryProvider = Provider<HomeContentRepository>(
  (ref) => SupabaseHomeContentRepository(ref.watch(supabaseClientProvider)),
);

final bannersProvider = FutureProvider.autoDispose<List<HomeBanner>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(homeContentRepositoryProvider).banners();
});

final announcementsProvider = FutureProvider.autoDispose<List<Announcement>>((
  ref,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(homeContentRepositoryProvider).announcements();
});

/// Jumlah pengumuman belum dibaca (badge lonceng).
final unreadAnnouncementsProvider = Provider.autoDispose<int>((ref) {
  final list = ref.watch(announcementsProvider).value ?? const <Announcement>[];
  return list.where((a) => !a.isRead).length;
});

final faqsProvider = FutureProvider.autoDispose<List<Faq>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(homeContentRepositoryProvider).faqs();
});

final premiumStatusProvider = FutureProvider<PremiumStatus>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const PremiumStatus();
  return ref.watch(homeContentRepositoryProvider).premiumStatus();
});

final premiumInfoProvider = FutureProvider.autoDispose<PremiumInfo>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(homeContentRepositoryProvider).premiumInfo();
});

/// Pengguna Premium? (false saat memuat/gagal → konten Premium tetap terkunci).
final isPremiumProvider = Provider<bool>(
  (ref) => ref.watch(premiumStatusProvider).value?.isPremium ?? false,
);
