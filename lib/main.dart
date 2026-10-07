import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/main_shell.dart';
import 'core/ads/ads_providers.dart';
import 'core/app_config.dart';
import 'core/notifications/device_time_zone.dart';
import 'core/route_observer.dart';
import 'core/providers/providers.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'data/local/json_store.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/sign_up_screen.dart';
import 'features/onboarding/presentation/onboarding_quiz_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'firebase_options.dart';
import 'core/design/app_toast.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only, and it is a design constraint rather than a preference.
  //
  // Every screen is a fixed 428 x 926 artboard. In landscape the canvas scales
  // to the short edge and scrolls, which puts the floating tab bar across the
  // middle of the content — and the two things this app is for, framing a plate
  // and logging one-handed, are both portrait actions.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Opening the store is the one piece of async setup the whole app needs, so
  // it happens before the first frame and is injected rather than awaited
  // inside a provider. That keeps every repository construction synchronous.
  final store = await JsonStore.open();
  // Before the first frame, because two things read it and both are wrong
  // without it: the reminder scheduler, which otherwise builds its times in
  // UTC, and the suggested meal times, which have to answer synchronously.
  await DeviceTimeZone.resolve();
  final backend = await _startBackend();

  // Release only. Debug and profile keep the fallback, which is the whole
  // point of it — working offline with no Firebase config is a feature during
  // development and a lie in a shipped build. See [_startBackend].
  if (kReleaseMode &&
      backend == AppBackend.local &&
      AppConfig.backend == AppBackend.firebase) {
    runApp(const _MisconfiguredApp(reason: _noFirebase));
    return;
  }

  // The same judgement, one build flag along. Every server-side thing this app
  // does — analysing a photo, writing a plan, validating a receipt, deleting an
  // account properly — goes through the Worker, and without `WORKER_URL` the
  // very first of them throws a bare `StateError` deep inside a screen.
  //
  // `tool/build_release.sh` refuses to build without the define, so the only
  // way to reach here is a `flutter build apk --release` typed by hand. That
  // has happened, and the symptom was a grey rectangle on the scan result with
  // nothing to read: the failure surfaced five screens in, in the one place
  // that looks like the AI is broken rather than the build. Naming it at launch
  // costs one screen and saves that hunt.
  if (kReleaseMode &&
      backend == AppBackend.firebase &&
      AppConfig.workerBaseUrl.isEmpty) {
    runApp(const _MisconfiguredApp(reason: _noWorkerUrl));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        backendProvider.overrideWithValue(backend),
      ],
      child: const CarbsaiApp(),
    ),
  );
}

/// Brings Firebase up, and falls back to the on-device backend if it will not
/// start.
///
/// A missing `google-services.json`, a project that has been deleted, or a
/// platform the app was never registered for all throw here. None of those are
/// worth a crash on the splash screen in development, when there is a working
/// offline mode a line away — but they must be loud, because silently running
/// local while believing you are on Firebase is a confusing way to lose an
/// afternoon.
///
/// **In a release build the fallback is not a degraded experience, it is a
/// wrong one.** `LocalScanRepository` waits two seconds and returns the same
/// three foods whatever you photograph. A shipped build that quietly landed
/// there would invent nutrition figures and log them to a real person's diary,
/// which is worse than any error screen. So release says so, in
/// [_MisconfiguredApp], rather than carrying on.
Future<AppBackend> _startBackend() async {
  if (AppConfig.backend == AppBackend.local) return AppBackend.local;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _startCrashReporting();
    await _startAppCheck();
    return AppBackend.firebase;
  } catch (error, stack) {
    debugPrint('Firebase failed to start; falling back to local. $error');
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    }
    return AppBackend.local;
  }
}

