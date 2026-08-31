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
  const SplashScreen({super.key, this.onFinished, this.duration = const Duration(milliseconds: 2500)});

  /// Invoked once the splash has been shown for [duration].
  /// Left null until the onboarding flow (frames 02–04) exists.
  final VoidCallback? onFinished;

  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    final onFinished = widget.onFinished;
    if (onFinished != null) {
      Future<void>.delayed(widget.duration, () {
        if (mounted) onFinished();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: const Scaffold(
        backgroundColor: AppColors.background,
        body: _SplashCanvas(),
      ),
    );
  }
}

class _SplashCanvas extends StatelessWidget {
  const _SplashCanvas();

  @override
  Widget build(BuildContext context) {
    return const DesignCanvas(
      background: AppColors.background,
      // Full-bleed artwork: the collage is designed to run off the frame.
      fit: DesignFit.cover,
      children: [
        // Paint order below mirrors the child order of the Figma frame.
        _Art(asset: 'card_healthy.png', left: 189, top: 720, width: 120.67, height: 120.67),
        _Art(asset: 'logo_nutriai.png', left: 133, top: 156, width: 162, height: 54),
        _Art(asset: 'card_pink.png', left: 193, top: 828, width: 145.33, height: 98),
        _Art(asset: 'card_purple.png', left: 275, top: 718, width: 153, height: 208),
        _Art(asset: 'card_orange.png', left: 60.89, top: 741, width: 157.33, height: 185),
        _Art(asset: 'card_blue.png', left: 8, top: 641, width: 126.33, height: 124),
        _Art(asset: 'pill_today.png', left: 29, top: 810, width: 52, height: 102),
        _Art(asset: 'spark_star.png', left: 9, top: 766, width: 61.67, height: 61.67),
        _Art(asset: 'card_yellow.png', left: 265, top: 590, width: 162, height: 164.67),
        _Headline(),
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
  });

  final String asset;
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DesignImage(
      asset: 'assets/images/splash/$asset',
      left: left,
      top: top,
      width: width,
      height: height,
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
  const _Headline();

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
          top: 250,
          width: _boxWidth,
          height: _lineHeight,
          child: Text('Eating', style: style, textAlign: TextAlign.left),
        ),
        Positioned(
          left: 198,
          top: 250,
          width: 114,
          height: _lineHeight,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.accentOrange,
              // Figma stores 50; on a 36pt-tall pill that resolves to a stadium.
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: Center(
              child: Text('healthy', style: style, textAlign: TextAlign.center),
            ),
          ),
        ),
        Positioned(
          left: _boxLeft,
          top: 286,
          width: _boxWidth,
          height: _lineHeight,
          child: Text('made easy!', style: style, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}
