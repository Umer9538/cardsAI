import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'json_store.dart';

class LocalWaterRepository implements WaterRepository {
  LocalWaterRepository(this._store) {
    _load();
  }

  final JsonStore _store;
  final _controller = StreamController<List<WaterEntry>>.broadcast();
  static const _uuid = Uuid();

  List<WaterEntry> _entries = const [];

  void _load() {
    final stored = _store.readList(StoreKeys.water) ?? const [];
    _entries = [for (final json in stored) WaterEntry.fromJson(json)]
      ..sort((a, b) => a.at.compareTo(b.at));
    _controller.add(_entries);
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  List<WaterEntry> _on(DateTime day) {
    final midnight = _midnight(day);
    return [
      for (final entry in _entries)
        if (entry.day == midnight) entry,
    ];
  }

  @override
  Stream<List<WaterEntry>> watchDay(DateTime day) async* {
    yield _on(day);
    yield* _controller.stream.map((_) => _on(day));
  }

  @override
  Future<Map<DateTime, double>> totalsBetween(
    DateTime from,
    DateTime to,
  ) async {
    final totals = <DateTime, double>{};
    for (final entry in _entries) {
      if (entry.at.isBefore(from) || entry.at.isAfter(to)) continue;
      totals[entry.day] = (totals[entry.day] ?? 0) + entry.ml;
    }
    return totals;
  }

  @override
  Future<void> log(double ml, {DateTime? at}) async {
    if (ml <= 0) return;
    _entries = [
      ..._entries,
      WaterEntry(id: _uuid.v4(), at: at ?? DateTime.now(), ml: ml),
    ]..sort((a, b) => a.at.compareTo(b.at));
    await _persist();
    _controller.add(_entries);
  }

  @override
  Future<void> removeLast(DateTime day) async {
    final onDay = _on(day);
    if (onDay.isEmpty) return;
    final last = onDay.last;
    _entries = [
      for (final entry in _entries)
        if (entry.id != last.id) entry,
    ];
    await _persist();
    _controller.add(_entries);
  }

  Future<void> _persist() => _store.writeList(
        StoreKeys.water,
        _entries.map((e) => e.toJson()).toList(),
      );

  void dispose() => _controller.close();
}
