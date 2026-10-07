import 'dart:convert';

import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/meal_reminders.dart';
import 'package:carbsai/core/notifications/reminder_schedule.dart';
import 'package:carbsai/core/ads/ads_providers.dart';
import 'package:carbsai/core/ads/ads_service.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<
    ({
      ProviderContainer container,
      FakeReminderService service,
      _StubSettings prefs
    })> _harness({
  List<Meal>? meals,
  Map<String, bool>? settings,
  ReminderPreferences? times,
  bool granted = true,
  bool? permitted,
}) async {
  final service = FakeReminderService(granted: granted, permitted: permitted);
  final prefs = _StubSettings(settings);
  // The reminder times live in the device store, so the coordinator needs a
  // real one. Mock preferences rather than a stub of the store: the JSON round
  // trip is where a wrong time would actually come back through.
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (times != null) StoreKeys.reminderTimes: jsonEncode(times.toJson()),
  });
  final container = ProviderContainer(
    overrides: [
      jsonStoreProvider.overrideWithValue(await JsonStore.open()),
      reminderServiceProvider.overrideWithValue(service),
      // The coordinator tells the ad service not to treat the permission
      // sheet's resume as an app open. Nothing here is testing ads.
      adsServiceProvider.overrideWithValue(const NoAdsService()),
      diaryRepositoryProvider.overrideWithValue(_StubDiary(meals ?? const [])),
      notificationSettingsRepositoryProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, service: service, prefs: prefs);
}

