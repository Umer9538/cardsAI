import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/ad_config.dart';
import '../../../core/ads/ads_providers.dart';
import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import 'scan_controller.dart';

/// One macro tile in the 2x2 grid.
class MacroStat {
  const MacroStat({
    required this.label,
    required this.colour,
    this.value,
    this.percent,
  });

  final String label;
  final Color colour;

  /// Shown instead of a progress bar — the Calories tile uses this.
  final String? value;

  /// 0..1. Renders the bar plus its "n%" / "100%" captions.
  final double? percent;
}

/// Scan result — Figma frame `32_Scan Result` (2002:1017).
///
/// A 351pt photo with the sheet overlapping its lower third, a 2x2 macro grid,
/// then one card per recognised item. The item list is what makes this screen
/// grow, so the canvas is sized from the content and scrolls.
///
/// The percentages on the three macro tiles are this meal measured against the
/// day's goal, not against the meal itself — a meal is never 100% of its own
/// protein. The artboard's numbers (83 / 50 / 63) are mock values.
class ScanResultScreen extends ConsumerWidget {
  const ScanResultScreen({
    super.key,
    this.result,
    this.onBack,
    this.onFavourite,
    this.onAdd,
    this.onUpgrade,
  });

  /// Overrides the in-flight scan, for tests and previews. Null means "read the
  /// controller".
  final ScanResult? result;

  final VoidCallback? onBack;
  final VoidCallback? onFavourite;
  final VoidCallback? onAdd;

  /// Opens the paywall. Offered alongside the rewarded ad when the scan
  /// allowance runs out.
  final VoidCallback? onUpgrade;

  static const double _gridTop = 340;
  static const double _gridHeight = 212;
  /// The artboard's 86, plus the portion row the design does not have.
  ///
  /// An AI estimate that cannot be corrected is worse than useless — it
  /// silently poisons the day's total — and the PRD makes portion adjustment
  /// part of the core loop. The row is always drawn, even in a preview with no
  /// controller behind it, so the card has one height everywhere and the list
  /// geometry cannot drift out of step with it.
  static const double _itemHeight = 132;
  static const double _gap = 20;

  static double _contentHeight(int itemCount) {
    final listBottom =
        _gridTop + _gridHeight + itemCount * (_gap + _itemHeight) + 56;
    return listBottom < DesignCanvas.designHeight
        ? DesignCanvas.designHeight
        : listBottom;
  }

  /// Calories as an absolute figure; the three macros as a share of the day.
  static List<MacroStat> _macros(Nutrition meal, Nutrition targets) {
    double share(double part, double whole) => whole <= 0 ? 0 : part / whole;
    return [
      MacroStat(
        label: 'Calories',
        colour: AppColors.lilac,
        value: NutritionFormat.calories(meal.calories),
      ),
      MacroStat(
        label: 'Protein',
        colour: AppColors.accentGreen,
        percent: share(meal.protein, targets.protein),
      ),
      MacroStat(
        label: 'Carbs',
        colour: AppColors.planYellow,
        percent: share(meal.carbs, targets.carbs),
      ),
      MacroStat(
        label: 'Fat',
        colour: AppColors.accentOrange,
        percent: share(meal.fat, targets.fat),
      ),
    ];
  }

