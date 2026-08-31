import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// One logged meal in the day's list.
///
/// Not in the Figma file — the design has no diary list anywhere, which left
/// the app able to log a meal and never show it again. Built from the pieces
/// the design does define: the scan result's `Food Item` card (388x86, radius
/// 16, #232220 on a 1pt #2F2F2F outline) with the meal's own photo in place of
/// the leading space.
class MealCard extends StatelessWidget {
  const MealCard({
    super.key,
    required this.meal,
    this.onTap,
    this.onDelete,
  });

  final Meal meal;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  static const double height = 86;
  static const double _thumb = 60;

  static final DateFormat _time = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // The design gives a card no delete affordance, and inventing a visible
      // one would put a control on every row that the rest of the app does not
      // have. Long press is the platform convention for exactly this.
      onLongPress: onDelete,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.inkMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        // Insets drop by the 1pt border, which Flutter adds outside the padding
        // box while Figma strokes inside.
        padding: const EdgeInsets.fromLTRB(11, 11, 15, 11),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: _thumb,
                child: _Thumbnail(meal: meal),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    meal.name,
                    style: AppTypography.body(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${meal.slot.label} · ${_time.format(meal.eatenAt)}',
                    style: AppTypography.meta(color: AppColors.placeholder),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              NutritionFormat.calories(meal.nutrition.calories),
              style: AppTypography.cardHeading(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The meal's photo: a local capture, an uploaded URL, or — when the meal was
/// typed rather than photographed — a tinted initial.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final path = meal.photoPath;

    if (path == null || path.isEmpty) return _Placeholder(meal: meal);

    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _Placeholder(meal: meal),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover, filterQuality: FilterQuality.high);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      // A capture in the OS temp directory can be swept up at any time; the
      // meal outlives its photo.
      errorBuilder: (_, _, _) => _Placeholder(meal: meal),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.meal});

  final Meal meal;

  /// One of the palette's accents, chosen from the name so the same meal keeps
  /// the same colour without storing one.
  static const List<Color> _tints = [
    AppColors.lilac,
    AppColors.accentGreen,
    AppColors.planYellow,
    AppColors.accentOrange,
  ];

  @override
  Widget build(BuildContext context) {
    final name = meal.name.trim();
    final tint = _tints[name.hashCode.abs() % _tints.length];

    return ColoredBox(
      color: tint,
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: AppTypography.cardTitle(color: AppColors.ink),
        ),
      ),
    );
  }
}
