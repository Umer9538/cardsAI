import 'package:flutter/foundation.dart';

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
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String title;
  final bool read;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        body: body,
        createdAt: createdAt,
        title: title,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'title': title,
        'read': read,
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
      );

  @override
  bool operator ==(Object other) =>
      other is AppNotification && other.id == id && other.read == read;

  @override
  int get hashCode => Object.hash(id, read);
}
