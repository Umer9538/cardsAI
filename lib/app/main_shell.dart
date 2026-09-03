import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/providers/providers.dart';
import '../features/analysis/presentation/analysis_screen.dart';
import '../features/app/presentation/home_screen.dart';
import '../features/app/presentation/notifications_screen.dart';
import '../features/app/presentation/widgets/bottom_nav.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/diets/presentation/diet_detail_screen.dart';
import '../features/diets/presentation/diets_screen.dart';
import '../features/diets/presentation/plan_builder_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/premium/presentation/plan_detail_screen.dart';
import '../features/premium/presentation/premium_offer_screen.dart';
import '../features/premium/presentation/premium_plans_screen.dart';
import '../features/premium/presentation/review_summary_screen.dart';
import '../features/scan/presentation/camera_session.dart';
import '../features/scan/presentation/describe_meal_screen.dart';
import '../features/scan/presentation/food_search_screen.dart';
import '../features/scan/presentation/scan_controller.dart';
import '../features/scan/presentation/scan_result_screen.dart';
import '../features/scan/presentation/scanning_screen.dart';
import '../features/settings/presentation/change_password_screen.dart';
import '../features/settings/presentation/legal_page_screen.dart';
import '../features/settings/presentation/more_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/settings/presentation/payment_method_screen.dart';
import '../features/settings/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

