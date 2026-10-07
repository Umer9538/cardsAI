import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Water, on Home.
///
/// Onboarding page 2 has promised "log calories, macros, water" since the
/// first build while nothing in the app could record a glass. This is the
/// feature that makes the sentence true — and it is what lets the water
/// reminder point at something.
///
/// Logging is **one tap**, because the whole feature lives or dies on that.
/// Anything that takes a sheet and a keyboard to record a glass of water will
/// not be used twice; the quick-add row covers the three containers people
/// actually drink from and a long press undoes a mistap.
class WaterCard extends ConsumerWidget {
  const WaterCard({super.key, required this.top, this.preview});

  final double top;

  /// Pins the log, for tests and previews. Null reads the real one.
  final WaterLog? preview;

  static const double width = 388;

  /// Booked scroll room on Home. The card sizes to its own content — this is
  /// only what the layout reserves, like the Analysis cards.
  ///
  /// 140: the card measures 135 at 1.0x and 139 at the 1.15x text ceiling, so
  /// this is the ceiling plus a point. It was 152, which is safe but shows as
  /// 13pt of dead space above the card below it — and Home's gaps are 14, so
  /// that nearly doubled one of them. `home_cards_test` asserts the rendered
  /// height against this, which is the only thing that catches it going the
  /// other way: two `Positioned` children overlapping throws nothing.
  static const double reserve = 140;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WaterLog log = preview ?? ref.watch(waterLogProvider);
    final units = ref.watch(unitSystemProvider);
    // Replaces the readout rather than adding a row: `reserve` is asserted
    // against the rendered height at the 1.15x text ceiling, so an extra line
    // here is an overlap on Home. Without it a refused read looks exactly like
    // a day nobody drank on, and every quick-add appears to do nothing.
    final failed = preview == null && ref.watch(waterFailedProvider);

    return Positioned(
      left: 20,
      top: top,
      width: width,
      child: Container(
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
                  child: Text('Water', style: AppTypography.cardHeading()),
                ),
                if (failed)
                  Text(
                    'Could not load',
                    style: AppTypography.meta(color: AppColors.error),
                  )
                else
                  Text(
                    '${units.formatVolume(log.totalMl)} / '
                    '${units.volumeWithUnit(log.targetMl)}',
                    style: AppTypography.meta(color: AppColors.placeholder),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _WaterBar(progress: log.progress),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (i, ml) in WaterTargets.quickAddMl.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAdd(
                      label: '+${units.formatVolume(ml)}',
                      onTap: preview != null
                          ? null
                          : () => ref.read(waterRepositoryProvider).log(ml),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                _Undo(
                  enabled: !log.isEmpty && preview == null,
                  onTap: () => ref
                      .read(waterRepositoryProvider)
                      .removeLast(ref.read(selectedDateProvider)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The fill, as a bar rather than a ring.
///
/// Home already leads with a calorie ring and a second one beside it would
/// compete with the number the screen is actually about. A bar also reads
/// correctly at a glance for something that only goes up during the day.
class _WaterBar extends StatelessWidget {
  const _WaterBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      // stretch, not the default: a ColoredBox with no child inside a Row or
      // a non-positioned Stack child gets loose constraints and collapses to
      // zero height. This codebase has shipped that three times.
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            // Required. Without it this takes the smallest height allowed,
            // which is zero, and the fill never draws.
            heightFactor: 1,
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accentBlue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add $label of water',
      excludeSemantics: true,
      child: Material(
        color: AppColors.outline,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Center(child: Text(label, style: AppTypography.meta())),
          ),
        ),
      ),
    );
  }
}

class _Undo extends StatelessWidget {
  const _Undo({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Undo last drink',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: enabled
                ? AppColors.outline
                : AppColors.outline.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 44,
            height: 40,
            child: Icon(
              Icons.undo,
              size: 18,
              color: enabled
                  ? AppColors.white
                  : AppColors.white.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
