import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_widgets.dart';

/// Reset password — Figma frames `11_Reset Password` (2002:1838) and
/// `12_Reset Password` (2002:1826).
///
/// Frame 12 is frame 11 with a success dialog over it, so it is the same
/// screen with [_showSuccess] set rather than a second layout.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.onBack,
    this.onLogIn,
    this.showSuccessInitially = false,
  });

  final VoidCallback? onBack;
  final VoidCallback? onLogIn;

  /// Renders the frame-12 state directly. Used by the design-comparison test.
  final bool showSuccessInitially;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  String? _passwordError;
  String? _confirmError;
  late bool _showSuccess = widget.showSuccessInitially;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _passwordError = _password.text.isEmpty
          ? 'Please enter a new password'
          : null;
      _confirmError = _confirm.text != _password.text
          ? 'Passwords do not match'
          : (_confirm.text.isEmpty ? 'Please confirm your password' : null);
    });
    if (_passwordError != null || _confirmError != null) return;

    // The reset link already proved possession of the address, so there is no
    // current password to supply — the repository takes the new one twice.
    final controller = ref.read(authControllerProvider.notifier);
    final ok = await controller.changePassword(
      currentPassword: '',
      newPassword: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _showSuccess = true);
    } else {
      setState(() => _passwordError = controller.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      onBack: widget.onBack,
      title: 'Reset Your Password',
      subtitle: 'Enter a new password to regain access\nto your account.',
      subtitleHeight: 50,
      overlay: _showSuccess
          ? _PasswordChangedDialog(onLogIn: widget.onLogIn)
          : null,
      children: [
        Positioned(
          left: 20,
          top: 279,
          width: 388,
          child: AuthTextField(
            label: 'New Password',
            hint: 'Enter New Password',
            controller: _password,
            errorText: _passwordError,
            obscure: true,
            textInputAction: TextInputAction.next,
          ),
        ),
        Positioned(
          left: 20,
          top: 378,
          width: 388,
          child: AuthTextField(
            label: 'Confirm Password',
            hint: 'Enter Confirm Password',
            controller: _confirm,
            errorText: _confirmError,
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ),
        Positioned(
          left: 20,
          top: 810,
          width: 388,
          height: 50,
          child: PrimaryButton(
            label: 'Reset Password',
            onPressed: _submit,
            busy: busy,
          ),
        ),
      ],
    );
  }
}

/// Success overlay — Figma frame 12's `Background` scrim plus its `Message`
/// card.
///
/// The scrim is black at 50% *fill* opacity over a 6pt backdrop blur; the
/// node's colour alpha is 1, so reading only the colour makes it look solid.
class _PasswordChangedDialog extends StatelessWidget {
  const _PasswordChangedDialog({this.onLogIn});

  final VoidCallback? onLogIn;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // Kept self-contained with its own Material so the Text widgets never
      // fall back to the debug style if this is ever hosted outside a Scaffold.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
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
              // 262 is the artboard height and what this resolves to when the
              // copy fits two lines. Constraining rather than fixing it lets a
              // wider font cut wrap to three without overflowing the card.
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
                      'Password changed',
                      style: AppTypography.cardTitle(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your password has been updated! You can now log in '
                      'with your new credentials.',
                      style: AppTypography.socialLabel(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 226,
                      child: PrimaryButton(label: 'Log In', onPressed: onLogIn),
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