/// The signed-in application: four tabbed destinations plus a scan flow that
/// opens over them.
///
/// Tabs are kept in an [IndexedStack] so each keeps its scroll position and
/// state when you switch away and back. Scan is not a tab in that sense — the
/// artboard has no tab bar on it — so selecting it pushes the camera instead.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  AppTab _tab = AppTab.home;
  DietsTab _dietsTab = DietsTab.all;

  Future<void> _push(Widget screen) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _selectTab(AppTab tab) {
    if (tab == AppTab.scan) {
      _openScan();
      return;
    }
    setState(() => _tab = tab);
  }

  void _openScan() {
    _push(
      Builder(
        builder: (context) => ScanningScreen(
          onClose: () => Navigator.of(context).pop(),
          onCaptured: _capture,
          onBarcode: (code) {
            ref.read(scanControllerProvider.notifier).scanBarcode(code);
            _openResult(imagePath: null);
          },
          onDescribe: () => _push(
            Builder(
              builder: (c) => DescribeMealScreen(
                onBack: () => Navigator.of(c).pop(),
                onAnalysed: () => _openResult(imagePath: null),
              ),
            ),
          ),
          onSearch: () => _push(
            Builder(
              builder: (c) => FoodSearchScreen(
                onBack: () => Navigator.of(c).pop(),
                onDone: () => _openResult(imagePath: null),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Starts the analysis and moves straight to the result, which renders its
  /// own working state off the controller. Waiting here instead would leave the
  /// shutter looking dead for the duration.
  void _capture(ScanMode mode, String? imagePath, String? hint) {
    final controller = ref.read(scanControllerProvider.notifier);

    // No path means no usable camera — a simulator, or a refused permission.
    // Analysing the design's own photograph keeps the flow walkable there.
    final path = imagePath ?? 'assets/images/app/scan_food.png';

    switch (mode) {
      case ScanMode.camera:
        controller.analyzePhoto(path, hint: hint);
      case ScanMode.gallery:
        controller.analyzeGallery(path, hint: hint);
      case ScanMode.barcode:
        // Reached only if a shutter press slips through; the reader normally
        // fires onBarcode with a real code.
        return;
    }

    _openResult(imagePath: imagePath);
  }

  /// The result screen, however the result was produced.
  void _openResult({required String? imagePath}) {
    final controller = ref.read(scanControllerProvider.notifier);

    _push(
      Builder(
        builder: (context) => ScanResultScreen(
          onBack: () {
            ref.read(imageCaptureProvider).discard(imagePath);
            controller.discard();
            Navigator.of(context).pop();
          },
          // Logs the meal and keeps it for one-tap re-logging — the PRD's
          // "Log again", which matters because people eat the same breakfast
          // for months.
          onFavourite: () async {
            final messenger = ScaffoldMessenger.of(context);
            final meal = await controller.logMeal(favourite: true);
            messenger.showSnackBar(
              SnackBar(content: Text('${meal.name} saved to favourites.')),
            );
            if (context.mounted) {
              Navigator.of(context).popUntil((r) => r.isFirst);
            }
          },
          onAdd: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onUpgrade: _openPremium,
        ),
      ),
    );
  }

  void _openPremium() {
    // Someone already paying does not need the pitch again; send them to the
    // plan list, which is also where a change of plan starts.
    if (ref.read(isPremiumProvider)) {
      _openPlans();
      return;
    }
    _push(
      Builder(
        builder: (context) => PremiumOfferScreen(
          onClose: () => Navigator.of(context).pop(),
          onSkip: () => Navigator.of(context).pop(),
          onUpgrade: _openPlans,
        ),
      ),
    );
  }

  void _openPlans() {
    _push(
      Builder(
        builder: (context) => PremiumPlansScreen(
          onBack: () => Navigator.of(context).pop(),
          onSelect: _openPlanDetail,
        ),
      ),
    );
  }

  /// The plan chosen here is carried through to the review screen, rather than
  /// the summary hardcoding one — picking Annual and being charged Monthly is
  /// the kind of bug that ends up in a store review.
  void _openPlanDetail(SubscriptionPlan plan) {
    _push(
      Builder(
        builder: (context) => PlanDetailScreen(
          plan: plan,
          onBack: () => Navigator.of(context).pop(),
          onContinue: () => _push(
            Builder(
              builder: (context) => ReviewSummaryScreen(
                plan: plan,
                onBack: () => Navigator.of(context).pop(),
                onExplore: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSettingsDestination(String key) {
    switch (key) {
      case 'profile':
        _push(Builder(
          builder: (c) => ProfileScreen(
            onBack: () => Navigator.of(c).pop(),
            onSave: () => Navigator.of(c).pop(),
          ),
        ));
      case 'password':
        _push(Builder(
          builder: (c) => ChangePasswordScreen(
            onBack: () => Navigator.of(c).pop(),
            onDone: () => Navigator.of(c).pop(),
          ),
        ));
      case 'notifications':
        _push(Builder(
          builder: (c) =>
              NotificationSettingsScreen(onBack: () => Navigator.of(c).pop()),
        ));
      case 'payment':
        _push(Builder(
          builder: (c) => PaymentMethodScreen(
            onBack: () => Navigator.of(c).pop(),
            onUpgrade: _openPlans,
          ),
        ));
      case 'favorites':
        _push(Builder(
          builder: (c) => FavoritesScreen(onBack: () => Navigator.of(c).pop()),
        ));
      case 'more':
        _openMore();
    }
  }

  void _openMore() {
    _push(
      Builder(
        builder: (c) => MoreScreen(
          onBack: () => Navigator.of(c).pop(),
          onDelete: () {
            Navigator.of(c).pop();
            ref.read(authControllerProvider.notifier).deleteAccount();
          },
          onOpen: (key) => _push(
            Builder(
              builder: (c2) => switch (key) {
                'terms' =>
                  LegalPageScreen.terms(onBack: () => Navigator.of(c2).pop()),
                'privacy' =>
                  LegalPageScreen.privacy(onBack: () => Navigator.of(c2).pop()),
                _ => LegalPageScreen.help(onBack: () => Navigator.of(c2).pop()),
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Back on any tab but Home returns to Home; only Home lets the gesture
    // through.
    //
    // The tabs live in an IndexedStack rather than on the navigator, so there
    // is nothing under Settings for the system back to pop except MainShell
    // itself — which is the whole signed-in app. Pressing back on Settings
    // therefore closed the app. Every other tabbed app treats back as "up one
    // level" here, and Home is the level above a tab.
    return PopScope(
      canPop: _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _tab == AppTab.home) return;
        setState(() => _tab = AppTab.home);
      },
      child: _tabs(),
    );
  }

  Widget _tabs() {
    return IndexedStack(
      index: switch (_tab) {
        AppTab.home => 0,
        AppTab.analysis => 1,
        AppTab.diets => 2,
        AppTab.settings => 3,
        AppTab.scan => 0,
      },
      children: [
        HomeScreen(
          onTabSelected: _selectTab,
          onPremium: _openPremium,
          onPlanTap: (plan) => _push(
            Builder(
              builder: (c) => DietDetailScreen(
                plan: plan,
                onBack: () => Navigator.of(c).pop(),
                onAdd: () => Navigator.of(c).pop(),
              ),
            ),
          ),
          onNotifications: () => _push(
            Builder(
              builder: (c) =>
                  NotificationsScreen(onBack: () => Navigator.of(c).pop()),
            ),
          ),
        ),
        AnalysisScreen(onNavSelected: _selectTab),
        DietsScreen(
          tab: _dietsTab,
          onTabChanged: (t) => setState(() => _dietsTab = t),
          onBuildPlan: () => _push(
            Builder(
              builder: (c) => PlanBuilderScreen(
                onBack: () => Navigator.of(c).pop(),
                onCreated: (plan) {
                  // Replace rather than stack: going back from a plan you just
                  // built should land on My Diets, not on the form that built
                  // it.
                  Navigator.of(c).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (c2) => DietDetailScreen(
                        plan: plan,
                        onBack: () => Navigator.of(c2).pop(),
                        onAdd: () => Navigator.of(c2).pop(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          onNavSelected: _selectTab,
          onPlanTap: (plan) => _push(
            Builder(
              builder: (c) => DietDetailScreen(
                plan: plan,
                onBack: () => Navigator.of(c).pop(),
                onAdd: () => Navigator.of(c).pop(),
              ),
            ),
          ),
        ),
        SettingsScreen(
          onNavSelected: _selectTab,
          onOpen: _openSettingsDestination,
          onLogOut: () =>
              ref.read(authControllerProvider.notifier).signOut(),
        ),
      ],
    );
  }
}
