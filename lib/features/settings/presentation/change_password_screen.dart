import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';
import '../../../core/repositories/repositories.dart';
import '../../auth/presentation/auth_controller.dart';
import 'widgets/settings_widgets.dart';

/// Change password — Figma frames `35_Change Password` (2002:959) and
/// `36_Password Changed` (2002:950). Frame 36 is this screen with the
/// confirmation over it.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({
    super.key,
    this.showSuccess = false,
    this.onBack,
    this.onDone,
  });

  final bool showSuccess;
  final VoidCallback? onBack;
  final VoidCallback? onDone;

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late bool _success = widget.showSuccess;

  String? _currentError;
  String? _passwordError;
  String? _confirmError;

  /// Firebase requires a recent sign-in to change a password, and satisfying
  /// that by re-authenticating with the current one is less disruptive than
  /// bouncing someone back to the login screen. The artboard has only two
  /// fields; this adds the one it is missing rather than failing at the server.
  Future<void> _save() async {
    setState(() {
      _currentError =
          _current.text.isEmpty ? 'Enter your current password' : null;
      _passwordError =
          _password.text.isEmpty ? 'Enter a new password' : null;
      _confirmError = _confirm.text != _password.text
          ? 'Passwords do not match'
          : (_confirm.text.isEmpty ? 'Confirm your new password' : null);
    });
    if (_currentError != null ||
        _passwordError != null ||
        _confirmError != null) {
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    final ok = await controller.changePassword(
      currentPassword: _current.text,
      newPassword: _password.text,
    );
    if (!mounted) return;

    if (ok) {
      setState(() => _success = true);
    } else {
      setState(() {
        final code =
            (ref.read(authControllerProvider).error as RepositoryException?)
                ?.code;
        final message = controller.errorMessage;
        // A rejected re-authentication belongs under the current-password
        // field; anything else is about the new one.
        final aboutCurrent = code == 'wrong-password' ||
            code == 'invalid-credential' ||
            code == 'requires-recent-login';
        _currentError = aboutCurrent ? message : null;
        _passwordError = aboutCurrent ? null : message;
      });
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
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
          PremiumTopBar(title: 'Change Password', onBack: widget.onBack),
          // The artboard puts New Password at 155 and Confirm at 254. Current
          // Password takes the first slot and the other two shift down by the
          // same 99pt step the design already uses between fields.
          Positioned(
            left: 20,
            top: 155,
            width: 388,
            child: AuthTextField(
              label: 'Current Password',
              hint: 'Enter Current Password',
              controller: _current,
              errorText: _currentError,
              obscure: true,
              textInputAction: TextInputAction.next,
            ),
          ),
          Positioned(
            left: 20,
            top: 254,
            width: 388,
            child: AuthTextField(
              label: 'New Password',
              hint: 'Enter Password',
              controller: _password,
              errorText: _passwordError,
              obscure: true,
              textInputAction: TextInputAction.next,
            ),
          ),
          Positioned(
            left: 20,
            top: 353,
            width: 388,
            child: AuthTextField(
              label: 'Confirm Password',
              hint: 'Confirm New Password',
              controller: _confirm,
              errorText: _confirmError,
              obscure: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
          ),
          Positioned(
            left: 20,
            top: 810,
            width: 388,
            height: 50,
            child: PrimaryButton(
              label: 'Save',
              onPressed: _save,
              busy: busy,
            ),
          ),
          if (_success)
            ConfirmDialog(
              title: 'Password changed',
              body: 'Congratulation! Your password \nhas been updated!',
              primaryLabel: 'Go Back',
              onPrimary: widget.onDone,
            ),
        ],
      ),
    );
  }
}