  Future<void> _add(WidgetRef ref) async {
    // An overridden result is a preview, not a live scan — nothing to log.
    if (result == null) {
      await ref.read(scanControllerProvider.notifier).logMeal();
    }
    onAdd?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final scan = result ?? state.value;
    final foods = scan?.items ?? const <FoodItem>[];
    final targets = ref.watch(targetsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            DesignCanvas(
              background: AppColors.background,
              height: _contentHeight(foods.length),
              children: [
                _CaptureImage(path: scan?.photoPath),
                // Sheet, overlapping the photo's lower third.
                Positioned(
                  left: 0,
                  top: 320,
                  width: 428,
                  height: _contentHeight(foods.length) - 320,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 20,
                  top: 71,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: onBack,
                    behavior: HitTestBehavior.opaque,
                    child: Image.asset(
                      'assets/images/auth/back_button.png',
                      width: 40,
                      height: 40,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                Positioned(
                  left: 117,
                  top: 73,
                  width: 200,
                  height: 36,
                  child: Text('Scan', style: AppTypography.topBarTitle()),
                ),
                Positioned(
                  left: 368,
                  top: 71,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: onFavourite,
                    behavior: HitTestBehavior.opaque,
                    child: Image.asset(
                      'assets/images/app/fav_button.png',
                      width: 40,
                      height: 40,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),

                // 2x2 macro grid: 184pt columns 20pt apart, 100pt rows 12 apart.
                for (final (i, macro)
                    in _macros(scan?.nutrition ?? Nutrition.zero, targets)
                        .indexed)
                  Positioned(
                    left: 20 + (i.isOdd ? 204 : 0),
                    top: _gridTop + (i >= 2 ? 112 : 0),
                    width: 184,
                    height: 100,
                    child: MacroTile(stat: macro),
                  ),

                for (final (i, food) in foods.indexed)
                  Positioned(
                    left: 20,
                    top: _gridTop + _gridHeight + _gap + i * (_itemHeight + _gap),
                    width: 388,
                    child: _FoodItemCard(
                      food: food,
                      // A preview has no controller behind it, so its controls
                      // render but do nothing.
                      portion: result != null
                          ? 1
                          : ref
                              .read(scanControllerProvider.notifier)
                              .portionOf(food.id),
                      onPortion: result != null
                          ? null
                          : (factor) => ref
                              .read(scanControllerProvider.notifier)
                              .adjustPortion(food.id, factor),
                      onRemove: result != null
                          ? null
                          : () => ref
                              .read(scanControllerProvider.notifier)
                              .removeItem(food.id),
                    ),
                  ),

                // The design has no low-confidence treatment, so this sits
                // under the list rather than on the items themselves.
                //
                // The model's own question, when it asked one, is more useful
                // than the generic caveat — it names the thing that would
                // actually change the numbers.
                if (scan != null && scan.confidence != FoodConfidence.high)
                  Positioned(
                    left: 20,
                    top: _gridTop +
                        _gridHeight +
                        _gap +
                        foods.length * (_itemHeight + _gap) -
                        4,
                    width: 388,
                    height: 38,
                    child: Text(
                      scan.clarifyingQuestion ??
                          'AI estimate — adjust portions when you know better.',
                      style: AppTypography.meta(color: AppColors.placeholder),
                    ),
                  ),
              ],
            ),

            // Pinned to the viewport so it stays reachable as the list grows.
            Positioned(
              left: 0,
              right: 0,
              bottom: 926 - 832 - 50,
              child: Center(
                child: SizedBox(
                  width: 388,
                  height: 50,
                  child: PrimaryButton(
                    label: 'Add to My Diet',
                    busy: state.isLoading,
                    onPressed: foods.isEmpty ? null : () => _add(ref),
                  ),
                ),
              ),
            ),

            if (state.isLoading) const _AnalysingOverlay(),
            if (state.hasError)
              _ErrorOverlay(
                message: ref.read(scanControllerProvider.notifier).errorMessage!,
                outOfScans:
                    ref.read(scanControllerProvider.notifier).outOfScans,
                onDismiss: onBack,
                onUpgrade: onUpgrade,
              ),
          ],
        ),
      ),
    );
  }
}

/// The captured photo, or the artboard's stand-in before a real camera exists.
///
/// A scan carries a file path from the device; the design's own photograph is
/// what shows in tests and previews, where there is no capture.
class _CaptureImage extends StatelessWidget {
  const _CaptureImage({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final isAsset = path == null || path!.startsWith('assets/');
    return Positioned(
      left: 0,
      top: 0,
      width: 428,
      height: 351,
      child: isAsset
          ? Image.asset(
              path ?? 'assets/images/app/scan_food.png',
              width: 428,
              height: 351,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            )
          : Image.file(
              File(path!),
              width: 428,
              height: 351,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              // A capture can be deleted from under us; the design's photo is a
              // better fallback than a broken-image glyph.
              errorBuilder: (_, _, _) => Image.asset(
                'assets/images/app/scan_food.png',
                width: 428,
                height: 351,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}

/// Covers the screen while the pipeline works. The design carries no analysing
/// frame, so this is the minimum that reads as "working, not broken".
class _AnalysingOverlay extends StatelessWidget {
  const _AnalysingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.86),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.accentGreen),
              ),
            ),
            const SizedBox(height: 20),
            Text('Reading your plate…', style: AppTypography.cardHeading()),
          ],
        ),
      ),
    );
  }
}

/// The failure state, and the way out of it.
///
/// Running out of scans is not really an error — it is the paywall arriving —
/// so it gets its own two options rather than a dead end with a Back button.
class _ErrorOverlay extends ConsumerWidget {
  const _ErrorOverlay({
    required this.message,
    this.outOfScans = false,
    this.onDismiss,
    this.onUpgrade,
  });

  final String message;
  final bool outOfScans;
  final VoidCallback? onDismiss;
  final VoidCallback? onUpgrade;

