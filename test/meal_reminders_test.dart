import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/meal_reminders.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_reminder_service.dart';

/// A diary holding one fixed set of meals.
class _StubDiary implements DiaryRepository {
  _StubDiary(this.meals);

  final List<Meal> meals;

  @override
  Future<List<Meal>> mealsBetween(DateTime from, DateTime to) async => meals;

  @override
  Stream<List<Meal>> watchDay(DateTime date) => Stream.value(meals);

  @override
  Future<Meal> addMeal(Meal meal) async => meal;

  @override
  Future<Meal> updateMeal(Meal meal) async => meal;

  @override
  Future<void> deleteMeal(String id) async {}

  @override
  Future<int> currentStreak() async => 0;
}

class _StubSettings implements NotificationSettingsRepository {
  _StubSettings([Map<String, bool>? initial])
      : _values = {...?initial};

  final Map<String, bool> _values;

  Map<String, bool> get values => _values;

  @override
  Stream<Map<String, bool>> watch() => Stream.value(Map.of(_values));

  @override
  Future<void> setEnabled(String key, {required bool enabled}) async {
    _values[key] = enabled;
  }
}

Meal _meal(DateTime at, MealSlot slot) => Meal(
      id: '${slot.name}-${at.day}-${at.hour}',
      slot: slot,
      eatenAt: at,
      items: const [],
    );

/// Fourteen days of a regular eater, ending yesterday so "now" cannot land
/// mid-pattern.
///
/// Anchored on today rather than a fixed date: the schedule only looks back 28
/// days, so a hardcoded anchor stops producing reminders the moment the
/// calendar passes it — a test that would pass today and fail next month.
List<Meal> _regularDiary() {
  final now = DateTime.now();
  final anchor = DateTime(now.year, now.month, now.day);
  return [
    for (var day = 1; day <= 14; day++) ...[
      _meal(anchor.subtract(Duration(days: day)).add(const Duration(hours: 8)),
          MealSlot.breakfast),
      _meal(anchor.subtract(Duration(days: day)).add(const Duration(hours: 13)),
          MealSlot.lunch),
      _meal(anchor.subtract(Duration(days: day)).add(const Duration(hours: 19)),
          MealSlot.dinner),
    ],
  ];
}

({ProviderContainer container, FakeReminderService service, _StubSettings prefs})
    _harness({
  List<Meal>? meals,
  Map<String, bool>? settings,
  bool granted = true,
}) {
  final service = FakeReminderService(granted: granted);
  final prefs = _StubSettings(settings);
  final container = ProviderContainer(
    overrides: [
      reminderServiceProvider.overrideWithValue(service),
      diaryRepositoryProvider.overrideWithValue(_StubDiary(meals ?? const [])),
      notificationSettingsRepositoryProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, service: service, prefs: prefs);
}

void main() {
  test('turning the toggle on asks for permission and schedules', () async {
    final h = _harness(meals: _regularDiary());

    final settled =
        await h.container.read(mealRemindersProvider).setEnabled(enabled: true);

    expect(settled, isTrue);
    expect(h.service.permissionRequests, 1);
    expect(h.prefs.values[MealReminders.key], isTrue);
    expect(h.service.scheduled.map((r) => r.slot), [
      MealSlot.breakfast,
      MealSlot.lunch,
      MealSlot.dinner,
    ]);
  });

  test('a refused prompt leaves the preference off', () async {
    final h = _harness(meals: _regularDiary(), granted: false);

    final settled =
        await h.container.read(mealRemindersProvider).setEnabled(enabled: true);

    // The switch must settle back to off. Saying "on" while the OS drops every
    // notification is the version of this that gets uninstalled.
    expect(settled, isFalse);
    expect(h.prefs.values[MealReminders.key], isNot(true));
    expect(h.service.scheduled, isEmpty);
    expect(h.service.cancels, 1);
  });

  test('turning it off cancels without asking for permission', () async {
    final h = _harness(
      meals: _regularDiary(),
      settings: {MealReminders.key: true},
    );

    await h.container.read(mealRemindersProvider).setEnabled(enabled: false);

    expect(h.service.permissionRequests, 0);
    expect(h.prefs.values[MealReminders.key], isFalse);
    expect(h.service.cancels, 1);
    expect(h.service.syncs, 0);
  });

  test('refresh does nothing while the preference is off', () async {
    final h = _harness(meals: _regularDiary());

    await h.container.read(mealRemindersProvider).refresh();

    expect(h.service.syncs, 0);
    expect(h.service.scheduled, isEmpty);
  });

  test('refresh reschedules from the diary when it is on', () async {
    final h = _harness(
      meals: _regularDiary(),
      settings: {MealReminders.key: true},
    );

    await h.container.read(mealRemindersProvider).refresh();

    expect(h.service.syncs, 1);
    expect(h.service.scheduled, hasLength(3));
  });

  test('an empty diary schedules nothing', () async {
    final h = _harness(settings: {MealReminders.key: true});

    await h.container.read(mealRemindersProvider).refresh();

    // No evidence about when this person eats, so no guess. Generic fixed-time
    // prompts measured as no better than none at all.
    expect(h.service.scheduled, isEmpty);
  });
}
