import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_widgets.dart';

/// Email verification — Figma frames `09_Verification` (2002:1859) and
/// `15_Verification` (2002:1774).
///
/// Those two artboards are byte-identical apart from the frame name; the file
/// carries one copy per entry point (sign up and password reset). This is the
/// single screen behind both.
///
/// The artboards also mock an iOS keyboard at y=635. That is omitted, as with
/// the status bar, so the real keyboard is what appears.
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({
    super.key,
    required this.email,
    this.onBack,
    this.onVerified,
    this.initialCode,
    this.autoSend = true,
  });

  final String email;
  final VoidCallback? onBack;
  final VoidCallback? onVerified;

  /// Sends a code as soon as the screen appears. Off for tests and previews,
  /// which have no server to ask.
  final bool autoSend;

  /// Seeds the code cells. Used by the design-comparison test to reproduce the
  /// artboard's "856346".
  final String? initialCode;

  @override
  ConsumerState<VerificationScreen> createState() =>
      _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  late final TextEditingController _code =
      TextEditingController(text: widget.initialCode ?? '');
  final FocusNode _focus = FocusNode();

  /// The artboard has no error state for a bad code, so messages go under the
  /// "Didn't receive code?" line rather than inventing a field treatment.
  /// Confirmations land in the same place, tinted differently.
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    // Send on arrival, unless a code was seeded for a test or preview.
    if (widget.initialCode == null && widget.autoSend) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(initial: true));
    }
  }

  /// Asks the server for a code. The server throttles, so a rejected resend
  /// reports the wait rather than silently doing nothing.
  Future<void> _send({bool initial = false}) async {
    final controller = ref.read(authControllerProvider.notifier);
    final ok = await controller.sendEmailOtp();
    if (!mounted) return;
    setState(() {
      _error = ok ? null : controller.errorMessage;
      _notice = ok ? 'Code sent to ${widget.email}.' : null;
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final controller = ref.read(authControllerProvider.notifier);
    final ok = await controller.verifyCode(_code.text);
    if (!mounted) return;
    if (ok) {
      widget.onVerified?.call();
    } else {
      setState(() {
        _error = controller.errorMessage;
        _notice = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      onBack: widget.onBack,
      title: 'Verify Your Email Address',
      subtitle: 'Enter the code we’ve sent to\n${widget.email}',
      subtitleHeight: 50,
      children: [
        Positioned(
          left: 20,
          top: 279,
          width: 386,
          height: 51,
          child: OtpRow(controller: _code, focusNode: _focus),
        ),
        Positioned(
          left: 130,
          top: 362,
          width: 169,
          height: 25,
          child: Text(
            'Didn’t receive code?',
            style: AppTypography.body(),
            textAlign: TextAlign.center,
          ),
        ),
        Positioned(
          left: 130,
          top: 391,
          width: 169,
          height: 25,
          child: GestureDetector(
            onTap: busy ? null : () => _send(),
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Resend code',
              style: AppTypography.body(color: AppColors.primary)
                  .copyWith(decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: 553,
          width: 388,
          height: 50,
          child: PrimaryButton(
            label: 'Verify',
            onPressed: _verify,
            busy: busy,
          ),
        ),
        if (_error != null || _notice != null)
          Positioned(
            left: 20,
            top: 425,
            width: 388,
            height: 40,
            child: Text(
              _error ?? _notice!,
              style: _error != null
                  ? AppTypography.errorMessage()
                  : AppTypography.errorMessage(color: AppColors.accentGreen),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
