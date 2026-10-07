import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/app_config.dart';
import '../core/providers/providers.dart';
import '../core/repositories/repositories.dart';
import '../core/theme/app_colors.dart';
import '../features/analysis/presentation/analysis_screen.dart';
import '../features/app/presentation/home_screen.dart';
import '../features/app/presentation/notifications_screen.dart';
import '../features/app/presentation/widgets/bottom_nav.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/diets/presentation/diet_detail_screen.dart';
import '../features/diets/presentation/diets_screen.dart';
import '../features/diets/presentation/taste_quiz_screen.dart';
import '../features/onboarding/presentation/onboarding_quiz_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/premium/presentation/plan_detail_screen.dart';
import '../features/premium/presentation/premium_offer_screen.dart';
import '../features/premium/presentation/premium_plans_screen.dart';
import '../features/premium/presentation/review_summary_screen.dart';
import '../features/premium/presentation/subscription_controller.dart';
import '../features/scan/presentation/camera_session.dart';
import '../features/scan/presentation/describe_meal_screen.dart';
import '../features/scan/presentation/food_search_screen.dart';
import '../features/scan/presentation/scan_controller.dart';
import '../features/scan/presentation/scan_result_screen.dart';
import '../features/scan/presentation/scanning_screen.dart';
import '../features/scan/presentation/widgets/ai_disclosure.dart';
import '../features/settings/presentation/change_password_screen.dart';
import '../features/settings/presentation/legal_page_screen.dart';
import '../features/settings/presentation/more_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/settings/presentation/payment_method_screen.dart';
import '../features/settings/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../core/design/app_toast.dart';

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

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  AppTab _tab = AppTab.home;
  DietsTab _dietsTab = DietsTab.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame: the schedule reads the diary, and nothing about
    // it should delay the app appearing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReminders());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reminders are scheduled a day at a time and the times move as habits
    // move, so they are rewritten whenever the app comes back rather than only
    // at a cold start — which on a phone that is never killed would be never.
    if (state == AppLifecycleState.resumed) _syncReminders();
  }

  void _syncReminders() {
    if (!mounted) return;
    ref.read(mealRemindersProvider).refresh();
    // The feed is derived from the diary and from the time of day — an
    // unlogged lunch only becomes worth mentioning at 14:00 — so it is
    // recomputed on the same beat as the reminders rather than once at start.
    ref.invalidate(feedRefreshProvider);
  }

  Future<void> _push(Widget screen) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _selectTab(AppTab tab) {
    if (tab == AppTab.scan) {
      unawaited(_openScan());
      return;
    }
    setState(() => _tab = tab);
  }

  Future<void> _openScan() async {
    // Told once, before anything leaves the device. Play requires the
    // disclosure in the app and before the transfer, not only in the policy.
    if (!await confirmAiDisclosure(context, ref)) return;
    if (!mounted) return;
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
                // Replaces the search screen rather than stacking on it: the
                // search found nothing, so going "back" to it from describe
                // would land on the dead end that was just escaped.
                onDescribe: (query) => Navigator.of(c).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (d) => DescribeMealScreen(
                      initialText: query,
                      onBack: () => Navigator.of(d).pop(),
                      onAnalysed: () => _openResult(imagePath: null),
                    ),
                  ),
                ),
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
    // Analysing the design's own photograph keeps the flow walkable there, but
    // only where nothing is charged for it: against the real backend that is a
    // paid scan of a stock plate, and the person is told their lunch is a
    // salmon salad. On a device the shutter is blocked before this point; this
    // is the second line of defence.
    if (imagePath == null && ref.read(backendProvider) != AppBackend.local) {
      showToast(
        context,
        'The camera is not ready yet. Try again in a moment.',
        tone: ToastTone.error,
      );
      return;
    }
    final path = imagePath ?? 'assets/images/app/scan_food.webp';

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
              appToast(
                '${meal.name} saved to favourites.',
                tone: ToastTone.success,
              ),
            );
            if (context.mounted) _afterLogging(context);
          },
          onAdd: () => _afterLogging(context),
          onUpgrade: _openPremium,
        ),
      ),
    );
  }

  /// Closes the scan flow and shows the day it just changed.
  ///
  /// Scan is a pushed route over whichever tab was showing, so logging a meal
  /// from Settings used to drop the person back on Settings — having just
  /// added something to a diary they could not see. The point of logging is the
  /// day updating; land where that is visible.
  void _afterLogging(BuildContext context) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    // Today, not whatever day was being browsed: the meal was logged now.
    ref.read(selectedDateProvider.notifier).today();
    if (_tab != AppTab.home) setState(() => _tab = AppTab.home);
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
          onRestore: () => _restorePurchases(context),
          onTerms: () => _push(
            Builder(
              builder: (c) =>
                  LegalPageScreen.terms(onBack: () => Navigator.of(c).pop()),
            ),
          ),
          onPrivacy: () => _push(
            Builder(
              builder: (c) =>
                  LegalPageScreen.privacy(onBack: () => Navigator.of(c).pop()),
            ),
          ),
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

  /// Restore, from the paywall footer.
  ///
  /// Both stores require this: someone who reinstalled or changed device has
  /// already paid, and without it their only route back to what they own is
  /// paying again.

  /// "Something else" on a plan someone built.
  ///
  /// Goes back through the quiz screen rather than generating inline, so the
  /// sweep, the caption, the "taking longer than usual" line and the retry are
  /// the same ones the first build used — and lands on the build step with the
  /// stored answers already filled in, so nothing is asked twice.
  ///
  /// Offered only when there is something to rebuild from: a catalogue plan
  /// was not built from anyone's answers, and a fresh install has none stored.
  VoidCallback? _rebuildFrom(BuildContext c, DietPlan plan) {
    final taste = ref.read(lastTasteProvider);
    if (!plan.isMine || plan.builtFor.isEmpty || taste == null) return null;
    return () => Navigator.of(c).pushReplacement(
      MaterialPageRoute<void>(
        builder: (q) => TasteQuizScreen(
          rebuildFrom: taste,
          onBack: () => Navigator.of(q).pop(),
          onCreated: (next) => Navigator.of(q).pushReplacement(
            MaterialPageRoute<void>(
              builder: (d) => DietDetailScreen(
                plan: next,
                onBack: () => Navigator.of(d).pop(),
                onAdd: () => Navigator.of(d).pop(),
                onRebuild: _rebuildFrom(d, next),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restorePurchases(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(appToast('Checking for previous purchases…'));
    final ok = await ref
        .read(subscriptionControllerProvider.notifier)
        .restore();
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    final premium = ref.read(isPremiumProvider);
    messenger.showSnackBar(
      appToast(
        premium
            ? 'Your subscription is active again.'
            : ok
            ? 'No previous purchase found on this account.'
            : 'We could not reach the store. Try again in a moment.',
        tone: premium
            ? ToastTone.success
            : ok
            ? ToastTone.info
            : ToastTone.error,
      ),
    );
  }

  void _openSettingsDestination(String key) {
    switch (key) {
      case 'profile':
        _push(
          Builder(
            builder: (c) => ProfileScreen(
              onBack: () => Navigator.of(c).pop(),
              onSave: () => Navigator.of(c).pop(),
              // The quiz saves the profile and recomputes the targets itself;
              // finishing it, or skipping it, just comes back here.
              onEditGoal: () => Navigator.of(c).push(
                MaterialPageRoute<void>(
                  builder: (q) => OnboardingQuizScreen(
                    onFinished: () => Navigator.of(q).pop(),
                  ),
                ),
              ),
            ),
          ),
        );
      case 'password':
        _push(
          Builder(
            builder: (c) => ChangePasswordScreen(
              onBack: () => Navigator.of(c).pop(),
              onDone: () => Navigator.of(c).pop(),
            ),
          ),
        );
      case 'notifications':
        _push(
          Builder(
            builder: (c) =>
                NotificationSettingsScreen(onBack: () => Navigator.of(c).pop()),
          ),
        );
      case 'payment':
        _push(
          Builder(
            builder: (c) => PaymentMethodScreen(
              onBack: () => Navigator.of(c).pop(),
              onUpgrade: _openPlans,
            ),
          ),
        );
      case 'favorites':
        _push(
          Builder(
            builder: (c) =>
                FavoritesScreen(onBack: () => Navigator.of(c).pop()),
          ),
        );
      case 'more':
        _openMore();
    }
  }

  void _openMore() {
    _push(
      Builder(
        builder: (c) => MoreScreen(
          onBack: () => Navigator.of(c).pop(),
          onDelete: () => _deleteAccount(c),
          onOpen: (key) => _push(
            Builder(
              builder: (c2) => switch (key) {
                'terms' => LegalPageScreen.terms(
                  onBack: () => Navigator.of(c2).pop(),
                ),
                'privacy' => LegalPageScreen.privacy(
                  onBack: () => Navigator.of(c2).pop(),
                ),
                _ => LegalPageScreen.help(onBack: () => Navigator.of(c2).pop()),
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Deletes the account, and says so if it does not work.
  ///
  /// Deletion is not instant — the server walks the whole diary — so the
  /// screen is held under a barrier rather than popped immediately. Popping
  /// first would drop the only place an error could be reported, which is how
  /// this previously failed silently.
  Future<void> _deleteAccount(BuildContext sheetContext) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(sheetContext);

    showDialog<void>(
      context: sheetContext,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    final ok = await ref.read(authControllerProvider.notifier).deleteAccount();

    // Close the barrier.
    if (navigator.canPop()) navigator.pop();

    if (ok) {
      // Everything pushed has to come off. Signing out rebuilds the app from
      // the auth stream, but that only replaces `MaterialApp.home` — pushed
      // routes sit above it and would leave the deleted account's More screen
      // on top of the login page.
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    // Failure leaves More where it is, so the message appears over the screen
    // the button was on.
    final error = ref.read(authControllerProvider).error;
    messenger.showSnackBar(
      appToast(
        error is RepositoryException
            ? error.message
            : 'Your account could not be deleted. Please try again.',
        tone: ToastTone.error,
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
    // A logged meal is new evidence about when this person eats, so the
    // schedule is rewritten as soon as one lands. Listening to today's meals
    // catches every logging path — camera, barcode, search, description —
    // without each of them having to remember to call it.
    final now = DateTime.now();
    ref.listen(dayMealsProvider(DateTime(now.year, now.month, now.day)), (
      _,
      next,
    ) {
      _syncReminders();
    });

    // Watched, not read: a FutureProvider nobody watches never runs, and the
    // bell badge has to be right without opening the notifications screen
    // first.
    ref.watch(feedRefreshProvider);

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
                onRebuild: _rebuildFrom(c, plan),
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
          onBuildPlan: () async {
            // The plan builder sends the person's targets and taste answers to
            // the same provider, so it is behind the same one-time disclosure.
            if (!await confirmAiDisclosure(context, ref)) return;
            if (!mounted) return;
            _push(
              Builder(
                builder: (c) => TasteQuizScreen(
                  onBack: () => Navigator.of(c).pop(),
                  onCreated: (plan) {
                    // The comment below has always been the intent and the tab
                    // was never switched, so backing out of a freshly built plan
                    // landed on All Diets — where the catalogue is, and the new
                    // plan is not. It reads as the build having done nothing.
                    if (_dietsTab != DietsTab.mine) {
                      setState(() => _dietsTab = DietsTab.mine);
                    }
                    // Replace rather than stack: going back from a plan you just
                    // built should land on My Diets, not on the form that built
                    // it.
                    Navigator.of(c).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (c2) => DietDetailScreen(
                          plan: plan,
                          onBack: () => Navigator.of(c2).pop(),
                          onAdd: () => Navigator.of(c2).pop(),
                          onRebuild: _rebuildFrom(c2, plan),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
          onNavSelected: _selectTab,
          onPlanTap: (plan) => _push(
            Builder(
              builder: (c) => DietDetailScreen(
                plan: plan,
                onBack: () => Navigator.of(c).pop(),
                onAdd: () => Navigator.of(c).pop(),
                onRebuild: _rebuildFrom(c, plan),
              ),
            ),
          ),
        ),
        SettingsScreen(
          onNavSelected: _selectTab,
          onOpen: _openSettingsDestination,
          onLogOut: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      ],
    );
  }
}
