import 'package:flutter/foundation.dart';

import 'nutrition.dart';

enum Gender { female, male, other, unspecified }

/// How much someone moves, as the multiplier applied to their BMR.
///
/// The five standard Harris-Benedict activity factors, which every mainstream
/// tracker uses. The labels matter as much as the numbers: "moderately active"
/// means nothing to most people, so each carries the concrete description the
/// quiz shows underneath it.
enum ActivityLevel {
  sedentary('Not very active', 'Desk job, little or no exercise', 1.2),
  light('Lightly active', 'Exercise 1-3 days a week', 1.375),
  moderate('Moderately active', 'Exercise 3-5 days a week', 1.55),
  very('Very active', 'Exercise 6-7 days a week', 1.725),
  athlete('Extremely active', 'Hard daily exercise, or a physical job', 1.9);

  const ActivityLevel(this.label, this.detail, this.multiplier);

  final String label;
  final String detail;
  final double multiplier;
}

/// Which direction the daily calorie target moves from maintenance.
enum WeightGoal {
  lose('Lose weight'),
  maintain('Maintain weight'),
  gain('Gain weight');

  const WeightGoal(this.label);

  final String label;
}

/// The signed-in person, and the goals their diary is measured against.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatar = 'assets/images/app/avatar.png',
    this.dateOfBirth,
    this.gender = Gender.unspecified,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.goal,
    this.goalWeightKg,
    this.weeklyRateKg = 0.5,
    this.targets = defaultTargets,
    this.isPremium = false,
  });

  /// Fallback goals for a profile that has not been through the quiz, or has
  /// skipped it. Chosen to match the figures the artboards show, so the seeded
  /// app looks like the design.
  ///
  /// Every user seeing the same number is the problem the quiz exists to fix:
  /// a 22-year-old athlete and a sedentary 55-year-old do not share a calorie
  /// goal, and the ring on Home is the app's central claim.
  static const Nutrition defaultTargets = Nutrition(
    calories: 2000,
    protein: 120,
    carbs: 250,
    fat: 65,
  );

  final String id;
  final String name;
  final String email;

  /// Asset path today; a Storage URL once accounts are real.
  final String avatar;

  final DateTime? dateOfBirth;
  final Gender gender;
  final double? heightCm;
  final double? weightKg;

  /// The two inputs a calorie target cannot be computed without, and the two
  /// the app had no way to ask for until the quiz existed.
  final ActivityLevel? activityLevel;
  final WeightGoal? goal;

  /// Where they are heading. Only meaningful when [goal] is not maintain.
  final double? goalWeightKg;

  /// Kilograms per week. 0.5 is the usual recommendation — roughly a 500 kcal
  /// daily change — and the quiz does not offer a rate fast enough to be
  /// unsafe.
  final double weeklyRateKg;

  /// Whether there is enough here to compute a real target.
  ///
  /// What decides whether the quiz is shown. Everything else about a profile is
  /// optional; without these five the app can only show [defaultTargets], which
  /// is the same number for everybody.
  bool get canPersonaliseTargets =>
      age != null &&
      heightCm != null &&
      weightKg != null &&
      activityLevel != null &&
      goal != null;

  /// Daily goals — what the ring and the macro cards count against.
  final Nutrition targets;

  final bool isPremium;

  /// Whole years, or null when no date of birth is set.
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    var years = now.year - dateOfBirth!.year;
    final hadBirthday = now.month > dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day >= dateOfBirth!.day);
    if (!hadBirthday) years--;
    return years;
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatar,
    DateTime? dateOfBirth,
    Gender? gender,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    WeightGoal? goal,
    double? goalWeightKg,
    double? weeklyRateKg,
    Nutrition? targets,
    bool? isPremium,
  }) =>
      UserProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        avatar: avatar ?? this.avatar,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activityLevel: activityLevel ?? this.activityLevel,
        goal: goal ?? this.goal,
        goalWeightKg: goalWeightKg ?? this.goalWeightKg,
        weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
        targets: targets ?? this.targets,
        isPremium: isPremium ?? this.isPremium,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar': avatar,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'gender': gender.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevel?.name,
        'goal': goal?.name,
        'goalWeightKg': goalWeightKg,
        'weeklyRateKg': weeklyRateKg,
        'targets': targets.toJson(),
        'isPremium': isPremium,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatar: json['avatar'] as String? ??
            'assets/images/app/avatar.png',
        dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? ''),
        gender: Gender.values
                .where((g) => g.name == json['gender'])
                .firstOrNull ??
            Gender.unspecified,
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        // Unknown names fall back to null rather than throwing, so a value
        // added server-side cannot crash an older build.
        activityLevel: ActivityLevel.values
            .where((a) => a.name == json['activityLevel'])
            .firstOrNull,
        goal: WeightGoal.values
            .where((g) => g.name == json['goal'])
            .firstOrNull,
        goalWeightKg: (json['goalWeightKg'] as num?)?.toDouble(),
        weeklyRateKg: (json['weeklyRateKg'] as num?)?.toDouble() ?? 0.5,
        targets: json['targets'] == null
            ? defaultTargets
            : Nutrition.fromJson(
                (json['targets'] as Map).cast<String, dynamic>()),
        isPremium: json['isPremium'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.targets == targets &&
      other.isPremium == isPremium;

  @override
  int get hashCode => Object.hash(id, name, email, targets, isPremium);
}
