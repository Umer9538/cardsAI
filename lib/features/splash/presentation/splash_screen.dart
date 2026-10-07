import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Splash screen — a 1:1 build of Figma frame `01_Splash Screen` (id 2002:2323).
///
/// The whole screen is laid out on the design's own 428 x 926 canvas using raw
/// Figma coordinates, then scaled to the device by a single [FittedBox]. That
/// keeps every number in this file directly comparable to the Figma inspector:
/// if a value here disagrees with the design, it is a bug in this file.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.onFinished,
    this.duration = const Duration(milliseconds: 1800),
  });

  /// Invoked once the splash has been shown for [duration].
  /// Left null until the onboarding flow (frames 02–04) exists.
  final VoidCallback? onFinished;

  /// 1800, not 2500.
  ///
  /// The entrance finishes at 1500ms, so the old figure held a *finished*
  /// picture for a further second — and this hold runs in series with whatever
  /// comes next, because `_Stage.ready` then shows this same widget again while
  /// the stored session is read back and once more while the profile loads. A
  /// second of dead screen at the front of a three-part wait is the whole
  /// difference between "it opened" and "it is stuck". 300ms is enough to see
  /// the composition land; past that nothing is happening.
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// The whole entrance, as one 0→1 value. Each element takes a slice of it,
  /// so the stagger is a property of the timeline rather than a pile of
  /// delayed futures that have to be cancelled.
  ///
  /// Forward only, and it stays at 1. It must not be the thing that repeats:
  /// this widget is also the app's *loading* screen, and replaying the
  /// entrance under a wait would deal the cards out and back in forever.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  /// A separate, slower clock for the one element that keeps moving.
  ///
  /// The app shows this same widget with no `onFinished` while the stored
  /// session is read back, and that wait has no known length — a completely
  /// still screen then reads as a hang. One sparkle breathing is enough to
  /// say "working" without turning the splash into a progress bar it has no
  /// information to fill.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void initState() {
    super.initState();
    final onFinished = widget.onFinished;
    if (onFinished != null) {
      Future<void>.delayed(widget.duration, () {
        if (mounted) onFinished();
      });
    }
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _idle.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AnimatedBuilder(
          animation: Listenable.merge([_intro, _idle]),
          builder: (context, _) {
            // Reduced motion gets the finished frame, not a frozen first one.
            final still = MediaQuery.disableAnimationsOf(context);
            return _SplashCanvas(
              t: still ? 1 : _intro.value,
              breath: still ? 0 : Curves.easeInOut.transform(_idle.value),
            );
          },
        ),
      ),
    );
  }
}

class _SplashCanvas extends StatelessWidget {
  const _SplashCanvas({required this.t, required this.breath});

  /// The entrance, 0 → 1.
  final double t;

  /// A 0 → 1 → 0 sway, used only while this screen is standing in for a wait.
  final double breath;

  /// The collage, in paint order, each with the point on the timeline where it
  /// starts. They are **dealt**, bottom-most first, rather than fading in
  /// together: the artboard is a scatter of cards, and a scatter that arrives
  /// all at once reads as one flat image appearing, which is what this screen
  /// did before. Dealt, it reads as the app laying your day out.
  static const List<(String, double, double, double, double, double)> _cards = [
    ('card_healthy.png', 189, 720, 120.67, 120.67, 0.30),
    ('card_pink.png', 193, 828, 145.33, 98, 0.36),
    ('card_purple.png', 275, 718, 153, 208, 0.42),
    ('card_orange.png', 60.89, 741, 157.33, 185, 0.48),
    ('card_blue.png', 8, 641, 126.33, 124, 0.54),
    ('pill_today.png', 29, 810, 52, 102, 0.60),
    ('card_yellow.png', 265, 590, 162, 164.67, 0.66),
  ];

  /// [t] mapped onto a slice that starts at [from] and lasts [span].
  static double _phase(double t, double from, [double span = 0.34]) =>
      ((t - from) / span).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final wordmark = Curves.easeOutCubic.transform(_phase(t, 0.02, 0.30));
    final headline = Curves.easeOutCubic.transform(_phase(t, 0.14, 0.30));
    final pill = Curves.easeOutCubic.transform(_phase(t, 0.30, 0.34));
    final spark = Curves.easeOutBack.transform(_phase(t, 0.72, 0.28));

