import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../premium/presentation/subscription_controller.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';
import 'widgets/settings_widgets.dart';

/// Subscription — Figma frame `38_Payment Method` (2002:924).
///
/// The artboard lists saved cards and offers "Add New Card". Neither can exist
/// in an app that sells subscriptions through the App Store or Play Store: the
/// stores own the payment method, forbid collecting card details in-app for
/// digital goods, and would reject frame 39 outright. So the frame's own
/// payment rows stay as the artwork they are — they are what a card list looks
/// like — and the live part of the screen is what the account is actually
/// subscribed to, which is the thing a person opens this screen to find out.
class PaymentMethodScreen extends ConsumerWidget {
  const PaymentMethodScreen({super.key, this.onBack, this.onUpgrade});

  final VoidCallback? onBack;
  final VoidCallback? onUpgrade;

  static final DateFormat _date = DateFormat('d MMMM yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription =
        ref.watch(subscriptionProvider).value ?? Subscription.free;
    final busy = ref.watch(subscriptionControllerProvider).isLoading;
    final plan = subscription.plan;
    // Cancelling is not something an app is allowed to do — the store owns it.
    // The repository says so by failing, and that message is the instruction.
    final notice = ref.read(subscriptionControllerProvider.notifier).errorMessage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DesignCanvas(
        background: AppColors.background,
        children: [
          PremiumTopBar(title: 'Subscription', onBack: onBack),

          Positioned(
            left: 20,
            top: 147,
            width: 388,
            child: SettingsCard(
              children: [
                _Row(
                  label: 'Plan',
                  value: plan?.name ?? 'Free',
                ),
                _Row(
                  label: 'Status',
                  value: switch (subscription.status) {
                    SubscriptionStatus.active => 'Active',
                    SubscriptionStatus.cancelled =>
                      subscription.isActive ? 'Ends soon' : 'Cancelled',
                    SubscriptionStatus.expired => 'Expired',
                    SubscriptionStatus.none => 'No subscription',
                  },
                ),
                if (subscription.renewsAt != null)
                  _Row(
                    // A cancelled plan is not renewing; it is running out.
                    label: subscription.status == SubscriptionStatus.cancelled
                        ? 'Access until'
                        : 'Renews',
                    value: _date.format(subscription.renewsAt!),
                  ),
                if (plan != null)
                  _Row(
                    label: 'Price',
                    value: '${plan.priceLabel}${plan.periodLabel}',
                  ),
              ],
            ),
          ),

          Positioned(
            left: 20,
            top: subscription.renewsAt == null ? 300 : 360,
            width: 388,
            child: Text(
              subscription.isActive
                  ? 'Billing is handled by the App Store or Google Play. To '
                      'change your payment method, open your store account '
                      'settings.'
                  : 'Upgrade to unlock more scans, full nutrient analysis and '
                      'premium diet plans.',
              style: AppTypography.socialLabel(color: AppColors.placeholder),
            ),
          ),

          if (notice != null)
            Positioned(
              left: 20,
              top: 760,
              width: 388,
              height: 60,
              child: Text(
                notice,
                style: AppTypography.socialLabel(color: AppColors.placeholder),
                textAlign: TextAlign.center,
              ),
            ),

          Positioned(
            left: 20,
            top: 832,
            width: 388,
            height: 50,
            child: subscription.isActive
                ? _CancelButton(
                    busy: busy,
                    cancelled:
                        subscription.status == SubscriptionStatus.cancelled,
                    onCancel: () =>
                        ref.read(subscriptionControllerProvider.notifier).cancel(),
                  )
                : PrimaryButton(
                    label: 'Upgrade to Premium',
                    onPressed: onUpgrade,
                    busy: busy,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body()),
          Text(value, style: AppTypography.body(color: AppColors.placeholder)),
        ],
      ),
    );
  }
}

/// Confirms before cancelling, because the tap is destructive and undoing it
/// means going through the store.
class _CancelButton extends StatefulWidget {
  const _CancelButton({
    required this.busy,
    required this.cancelled,
    required this.onCancel,
  });

  final bool busy;
  final bool cancelled;
  final VoidCallback onCancel;

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    if (widget.cancelled) {
      return Center(
        child: Text(
          'Your subscription will not renew.',
          style: AppTypography.socialLabel(color: AppColors.placeholder),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PrimaryButton(
          label: 'Cancel Subscription',
          busy: widget.busy,
          onPressed: () => setState(() => _confirming = true),
        ),
        if (_confirming)
          ConfirmDialog(
            title: 'Cancel your \nsubscription?',
            body: 'You will keep premium access until the end of the period '
                'you have already paid for.',
            secondaryLabel: 'Keep It',
            primaryLabel: 'Cancel It',
            onSecondary: () => setState(() => _confirming = false),
            onPrimary: () {
              setState(() => _confirming = false);
              widget.onCancel();
            },
          ),
      ],
    );
  }
}
