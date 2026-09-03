import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// The full-width intro card that heads Analysis, Diets and Premium Plans.
///
/// The same 388 x 128 rounded card with a heading and a line of body copy was
/// written out three times, and all three carried the same defect: a fixed 12pt
/// gap and a body line at its natural height filled the card *exactly* at the
/// artboard's own text size. Any OS text scale above 1.0 — or a sentence longer
/// than the one the design happened to be drawn with — put the column over its
/// own box.
///
/// Here the body takes whatever the heading leaves, and ellipsises rather than
/// overflowing. The card is the fixed thing; the copy inside it is not.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.title,
    required this.body,
    required this.colour,
    required this.ink,
  });

  final String title;
  final String body;
  final Color colour;

  /// Text colour. The three cards sit on different fills, and the design puts
  /// dark ink on the light ones and white on the dark.
  final Color ink;

  /// The artboard's box, at (20, 143) on each of the three screens.
  static const double width = 388;
  static const double height = 128;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.sectionTitle(color: ink),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              body,
              style: AppTypography.body(color: ink),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
