/// The notification kinds the Settings screen switches on and off.
///
/// One place owns the pairing of stored key to on-screen label, because the
/// two do not match and cannot be made to: the labels come from Figma frame
/// `37_Notification` and the keys were already in storage under different
/// names before those labels were read off the artboard. Renaming the keys
/// would silently reset the preference on every existing account, so the
/// mismatch is kept and made explicit here instead of being rediscovered at
/// each use site — `weeklySummary` driving milestone notifications is exactly
/// the sort of thing that reads as a bug later.
enum NotificationCategory {
  /// Scheduled OS reminders. The only category that leaves the app — the rest
  /// are entries in the in-app feed.
  mealReminders(key: 'mealReminders', label: 'Meal Reminders'),

  /// How today and yesterday went against the calorie target.
  progressSummary(key: 'goalProgress', label: 'Progress Summary'),

  /// Streaks and goal-weight milestones.
  goalMilestones(key: 'weeklySummary', label: 'Goal Milestone Notifications'),

  /// Suggestions to try a diet plan.
  planSuggestions(key: 'tipsAndEducation', label: 'New Plan Recommendations');

  const NotificationCategory({required this.key, required this.label});

  /// What the preference is stored under. Do not change — see the class note.
  final String key;

  /// What the Settings row reads, verbatim from the artboard.
  final String label;

  /// Whether this category is on, given the stored preference map.
  ///
  /// Defaults to off for an unknown key: a category nobody has switched on
  /// should not start posting.
  bool isOn(Map<String, bool> settings) => settings[key] ?? false;

  static NotificationCategory? forKey(String key) {
    for (final category in values) {
      if (category.key == key) return category;
    }
    return null;
  }
}