void main() {
  // SharedPreferences' mock needs the binding, and the harness sets one up per
  // test.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('turning the toggle on asks for permission and schedules', () async {
    final h = await _harness(meals: _regularDiary());

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
    final h = await _harness(meals: _regularDiary(), granted: false);

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
    final h = await _harness(
      meals: _regularDiary(),
      settings: {MealReminders.key: true},
    );

    await h.container.read(mealRemindersProvider).setEnabled(enabled: false);

    expect(h.service.permissionRequests, 0);
    expect(h.prefs.values[MealReminders.key], isFalse);
    // The outcome, not the mechanism: the schedule is rewritten with no meals
    // in it rather than short-circuited to a cancel, because the weigh-in and
    // the water nudges have their own switches and must survive this one.
    expect(h.service.scheduled, isEmpty);
  });

  test('refresh schedules no meals while the preference is off', () async {
    final h = await _harness(meals: _regularDiary());

    await h.container.read(mealRemindersProvider).refresh();

    expect(h.service.scheduled, isEmpty);
  });

  test('the weigh-in survives the meal toggle being off', () async {
    final h = await _harness(meals: _regularDiary());

    await h.container
        .read(mealRemindersProvider)
        .setWeighInEnabled(enabled: true);

    // The three switches are independent. Before this, sync returned early on
    // the meal preference and took the weekly prompt with it.
    expect(h.service.scheduled, isEmpty);
    expect(h.service.weighIn, isNotNull);
  });

  test('water does too, and lands inside the eating window', () async {
    final h = await _harness(meals: _regularDiary());

    await h.container
        .read(mealRemindersProvider)
        .setWaterEnabled(enabled: true);

    expect(h.service.scheduled, isEmpty);
    expect(h.service.water, isNotEmpty);
    for (final drink in h.service.water) {
      expect(drink.hour, inInclusiveRange(6, 23));
    }
  });

  test('a refused prompt leaves water off too', () async {
    final h = await _harness(meals: _regularDiary(), granted: false);

    final settled = await h.container
        .read(mealRemindersProvider)
        .setWaterEnabled(enabled: true);

    expect(settled, isFalse);
    expect(h.container.read(waterPreferenceProvider).enabled, isFalse);
    expect(h.service.water, isEmpty);
  });

  test('refresh reschedules from the diary when it is on', () async {
    final h = await _harness(
      meals: _regularDiary(),
      settings: {MealReminders.key: true},
    );

    await h.container.read(mealRemindersProvider).refresh();

    expect(h.service.syncs, 1);
    expect(h.service.scheduled, hasLength(3));
  });

  test('permission revoked in system settings turns the toggle off', () async {
    final h = await _harness(
      meals: _regularDiary(),
      settings: {MealReminders.key: true},
      // Granted once, then taken away in the OS. Nothing tells the app.
      permitted: false,
    );

    await h.container.read(mealRemindersProvider).refresh();

    // The switch must stop claiming reminders are on while Android drops
    // every one of them.
    expect(h.prefs.values[MealReminders.key], isFalse);
    expect(h.service.scheduled, isEmpty);
  });

  test('an empty diary still gets all three reminders', () async {
    final h = await _harness(settings: {MealReminders.key: true});

    await h.container.read(mealRemindersProvider).refresh();

    // This asserted `isEmpty` until the day it was noticed that new accounts
    // therefore never got a reminder at all — and the diary that would have
    // earned them one is the thing reminders exist to produce. A suggested
    // time the person can move is the way out of that circle; it is not the
    // fixed prompt the trial measured, because it stops being fixed the moment
    // anyone touches it or logs three of anything.
    expect(h.service.scheduled, hasLength(3));
    expect(
      h.service.scheduled.every((r) => r.source == ReminderSource.suggested),
      isTrue,
    );
  });

  test('a time the person set survives the round trip and beats the diary',
      () async {
    final h = await _harness(
      meals: _regularDiary(),
      settings: {MealReminders.key: true},
      times: const ReminderPreferences(times: {MealSlot.breakfast: 7 * 60 + 30}),
    );

    await h.container.read(mealRemindersProvider).refresh();

    final breakfast =
        h.service.scheduled.firstWhere((r) => r.slot == MealSlot.breakfast);
    expect(breakfast.hour, 7);
    expect(breakfast.minute, 30);
    expect(breakfast.source, ReminderSource.chosen);

    // The other two are untouched, and still learned from the diary — 13:00
    // plus the 45-minute grace.
    final lunch = h.service.scheduled.firstWhere((r) => r.slot == MealSlot.lunch);
    expect(lunch.source, ReminderSource.observed);
    expect(lunch.minuteOfDay, 13 * 60 + ReminderSchedule.graceMinutes);
  });

  test('a slot switched off is not scheduled', () async {
    final h = await _harness(
      meals: _regularDiary(),
      settings: {MealReminders.key: true},
      times: const ReminderPreferences(off: {MealSlot.breakfast}),
    );

    await h.container.read(mealRemindersProvider).refresh();

    // Someone who does not eat breakfast should not have to turn off all three
    // to stop being asked about it.
    expect(
      h.service.scheduled.map((r) => r.slot),
      [MealSlot.lunch, MealSlot.dinner],
    );
  });

  test('changing a time reschedules without being asked', () async {
    final h = await _harness(
      meals: _regularDiary(),
      settings: {MealReminders.key: true},
    );
    await h.container.read(mealRemindersProvider).refresh();
    final before = h.service.syncs;

    h.container
        .read(reminderPreferencesProvider.notifier)
        .setTime(MealSlot.dinner, 21 * 60);
    // The controller fires the reschedule and does not await it.
    await Future<void>.delayed(Duration.zero);

    // Storing the time is half of it: the OS is holding the old one until
    // something rewrites it, and nothing else on this path will.
    expect(h.service.syncs, greaterThan(before));
    expect(
      h.service.scheduled
          .firstWhere((r) => r.slot == MealSlot.dinner)
          .minuteOfDay,
      21 * 60,
    );
  });

  test('logging a meal reschedules', () async {
    final h = await _harness(
      meals: _regularDiary(),
      settings: {MealReminders.key: true},
    );
    await h.container.read(mealRemindersProvider).refresh();
    final before = h.service.syncs;

    await h.container.read(mealRemindersProvider).mealLogged();

    // The trigger the class comment always claimed and never had.
    expect(h.service.syncs, before + 1);
  });

  test('logging a meal schedules no meal reminder while the toggle is off',
      () async {
    final h = await _harness(meals: _regularDiary());

    await h.container.read(mealRemindersProvider).mealLogged();

    expect(h.service.scheduled, isEmpty);
    expect(h.service.weighIn, isNull);
    expect(h.service.water, isEmpty);
  });
}