/// Sends crashes to Firebase Crashlytics.
///
/// The app had no crash reporting at all: a crash on someone's phone produced
/// a bad review and nothing else. Play Console's Android vitals sees native
/// crashes and ANRs, but a Dart exception that kills a screen is not one — it
/// is caught by the framework, drawn as a grey box in release, and never
/// leaves the device.
///
/// **Set up here rather than in `main()` because it needs Firebase**, and
/// `_startBackend` is the one place that knows whether Firebase actually came
/// up. On `BACKEND=local`, or after a failed init, nothing below runs and the
/// app is unchanged.
///
/// Two handlers, because Flutter has two error paths and each misses what the
/// other catches:
///
///   * `FlutterError.onError` — anything thrown inside the framework: a build,
///     a layout, a gesture callback.
///   * `PlatformDispatcher.onError` — everything else that reaches the engine,
///     which is mostly an unawaited future that threw. `runZonedGuarded` was
///     the old way to catch these; it is no longer needed and brings a zone
///     mismatch with `WidgetsFlutterBinding` if it is used carelessly.
///
/// **No user identifier is attached.** `setUserIdentifier` would tie a crash to
/// an account, which is occasionally useful and would put a persistent
/// identifier into a third-party crash record for every user forever. A stack
/// trace is what fixes a bug; who hit it is not.
Future<void> _startCrashReporting() async {
  try {
    // Nothing from a development machine. A dashboard full of crashes from
    // hot reload and a half-written screen is how the real ones become
    // unfindable, and every one of them would also count against the issue
    // list the store release is judged on.
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    final present = FlutterError.onError;
    FlutterError.onError = (details) {
      // The previous handler is kept rather than replaced: it is what prints
      // the error to the console and draws the red screen in debug, and a
      // silent debug build is a worse trade than a duplicated report.
      present?.call(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      // Handled, so the engine does not also print it. Returning false here
      // would double-report every one of them.
      return true;
    };
  } catch (error) {
    // Crash reporting that cannot start must not be the thing that stops the
    // app starting.
    debugPrint('crash reporting unavailable: $error');
  }
}

/// Attests that requests are coming from this app, on a real device.
///
/// The Firebase API key ships in every binary and is meant to — it identifies
/// the project, it is not a secret. What that means without App Check is that
/// anyone who unzips the APK can create accounts against this project and call
/// the Worker, and every one of those accounts gets its own scan quota against
/// a real model bill. `spend.ts` caps the day's total, so the damage is bounded
/// rather than unbounded, but a bounded bill someone else chose to spend is
/// still not a good place to be.
///
/// **Non-fatal by design, in both directions.** A device that cannot attest —
/// no Play Services, a rooted phone, an emulator — must still be able to use
/// the app; refusing would turn an anti-abuse measure into a support queue. So
/// this never throws, and enforcement is a switch in the Firebase console
/// rather than a property of the client:
///
///   1. Firebase console -> App Check -> register the Android app with Play
///      Integrity and the iOS app with App Attest.
///   2. Watch the metrics until the "verified" share settles.
///   3. Only then turn enforcement on, per API.
///
/// Turning it on before step 2 locks out whatever share of real devices cannot
/// attest, and that number is only knowable by measuring it.
Future<void> _startAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      // Debug providers, in debug builds only. They print a token to the log
      // that has to be pasted into the console — without them nothing attests
      // on an emulator and every call would fail once enforcement is on.
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      // App Attest needs iOS 14; the deployment target is 15, so the fallback
      // is only reached if Apple ever cannot attest, and Device Check is the
      // right answer there rather than nothing.
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (error) {
    debugPrint('App Check unavailable: $error');
  }
}

/// Shown instead of the app when the configured backend could not start.
///
/// Deliberately not a crash: a crash tells the user nothing and tells you only
/// that it crashed. This names the cause, which is always a build or config
/// problem rather than anything the person holding the phone did.
const String _noFirebase =
    'This build is missing its Firebase configuration, so it has no way to '
    'reach your account or analyse a meal. Reinstalling from the store should '
    'fix it.';

const String _noWorkerUrl =
    'This build was made without its server address, so it cannot analyse a '
    'meal or build a plan. Reinstalling from the store should fix it.';

class _MisconfiguredApp extends StatelessWidget {
  const _MisconfiguredApp({required this.reason});

  /// Which piece is missing, in words the person holding the phone can act on.
  /// Both causes are build mistakes; neither is anything they did.
  final String reason;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Carbs AI can’t start',
                  style: AppTypography.authTitle(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  reason,
                  style: AppTypography.body(color: AppColors.placeholder),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CarbsaiApp extends StatelessWidget {
  const CarbsaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carbs AI',
      // So a screen holding a camera can tell when another route covers it.
      // See [appRouteObserver].
      navigatorObservers: [appRouteObserver],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: AppTypography.fontFamily,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accentGreen,
          brightness: Brightness.dark,
          surface: AppColors.background,
        ),

        // Every message the app shows — a meal logged, a favourite saved, a
        // deletion that failed — went through Material's default snack bar:
        // light grey with dark text, floating over a black app in a typeface
        // nothing else uses. It read as a system message rather than as this
        // app talking.
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.inkMuted,
          contentTextStyle: AppTypography.socialLabel(color: AppColors.white),
          actionTextColor: AppColors.primary,
          insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.outline),
          ),
          elevation: 0,
        ),

        // Dialogs and sheets take the app's own surface for the same reason.
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.inkMuted,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.inkMuted,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const AppRoot(),
    );
  }
}

/// The pre-session stages. Past [_Stage.ready] the screen is decided by whether
/// anyone is signed in, not by this enum.
enum _Stage { splash, onboarding, ready }

/// Top-level flow: splash → onboarding (first launch only) → auth → the
/// signed-in shell.
///
/// Splash and onboarding are local stages because they are one-way and carry no
/// session meaning. Everything after them is derived from [authStateProvider],
/// so signing out anywhere in the app returns here without a callback chain.
class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> with WidgetsBindingObserver {
  _Stage _stage = _Stage.splash;

  /// When the app last went to the background. See
  /// [didChangeAppLifecycleState].
  DateTime? _leftAt;

