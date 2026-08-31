import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Shared building blocks for the auth artboards (Figma frames 05–15).
///
/// Metrics come from the `Master Input/With title` and `Button` components in
/// the design file, so they are defined once here rather than per screen.

/// Labelled text field — Figma `Master Input/With title`.
///
/// Layout inside the group: 25pt label, 4pt gap, 50pt field, and when a
/// validation message is present another 4pt gap and an 18pt message. That
/// message is what shifts the rest of the form down 23pt per errored field in
/// the `06_Log in-Error` artboard.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.errorText,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? errorText;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  static const double fieldHeight = 50;
  static const double labelHeight = 25;
  static const double labelGap = 4;
  static const double messageGap = 4;
  static const double messageHeight = 18;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Grey by default, white while focused, red whenever a message is showing —
  /// the three border treatments across frames 05, 06 and 07.
  Color get _borderColor {
    if (widget.errorText != null) return AppColors.error;
    if (_focus.hasFocus) return AppColors.white;
    return AppColors.outline;
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: AuthTextField.labelHeight,
          child: Text(widget.label, style: AppTypography.body()),
        ),
        const SizedBox(height: AuthTextField.labelGap),
        Container(
          height: AuthTextField.fieldHeight,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          // Field text sits at x=40 on an artboard where the field starts at
          // x=20, so 20 minus the 1pt border.
          padding: const EdgeInsets.symmetric(horizontal: 19),
          alignment: Alignment.center,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            cursorColor: AppColors.white,
            cursorWidth: 1,
            style: AppTypography.body(),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: AppTypography.body(color: AppColors.placeholder),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AuthTextField.messageGap),
          SizedBox(
            height: AuthTextField.messageHeight,
            child: Text(error, style: AppTypography.errorMessage()),
          ),
        ],
      ],
    );
  }
}

/// Filled CTA — Figma `Button` at 388x50, radius 12, fill #FF5A16.
///
/// The design carries no busy state. [busy] swaps the label for a spinner and
/// blocks the tap, keeping the fill and geometry identical so the button does
/// not move or resize mid-request.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  )
                : Text(
                    label,
                    style: AppTypography.buttonLabel(),
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Provider sign-in button — Figma `Button` at 388x50, radius 12, fill #2F2F2F,
/// with a 24pt icon and a 12pt gap before the label, the pair centred together.
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Material(
        color: AppColors.outline,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(icon, width: 24, height: 24, filterQuality: FilterQuality.high),
              const SizedBox(width: 12),
              Text(label, style: AppTypography.socialLabel()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hairline rule with a centred "Or" chip that masks the line behind it —
/// Figma `Divider Container`, 19pt tall with the rule at its vertical centre.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 19,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Divider(color: AppColors.outline, height: 1, thickness: 1),
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('Or', style: AppTypography.divider()),
          ),
        ],
      ),
    );
  }
}

/// A sentence whose trailing clause is tappable and tinted, e.g.
/// "Don't have an account? Sign Up".
///
/// Figma stores this as one text node with a character-level override on the
/// action run (`styleOverrideTable`), which a node's top-level `fills` does not
/// reveal — the action is #FF5A16, not the white the node reports.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.text,
    required this.actionText,
    this.onTap,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final String actionText;
  final VoidCallback? onTap;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text.rich(
        TextSpan(
          text: text,
          style: AppTypography.body(),
          children: [
            TextSpan(
              text: actionText,
              style: AppTypography.body(color: AppColors.primary),
            ),
          ],
        ),
        textAlign: textAlign,
      ),
    );
  }
}

/// Circular back affordance — Figma `Back Button`: a 40pt #232220 disc with a
/// 20pt arrow-left glyph. Exported whole rather than redrawn, because the
/// nested icon instance cannot be exported on its own.
class BackCircleButton extends StatelessWidget {
  const BackCircleButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        'assets/images/auth/back_button.png',
        width: 40,
        height: 40,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// One cell of the verification code row — Figma `Number Container`:
/// 51x51, radius 8, 1pt #232220 border.
class OtpBox extends StatelessWidget {
  const OtpBox({super.key, required this.digit});

  final String digit;

  static const double size = 51;
  static const double gap = 16;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.inkMuted),
      ),
      child: Text(digit, style: AppTypography.body()),
    );
  }
}

/// Six-cell code entry backed by a single hidden field, so the OS keyboard and
/// SMS autofill work normally while the cells stay purely presentational.
class OtpRow extends StatelessWidget {
  const OtpRow({
    super.key,
    required this.controller,
    required this.focusNode,
    this.length = 6,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return Row(
              children: [
                for (var i = 0; i < length; i++) ...[
                  if (i > 0) const SizedBox(width: OtpBox.gap),
                  OtpBox(digit: i < value.text.length ? value.text[i] : ''),
                ],
              ],
            );
          },
        ),
        // Invisible but focusable: gives the row a real text connection
        // without drawing a second caret over the cells.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              maxLength: length,
              showCursor: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
