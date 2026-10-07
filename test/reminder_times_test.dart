import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/meal_clock.dart';
import 'package:carbsai/core/notifications/meal_reminders.dart';
import 'package:carbsai/core/notifications/reminder_schedule.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/features/settings/presentation/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_reminder_service.dart';

/// The reminder times only exist on screen while meal reminders are switched
/// on, and the toggle ships off — so a default render of this screen never
/// reaches them.
///
/// That is the shape of the bug `FoodSearchScreen` shipped: a fixed-height row
/// that was 2px over on a device, surviving because the only state a test could
/// reach was the empty one. These tests pin the state that has the rows in it,
/// including at the text-scale ceiling the whole artboard convention rests on.
class _Settings implements NotificationSettingsRepository {
  _Settings(this._values);

  final Map<String, bool> _values;

  @override
  Stream<Map<String, bool>> watch() => Stream.value(Map.of(_values));

  @override
  Future<void> setEnabled(String key, {required bool enabled}) async {
    _values[key] = enabled;
  }
}

class _Diary implements DiaryRepository {
  _Diary(this.meals);

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

Meal _meal(DateTime at, MealSlot slot) =>
    Meal(id: '${slot.name}${at.day}', slot: slot, eatenAt: at, items: const []);

/// A fortnight of eating at 8:00, 13:00 and 19:00.
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

/// Pinned rather than read from the host: `MealClock.forLocale()` would make
/// every assertion below depend on the locale of whatever machine runs the
/// suite. These are the Pakistan times — 08:30 / 13:30 / 20:30 — plus the
/// 45-minute grace.
const _clock = MealClock(
  region: 'South Asia',
  breakfast: 8 * 60 + 30,
  lunch: 13 * 60 + 30,
  dinner: 20 * 60 + 30,
);

/// The artboard's own viewport. The default 800x600 puts the lower rows of the
/// card outside the frame, where `tester.tap` misses and only *warns* — so a
/// test can look like it exercised a control it never touched.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(428 * 3, 926 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester, {
  List<Meal> meals = const [],
  double textScale = 1,
}) async {
  _phone(tester);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = await JsonStore.open();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        mealClockProvider.overrideWithValue(_clock),
        reminderServiceProvider.overrideWithValue(FakeReminderService()),
        diaryRepositoryProvider.overrideWithValue(_Diary(meals)),
        notificationSettingsRepositoryProvider
            .overrideWithValue(_Settings({MealReminders.key: true})),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: const NotificationSettingsScreen(),
        ),
      ),
    ),
  );
  // Bounded, not pumpAndSettle: the screen carries no animation to settle, and
  // the diary read has to land before the times are real.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a new account sees three suggested times, not an empty card',
      (tester) async {
    await _pump(tester);

    for (final slot in ReminderSchedule.slots) {
      expect(find.text(ReminderSchedule.title(slot)), findsOneWidget);
    }
    // The whole point of the change: something to see and move on day one —
    // and it names where the time came from rather than looking arbitrary.
    expect(find.text('Suggested for South Asia'), findsNWidgets(3));
    expect(find.text('9:15 AM'), findsOneWidget);
    expect(find.text('2:15 PM'), findsOneWidget);
    expect(find.text('9:15 PM'), findsOneWidget);
  });

  testWidgets('a diary of its own replaces the suggestion', (tester) async {
    await _pump(tester, meals: _regularDiary());

    expect(find.text('From when you usually eat'), findsNWidgets(3));
    // 08:00 plus the 45 minutes of grace.
    expect(find.text('8:45 AM'), findsOneWidget);
    expect(find.text('7:45 PM'), findsOneWidget);
    expect(find.textContaining('Suggested for'), findsNothing);
  });

  testWidgets('switching one meal off leaves the other two', (tester) async {
    await _pump(tester);

    await tester.tap(find.bySemanticsLabel('Breakfast reminder'));
    await tester.pump();

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Suggested for South Asia'), findsNWidgets(2));
  });

  testWidgets('the card holds together at the text-scale ceiling',
      (tester) async {
    // DesignCanvas.maxTextScale. Every child of the canvas is positioned at a
    // fixed y, so text that grows overlaps rather than pushing down — and
    // these rows are fixed-height, which is exactly how the search row ended
    // up 2px over.
    await _pump(tester, meals: _regularDiary(), textScale: 1.15);

    expect(tester.takeException(), isNull);
    for (final slot in ReminderSchedule.slots) {
      expect(find.text(ReminderSchedule.title(slot)), findsOneWidget);
    }
  });

  testWidgets('the test reminder reports why it failed', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await JsonStore.open();
    // Permission taken away in system settings after it was granted — the
    // state someone is actually in when they say reminders do not work.
    final service = FakeReminderService(permitted: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          mealClockProvider.overrideWithValue(_clock),
          reminderServiceProvider.overrideWithValue(service),
          diaryRepositoryProvider.overrideWithValue(_Diary(const [])),
          notificationSettingsRepositoryProvider
              .overrideWithValue(_Settings({MealReminders.key: true})),
        ],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Send a test reminder'));
    await tester.pump();
    await tester.pump();

    expect(service.testsSent, 1);
    // Naming the cause is the whole point: "it did not work" is what people
    // uninstall over.
    expect(find.textContaining('Android is blocking'), findsOneWidget);
  });

  testWidgets('a test reminder can be sent without waiting for a meal time',
      (tester) async {
    await _pump(tester);

    expect(find.text('Send a test reminder'), findsOneWidget);
  });

  testWidgets('the times are hidden while reminders are off', (tester) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = await JsonStore.open();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          mealClockProvider.overrideWithValue(_clock),
          reminderServiceProvider.overrideWithValue(FakeReminderService()),
          diaryRepositoryProvider.overrideWithValue(_Diary(const [])),
          notificationSettingsRepositoryProvider
              .overrideWithValue(_Settings({MealReminders.key: false})),
        ],
        child: const MaterialApp(home: NotificationSettingsScreen()),
      ),
    );
    await tester.pump();

    // Nothing to configure about reminders that are not being sent.
    expect(find.text('Breakfast'), findsNothing);
  });
}
