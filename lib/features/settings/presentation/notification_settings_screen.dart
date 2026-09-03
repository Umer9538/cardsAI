import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/notifications/meal_reminders.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';
import 'widgets/settings_widgets.dart';

/// Notification preferences — Figma frame `37_Notification` (2002:933).
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  /// The artboard's four rows, in order, mapped to the keys the repository
  /// stores. Order is fixed here rather than taken from the map so the list
  /// cannot reshuffle between builds.
  static const List<(String, String)> rows = [
    ('mealReminders', 'Meal Reminders'),
    ('goalProgress', 'Progress Summary'),
    ('weeklySummary', 'Goal Milestone Notifications'),
    ('tipsAndEducation', 'New Plan Recommendations'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(notificationSettingsProvider).value ?? const {};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DesignCanvas(
        background: AppColors.background,
        children: [
          PremiumTopBar(title: 'Notification', onBack: onBack),
          Positioned(
            left: 20,
            top: 147,
            width: 388,
            child: SettingsCard(
              gap: 20,
              children: [
                for (final (key, label) in rows)
                  SettingsToggleRow(
                    label: label,
                    value: values[key] ?? false,
                    // Meal reminders go through the coordinator, which asks
                    // for OS permission and rewrites the schedule. It writes
                    // the preference itself, and only once permission is
                    // actually granted — so a refused prompt leaves the row
                    // off rather than claiming notifications are on while the
                    // OS silently drops every one.
                    onChanged: key == MealReminders.key
                        ? (v) => ref
                            .read(mealRemindersProvider)
                            .setEnabled(enabled: v)
                        : (v) => ref
                            .read(notificationSettingsRepositoryProvider)
                            .setEnabled(key, enabled: v),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
