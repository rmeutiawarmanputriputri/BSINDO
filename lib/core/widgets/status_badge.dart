import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Lencana status dengan ikon + teks (bukan hanya warna, DESIGN_SYSTEM §1.2).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  /// Status konten: draft/in_review/verified/published/archived.
  factory StatusBadge.content(String status) => switch (status) {
        'draft' => const StatusBadge(
            label: 'Draf', icon: Icons.edit_note, color: Color(0xFF475569)),
        'in_review' => const StatusBadge(
            label: 'Ditinjau', icon: Icons.hourglass_top, color: AppColors.warning),
        'verified' => const StatusBadge(
            label: 'Terverifikasi', icon: Icons.verified_outlined, color: AppColors.primary),
        'published' => const StatusBadge(
            label: 'Terbit', icon: Icons.public, color: AppColors.success),
        'archived' => const StatusBadge(
            label: 'Diarsipkan', icon: Icons.archive_outlined, color: Color(0xFF334155)),
        _ => StatusBadge(label: status, icon: Icons.help_outline, color: AppColors.textSecondary),
      };

  /// Status laporan: open/in_review/resolved/rejected.
  factory StatusBadge.report(String status) => switch (status) {
        'open' => const StatusBadge(
            label: 'Menunggu', icon: Icons.schedule, color: AppColors.warning),
        'in_review' => const StatusBadge(
            label: 'Ditinjau', icon: Icons.manage_search, color: AppColors.primary),
        'resolved' => const StatusBadge(
            label: 'Selesai', icon: Icons.check_circle_outline, color: AppColors.success),
        'rejected' => const StatusBadge(
            label: 'Ditolak', icon: Icons.cancel_outlined, color: AppColors.error),
        _ => StatusBadge(label: status, icon: Icons.help_outline, color: AppColors.textSecondary),
      };

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
