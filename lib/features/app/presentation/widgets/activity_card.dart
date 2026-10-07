import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'activity_sheet.dart';

/// Activity, on Home.
///
/// The other half of the sentence onboarding has always made — "calories,
/// macros, water and activity" — with nothing behind it.
///
/// **The energy spent is shown and is deliberately not added back to the
/// day's calorie budget.** Consumer estimates of exercise energy are widely
/// off, and an app that hands back 500 kcal for a run it guessed at is
/// inventing a number and then inviting someone to eat it — the same class of
/// mistake as the pre-favourited plans. The figure is here because it is worth
/// seeing; the ring stays what `TargetCalculator` computed, and the deficit
/// stays real.
class ActivityCard extends ConsumerWidget {
  const ActivityCard({super.key, required this.top, this.preview});

  final double top;

  /// Pins the log, for tests and previews. Null reads the real one.
  final ActivityLog? preview;

  static const double width = 388;

  /// Padding, heading, the gaps and the button — everything but the rows.
  static const double _chrome = 120;
  static const double _rowHeight = 36;

  /// Booked scroll room on Home, which grows with the day's bouts.
  ///
  /// A function rather than a constant, like `_mealsHeight`: the card sizes
  /// to its own content, and a fixed reserve would put the next block over it
  /// the moment someone logged a second walk. The trailing slack is what the
  /// rows need at the 1.15x text ceiling.
  static double reserveFor(int entries) =>
      _chrome + (entries == 0 ? 20 : entries * _rowHeight) + 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActivityLog log = preview ?? ref.watch(activityLogProvider);
    // An empty day and a refused read look identical through
    // `.value ?? const []`, and saying "Nothing logged today" after someone
    // just pressed Save is the worst of the two readings — it tells them the
    // save failed silently when the truth is that the *read* did.
    final failed = preview == null && ref.watch(activityFailedProvider);

    return Positioned(
      left: 20,
      top: top,
      width: width,
      child: Container(
        // 19, not 20: Flutter draws a Border outside the padding box and
        // Figma strokes inside.
        padding: const EdgeInsets.fromLTRB(19, 16, 19, 16),
        decoration: BoxDecoration(
          color: AppColors.inkMuted,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text('Activity', style: AppTypography.cardHeading()),
                ),
                if (!log.isEmpty)
                  Text(
                    '${log.minutes} min · ${log.kcal.round()} kcal',
                    style: AppTypography.meta(color: AppColors.placeholder),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (failed)
              Text(
                "Today's activity could not be loaded.",
                style: AppTypography.meta(color: AppColors.error),
              )
            else if (log.isEmpty)
              Text(
                'Nothing logged today.',
                style: AppTypography.meta(color: AppColors.placeholder),
              )
            else
              for (final entry in log.entries)
                _ActivityRow(entry: entry, interactive: preview == null),
            const SizedBox(height: 12),
            _AddButton(
              onTap: preview == null ? () => showActivitySheet(context) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.interactive});

  final ActivityEntry entry;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: interactive,
      label:
          '${entry.name}, ${entry.minutes} minutes, '
          '${entry.kcal.round()} kilocalories',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive
            ? () => showActivitySheet(context, existing: entry)
            : null,
        // minHeight, not height: 36 has no slack at the 1.15x text ceiling.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Row(
            children: [
              Expanded(child: Text(entry.name, style: AppTypography.body())),
              Text(
                '${entry.minutes} min',
                style: AppTypography.meta(color: AppColors.placeholder),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 68,
                child: Text(
                  '${entry.kcal.round()} kcal',
                  textAlign: TextAlign.end,
                  style: AppTypography.meta(color: AppColors.accentBlue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Log activity',
      excludeSemantics: true,
      child: Material(
        color: AppColors.outline,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            width: double.infinity,
            child: Center(
              child: Text('Log activity', style: AppTypography.meta()),
            ),
          ),
        ),
      ),
    );
  }
}
