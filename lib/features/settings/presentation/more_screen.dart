import 'package:flutter/material.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/theme/app_colors.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';
import 'widgets/settings_widgets.dart';

/// More — Figma frames `42_More` (2002:827) and `46_Delete Account`
/// (2002:738). Frame 46 is this screen with the delete confirmation over it.
class MoreScreen extends StatefulWidget {
  const MoreScreen({
    super.key,
    this.showDeleteConfirm = false,
    this.onBack,
    this.onOpen,
    this.onDelete,
  });

  final bool showDeleteConfirm;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpen;
  final VoidCallback? onDelete;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  late bool _confirming = widget.showDeleteConfirm;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DesignCanvas(
        background: AppColors.background,
        children: [
          PremiumTopBar(title: 'More', onBack: widget.onBack),
          Positioned(
            left: 20,
            top: 147,
            width: 388,
            child: SettingsCard(
              children: [
                SettingsRow(
                  label: 'Terms and Conditions',
                  onTap: () => widget.onOpen?.call('terms'),
                ),
                SettingsRow(
                  label: 'Privacy Policy',
                  onTap: () => widget.onOpen?.call('privacy'),
                ),
                SettingsRow(label: 'Help', onTap: () => widget.onOpen?.call('help')),
              ],
            ),
          ),
          Positioned(
            left: 20,
            top: 342,
            width: 388,
            child: SettingsCard(
              children: [
                SettingsRow(
                  label: 'Delete Account',
                  onTap: () => setState(() => _confirming = true),
                ),
              ],
            ),
          ),
          if (_confirming)
            ConfirmDialog(
              title: 'Are you sure you want \nto delete account?',
              body: 'Permanently remove your data and close your Carbsai '
                  'account.',
              secondaryLabel: 'Cancel',
              primaryLabel: 'Delete',
              onSecondary: () => setState(() => _confirming = false),
              onPrimary: widget.onDelete,
            ),
        ],
      ),
    );
  }
}
