import 'package:carbsai/core/notifications/reminder_schedule.dart';
import 'package:carbsai/core/notifications/reminder_service.dart';

/// A [ReminderService] that records instead of talking to the OS.
///
/// The real one reaches a platform channel that does not exist under
/// `flutter test`. It degrades quietly, which is right on a device and merely
/// noisy here — and it also means a test could never see what was scheduled.
class FakeReminderService implements ReminderService {
  FakeReminderService({this.granted = true, bool? permitted})
      : permitted = permitted ?? granted;

  /// What the permission prompt answers.
  bool granted;

  /// What the OS currently allows, independently of whether we ever asked —
  /// permission can be withdrawn in system settings after being given.
  bool permitted;

  /// The last schedule handed to [sync], or empty after a [cancelAll].
  List<MealReminder> scheduled = const [];

  int syncs = 0;
  int cancels = 0;
  int permissionRequests = 0;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    permitted = granted;
    return granted;
  }

  /// The weigh-in passed to the last [sync], if any.
  WeightReminder? weighIn;

  /// The water run passed to the last [sync].
  List<WaterReminder> water = const [];

  @override
  Future<void> sync(
    List<MealReminder> reminders, {
    WeightReminder? weighIn,
    List<WaterReminder> water = const [],
    DaySummaryReminder? daySummary,
  }) async {
    syncs++;
    scheduled = reminders;
    this.weighIn = weighIn;
    this.water = water;
    this.daySummary = daySummary;
  }

  /// The nightly summary handed to the last [sync], if any.
  DaySummaryReminder? daySummary;

  /// What [sendTest] should answer.
  ReminderTestResult testResult = ReminderTestResult.sent;
  int testsSent = 0;

  @override
  Future<ReminderTestResult> sendTest() async {
    testsSent++;
    return permitted ? testResult : ReminderTestResult.noPermission;
  }

  /// Everything handed to [post], in order.
  final List<({int id, String body, NotificationChannel channel})> posted = [];

  @override
  Future<void> post({
    required int id,
    required String title,
    required String body,
    required NotificationChannel channel,
  }) async {
    if (!permitted) return;
    posted.add((id: id, body: body, channel: channel));
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled = const [];
    weighIn = null;
    water = const [];
  }
}
