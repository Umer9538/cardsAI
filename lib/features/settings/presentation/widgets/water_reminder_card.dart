import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/reminder_schedule.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'settings_widgets.dart';

/// The water nudges — switch, and how many a day.
///
/// **Not in the Figma file**, like the weigh-in card, and built from the same
/// [SettingsCard] and [SettingsRow] so it reads as part of frame 37.
///
/// There is no time picker here on purpose. The times come from the eating
/// window the meal reminders already derive, so they move when someone's day
/// moves; six pickers would be six fields nobody fills in, producing a fixed
/// schedule that is wrong the first time someone works a late shift.
class WaterReminderCard extends ConsumerWidget {
  const WaterReminderCard({super.key, this.preview});

  /// Pins the preference, for tests and previews. Null reads the real one.
  ///
  /// The count row is invisible until the switch is on, so without this a
  /// default render never reaches it.
  final WaterPreference? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WaterPreference prefs = preview ?? ref.watch(waterPreferenceProvider);

    return SettingsCard(
      gap: 18,
      children: [
        SettingsToggleRow(
          label: 'Water reminders',
          value: prefs.enabled,
          // Through the coordinator, so it gets the OS permission prompt —
          // see [WeighInCard].
          onChanged: (v) =>
              ref.read(mealRemindersProvider).setWaterEnabled(enabled: v),
        ),
        if (prefs.enabled) ...[
          SizedBox(
            width: double.infinity,
            child: Text(
              'Spread through the hours you usually eat, never closer together '
              'than an hour.',
              style: AppTypography.meta(color: AppColors.placeholder),
            ),
          ),
          _CountRow(count: prefs.count),
        ],
      ],
    );
  }
}

class _CountRow extends ConsumerWidget {
  const _CountRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // minHeight, not height: 44 is exactly the tap target and leaves no slack
    // at the 1.15x text ceiling.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          Expanded(
            child: Text('A day', style: AppTypography.body()),
          ),
          for (var n = 2; n <= WaterSchedule.maxPerDay; n += 2) ...[
            if (n > 2) const SizedBox(width: 8),
            _CountChip(
              value: n,
              selected: count == n,
              onTap: () =>
                  ref.read(waterPreferenceProvider.notifier).setCount(n),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$value water reminders a day',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
            ),
          ),
          child: Text(
            '$value',
            style: AppTypography.meta(
              color: selected ? AppColors.ink : AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}
