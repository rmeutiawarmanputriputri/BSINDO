import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/content_page.dart';
import '../../../core/widgets/state_views.dart';
import '../data/home_content_repository.dart';
import '../domain/home_content.dart';

/// Notifikasi dalam aplikasi (pengumuman dari CMS).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _marked = false;

  Future<void> _markAllRead(List<Announcement> list) async {
    if (_marked) return;
    _marked = true;
    final unread = list.where((a) => !a.isRead).map((a) => a.id).toList();
    if (unread.isEmpty) return;
    try {
      await ref.read(homeContentRepositoryProvider).markRead(unread);
    } catch (_) {
      // Tanda baca tidak penting; abaikan kegagalan.
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(announcementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: AsyncValueView<List<Announcement>>(
        value: list,
        onRetry: () => ref.invalidate(announcementsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(
          icon: Icons.notifications_none,
          title: 'Belum ada notifikasi',
          message: 'Pengumuman dari pengelola akan tampil di sini.',
        ),
        data: (items) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _markAllRead(items),
          );
          return RefreshIndicator(
            onRefresh: () async {
              _marked = false;
              ref.invalidate(announcementsProvider);
            },
            child: ContentListView(
              children: [
                for (final a in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (!a.isRead)
                                const Padding(
                                  padding: EdgeInsets.only(
                                    right: AppSpacing.sm,
                                  ),
                                  child: Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: AppColors.primary,
                                    semanticLabel: 'Belum dibaca',
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  a.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            formatDateTimeId(a.publishedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            a.body,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// FAQ / Bantuan (isi dari CMS).
class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(faqsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ & Bantuan')),
      body: AsyncValueView<List<Faq>>(
        value: faqs,
        onRetry: () => ref.invalidate(faqsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyView(
          icon: Icons.help_outline,
          title: 'FAQ belum tersedia',
          message: 'Pertanyaan umum akan ditambahkan oleh pengelola.',
        ),
        data: (items) => ContentListView(
          children: [
            for (final f in items)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ExpansionTile(
                  title: Text(
                    f.question,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  expandedAlignment: Alignment.centerLeft,
                  children: [
                    Text(
                      f.answer,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Informasi Premium + status langganan pengguna.
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(premiumInfoProvider);
    final status =
        ref.watch(premiumStatusProvider).value ?? const PremiumStatus();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: AsyncValueView<PremiumInfo>(
        value: info,
        onRetry: () => ref.invalidate(premiumInfoProvider),
        data: (i) => ContentListView(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: status.isPremium
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFFF4E0),
                borderRadius: BorderRadius.circular(AppRadius.contentCard),
              ),
              child: Row(
                children: [
                  Icon(
                    status.isPremium
                        ? Icons.workspace_premium
                        : Icons.lock_outline,
                    size: 36,
                    color: status.isPremium
                        ? AppColors.success
                        : const Color(0xFF8A5300),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.isPremium
                              ? 'Akun Anda Premium'
                              : 'Akun Anda gratis',
                          style: theme.textTheme.titleMedium,
                        ),
                        if (status.isPremium && status.plan != null)
                          Text('Paket: ${status.plan}'),
                        if (status.isPremium && status.expiresAt != null)
                          Text(
                            'Berlaku sampai ${formatDateId(status.expiresAt!)}',
                          ),
                        if (!status.isPremium)
                          const Text(
                            'Materi bertanda Premium dapat dibuka setelah akun diaktifkan Premium.',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!i.enabled && i.plans.isEmpty && i.description == null)
              const EmptyView(
                icon: Icons.info_outline,
                title: 'Informasi paket belum tersedia',
                message: 'Hubungi pengelola untuk informasi Premium.',
              )
            else ...[
              if (i.title != null)
                Text(i.title!, style: theme.textTheme.headlineSmall),
              if (i.description != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(i.description!, style: theme.textTheme.bodyLarge),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final p in i.plans)
                Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: const Icon(
                      Icons.star_outline,
                      color: AppColors.accent,
                    ),
                    title: Text(p.name),
                    subtitle: p.description == null
                        ? null
                        : Text(p.description!),
                    trailing: p.priceLabel == null
                        ? null
                        : Text(
                            p.priceLabel!,
                            style: theme.textTheme.titleSmall,
                          ),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Aktivasi Premium dilakukan oleh pengelola. Hubungi admin untuk berlangganan.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
