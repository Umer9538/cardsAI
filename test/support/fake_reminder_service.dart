import 'package:carbsai/core/models/models.dart';
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

  @override
  Future<void> sync(List<Meal> meals, {required bool enabled}) async {
    syncs++;
    scheduled = enabled ? ReminderSchedule.from(meals) : const [];
  }

  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled = const [];
  }
}
