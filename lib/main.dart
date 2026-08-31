import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/main_shell.dart';
import 'core/ads/ads_providers.dart';
import 'core/app_config.dart';
import 'core/providers/providers.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'data/local/json_store.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/sign_up_screen.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opening the store is the one piece of async setup the whole app needs, so
  // it happens before the first frame and is injected rather than awaited
  // inside a provider. That keeps every repository construction synchronous.
  final store = await JsonStore.open();
  final backend = await _startBackend();

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
/// worth a crash on the splash screen when there is a working offline mode a
/// line away — but they must be loud in debug, because silently running local
/// while believing you are on Firebase is a confusing way to lose an afternoon.
Future<AppBackend> _startBackend() async {
  if (AppConfig.backend == AppBackend.local) return AppBackend.local;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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

class CarbsaiApp extends StatelessWidget {
  const CarbsaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carbsai',
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
    if (state != AppLifecycleState.resumed) return;
    if (_stage != _Stage.ready) return;
    if (ref.read(authStateProvider).value == null) return;
    ref.read(adsServiceProvider).showAppOpenIfReady();
  }

  /// Splash is done. Returning users skip the carousel.
  void _afterSplash() {
    final seen = ref.read(jsonStoreProvider).flag(StoreKeys.onboardingSeen);
    setState(() => _stage = seen ? _Stage.ready : _Stage.onboarding);
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
          data: (user) => user == null ? const _AuthFlow() : const MainShell(),
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
              onSent: (email) => ScaffoldMessenger.of(c).showSnackBar(
                SnackBar(
                  content: Text('Password reset link sent to $email.'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
