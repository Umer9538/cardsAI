import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/password_strength.dart';
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
    this.readOnly = false,
    this.inputFormatters,
    this.onTap,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final String? errorText;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Shows the value but refuses the caret. For a field that is a *fact about
  /// the account* rather than something the person is being asked for — see
  /// the email row on My Profile.
  final bool readOnly;

  /// What the field will physically accept. The cheapest validation there is:
  /// a height that cannot contain a letter never has to be rejected later.
  final List<TextInputFormatter>? inputFormatters;

  /// Makes the whole field a button — for a value that is *chosen* rather than
  /// typed, like a date or one of a fixed set. Pair with [readOnly], or the
  /// keyboard and the picker both open.
  final VoidCallback? onTap;

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

  /// Whether the characters are currently hidden.
  ///
  /// Starts at [AuthTextField.obscure] and is only ever reachable on a field
  /// that asked to be obscured, so the toggle cannot be used to hide an
  /// ordinary field.
  late bool _hidden = widget.obscure;

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
          // The right inset yields to the reveal toggle when there is one, so
          // the glyph sits where the 19pt gutter was rather than outside it.
          padding: EdgeInsets.only(left: 19, right: widget.obscure ? 4 : 19),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  readOnly: widget.readOnly,
                  inputFormatters: widget.inputFormatters,
                  onTap: widget.onTap,
                  // No caret and no keyboard on a read-only field: a caret that
                  // blinks in a box nothing can change is an invitation.
                  showCursor: !widget.readOnly,
                  enableInteractiveSelection: !widget.readOnly,
                  obscureText: _hidden,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: AppColors.white,
                  cursorWidth: 1,
                  style: AppTypography.body(
                    color: widget.readOnly && widget.onTap == null
                        ? AppColors.placeholder
                        : AppColors.white,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: AppTypography.body(color: AppColors.placeholder),
                  ),
                ),
              ),
              if (widget.obscure) _RevealToggle(
                hidden: _hidden,
                onTap: () => setState(() => _hidden = !_hidden),
              ),
            ],
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

/// The meter and checklist under a password someone is choosing.
///
/// Shown only once there is something to judge, so a freshly opened Sign Up is
/// still the artboard. That makes it the same shape as `ReminderTimesCard` —
/// invisible on a default render, therefore invisible to any test that does not
/// ask for it — so it takes the same [preview] escape hatch, and
/// `password_strength_test` renders it at the 1.15x text ceiling. A screen whose
/// full state no test can reach is how the search result row shipped 2pt over.
///
/// The checklist is the point rather than the bar. A bar says *no*; three rules
/// with ticks against them say what to do next, and the person can see the
/// first two land as they type.
class PasswordStrengthGuide extends StatelessWidget {
  const PasswordStrengthGuide({super.key, required this.check});

  final PasswordCheck check;

  /// Renders the guide for a made-up password, for tests and previews.
  static Widget preview() =>
      PasswordStrengthGuide(check: PasswordCheck.of('walnut-bridge-92'));

  Color get _meterColour => switch (check.strength) {
        PasswordStrength.unusable || PasswordStrength.weak => AppColors.error,
        PasswordStrength.fair => AppColors.accentOrange,
        PasswordStrength.good || PasswordStrength.strong => AppColors.accentGreen,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                // A bare box with no child inside a Row gets loose vertical
                // constraints and collapses to zero — the bug this codebase
                // has shipped three times. The height is explicit here, and
                // the test asserts it rendered.
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: ColoredBox(color: AppColors.controlMuted),
                      ),
                      FractionallySizedBox(
                        widthFactor: check.strength.fraction,
                        heightFactor: 1,
                        child: ColoredBox(color: _meterColour),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              check.strength.label,
              style: AppTypography.meta(color: _meterColour),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final rule in check.rules) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  rule.met ? Icons.check_circle : Icons.circle_outlined,
                  size: 14,
                  color: rule.met
                      ? AppColors.accentGreen
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.label,
                    style: AppTypography.meta(
                      color: rule.met
                          ? AppColors.accentGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The eye on a password field.
///
/// **Not in the design file** — the artboards draw a password as a row of dots
/// and stop there. Testers reported it missing, and they are describing the
/// thing every password field has had for a decade: without it the only way to
/// find a typo is to clear the field and start again, on a phone keyboard,
/// which is why people pick shorter passwords than they otherwise would.
///
/// A [Semantics] label rather than a bare glyph, because an icon with no text
/// near it does not exist to a screen reader — and it names the *action*
/// ("Show password"), not the state, since that is what a button's label is
/// for. 44pt square: the field is 50 tall, so this is the largest touch target
/// that fits inside it, and it is Apple's minimum rather than a coincidence.
class _RevealToggle extends StatelessWidget {
  const _RevealToggle({required this.hidden, required this.onTap});

  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: hidden ? 'Show password' : 'Hide password',
      // The action has to be declared on the node that carries the label.
      // `excludeSemantics` drops the GestureDetector's own tap action, so
      // without this the toggle announced itself as a button and then could
      // not be activated by anyone using a screen reader — a control that
      // describes itself and does nothing.
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.placeholder,
          ),
        ),
      ),
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
    final enabled = onPressed != null && !busy;

    return Semantics(
      button: true,
      enabled: enabled,
      // Spoken instead of the child, so a spinner is announced as "working"
      // rather than as nothing at all.
      label: busy ? '$label, working' : label,
      // Declared here, not only on the InkWell: `excludeSemantics` drops the
      // child's own tap action, so every primary CTA in the app — Log In,
      // Sign Up, Got it, Add to My Diet — announced itself as a button and
      // then could not be activated with TalkBack or VoiceOver. The glyphs
      // had labels; the buttons had no actions.
      onTap: busy ? null : onPressed,
      excludeSemantics: true,
      child: SizedBox(
        height: 50,
        child: Material(
          // A disabled button has to look disabled. This drew at full strength
          // whatever `onPressed` was, so "Add to My Diet" over an empty result
          // — a photo with no food in it, a search with nothing picked — read
          // as a live control that did nothing when tapped, which is
          // indistinguishable from the app being broken.
          //
          // Opacity rather than a second colour: the fill is an exact Figma
          // value and dimming it keeps one source of truth for the hue.
          color: enabled
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.38),
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    )
                  : Text(
                      label,
                      style: AppTypography.buttonLabel(
                        color: enabled
                            ? AppColors.white
                            : AppColors.white.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
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
              Image.asset(
                icon,
                width: 24,
                height: 24,
                filterQuality: FilterQuality.high,
              ),
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
    // The glyph is an exported image with no text anywhere near it, so without
    // this a screen reader announces nothing at all — the control simply does
    // not exist for anyone not looking at it.
    return Semantics(
      button: true,
      // A nullable callback must not render as a live control. These are
      // always wired in the app, but a screen that forgot to pass one would
      // otherwise ship a button that looks and announces exactly like a
      // working one and does nothing — which is the failure
      // `no_dead_controls_test` exists to make impossible.
      enabled: onTap != null,
      onTap: onTap,
      label: 'Back',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Image.asset(
          'assets/images/auth/back_button.png',
          width: 40,
          height: 40,
          filterQuality: FilterQuality.high,
        ),
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
