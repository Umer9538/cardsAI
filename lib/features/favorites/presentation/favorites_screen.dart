import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../diets/presentation/diets_screen.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';

/// Favorites — Figma frames `40_Favorite-empty` (2002:853) and
/// `41_Favorite-empty` (2002:845).
///
/// Both artboards carry the name "Favorite-empty"; only frame 40 is actually
/// the empty state — 41 holds three saved plans. Treated here as the two
/// states of one screen.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key, this.plans, this.onBack});

  /// Overrides the repository, for tests that need a fixed list. Null means
  /// "read the real one".
  final List<DietPlan>? plans;

  final VoidCallback? onBack;

  static const double _cardHeight = 282;
  static const double _cardGap = 20;

  double _contentHeight(List<DietPlan> plans) {
    if (plans.isEmpty) return DesignCanvas.designHeight;
    final bottom =
        147 + plans.length * _cardHeight + (plans.length - 1) * _cardGap + 40;
    return bottom < DesignCanvas.designHeight
        ? DesignCanvas.designHeight
        : bottom;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        plans ?? ref.watch(favoriteDietsProvider).value ?? const <DietPlan>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DesignCanvas(
        background: AppColors.background,
        height: _contentHeight(saved),
        children: [
          PremiumTopBar(title: 'Favorite', onBack: onBack),
          if (saved.isEmpty) ...[
            const DesignImage(
              asset: 'assets/images/app/illus_no_notifications.png',
              left: 87,
              top: 289,
              width: 254,
              height: 216,
            ),
            Positioned(
              left: 87,
              top: 545,
              width: 254,
              height: 36,
              child: Text('No Favorites Yet.',
                  style: AppTypography.cardTitle(),
                  textAlign: TextAlign.center),
            ),
            Positioned(
              left: 87,
              top: 593,
              width: 254,
              height: 44,
              child: Text(
                'Quick access to your most-loved items makes logging even '
                'faster.',
                style: AppTypography.socialLabel(),
                textAlign: TextAlign.center,
              ),
            ),
          ] else
            for (final (i, plan) in saved.indexed)
              Positioned(
                left: 20,
                top: 147 + i * (_cardHeight + _cardGap),
                width: 388,
                child: DietCard(
                  plan: plan,
                  showFavourite: true,
                  // Un-hearting here removes the card from this very list.
                  onFavourite: () => ref
                      .read(dietRepositoryProvider)
                      .setFavorite(plan.id, favorite: false),
                ),
              ),
        ],
      ),
    );
  }
}
