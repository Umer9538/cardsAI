import 'dart:async';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'json_store.dart';

class LocalActivityRepository implements ActivityRepository {
  LocalActivityRepository(this._store) {
    _load();
  }

  final JsonStore _store;
  final _controller = StreamController<List<ActivityEntry>>.broadcast();

  List<ActivityEntry> _entries = const [];

  void _load() {
    final stored = _store.readList(StoreKeys.activity) ?? const [];
    _entries = [for (final json in stored) ActivityEntry.fromJson(json)]
      ..sort((a, b) => a.at.compareTo(b.at));
    _controller.add(_entries);
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  List<ActivityEntry> _on(DateTime day) {
    final midnight = _midnight(day);
    return [
      for (final entry in _entries)
        if (entry.day == midnight) entry,
    ];
  }

  @override
  Stream<List<ActivityEntry>> watchDay(DateTime day) async* {
    yield _on(day);
    yield* _controller.stream.map((_) => _on(day));
  }

  @override
  Future<Map<DateTime, ActivityLog>> logsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final byDay = <DateTime, List<ActivityEntry>>{};
    for (final entry in _entries) {
      if (entry.at.isBefore(from) || entry.at.isAfter(to)) continue;
      (byDay[entry.day] ??= []).add(entry);
    }
    return {
      for (final day in byDay.keys) day: ActivityLog(entries: byDay[day]!),
    };
  }

  @override
  Future<void> log(ActivityEntry entry) async {
    if (entry.minutes < ActivityCatalogue.minimumMinutes) return;
    _entries = [
      for (final existing in _entries)
        if (existing.id != entry.id) existing,
      entry,
    ]..sort((a, b) => a.at.compareTo(b.at));
    await _persist();
    _controller.add(_entries);
  }

  @override
  Future<void> remove(String id) async {
    _entries = [
      for (final entry in _entries)
        if (entry.id != id) entry,
    ];
    await _persist();
    _controller.add(_entries);
  }

  Future<void> _persist() => _store.writeList(
        StoreKeys.activity,
        _entries.map((e) => e.toJson()).toList(),
      );

  void dispose() => _controller.close();
}
