import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/reminder_schedule.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'settings_widgets.dart';

/// The weekly weigh-in prompt — switch, weekday and time.
///
/// **Not in the Figma file.** Frame 37 has four toggles and no weigh-in, but
/// the app tracks weight, draws a trend from it on Home, and predicts a goal
/// date off it, while nothing ever asked anyone to stand on a scale. A trend
/// with no readings is the same class of promise as the plan that said "on
/// track for X kg" with nothing behind it.
///
/// Built from the same [SettingsCard] and [SettingsRow] the artboard defines,
/// so it reads as part of the screen rather than bolted on.
class WeighInCard extends ConsumerWidget {
  const WeighInCard({super.key, this.preview});

  /// Pins the preference, for tests and previews. Null reads the real one.
  ///
  /// The card's interesting half is invisible until the switch is on, so
  /// without this a default render never reaches it — which is exactly how
  /// the search result row shipped 2px over its box.
  final WeighInPreference? preview;

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WeighInPreference prefs =
        preview ?? ref.watch(weighInPreferenceProvider);

    return SettingsCard(
      gap: 18,
      children: [
        SettingsToggleRow(
          label: 'Weekly weigh-in',
          value: prefs.enabled,
          // Through the coordinator, not the preference: this may be the
          // first notification anyone enables, so it needs the same OS
          // permission prompt the meal toggle gets. A refusal leaves the
          // preference unwritten and the switch off.
          onChanged: (v) =>
              ref.read(mealRemindersProvider).setWeighInEnabled(enabled: v),
        ),
        if (prefs.enabled) ...[
          SizedBox(
            width: double.infinity,
            child: Text(
              'One reading a week is what the trend on Home is built from — '
              'daily weight swings too much to mean anything.',
              style: AppTypography.meta(color: AppColors.placeholder),
            ),
          ),
          _WeighInRow(prefs: prefs),
        ],
      ],
    );
  }
}

class _WeighInRow extends ConsumerWidget {
  const _WeighInRow({required this.prefs});

  final WeighInPreference prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = WeighInCard._weekdays[prefs.weekday - 1];
    final time = TimeOfDay(hour: prefs.hour, minute: prefs.minute);

    // minHeight, not height: 44 is exactly the tap target and leaves no slack
    // at the 1.15x text ceiling.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _pickDay(context, ref),
              child: Text(label, style: AppTypography.body()),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked == null) return;
              ref
                  .read(weighInPreferenceProvider.notifier)
                  .setTime(picked.hour * 60 + picked.minute);
            },
            child: Text(
              time.format(context),
              style: AppTypography.body(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDay(BuildContext context, WidgetRef ref) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.inkMuted,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var day = 1; day <= 7; day++)
              ListTile(
                title: Text(
                  WeighInCard._weekdays[day - 1],
                  style: AppTypography.body(),
                ),
                trailing: day == prefs.weekday
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(day),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      ref.read(weighInPreferenceProvider.notifier).setWeekday(chosen);
    }
  }
}
