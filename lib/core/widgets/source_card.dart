import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../utils/date_format.dart';

/// Penanda materi contoh dev (DATABASE_SCHEMA §4).
bool isSampleValidator(String? validatedBy) =>
    validatedBy != null && validatedBy.startsWith('DEV-SAMPLE');

/// Kartu "Sumber & validasi" (IMPLEMENTATION_BRIEF §8 butir 3).
class SourceCard extends StatelessWidget {
  const SourceCard({
    super.key,
    required this.sourceNote,
    required this.validatedBy,
    required this.verifiedAt,
  });

  final String? sourceNote;
  final String? validatedBy;
  final DateTime? verifiedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sample = isSampleValidator(validatedBy);
    return Card(
      color: sample ? const Color(0xFFFFF7E6) : AppColors.inputFill,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    sample ? Icons.science_outlined : Icons.verified_outlined,
                    color: sample ? AppColors.warning : AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text('Sumber & validasi', style: theme.textTheme.titleSmall),
                ),
                if (sample) const SampleBadge(),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (sample)
              Text(
                'Materi ini belum divalidasi — hanya contoh pengembangan.',
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              Text(
                'Divalidasi oleh ${validatedBy ?? '-'}'
                '${verifiedAt != null ? ' · ${formatDateId(verifiedAt!)}' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
              if (sourceNote != null && sourceNote!.isNotEmpty)
                Text('Sumber: $sourceNote', style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lencana "Materi contoh".
class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Materi contoh, belum divalidasi',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.science_outlined, size: 14, color: AppColors.warning),
              const SizedBox(width: 4),
              Text(
                'Materi contoh',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
