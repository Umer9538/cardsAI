import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/notifications/meal_clock.dart';
import '../../../../core/notifications/reminder_schedule.dart';
import '../../../../core/notifications/reminder_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'settings_widgets.dart';
import '../../../../core/design/app_toast.dart';

/// The three meal reminders, with their times and where each time came from.
///
/// Not on any artboard — the design has one Meal Reminders switch and nothing
/// behind it. It is here because a reminder the app picked has to be movable:
/// [ReminderSchedule.suggested] is a guess at when a stranger eats, and with no
/// way to correct it the only choices were a wrong time or no reminders at all.
/// Every app in this category ships exactly this screen.
///
/// It also *says* which time is which. "Suggested" and "From when you usually
/// eat" are different promises, and someone who can watch the app learn their
/// morning is being shown a reason to leave the notifications on.
class ReminderTimesCard extends ConsumerWidget {
  const ReminderTimesCard({super.key, this.preview});

  /// Pins the times, for tests and previews. Null reads the real schedule.
  final Map<MealSlot, MealReminder>? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(reminderPreferencesProvider);
    final clock = ref.watch(mealClockProvider);
    final times =
        preview ?? ref.watch(reminderPreviewProvider).value ?? const {};

    final anyChosen =
        ReminderSchedule.slots.any((s) => preferences.chosenFor(s) != null);

    return SettingsCard(
      gap: 18,
      children: [
        SizedBox(
          width: double.infinity,
          child: Text(
            'Reminders land a little after you usually eat. Tap a time to '
            'change it — otherwise your diary sets it.',
            style: AppTypography.meta(color: AppColors.placeholder),
          ),
        ),
        for (final slot in ReminderSchedule.slots)
          _ReminderRow(
            slot: slot,
            reminder: times[slot] ?? _fallback(slot, clock),
            enabled: preferences.isEnabled(slot),
            region: clock.region,
          ),
        if (anyChosen)
          SettingsRow(
            label: 'Use my diary’s times',
            onTap: () {
              final controller = ref.read(reminderPreferencesProvider.notifier);
              for (final slot in ReminderSchedule.slots) {
                controller.setTime(slot, null);
              }
            },
          ),
        // The first real reminder is hours away, so without this there is no
        // way to tell a working setup from a silently refused permission —
        // and no way to support anyone who says it is not working.
        SettingsRow(
          label: 'Send a test reminder',
          onTap: () => _test(context, ref),
        ),
      ],
    );
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(reminderServiceProvider).sendTest();
    messenger.showSnackBar(
      appToast(
        switch (result) {
          ReminderTestResult.sent => 'Sent — check your notifications.',
          // Naming the cause, because "it did not work" is what someone
          // uninstalls over. This is the common one: permission was never
          // granted, or was taken away in system settings afterwards.
          ReminderTestResult.noPermission =>
            'Android is blocking notifications for Carbs AI. Turn them on in '
                'system settings, then try again.',
          ReminderTestResult.unavailable =>
            'Reminders could not start on this device.',
        },
        tone: result == ReminderTestResult.sent
            ? ToastTone.success
            : ToastTone.error,
      ),
    );
  }

  /// What to show before the diary read comes back. This is where it lands for
  /// anyone with no history, so the row does not jump when the read completes.
  static MealReminder _fallback(MealSlot slot, MealClock clock) {
    final at = clock[slot] + ReminderSchedule.graceMinutes;
    return MealReminder(
      slot: slot,
      hour: at ~/ 60,
      minute: at % 60,
      source: ReminderSource.suggested,
    );
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow({
    required this.slot,
    required this.reminder,
    required this.enabled,
    required this.region,
  });

  final MealSlot slot;
  final MealReminder reminder;
  final bool enabled;

  /// Where the suggested time comes from, named — so a default that is wrong
  /// for someone says why it is what it is instead of looking arbitrary.
  final String region;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ReminderSchedule.title(slot);
    final time = TimeOfDay(hour: reminder.hour, minute: reminder.minute);
    final shown = MaterialLocalizations.of(context).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    // A minimum rather than a height. The two lines are 25 and 19, which is
    // exactly 44 and therefore has no slack at all — the same arithmetic that
    // put the search result row 2px over on a device. At the 1.15x text
    // ceiling they need 51, so the row grows and the card, which sizes to its
    // children, grows with it.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.body(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  enabled ? _caption(reminder.source, region) : 'Off',
                  style: AppTypography.meta(color: AppColors.placeholder),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => _pick(context, ref, time) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                shown,
                maxLines: 1,
                style: AppTypography.body(
                  color: enabled ? AppColors.accentGreen : AppColors.muted,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            toggled: enabled,
            label: '$label reminder',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ref
                  .read(reminderPreferencesProvider.notifier)
                  .setEnabled(slot, enabled: !enabled),
              child: SizedBox(
                width: 40,
                height: 22,
                // The switch art carries a drop shadow and is exported at
                // 46x34; drawn at that size so the 40x22 body lands right.
                child: OverflowBox(
                  minWidth: 46,
                  maxWidth: 46,
                  minHeight: 34,
                  maxHeight: 34,
                  child: Image.asset(
                    enabled
                        ? 'assets/images/app/toggle_on.png'
                        : 'assets/images/app/toggle_off.png',
                    width: 46,
                    height: 34,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _caption(ReminderSource source, String region) =>
      switch (source) {
        ReminderSource.chosen => 'You set this',
        ReminderSource.observed => 'From when you usually eat',
        ReminderSource.suggested => 'Suggested for $region',
      };

  Future<void> _pick(BuildContext context, WidgetRef ref, TimeOfDay from) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: from,
      helpText: 'Remind me about ${ReminderSchedule.title(slot).toLowerCase()}',
      // The picker is a Material dialog and this app is dark everywhere else;
      // the default light sheet over a #121212 screen reads as another app.
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.inkMuted,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    ref
        .read(reminderPreferencesProvider.notifier)
        .setTime(slot, picked.hour * 60 + picked.minute);
  }
}
