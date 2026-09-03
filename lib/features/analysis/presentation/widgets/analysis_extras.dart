import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../analysis_controller.dart';

/// How often the diary actually holds a full day.
///
/// The one number on this screen that governs every other one. Every average
/// above it is computed over logged days only, which is the honest way to
/// average — but it means a window with three logged days out of seven produces
/// confident-looking figures from very little. This says how much of the window
/// is really there.
///
/// The definition is deliberate: **days with at least two eating occasions**.
/// Turner-McGrievy's pooled RCTs found that exact measure the best adherence
/// predictor of six-month weight loss, beating every alternative tested. It is
/// the app's north star, and it was computed nowhere.
class ConsistencyCard extends StatelessWidget {
  const ConsistencyCard({super.key, required this.summary});

  final AnalysisSummary summary;

  static const double width = 388;

  /// An upper bound, used only to reserve scroll room on the canvas — the card
  /// itself sizes to its content. Fixed heights are how the two cards above it
  /// each ended up over their own box; the canvas scrolls, so over-reserving
  /// costs nothing and under-reserving costs a broken layout.
  static const double reserve = 200;

  @override
  Widget build(BuildContext context) {
    final days = summary.daysLoggedTwice;
    final window = summary.windowDays;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      padding: const EdgeInsets.fromLTRB(23, 19, 23, 19),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Days With a Full Picture', style: AppTypography.cardHeading()),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$days',
                style: AppTypography.headline().copyWith(fontSize: 40),
              ),
              const SizedBox(width: 6),
              Text(
                'of $window',
                style: AppTypography.body(color: AppColors.placeholder),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // A plain bar rather than a ring: this is a proportion of a known
          // whole, and the whole is small enough to read as segments.
          SizedBox(
            height: 8,
            child: Row(
              // stretch, not the default centre.
              //
              // A Row centres its children, which hands them *loose* vertical
              // constraints — and a DecoratedBox with no child takes the
              // smallest height it is allowed, which is zero. The segments drew
              // nothing and the card just had a gap in it. Same shape as the
              // FractionallySizedBox-in-a-Stack bug this codebase has shipped
              // twice; the test asserts the rendered height so it cannot come
              // back a fourth time.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < window; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: i < days
                            ? AppColors.accentGreen
                            : AppColors.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            summary.consistencyInsight,
            style: AppTypography.meta(color: AppColors.placeholder),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Where the day's energy goes, and how it got into the diary.
///
/// Two questions the app held the answer to and never asked. The meal split is
/// the one people act on — "my dinner is half my day" is a decision, where a
/// weekly average is not. The method mix is the product's own test: text
/// logging is meant to be the habit this app is built around, so if it is a
/// small share of entries then the describe path is not landing, whatever its
/// merits.
class HabitsCard extends StatelessWidget {
  const HabitsCard({super.key, required this.summary});

  final AnalysisSummary summary;

  static const double width = 388;

  /// See [ConsistencyCard.reserve].
  static const double reserve = 300;

  static String _sourceLabel(FoodSource source) => switch (source) {
        FoodSource.ai => 'Photo',
        FoodSource.barcode => 'Barcode',
        FoodSource.database => 'Search',
        FoodSource.manual => 'Described',
      };

  static Color _slotColour(MealSlot slot) => switch (slot) {
        MealSlot.breakfast => AppColors.planYellow,
        MealSlot.lunch => AppColors.accentGreen,
        MealSlot.dinner => AppColors.lilac,
        MealSlot.snack => AppColors.accentOrange,
      };

  @override
  Widget build(BuildContext context) {
    final slots = summary.slotBreakdown;
    final methods = summary.methodBreakdown;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      padding: const EdgeInsets.fromLTRB(23, 19, 23, 19),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where It Comes From', style: AppTypography.cardHeading()),
          const SizedBox(height: 14),
          if (slots.isEmpty)
            Text(
              'Nothing logged in this window yet.',
              style: AppTypography.meta(color: AppColors.placeholder),
            )
          else ...[
            SizedBox(
              height: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  // See the note on the consistency bar above.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final row in slots)
                      Expanded(
                        // Rounded to a whole percent so the flex weights are
                        // integers; a zero-width segment would still take its
                        // divider and look like a rendering fault.
                        flex: (row.share * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: _slotColour(row.slot)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final row in slots)
                  _Key(
                    colour: _slotColour(row.slot),
                    text: '${row.slot.label} '
                        '${(row.share * 100).round()}%',
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text('How you logged it', style: AppTypography.label()),
          const SizedBox(height: 8),
          if (methods.isEmpty)
            Text(
              '—',
              style: AppTypography.meta(color: AppColors.placeholder),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final row in methods)
                  Text(
                    '${_sourceLabel(row.source)} '
                    '${(row.share * 100).round()}%',
                    style: AppTypography.meta(color: AppColors.placeholder),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.colour, required this.text});

  final Color colour;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: AppTypography.meta(color: AppColors.placeholder)),
      ],
    );
  }
}
