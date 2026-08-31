import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_typography.dart';
import 'auth_controller.dart';
import 'widgets/auth_widgets.dart';

/// Log in — Figma frames `05_Log in-Default` (2002:1949),
/// `06_Log in-Error` (2002:1927), `07_Log in-Active` (2002:1905) and
/// `08_Log in-Fill` (2002:1883).
///
/// Those four artboards are states of one screen, not four screens: default
/// grey borders, red borders with inline messages, a white border on the
/// focused field, and filled values. They are reproduced here as real focus
/// and validation states rather than as separate layouts.
///
/// Two departures from the file, both deliberate:
///  * The mocked status bar and home indicator are omitted so the OS draws its
///    own, as on the other screens.
///  * Validation messages are set in Space Grotesk. The design specifies
///    Satoshi for those two strings only — the single place in all 47 frames
///    that leaves Space Grotesk — which reads as an oversight rather than an
///    intent worth bundling a second family for.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.onSignUp,
    this.onForgotPassword,
    this.onLoggedIn,
  });

  final VoidCallback? onSignUp;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onLoggedIn;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Empty-field checks stay local so the two inline messages the error
  /// artboard shows appear without a round trip. Anything the repository
  /// rejects — malformed address, short password — comes back as a single
  /// message under the field it belongs to.
  Future<void> _submit() async {
    setState(() {
      _emailError = _email.text.trim().isEmpty ? 'Please enter your email' : null;
      _passwordError =
          _password.text.isEmpty ? 'Please enter your password' : null;
    });
    if (_emailError != null || _passwordError != null) return;

    final controller = ref.read(authControllerProvider.notifier);
    final ok = await controller.signIn(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      widget.onLoggedIn?.call();
    } else {
      setState(() {
        final message = controller.errorMessage;
        // 'weak-password' is the only failure that belongs under the password
        // field; everything else reads as an address problem.
        final aboutPassword =
            (ref.read(authControllerProvider).error as RepositoryException?)
                    ?.code ==
                'weak-password';
        _emailError = aboutPassword ? null : message;
        _passwordError = aboutPassword ? message : null;
      });
    }
  }

  Future<void> _submitProvider(Future<bool> Function() signIn) async {
    final ok = await signIn();
    if (!mounted) return;
    if (ok) {
      widget.onLoggedIn?.call();
    } else {
      setState(() {
        _emailError = ref.read(authControllerProvider.notifier).errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        // The artboard is a fixed composition; resizing it around the keyboard
        // would move the pinned CTA away from its designed position.
        // The keyboard must be allowed to shrink the viewport.
        //
        // With this false — which is what fidelity to the artboard wanted — the
        // canvas keeps its full height behind the keyboard and the submit
        // button, which the design pins near the bottom, becomes physically
        // unreachable while typing. Letting the viewport shrink makes
        // DesignCanvas taller than its space, which turns it into a scroll, so
        // the button is always reachable.
        resizeToAvoidBottomInset: true,
        body: DesignCanvas(
          background: AppColors.background,
          children: [
            // Figma reports these two boxes as 321pt wide, but both text
            // nodes are textAutoResize: WIDTH_AND_HEIGHT — the box is sized to
            // the text in *Figma's* cut of Space Grotesk. Ours sets ~6% wider
            // (see the font note in the project README), so honouring 321 wraps
            // the title and drops "Carbsai". Left-aligned text does not move
            // when the box grows, so both are given the artboard's full content
            // width instead.
            const Positioned(
              left: 20,
              top: 135,
              width: 388,
              height: 42,
              child: _Title('Welcome Back to Carbsai'),
            ),
            const Positioned(
              left: 20,
              top: 181,
              width: 388,
              height: 25,
              child: _Subtitle('Eat better. Get back on track.'),
            ),

            // Everything from the email label down to the Apple button is one
            // auto-layout column in Figma, anchored at y=254. Laying it out as
            // a Column is what reproduces the 46pt downward shift the error
            // artboard shows when both fields are invalid.
            Positioned(
              left: 20,
              top: 254,
              width: 388,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    label: 'Email',
                    hint: 'Enter Email',
                    controller: _email,
                    errorText: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  AuthTextField(
                    label: 'Password',
                    hint: 'Enter Password',
                    controller: _password,
                    errorText: _passwordError,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 25,
                    child: GestureDetector(
                      onTap: widget.onForgotPassword,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'Forgot Password?',
                        style: AppTypography.body(),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const OrDivider(),
                  const SizedBox(height: 32),
                  SocialButton(
                    icon: 'assets/images/auth/icon_google.png',
                    label: 'Continue with Google',
                    onPressed: busy
                        ? null
                        : () => _submitProvider(
                              ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithGoogle,
                            ),
                  ),
                  const SizedBox(height: 20),
                  SocialButton(
                    icon: 'assets/images/auth/icon_apple.png',
                    label: 'Continue with Apple',
                    onPressed: busy
                        ? null
                        : () => _submitProvider(
                              ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithApple,
                            ),
                  ),
                ],
              ),
            ),

            // Pinned to the artboard bottom: unlike the form above it, this
            // block stays at y=761 in every state.
            Positioned(
              left: 20,
              top: 761,
              width: 388,
              height: 50,
              child: PrimaryButton(
                label: 'Log In',
                onPressed: _submit,
                busy: busy,
              ),
            ),
            Positioned(
              left: 20,
              top: 835,
              width: 388,
              height: 25,
              child: AuthFooterLink(
                text: 'Don’t have an account? ',
                actionText: 'Sign Up',
                onTap: widget.onSignUp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.authTitle());
}

class _Subtitle extends StatelessWidget {
  const _Subtitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.body());
}
