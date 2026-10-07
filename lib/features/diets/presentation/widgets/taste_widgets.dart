import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/nutrition/dish_taxonomy.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../onboarding/presentation/widgets/quiz_controls.dart';

/// The taste quiz's own controls, in the same sticker-book idiom as the
/// onboarding quiz — cream ground, flat colour, a thick black outline and a
/// hard offset shadow. Selecting presses the thing into the page exactly as
/// [StickerCard] does, so the two quizzes read as one instrument.
///
/// Nothing here is forked from `quiz_controls.dart`; these are the pieces that
/// quiz has no equivalent for — a picture tile, a multi-select chip, and an
/// outline "neither" — and they borrow [QuizPalette] rather than restating it.

/// One dish in the grid, or one side of a this-or-that pair.
///
/// [Dish.asset] is nullable and the tile has to look intentional either way:
/// the photos are being sourced separately, and a placeholder that reads as a
/// missing image says the quiz is unfinished. So without one the picture area
/// is a tint of the step's accent with a sparkle on it — the same mark the
/// onboarding illustrations are scattered with.
class DishTile extends StatelessWidget {
  const DishTile({
    super.key,
    required this.dish,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final Dish dish;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    // The name band reserves two lines whatever the name needs, so a row of
    // tiles keeps one picture height rather than stepping up and down with the
    // length of each dish's name. Scaled with the text, or 1.15x type would
    // overflow the band and stripe the tile.
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final bandHeight = 52 * scale + 16;

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: dish.name,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          // Pressed into the page: the shadow goes and the tile moves by
          // exactly the shadow's offset, so it lands where the shadow was.
          transform: selected
              ? Matrix4.translationValues(
                  QuizPalette.lift.dx,
                  QuizPalette.lift.dy,
                  0,
                )
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: QuizPalette.card,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? accent : QuizPalette.ink,
              width: QuizPalette.stroke,
            ),
            boxShadow: selected ? const [] : QuizPalette.shadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              // The label is on the Semantics node above; the band's own text
              // would otherwise be read out a second time.
              child: ExcludeSemantics(
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Picture(
                            dish: dish,
                            accent: accent,
                            selected: selected,
                          ),
                        ),
                        SizedBox(
                          height: bandHeight,
                          child: _Band(dish: dish),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        scale: selected ? 1 : 0,
                        child: _Check(accent: accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture({
    required this.dish,
    required this.accent,
    required this.selected,
  });

  final Dish dish;
  final Color accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final asset = dish.asset;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      color: accent.withValues(alpha: selected ? 0.32 : 0.18),
      child: Center(child: Sparkle(size: 26, colour: accent)),
    );
  }
}

/// The white band along the bottom: the name, and the cuisine under it.
class _Band extends StatelessWidget {
  const _Band({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
      decoration: const BoxDecoration(
        color: QuizPalette.card,
        // A hairline in the illustrations' own weight, so the band reads as
        // part of the drawing rather than a caption under a photo.
        border: Border(top: BorderSide(color: QuizPalette.ink, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dish.name,
            style: AppTypography.meta(color: QuizPalette.ink)
                .copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            dish.cuisine.label,
            style: AppTypography.divider(color: AppColors.inkMuted)
                .copyWith(fontSize: 11, height: 14 / 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The corner disc that says "picked".
class _Check extends StatelessWidget {
  const _Check({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        border: Border.all(color: QuizPalette.ink, width: 2),
      ),
      child: Icon(
        Icons.check_rounded,
        size: 15,
        color: QuizPalette.onAccent(accent),
      ),
    );
  }
}

/// A 3×3 of [DishTile]s: three rows of three, sized so the whole thing sits
/// between the step's subtitle and the CTA with the shadows showing.
///
/// A `Column` of `Row`s rather than a `GridView`: there is nothing to scroll,
/// and a scroll view clips the last row's shadow and the pressed tile's
/// translation at its own edge.
class DishGrid extends StatelessWidget {
  const DishGrid({
    super.key,
    required this.dishes,
    required this.liked,
    required this.accent,
    required this.onToggle,
  });

  final List<Dish> dishes;
  final List<String> liked;
  final Color accent;
  final ValueChanged<Dish> onToggle;

  static const int columns = 3;
  static const double gap = 12;
  static const double tileHeight = 136;

  /// The grid's own height, so the screen can reserve exactly this much.
  static double heightFor(int count) {
    final rows = (count / columns).ceil();
    return rows * tileHeight + (rows - 1) * gap + QuizPalette.lift.dy;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <List<Dish>>[];
    for (var i = 0; i < dishes.length; i += columns) {
      rows.add(dishes.sublist(i, (i + columns).clamp(0, dishes.length)));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: gap),
          SizedBox(
            height: tileHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: gap),
                  Expanded(
                    child: c < rows[r].length
                        ? DishTile(
                            dish: rows[r][c],
                            accent: accent,
                            selected: liked.contains(rows[r][c].id),
                            onTap: () => onToggle(rows[r][c]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A multi-select chip. Same press-in as the cards, in a pill.
class TasteChip extends StatelessWidget {
  const TasteChip({
    super.key,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = QuizPalette.onAccent(accent);
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: selected
              ? Matrix4.translationValues(
                  QuizPalette.lift.dx,
                  QuizPalette.lift.dy,
                  0,
                )
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: selected ? accent : QuizPalette.card,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: QuizPalette.ink,
              width: QuizPalette.stroke,
            ),
            boxShadow: selected ? const [] : QuizPalette.shadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                child: Text(
                  label,
                  style: AppTypography.socialLabel(
                    color: selected ? on : QuizPalette.ink,
                  ).copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The outline "neither" under a pair: a [StickerButton] with the fill
/// removed, so it is visibly the quieter of the three choices.
///
/// [pressed] is driven by the screen rather than a tap-down, because the
/// answer is recorded on tap and the screen holds the beat before advancing —
/// the button stays pressed for that beat, which is how the tap reads as taken.
class NeitherButton extends StatelessWidget {
  const NeitherButton({
    super.key,
    required this.label,
    required this.pressed,
    required this.onTap,
  });

  final String label;
  final bool pressed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: pressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 58,
        transform: pressed
            ? Matrix4.translationValues(
                QuizPalette.lift.dx,
                QuizPalette.lift.dy,
                0,
              )
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: QuizPalette.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: QuizPalette.ink,
            width: QuizPalette.stroke,
          ),
          boxShadow: pressed ? const [] : QuizPalette.shadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Center(
              child: Text(
                label,
                style: AppTypography.buttonLabel(color: QuizPalette.ink)
                    .copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
