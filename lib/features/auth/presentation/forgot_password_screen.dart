import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_widgets.dart';

/// Forgot password — Figma frame `10_Forgot Password` (2002:1848).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.onBack, this.onSent});

  final VoidCallback? onBack;
  /// Receives the address the link went to, so the next screen can show it.
  final ValueChanged<String>? onSent;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _email = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = _email.text.trim().isEmpty ? 'Please enter your email' : null;
    });
    if (_error != null) return;

    final controller = ref.read(authControllerProvider.notifier);
    final ok = await controller.sendPasswordReset(_email.text);
    if (!mounted) return;
    if (ok) {
      widget.onSent?.call(_email.text.trim());
    } else {
      setState(() => _error = controller.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      onBack: widget.onBack,
      title: 'Forgot Your Password?',
      subtitle: 'No worries! Enter your email, and we’ll \n'
          'send you a reset link.',
      subtitleHeight: 50,
      children: [
        Positioned(
          left: 20,
          top: 279,
          width: 388,
          child: AuthTextField(
            label: 'Email',
            hint: 'Enter Email',
            controller: _email,
            errorText: _error,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ),
        Positioned(
          left: 20,
          top: 759,
          width: 388,
          height: 50,
          child: PrimaryButton(
            label: 'Send Reset Link',
            onPressed: _submit,
            busy: busy,
          ),
        ),
        Positioned(
          left: 20,
          top: 833,
          width: 388,
          height: 27,
          child: GestureDetector(
            onTap: widget.onBack,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Back to Login',
              style: AppTypography.buttonLabel(color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
