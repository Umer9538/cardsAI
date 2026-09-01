import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'widgets/round_next_button.dart';

/// The content that varies between Figma frames `02`–`04`. Everything else on
/// those three artboards is identical down to the pixel, so the layout lives in
/// [_OnboardingPage] and only this record changes per page.
class _Page {
  const _Page({
    required this.background,
    required this.illustration,
    required this.illustrationLeft,
    required this.illustrationWidth,
    required this.title,
    required this.body,
  });

  final Color background;
  final String illustration;
  final double illustrationLeft;
  final double illustrationWidth;
  final String title;
  final String body;
}

const List<_Page> _pages = [
  _Page(
    background: AppColors.lilac,
    illustration: 'assets/images/onboarding/illus_1.png',
    illustrationLeft: 62,
    illustrationWidth: 304.33,
    title: 'Your Smart Nutrition Companion',
    body: 'Track your meals, monitor nutrients, and reach your health goals '
        'with AI-powered support.',
  ),
  _Page(
    background: AppColors.accentGreen,
    illustration: 'assets/images/onboarding/illus_2.png',
    illustrationLeft: 84,
    illustrationWidth: 260,
    title: 'Track Everything That Matters',
    body: 'Log calories, macros, water, and activity — \nall in one place.',
  ),
  _Page(
    background: AppColors.accentOrange,
    illustration: 'assets/images/onboarding/illus_3.png',
    illustrationLeft: 81,
    illustrationWidth: 266.33,
    title: 'Your Health Journey \nStarts Here',
    body: 'We help you choose healthier foods and enjoy tasty, nutritious '
        'meals for your well-being.',
  ),
];

/// Onboarding — Figma frames `02_Onboarding Screen 1` (2002:2213),
/// `03_Onboarding Screen 2` (2002:2085) and `04_Onboarding Screen 3`
/// (2002:1971).
///
/// The artboards carry no page-dot indicator, so the only way forward is the
/// round button; it is wired to advance the [PageView] and, on the last page,
/// to call [onFinished].
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onFinished, this.initialPage = 0});

  /// Invoked from "Get Started" on the final page. Left null until the auth
  /// flow (frames 05–15) exists.
  final VoidCallback? onFinished;

  /// Page to open on. Exists so each artboard can be rendered in isolation by
  /// the design-comparison test.
  final int initialPage;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.initialPage);
  late int _index = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _advance() {
    if (_index == _pages.length - 1) {
      widget.onFinished?.call();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Every onboarding background is light, so the system status bar needs
      // dark glyphs on all three pages.
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _pages[_index].background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _pages[_index].background,
        body: PageView.builder(
          controller: _controller,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => _OnboardingPage(
            page: _pages[i],
            isLast: i == _pages.length - 1,
            onNext: _advance,
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.page,
    required this.isLast,
    required this.onNext,
  });

  final _Page page;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DesignCanvas(
      background: page.background,
      // Full-bleed illustration; nothing sits near the bottom edge.
      fit: DesignFit.cover,
      children: [
        // The artboards mock up an iOS status bar at y=0..47. That region is
        // left empty here so the real system status bar shows through.
        Positioned(
          left: 20,
          top: 566,
          width: 388,
          height: 84,
          child: Text(
            page.title,
            style: AppTypography.onboardingTitle(),
            textAlign: TextAlign.center,
          ),
        ),
        Positioned(
          left: 20,
          top: 662,
          width: 388,
          height: 50,
          child: Text(
            page.body,
            style: AppTypography.onboardingBody(),
            textAlign: TextAlign.center,
          ),
        ),
        // White backing shape. Exported with its 32px drop shadow baked in,
        // which is why it sits at (109, 738) rather than the node's (141, 770).
        const DesignImage(
          asset: 'assets/images/onboarding/blob.png',
          left: 109,
          top: 738,
          width: 212,
          height: 188,
        ),
        Positioned(
          left: 165,
          top: 788,
          width: 100,
          height: 100,
          child: RoundNextButton(
            onTap: onNext,
            label: isLast ? 'Get\nStarted' : 'Next',
            showArrow: !isLast,
          ),
        ),
        DesignImage(
          asset: page.illustration,
          left: page.illustrationLeft,
          top: 105,
          width: page.illustrationWidth,
          height: 364,
        ),
      ],
    );
  }
}
