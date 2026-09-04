import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The heart, drawn rather than exported.
///
/// `assets/images/app/fav_button.png` is a Figma export of a disc sitting on
/// the artboard's own photograph, and the photograph came with it: the corners
/// outside the disc are not transparent, they are a blurred crop of someone
/// else's dinner. On the Scan result screen, where the button sits on the app's
/// flat ground rather than on that photo, it drew as a dark square with an
/// orange smudge in one corner.
///
/// Drawing it also fixes two things the raster could not: it carries a
/// `Semantics` label — a bare glyph with no text near it does not exist to a
/// screen reader — and it can actually show whether the thing is saved.
class FavouriteButton extends StatelessWidget {
  const FavouriteButton({
    super.key,
    required this.saved,
    this.onTap,
    this.size = 40,
    this.outlined = true,
  });

  /// Filled heart when true.
  final bool saved;

  final VoidCallback? onTap;

  /// Diameter of the disc. 40 in a header, 24 on a card.
  final double size;

  /// Whether to draw the disc and its outline. False on a photo card, where
  /// the glyph alone is the affordance the artboard draws.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(
      saved ? Icons.favorite : Icons.favorite_border,
      size: size * 0.5,
      color: AppColors.white,
    );

    return Semantics(
      button: true,
      label: saved ? 'Saved to favourites' : 'Save to favourites',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: size,
          child: outlined
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.inkMuted,
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Center(child: glyph),
                )
              : Center(
                  child: Icon(
                    saved ? Icons.favorite : Icons.favorite_border,
                    size: size,
                    color: AppColors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
