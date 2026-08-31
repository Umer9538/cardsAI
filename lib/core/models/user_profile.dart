import 'package:flutter/foundation.dart';

import 'nutrition.dart';

enum Gender { female, male, other, unspecified }

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
    this.targets = defaultTargets,
    this.isPremium = false,
  });

  /// Stand-in goals until onboarding collects real ones. Chosen to match the
  /// figures the artboards show, so the seeded app looks like the design.
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
