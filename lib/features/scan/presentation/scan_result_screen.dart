import 'dart:async';
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
import 'widgets/item_edit_sheet.dart';
import 'widgets/pinned_cta.dart';

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

  /// Height of the note under the list, reserved whether or not it shows, so
  /// the geometry does not move when the model happens to ask a question.
  static const double _noteHeight = 38;

  /// Room the content must leave beneath itself.
  ///
  /// "Add to My Diet" is pinned to the *viewport*, not to this canvas, so it
  /// covers the bottom `926 - 832` units of every scroll. Without this the
  /// model's clarifying question — the one line that says which number to
  /// distrust — sits underneath the button and cannot be read at any scroll
  /// position. Same shape of bug as the floating tab bar's clearance.
  static const double _ctaClearance = PinnedCta.clearance;

  static double _contentHeight(int itemCount) {
    final listBottom =
        _gridTop + _gridHeight + itemCount * (_gap + _itemHeight);
    final bottom = listBottom + _noteHeight + _ctaClearance;
    return bottom < DesignCanvas.designHeight
        ? DesignCanvas.designHeight
        : bottom;
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

  /// Opens the correction sheet for one item.
  ///
  /// A modal route rather than an overlay inside the `DesignCanvas`: this is a
  /// form, and `showModalBottomSheet` is the one thing that already handles the
  /// keyboard insets, the barrier and focus correctly. The canvas convention
  /// exists so overlays stay in register with artboard coordinates, and this
  /// sheet has none to stay in register with.
  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref,
    FoodItem food,
  ) async {
    final edited = await showItemEditSheet(context, food);
    if (edited == null) return;
    ref.read(scanControllerProvider.notifier).applyEdit(
          itemId: food.id,
          name: edited.name,
          nutrition: edited.nutrition,
          portionGrams: edited.grams,
        );
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
                      onEdit: result != null
                          ? null
                          : () => _editItem(context, ref, food),
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

            // Pinned to the viewport so it stays reachable as the list grows,
            // on a band so the item it lands on fades out behind it rather than
            // being sliced in half.
            PinnedCta(
              child: PrimaryButton(
                label: 'Add to My Diet',
                busy: state.isLoading,
                onPressed: foods.isEmpty ? null : () => _add(ref),
              ),
            ),

            if (state.isLoading) _AnalysingOverlay(path: scan?.photoPath),
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

  /// The artboard's own photograph, used wherever there is nothing better.
  static Widget _standIn() => Image.asset(
        'assets/images/app/scan_food.png',
        width: 428,
        height: 351,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );

  @override
  Widget build(BuildContext context) {
    final source = path;

    // A barcode scan has no photograph of its own — but Open Food Facts has
    // one of the packaging, which is a far better answer than a stock plate of
    // someone else's dinner sitting above a jar of Nutella.
    if (source != null && source.startsWith('http')) {
      return Positioned(
        left: 0,
        top: 0,
        width: 428,
        height: 351,
        // `contain`, not `cover`, and on the app's own ground.
        //
        // This is a packshot — a jar photographed against white — not a scene.
        // Cover would crop the top and bottom off the jar to fill a 428x351
        // letterbox, and Open Food Facts only serves 400px, so it would be an
        // upscaled crop of the thing you wanted to see whole. Contained on a
        // dark ground it reads as a product shot, which is what it is.
        child: ColoredBox(
          color: AppColors.background,
          // Inset below the header. A packshot is usually a label on white,
          // and the back button, the title and the favourite heart are white
          // too — drawn edge to edge, "Scan" vanished into the Nutella label.
          // The photo does not need the full 351 to read.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 118, 24, 10),
            child: Image.network(
              source,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => _standIn(),
              // No spinner: this lands in well under a second on any usable
              // connection, and a flash of progress indicator over the hero is
              // more distracting than a beat of the fallback.
              frameBuilder: (_, child, frame, wasSync) =>
                  frame == null && !wasSync ? _standIn() : child,
            ),
          ),
        ),
      );
    }

    final isAsset = source == null || source.startsWith('assets/');
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

/// Covers the screen while the pipeline works.
///
/// The design carries no analysing frame, and the first version of this was a
/// spinner over "Reading your plate…". A scan takes seven to twelve seconds —
/// a photo has to be prepared, sent, looked at by a reasoning model, and turned
/// into numbers — and a bare spinner over that long says "waiting", which is
/// exactly what makes a wait feel broken.
///
/// So it shows the plate being read: the capture itself, with a band sweeping
/// down it, and the stage that is actually running underneath.
///
/// **There is deliberately no percentage and no progress bar.** Nothing here
/// knows how far along the model is, and a bar that fills on a timer is a lie
/// that gets caught the first time a scan runs long. The stages are real steps
/// in a real order, and the last one simply waits.
class _AnalysingOverlay extends StatefulWidget {
  const _AnalysingOverlay({this.path});

  final String? path;

  @override
  State<_AnalysingOverlay> createState() => _AnalysingOverlayState();
}

class _AnalysingOverlayState extends State<_AnalysingOverlay>
    with SingleTickerProviderStateMixin {
  /// The pipeline's own steps. The last has no successor: it holds until the
  /// result lands, however long that takes.
  static const List<(String, Duration)> _stages = [
    ('Preparing your photo', Duration(milliseconds: 1400)),
    ('Finding the foods', Duration(milliseconds: 2600)),
    ('Estimating portions', Duration(milliseconds: 3000)),
    ('Working out the nutrition', Duration.zero),
  ];

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _advance();
  }

  void _advance() {
    final wait = _stages[_stage].$2;
    if (wait == Duration.zero) return;
    _timer = Timer(wait, () {
      if (!mounted) return;
      setState(() => _stage++);
      _advance();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background.withValues(alpha: 0.94),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 232,
              height: 232,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CapturePreview(path: widget.path),
                    // Dimmed so the sweep reads over any photograph.
                    const ColoredBox(color: Color(0x59121212)),
                    AnimatedBuilder(
                      animation: _sweep,
                      builder: (context, _) => _Sweep(t: _sweep.value),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Crossfaded, so the line changing is not mistaken for the line
            // being replaced by an error.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: Text(
                _stages[_stage].$1,
                key: ValueKey(_stage),
                style: AppTypography.cardHeading(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _stages.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    width: i == _stage ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i <= _stage
                          ? AppColors.accentGreen
                          : AppColors.outline,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The capture, or the design's stand-in, filling whatever box it is given.
class _CapturePreview extends StatelessWidget {
  const _CapturePreview({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || p.startsWith('assets/')) {
      return Image.asset(p ?? 'assets/images/app/scan_food.png',
          fit: BoxFit.cover);
    }
    return Image.file(
      File(p),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          Image.asset('assets/images/app/scan_food.png', fit: BoxFit.cover),
    );
  }
}

/// A band travelling down the capture, brightest at its leading edge.
class _Sweep extends StatelessWidget {
  const _Sweep({required this.t});

  /// 0..1 through one pass.
  final double t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        const band = 78.0;
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              // Starts above the frame and leaves below it, so the band is
              // never seen to appear or vanish mid-photo.
              top: -band + t * (h + band),
              height: band,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x0045C588),
                      Color(0x3345C588),
                      AppColors.accentGreen,
                    ],
                    stops: [0, 0.7, 1],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
      SnackBar(
        content: Text(
          granted == 1 ? '1 scan added.' : '$granted scans added.',
        ),
      ),
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
              // Premium leads; the ad is the alternative, not the headline.
              //
              // These were the other way round, which put "Watch an ad" as the
              // primary action at the exact moment the app had just refused to
              // do the thing the person opened it for. Reviewers of apps that
              // do this describe it as extortion rather than a fair exchange —
              // *"watch an ad to save this food" thats all I should have to
              // say* — and the anger is specifically about an ad standing
              // between them and a core action.
              //
              // Running out of scans is the paywall arriving, so the paywall is
              // the honest first offer. The ad stays because it is a real way
              // out for someone who will not pay, but it reads as a way out
              // rather than a toll.
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
              if (canWatch) ...[
                SizedBox(
                  width: 280,
                  height: 50,
                  child: GhostButton(
                    // Pluralised, because the grant is 1 now — "1 scans" is
                    // the kind of thing people screenshot.
                    label: AdConfig.scansPerRewardedAd == 1
                        ? 'Or watch an ad for 1 scan'
                        : 'Or watch an ad for '
                            '${AdConfig.scansPerRewardedAd} scans',
                    onPressed: busy ? null : () => _watchAd(context, ref),
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
    this.onEdit,
  });

  final FoodItem food;
  final double portion;
  final ValueChanged<double>? onPortion;
  final VoidCallback? onRemove;

  /// Opens the correction sheet.
  ///
  /// The single most-punished failure in this category is a wrong number you
  /// cannot fix — reviewers forgive the estimate and leave one star over the
  /// correction. The ½×–2× row only answers "about twice that"; this answers
  /// "it was 180 g and you cannot see the oil".
  final VoidCallback? onEdit;

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
      onTap: onEdit,
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    food.name,
                    style: AppTypography.body(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // The model flags its own uncertainty per item and the UI threw
                // that away, so a guess and a confident reading looked
                // identical. `prompt.ts` tells it to use "low" freely precisely
                // because a flagged guess is more useful than a confident wrong
                // number — but only if the flag reaches the screen.
                //
                // It points at the portion row directly beneath it, which is
                // the one-tap fix.
                if (food.needsReview) const _CheckThisChip(),
                // A pencil on every card, not only flagged ones — the whole
                // card is tappable, and a tap target with no mark on it is a
                // feature nobody finds. Quiet enough not to compete with the
                // name.
                if (onEdit != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.placeholder,
                  ),
                ],
              ],
            ),
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

/// Marks an item the model was not confident about.
///
/// Deliberately quiet — an outline rather than a fill. It is a nudge to check a
/// number, not a warning that something is wrong, and a plate of five foods can
/// easily carry two of these.
class _CheckThisChip extends StatelessWidget {
  const _CheckThisChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.accentOrange),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 12, color: AppColors.accentOrange),
          const SizedBox(width: 4),
          Text('Check this',
              style: AppTypography.divider(color: AppColors.accentOrange)),
        ],
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
