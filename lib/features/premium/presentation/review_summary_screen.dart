import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import 'subscription_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import 'widgets/premium_widgets.dart';

/// Review summary — Figma frames `21_Review Summary` (2002:1483) and
/// `22_Congratulation` (2002:1467).
///
/// Frame 22 is frame 21 with a confirmation dialog over it; its own top bar
/// still reads "Review Summary", so despite the frame name the two are one
/// screen and a modal, exactly like frames 11 and 12.
class ReviewSummaryScreen extends ConsumerStatefulWidget {
  const ReviewSummaryScreen({
    super.key,
    required this.plan,
    this.onBack,
    this.onExplore,
    this.showSuccessInitially = false,
  });

  final SubscriptionPlan plan;
  final VoidCallback? onBack;
  final VoidCallback? onExplore;

  /// Renders the frame-22 state directly. Used by the design-comparison test.
  final bool showSuccessInitially;

  @override
  ConsumerState<ReviewSummaryScreen> createState() =>
      _ReviewSummaryScreenState();
}

class _ReviewSummaryScreenState extends ConsumerState<ReviewSummaryScreen> {
  late bool _showSuccess = widget.showSuccessInitially;
  String? _error;

  /// This is where money would change hands.
  ///
  /// The entitlement is granted by a Cloud Function rather than written here,
  /// so the client never decides what it is entitled to. Store-receipt
  /// validation slots into that function without this screen changing.
  Future<void> _confirm() async {
    final controller = ref.read(subscriptionControllerProvider.notifier);
    final ok = await controller.purchase(widget.plan.id);
    if (!mounted) return;
    setState(() {
      _showSuccess = ok;
      _error = ok ? null : controller.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(subscriptionControllerProvider).isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: DesignCanvas(
          background: AppColors.background,
          children: [
            PremiumTopBar(title: 'Review Summary', onBack: widget.onBack),

            Positioned(
              left: 20,
              top: 147,
              width: 388,
              height: 36,
              child: Text('Your Plan', style: AppTypography.topBarTitle()),
            ),
            Positioned(
              left: 20,
              top: 195,
              width: 388,
              height: 130,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.planYellow,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(24),
                child: PlanRow(
                  title: widget.plan.name,
                  amount: widget.plan.priceLabel,
                  period: widget.plan.periodLabel,
                  // Frame 21's `Plan Info Container` uses a 1pt gap, not the
                  // chooser's 4pt; the card is sized to the tighter total.
                  gap: 1,
                ),
              ),
            ),

            Positioned(
              left: 20,
              top: 349,
              width: 388,
              height: 36,
              child: Text('Payment Method', style: AppTypography.topBarTitle()),
            ),
            // Card artwork, brand mark and label are one component in the
            // file; exported whole rather than rebuilt from its parts.
            const DesignImage(
              asset: 'assets/images/premium/payment_method_row.png',
              left: 20,
              top: 397,
              width: 388,
              height: 88,
            ),

            Positioned(
              left: 20,
              top: 810,
              width: 388,
              height: 50,
              child: PrimaryButton(
                label: 'Continue',
                onPressed: _confirm,
                busy: busy,
              ),
            ),

            if (_error != null)
              Positioned(
                left: 20,
                top: 760,
                width: 388,
                height: 40,
                child: Text(
                  _error!,
                  style: AppTypography.errorMessage(),
                  textAlign: TextAlign.center,
                ),
              ),

            if (_showSuccess)
              _CongratulationDialog(
                planName: widget.plan.name,
                onExplore: widget.onExplore,
              ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation overlay — frame 22's scrim and `Message` card.
///
/// Lives inside the screen's own [DesignCanvas] so it shares one transform;
/// a separately-positioned overlay drifts out of register once the canvas is
/// scaled or scrolled on a non-artboard size.
class _CongratulationDialog extends StatelessWidget {
  const _CongratulationDialog({required this.planName, this.onExplore});

  final String planName;
  final VoidCallback? onExplore;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Black at 50% fill opacity over a 6pt backdrop blur. The node's
            // colour alpha is 1 — the transparency is on the fill.
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: const ColoredBox(color: Color(0x80000000)),
              ),
            ),
            Positioned(
              left: 20,
              top: 332,
              width: 388,
              child: Container(
                constraints: const BoxConstraints(minHeight: 262),
                decoration: BoxDecoration(
                  color: AppColors.inkMuted,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outline),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Congratulation!',
                      style: AppTypography.cardTitle(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Congrats on upgrading to the ${planName.replaceAll(' Plan', '')} '
                      'Premium plan! Enjoy your new features.',
                      style: AppTypography.socialLabel(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 226,
                      child: PrimaryButton(
                        label: 'Exploring Premium Plan',
                        onPressed: onExplore,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
