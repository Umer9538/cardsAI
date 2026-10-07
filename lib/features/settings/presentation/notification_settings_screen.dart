import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/notifications/notification_category.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';
import 'widgets/reminder_times_card.dart';
import 'widgets/water_reminder_card.dart';
import 'widgets/weigh_in_card.dart';
import 'widgets/settings_widgets.dart';

/// Notification preferences — Figma frame `37_Notification` (2002:933).
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  /// The artboard's four rows, in order.
  ///
  /// [NotificationCategory] owns both the label and the key it is stored
  /// under, so a row can no longer drift from the preference it writes — the
  /// previous literal list paired `weeklySummary` with "Goal Milestone
  /// Notifications" and nothing read either.
  static const List<NotificationCategory> rows = NotificationCategory.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(notificationSettingsProvider).value ?? const {};
    final remindersOn = NotificationCategory.mealReminders.isOn(values);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DesignCanvas(
        background: AppColors.background,
        // Taller than the artboard: three cards of their own height cannot
        // all be pinned, so they stack in a column and the canvas scrolls to
        // fit. Taller again once the reminder times are showing. Generous on
        // purpose — surplus is background, whereas a short canvas clips the
        // last row.
        height: remindersOn ? 1460 : 1080,
        children: [
          PremiumTopBar(title: 'Notification', onBack: onBack),
          Positioned(
            left: 20,
            top: 147,
            width: 388,
            child: SettingsCard(
              gap: 20,
              children: [
                for (final category in rows)
                  SettingsToggleRow(
                    label: category.label,
                    value: category.isOn(values),
                    // Meal reminders go through the coordinator, which asks
                    // for OS permission and rewrites the schedule. It writes
                    // the preference itself, and only once permission is
                    // actually granted — so a refused prompt leaves the row
                    // off rather than claiming notifications are on while the
                    // OS silently drops every one.
                    onChanged: category == NotificationCategory.mealReminders
                        ? (v) => ref
                            .read(mealRemindersProvider)
                            .setEnabled(enabled: v)
                        : (v) => ref
                            .read(notificationSettingsRepositoryProvider)
                            .setEnabled(category.key, enabled: v),
                  ),
              ],
            ),
          ),
          // Below the first card. The top is its bottom (147 + 19 + 4 rows of
          // 25 + 3 gaps of 20 + 19 = 345) plus the 20 the artboard puts
          // between stacked cards. No height on either card: each sizes to its
          // own rows, which is what keeps them whole at the 1.15x text
          // ceiling.
          //
          // A column rather than two Positioned blocks, because the reminder
          // card's height depends on how many slots are switched on — so a
          // fixed top for the weigh-in card below it would be wrong for every
          // state but one.
          Positioned(
            left: 20,
            top: 365,
            width: 388,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Only when the switch above is on: there is nothing to
                // configure about reminders that are not being sent.
                if (remindersOn) ...[
                  const ReminderTimesCard(),
                  const SizedBox(height: 20),
                ],
                const WeighInCard(),
                const SizedBox(height: 20),
                const WaterReminderCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