  /// Whether the personalisation quiz has been dealt with, either way.
  ///
  /// Read on every build rather than latched in `initState`. Deleting an
  /// account clears the flag, and a latched copy meant the next sign-up in the
  /// same session was never asked — and quietly took the default 2000 kcal
  /// target the quiz exists to replace. The read is a cached preferences
  /// lookup, so there is nothing to save by holding it.
  bool get _quizSeen => ref.read(jsonStoreProvider).flag(StoreKeys.quizSeen);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Show the app-open ad when the app comes back to the foreground.
  ///
  /// Not on the very first launch: that is the splash, then onboarding, then a
  /// sign-in — putting a full-screen ad in front of someone who has not yet
  /// seen the app is the fastest way to lose them, and Google's own guidance
  /// says not to. The service also rate-limits itself, so switching out to the
  /// camera and back does not cost an ad.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _leftAt = DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    if (_stage != _Stage.ready) return;
    if (ref.read(authStateProvider).value == null) return;

    // How long the app was actually away, so a two-second system dialog is not
    // mistaken for someone opening the app. Null on the first resume of a
    // launch, which the service treats as "not an app-open" — the ad is for
    // *returning*, and there is nothing to return from yet.
    final leftAt = _leftAt;
    _leftAt = null;
    ref.read(adsServiceProvider).showAppOpenIfReady(
          awayFor: leftAt == null
              ? Duration.zero
              : DateTime.now().difference(leftAt),
        );
  }

  /// Splash is done. Returning users skip the carousel.
  void _afterSplash() {
    final seen = ref.read(jsonStoreProvider).flag(StoreKeys.onboardingSeen);
    setState(() => _stage = seen ? _Stage.ready : _Stage.onboarding);
  }

  /// The quiz is answered or skipped. Recorded so it is asked once, not every
  /// launch — skipping is a valid answer and leaves the default targets.
  Future<void> _completeQuiz() async {
    await ref.read(jsonStoreProvider).setFlag(StoreKeys.quizSeen, value: true);
    if (mounted) setState(() {});
  }

  Future<void> _completeOnboarding() async {
    await ref
        .read(jsonStoreProvider)
        .setFlag(StoreKeys.onboardingSeen, value: true);
    if (mounted) setState(() => _stage = _Stage.ready);
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.splash:
        return SplashScreen(onFinished: _afterSplash);
      case _Stage.onboarding:
        return OnboardingScreen(onFinished: _completeOnboarding);
      case _Stage.ready:
        final auth = ref.watch(authStateProvider);
        return auth.when(
          // Restoring the stored session takes a frame or two. Holding the
          // splash artwork over it avoids a flash of the login screen for
          // someone who is already signed in.
          loading: () => const SplashScreen(),
          error: (_, _) => const _AuthFlow(),
          data: (user) {
            if (user == null) return const _AuthFlow();

            // The quiz stands between signing in and the app only while the
            // profile cannot produce a real calorie target. Without it every
            // account counts against the same 2000 kcal, which is the one
            // number the whole app is built around.
            if (!_quizSeen) {
              final profile = ref.watch(profileProvider).value;
              if (profile == null) return const SplashScreen();
              if (!profile.canPersonaliseTargets) {
                return OnboardingQuizScreen(onFinished: _completeQuiz);
              }
            }
            return const MainShell();
          },
        );
    }
  }
}

/// Log in, and everything reachable from it.
///
/// `VerificationScreen` and `ResetPasswordScreen` are intentionally not
/// reachable from here at the moment — both need the email-code Cloud Function
/// that is parked. They are still built and tested; wiring them back is a
/// matter of restoring the two pushes this file used to make.
class _AuthFlow extends StatelessWidget {
  const _AuthFlow();

  Future<void> _push(BuildContext context, Widget screen) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  /// Signing in rebuilds [AppRoot] from the auth stream, which replaces this
  /// whole subtree. Any screens pushed on top of it have to come off first.
  void _dismissTo(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => LoginScreen(
        onLoggedIn: () => _dismissTo(context),
        onSignUp: () => _push(
          context,
          Builder(
            builder: (c) => SignUpScreen(
              onBack: () => Navigator.of(c).pop(),
              onLogIn: () => Navigator.of(c).pop(),
              // Straight into the app. Signing up already signs you in, so the
              // account exists and works from this moment; the verification
              // screen used to sit in front of that and could not be satisfied
              // — its code comes from a Cloud Function that is not deployed —
              // which left people signed in but trapped in the sign-up flow.
              //
              // Email verification is parked, not abandoned: see the OTP
              // section in CLAUDE.md.
              onSignedUp: (_) => _dismissTo(c),
            ),
          ),
        ),
        onForgotPassword: () => _push(
          context,
          Builder(
            builder: (c) => ForgotPasswordScreen(
              onBack: () => Navigator.of(c).pop(),
              // Firebase emails a reset LINK, not a code, and the password is
              // then changed in the browser. The six-box code screen and the
              // in-app reset form cannot serve that flow, so this confirms and
              // returns to log in rather than opening screens that dead-end.
              onSent: (email) => showToast(
                c,
                'Password reset link sent to $email.',
                tone: ToastTone.success,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
