import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../app/presentation/widgets/bottom_nav.dart';
import 'widgets/settings_widgets.dart';

/// Settings — Figma frames `33_Settings` (2002:981) and `47_Log out`
/// (2002:692).
///
/// Frame 47 is this screen with the log-out confirmation over it. Its
/// underlying list is laid out slightly differently in the file — 43pt row
/// spacing against 33's 55pt, and Legal folded into the same card — which
/// reads as drift between two copies of the same screen rather than intent.
/// This builds frame 33's version and puts the dialog on top; behind a 50%
/// scrim and a 6pt blur the difference is not visible.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.showLogOutConfirm = false,
    this.onNavSelected,
    this.onOpen,
    this.onLogOut,
  });

  /// Renders the frame-47 state.
  final bool showLogOutConfirm;

  final ValueChanged<AppTab>? onNavSelected;
  final ValueChanged<String>? onOpen;

  /// Called once the user confirms in the dialog.
  final VoidCallback? onLogOut;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _confirming = widget.showLogOutConfirm;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            DesignCanvas(
              background: AppColors.background,
              children: [
                Positioned(
                  left: 20,
                  top: 71,
                  width: 300,
                  height: 36,
                  child: Text('Settings', style: AppTypography.topBarTitle()),
                ),

                // Account card.
                Positioned(
                  left: 20,
                  top: 143,
                  width: 388,
                  height: 94,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.inkMuted,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.outline),
                    ),
                    padding: const EdgeInsets.all(19),
                    child: Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            profile?.avatar ?? 'assets/images/app/avatar.png',
                            width: 54,
                            height: 54,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(profile?.name ?? '',
                                  style: AppTypography.cardHeading()),
                              const SizedBox(height: 4),
                              Text(profile?.email ?? '',
                                  style: AppTypography.label()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  left: 20,
                  top: 261,
                  width: 388,
                  child: SettingsCard(
                    children: [
                      SettingsRow(
                        label: 'Profile',
                        onTap: () => widget.onOpen?.call('profile'),
                      ),
                      SettingsRow(
                        label: 'Change Password',
                        onTap: () => widget.onOpen?.call('password'),
                      ),
                      SettingsRow(
                        label: 'Notification',
                        onTap: () => widget.onOpen?.call('notifications'),
                      ),
                      SettingsRow(
                        // The artboard says "Payment Method"; the screen it
                        // opens is about the subscription, because the stores
                        // own the payment method and the app cannot show it.
                        label: 'Subscription',
                        onTap: () => widget.onOpen?.call('payment'),
                      ),
                      SettingsRow(
                        label: 'Favorite',
                        onTap: () => widget.onOpen?.call('favorites'),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 566,
                  width: 388,
                  child: SettingsCard(
                    children: [
                      SettingsRow(
                        label: 'More',
                        onTap: () => widget.onOpen?.call('more'),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 651,
                  width: 388,
                  child: SettingsCard(
                    children: [
                      SettingsRow(
                        label: 'Log Out',
                        onTap: () => setState(() => _confirming = true),
                      ),
                    ],
                  ),
                ),

                if (_confirming)
                  ConfirmDialog(
                    title: 'Are you sure you want \nto log out?',
                    body: 'Log out will remove your access to personalized '
                        'tracking and saved data until you log back in.',
                    secondaryLabel: 'Cancel',
                    primaryLabel: 'Log Out',
                    onSecondary: () => setState(() => _confirming = false),
                    onPrimary: widget.onLogOut,
                  ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 926 - AppBottomNav.top - AppBottomNav.height,
              child: Center(
                child: AppBottomNav(
                  current: AppTab.settings,
                  onSelect: widget.onNavSelected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
