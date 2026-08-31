import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';

/// Grouped card behind the settings lists — #232220 at radius 24 on a 1pt
/// #2F2F2F outline with 20pt padding.
///
/// Insets are 19, not 20: Flutter puts a Border outside the padding box while
/// Figma strokes inside, so honouring 20 makes every card 2pt too tall.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children, this.gap = 30});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inkMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      padding: const EdgeInsets.all(19),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) SizedBox(height: gap),
            child,
          ],
        ],
      ),
    );
  }
}

/// A 25pt row: label on the left, 20pt chevron hard right.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 25,
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.body())),
            Image.asset(
              'assets/images/app/chevron_row.png',
              width: 20,
              height: 20,
              filterQuality: FilterQuality.high,
            ),
          ],
        ),
      ),
    );
  }
}

/// A 25pt row with a 40x22 switch hard right.
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 25,
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.body())),
            // Exported at 46x34 because the switch carries a drop shadow;
            // drawn at that size and offset so the 40x22 body lands correctly.
            SizedBox(
              width: 40,
              height: 22,
              child: OverflowBox(
                minWidth: 46,
                maxWidth: 46,
                minHeight: 34,
                maxHeight: 34,
                child: Image.asset(
                  value
                      ? 'assets/images/app/toggle_on.png'
                      : 'assets/images/app/toggle_off.png',
                  width: 46,
                  height: 34,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal confirmation — Figma's `Background` scrim plus its `Message` card.
///
/// Frames 36, 46 and 47 all use it; 36 has a single button, the destructive
/// ones pair a Cancel with the confirming action.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.secondaryLabel,
    this.onPrimary,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final String? secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Black at 50% fill opacity over a 6pt backdrop blur.
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
              child: Container(
                constraints: const BoxConstraints(minHeight: 262),
                decoration: BoxDecoration(
                  color: AppColors.inkMuted,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.outline),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 31,
                  vertical: 39,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: AppTypography.cardTitle(),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Text(body,
                        style: AppTypography.socialLabel(),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    if (secondaryLabel == null)
                      SizedBox(
                        width: 226,
                        child: PrimaryButton(
                          label: primaryLabel,
                          onPressed: onPrimary,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _GhostButton(
                              label: secondaryLabel!,
                              onPressed: onSecondary,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: PrimaryButton(
                              label: primaryLabel,
                              onPressed: onPrimary,
                            ),
                          ),
                        ],
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

/// Outlined companion to [PrimaryButton], used for Cancel in the destructive
/// dialogs. Figma strokes it #FF5A16 and sets its label the same colour — not
/// the neutral outline the rest of the app uses.
class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.primary),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: AppTypography.buttonLabel(color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}
