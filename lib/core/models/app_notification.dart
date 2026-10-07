import 'package:flutter/foundation.dart';

import '../notifications/notification_category.dart';

/// A message in the notifications list.
///
/// The artboard shows only body copy on every row, so [title] is unused today —
/// it exists because a push payload carries one and dropping it on ingest would
/// be lossy.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.body,
    required this.createdAt,
    this.title = '',
    this.read = false,
    this.category,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String title;
  final bool read;

  /// Which switch governs it, and therefore which OS channel it belongs to.
  ///
  /// `ActivityFeed` already decided this when it chose whether to emit the
  /// entry at all; it simply had nowhere to put the answer, so the delivery
  /// layer could not tell a streak milestone from a lunch nudge. Null is the
  /// welcome entry, which hangs off no preference.
  final NotificationCategory? category;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        body: body,
        createdAt: createdAt,
        title: title,
        read: read ?? this.read,
        category: category,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'read': read,
        'category': category?.name,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        body: json['body'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        title: json['title'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        category: NotificationCategory.values
            .where((c) => c.name == json['category'])
            .firstOrNull,
      );

  @override
  bool operator ==(Object other) =>
      other is AppNotification && other.id == id && other.read == read;

  @override
  int get hashCode => Object.hash(id, read);
}