  Future<void> _watchAd(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(rewardControllerProvider.notifier);
    final granted = await controller.watchForScans();

    if (granted == null) {
      final problem = controller.errorMessage;
      if (problem != null) {
        messenger.showSnackBar(SnackBar(content: Text(problem)));
      }
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('$granted scans added.')),
    );
    // Straight back into the scan they were trying to do, rather than making
    // them photograph the plate again.
    await ref.read(scanControllerProvider.notifier).retryLast();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canWatch =
        outOfScans && ref.watch(adsServiceProvider).rewardedReady;
    final busy = ref.watch(rewardControllerProvider).isLoading;

    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: AppTypography.body(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              if (canWatch) ...[
                SizedBox(
                  width: 280,
                  height: 50,
                  child: PrimaryButton(
                    label:
                        'Watch an ad for ${AdConfig.scansPerRewardedAd} scans',
                    busy: busy,
                    onPressed: () => _watchAd(context, ref),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (outOfScans && onUpgrade != null) ...[
                SizedBox(
                  width: 280,
                  height: 50,
                  child: PrimaryButton(
                    label: 'Go Premium',
                    onPressed: onUpgrade,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: 200,
                height: 50,
                child: GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      'Back',
                      style: AppTypography.body(color: AppColors.placeholder),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared with the diet-detail screen, which uses the same 2x2 grid.
class MacroTile extends StatelessWidget {
  const MacroTile({super.key, required this.stat});

  final MacroStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: stat.colour,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 30,
            child: Text(
              stat.label,
              style: AppTypography.sectionTitle(color: AppColors.ink),
            ),
          ),
          if (stat.value != null) ...[
            const SizedBox(height: 11),
            Text(
              stat.value!,
              style: AppTypography.cardHeading(color: AppColors.ink),
            ),
          ] else ...[
            const SizedBox(height: 12),
            _ProgressBar(percent: stat.percent ?? 0),
          ],
        ],
      ),
    );
  }
}

/// 152x6 track at 10% ink with a filled portion, and the two captions beneath.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 6,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              // heightFactor is required: as a non-positioned Stack child this
              // gets loose vertical constraints, and without it the fill
              // collapses to zero height and the bar reads as empty.
              FractionallySizedBox(
                widthFactor: percent.clamp(0, 1),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${(percent * 100).round()}%',
                style: AppTypography.meta(color: AppColors.ink)),
            Text('100%', style: AppTypography.meta(color: AppColors.ink)),
          ],
        ),
      ],
    );
  }
}

/// One recognised item — Figma `Food Item`: 388x86, radius 16, #232220 on a
/// 1pt #2F2F2F outline, extended with a portion row.
class _FoodItemCard extends StatelessWidget {
  const _FoodItemCard({
    required this.food,
    this.portion = 1,
    this.onPortion,
    this.onRemove,
  });

  final FoodItem food;
  final double portion;
  final ValueChanged<double>? onPortion;
  final VoidCallback? onRemove;

  /// The PRD's steps. Coarse on purpose — someone correcting a plate of rice is
  /// choosing between "about half that" and "about twice that", not typing
  /// grams.
  static const List<(double, String)> _steps = [
    (0.5, '½×'),
    (0.75, '¾×'),
    (1, '1×'),
    (1.5, '1½×'),
    (2, '2×'),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // The artboard gives the card no remove affordance, so a long press
      // carries it rather than adding a control the design does not have.
      onLongPress: onRemove,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        decoration: BoxDecoration(
          color: AppColors.inkMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        // Insets drop by the 1pt border, which Flutter adds outside the padding
        // box while Figma strokes inside.
        padding: const EdgeInsets.fromLTRB(11, 13, 11, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(food.name, style: AppTypography.body()),
            const SizedBox(height: 14),
            SizedBox(
              height: 19,
              child: Row(
                children: [
                  for (final (i, part)
                      in NutritionFormat.macroRow(food.nutrition).indexed) ...[
                    if (i > 0) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 1,
                        height: 16,
                        child: ColoredBox(color: AppColors.muted),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(part, style: AppTypography.meta()),
                  ],
                ],
              ),
            ),
            ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 30,
                child: Row(
                  children: [
                    for (final (i, (factor, label)) in _steps.indexed) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _PortionChip(
                          label: label,
                          selected: (portion - factor).abs() < 0.01,
                          onTap: onPortion == null
                              ? null
                              : () => onPortion!(factor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One step of the portion control, in the segmented control's own language:
/// the selected step is filled #FF5A16 with white copy, the rest outlined.
class _PortionChip extends StatelessWidget {
  const _PortionChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.muted,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.meta(
            color: selected ? AppColors.white : AppColors.placeholder,
          ),
        ),
      ),
    );
  }
}
