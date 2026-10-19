/// Every screen in the app, as one list.
///
/// It lived inside `responsive_overflow_test` and is now shared, because a
/// second sweep needed exactly the same set and a screen added to one copy and
/// not the other is a screen nobody checks. `responsive_overflow_test` renders
/// these for overflow; `tablet_reachability_test` renders them for whether
/// their controls are on the display, which are different failures — cover
/// clips without overflowing, so the first suite cannot see the second one.
library;

import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/features/analysis/presentation/analysis_screen.dart';
import 'package:carbsai/features/app/presentation/home_screen.dart';
import 'package:carbsai/features/app/presentation/notifications_screen.dart';
import 'package:carbsai/features/auth/presentation/forgot_password_screen.dart';
import 'package:carbsai/features/auth/presentation/login_screen.dart';
import 'package:carbsai/features/auth/presentation/reset_password_screen.dart';
import 'package:carbsai/features/auth/presentation/sign_up_screen.dart';
import 'package:carbsai/features/auth/presentation/verification_screen.dart';
import 'package:carbsai/features/diets/presentation/diets_screen.dart';
import 'package:carbsai/features/diets/presentation/taste_quiz_screen.dart';
import 'package:carbsai/features/onboarding/presentation/onboarding_quiz_screen.dart';
import 'package:carbsai/features/onboarding/presentation/onboarding_screen.dart';
import 'package:carbsai/features/premium/presentation/plan_detail_screen.dart';
import 'package:carbsai/features/premium/presentation/premium_offer_screen.dart';
import 'package:carbsai/features/premium/presentation/premium_plans_screen.dart';
import 'package:carbsai/features/premium/presentation/review_summary_screen.dart';
import 'package:carbsai/features/scan/presentation/scan_result_screen.dart';
import 'package:carbsai/features/scan/presentation/scanning_screen.dart';
import 'package:carbsai/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';

List<(String, Widget)> appScreens() => [
  ('splash', const SplashScreen()),
  ('onboarding 1', const OnboardingScreen()),
  ('onboarding 3', OnboardingScreen(initialPage: 2)),
  // The quiz's first step. The five-option activity step is the tallest, and
  // is covered by the walk-through in navigation_flow_test — a trailing gap
  // there put it 10pt over its body and produced overflow stripes.
  ('onboarding quiz', const OnboardingQuizScreen()),
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
  // The plan builder's quiz, on its first grid: nine tiles with shadows is
  // the tallest body any quiz step has.
  ('taste quiz', const TasteQuizScreen()),
  ('notifications', const NotificationsScreen()),
  ('notifications empty', NotificationsScreen(items: [])),
  ('scanning', const ScanningScreen()),
  ('scan result', const ScanResultScreen()),
  ('premium offer', const PremiumOfferScreen()),
  ('premium plans', const PremiumPlansScreen()),
  (
    'plan detail monthly',
    PlanDetailScreen(plan: SubscriptionPlan.catalogue[0]),
  ),
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