    return DesignCanvas(
      background: AppColors.background,
      // Full-bleed artwork: the collage is designed to run off the frame.
      fit: DesignFit.cover,
      children: [
        for (final (asset, left, top, w, h, start) in _cards)
          _Art(
            asset: asset,
            left: left,
            // Rises into place. Animating `top` rather than wrapping the image
            // in a Transform is not a shortcut — DesignImage returns a
            // Positioned, and wrapping one detaches it from the Stack and
            // throws "Incorrect use of ParentDataWidget", an error that still
            // renders plausibly enough to survive a pixel diff.
            top:
                top +
                46 * (1 - Curves.easeOutCubic.transform(_phase(t, start))),
            width: w,
            height: h,
            opacity: _phase(t, start, 0.22),
          ),
        // The wordmark leads, because it is the one thing on this screen that
        // says which app just opened.
        _Art(
          asset: 'logo_carbsai.png',
          left: 133,
          top: 156 - 14 * (1 - wordmark),
          width: 162,
          height: 54,
          opacity: wordmark,
        ),
        // Last, and with a little overshoot — the sparkle is the app's own
        // mark for "the AI did something", and it is the beat the whole
        // entrance lands on. It keeps a slow pulse afterwards while the screen
        // is standing in for a wait.
        _Art(
          asset: 'spark_star.png',
          left: 9 - 4 * breath,
          top: 766 - 30 * (1 - spark) - 6 * breath,
          width: 61.67 * (0.6 + 0.4 * spark),
          height: 61.67 * (0.6 + 0.4 * spark),
          opacity: _phase(t, 0.72, 0.2),
        ),
        _Headline(reveal: headline, pill: pill),
      ],
    );
  }
}

/// Thin wrapper over [DesignImage] that prefixes the splash asset folder.
class _Art extends StatelessWidget {
  const _Art({
    required this.asset,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.opacity = 1,
  });

  final String asset;
  final double left;
  final double top;
  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DesignImage(
      asset: 'assets/images/splash/$asset',
      left: left,
      top: top,
      width: width,
      height: height,
      opacity: opacity.clamp(0.0, 1.0),
    );
  }
}

/// "Eating [healthy] / made easy!" — Figma group 2002:2401.
///
/// In Figma this is one text node whose first line is padded with 18 trailing
/// spaces to reserve room for the pill that overlays it. Reproducing that
/// padding would make the layout depend on the space advance matching Figma's
/// to the pixel, so the two lines are positioned explicitly instead: line one
/// sits flush to the text box's left edge and line two centres within it,
/// which is exactly where Figma's reported ink bounds put them
/// (x 118.82 → 276.70).
class _Headline extends StatelessWidget {
  const _Headline({required this.reveal, required this.pill});

  /// Both text lines, 0 → 1.
  final double reveal;

  /// The orange pill, 0 → 1. It wipes out from its left edge rather than
  /// fading: the pill is the design's own device — the word "healthy" set
  /// *inside* the sentence — and a wipe is the only entrance that reads as the
  /// sentence being written rather than a box appearing over it.
  final double pill;

  static const double _boxLeft = 117;
  static const double _boxWidth = 195;
  static const double _lineHeight = 36;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.headline();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _boxLeft,
          top: 250 - 10 * (1 - reveal),
          width: _boxWidth,
          height: _lineHeight,
          child: Opacity(
            opacity: reveal,
            child: Text('Eating', style: style, textAlign: TextAlign.left),
          ),
        ),
        Positioned(
          left: 198,
          top: 250,
          width: 114,
          height: _lineHeight,
          child: ClipRect(
            clipper: _Wipe(pill),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.accentOrange,
                // Figma stores 50; on a 36pt-tall pill that resolves to a stadium.
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              child: Center(
                child: Text(
                  'healthy',
                  style: style,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: _boxLeft,
          top: 286 - 10 * (1 - reveal),
          width: _boxWidth,
          height: _lineHeight,
          child: Opacity(
            opacity: reveal,
            child: Text(
              'made easy!',
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// Reveals its child from the left edge.
class _Wipe extends CustomClipper<Rect> {
  const _Wipe(this.progress);

  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(_Wipe old) => old.progress != progress;
}
