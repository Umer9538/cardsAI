import 'package:carbsai/features/auth/presentation/forgot_password_screen.dart';
import 'package:carbsai/features/auth/presentation/login_screen.dart';
import 'package:carbsai/features/auth/presentation/reset_password_screen.dart';
import 'package:carbsai/features/auth/presentation/sign_up_screen.dart';
import 'package:carbsai/features/auth/presentation/verification_screen.dart';
import 'package:carbsai/features/analysis/presentation/analysis_screen.dart';
import 'package:carbsai/features/app/presentation/home_screen.dart';
import 'package:carbsai/features/diets/presentation/diets_screen.dart';
import 'package:carbsai/features/app/presentation/notifications_screen.dart';
import 'package:carbsai/features/scan/presentation/scan_result_screen.dart';
import 'package:carbsai/features/scan/presentation/scanning_screen.dart';
import 'package:carbsai/features/onboarding/presentation/onboarding_screen.dart';
import 'package:carbsai/features/premium/presentation/plan_detail_screen.dart';
import 'package:carbsai/features/premium/presentation/premium_offer_screen.dart';
import 'package:carbsai/features/premium/presentation/premium_plans_screen.dart';
import 'package:carbsai/features/premium/presentation/review_summary_screen.dart';
import 'package:carbsai/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// Every screen, at every size we care about, must lay out without a render
/// overflow and must keep its bottom-most control reachable.
///
/// The artboards are a fixed 428x926. Before [DesignFit.fit] existed, the
/// canvas scaled with BoxFit.cover, which silently cropped the bottom of the
/// frame: at 375x667 the log-in CTA and footer fell 65pt below the display,
/// and at 834x1194 the artboard scaled 1.95x and buried 433pt.
const List<(String, Size)> _devices = [
  ('iPhone 5 / SE 1st gen', Size(320, 568)),
  ('Android small', Size(360, 640)),
  ('iPhone SE / 8', Size(375, 667)),
  ('iPhone 15', Size(393, 852)),
  ('Pixel 7', Size(412, 915)),
  ('Artboard', Size(428, 926)),
  ('iPhone 15 Pro Max', Size(430, 932)),
  ('iPad mini', Size(744, 1133)),
  ('iPad Pro 11"', Size(834, 1194)),
  ('Landscape phone', Size(852, 393)),
];

List<(String, Widget)> _screens() => [
  ('splash', const SplashScreen()),
  ('onboarding 1', const OnboardingScreen()),
  ('onboarding 3', OnboardingScreen(initialPage: 2)),
  ('login', const LoginScreen()),
  ('sign up', const SignUpScreen()),
  ('forgot password', const ForgotPasswordScreen()),
  ('reset password', const ResetPasswordScreen()),
  ('reset success', ResetPasswordScreen(showSuccessInitially: true)),
  ('verification', VerificationScreen(email: 'janecooper@email.com')),
  ('home', const HomeScreen()),
  ('analysis', const AnalysisScreen()),
  ('diets all', const DietsScreen()),
  ('diets mine', DietsScreen(tab: DietsTab.mine)),
  ('diets mine empty', DietsScreen(tab: DietsTab.mine, myPlans: [])),
  ('notifications', const NotificationsScreen()),
  ('notifications empty', NotificationsScreen(items: [])),
  ('scanning', const ScanningScreen()),
  ('scan result', const ScanResultScreen()),
  ('premium offer', const PremiumOfferScreen()),
  ('premium plans', const PremiumPlansScreen()),
  ('plan detail monthly', PlanDetailScreen(plan: SubscriptionPlan.catalogue[0])),
  ('plan detail annual', PlanDetailScreen(plan: SubscriptionPlan.catalogue[1])),
  ('review summary', ReviewSummaryScreen(plan: SubscriptionPlan.catalogue[0])),
  (
    'review summary success',
    ReviewSummaryScreen(
      plan: SubscriptionPlan.catalogue[0],
      showSuccessInitially: true,
    ),
  ),
];

void main() {
  setUpAll(loadDesignFonts);

  for (final (deviceName, size) in _devices) {
    testWidgets('no overflow on $deviceName (${size.width.toInt()}x'
        '${size.height.toInt()})', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      // One scope for the whole sweep — see designScopeBuilder().
      final scope = await designScopeBuilder();

      for (final (screenName, screen) in _screens()) {
        await tester.pumpWidget(
          scope(MaterialApp(debugShowCheckedModeBanner: false, home: screen)),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          tester.takeException(),
          isNull,
          reason: '$screenName overflowed on $deviceName',
        );
      }
    });
  }

  testWidgets('bottom-anchored controls stay on screen at every size',
      (tester) async {
    // The regression that motivated DesignFit.fit: a CTA sitting at y=761 on
    // the artboard must remain within the viewport, not merely exist in the
    // widget tree.
    for (final (deviceName, size) in _devices) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;

      await tester.pumpWidget(
        await designScope(
          const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final cta = find.text('Log In');
      expect(cta, findsOneWidget, reason: 'CTA missing on $deviceName');

      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        // Taller than the viewport, so the CTA is reachable by scrolling
        // rather than being clipped away.
        await tester.scrollUntilVisible(cta, 200,
            scrollable: scrollable.first);
        await tester.pump();
      }

      final box = tester.renderObject<RenderBox>(cta);
      final topLeft = box.localToGlobal(Offset.zero);
      expect(
        topLeft.dy + box.size.height <= size.height + 0.5 && topLeft.dy >= -0.5,
        isTrue,
        reason: 'CTA off-screen on $deviceName: '
            'y=${topLeft.dy.toStringAsFixed(1)} '
            'h=${box.size.height.toStringAsFixed(1)} '
            'viewport=${size.height}',
      );
    }
    addTearDown(tester.view.reset);
  });
}
