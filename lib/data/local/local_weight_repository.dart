import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'json_store.dart';

class LocalWeightRepository implements WeightRepository {
  LocalWeightRepository(this._store) {
    _load();
  }

  final JsonStore _store;
  final _controller = StreamController<WeightHistory>.broadcast();
  static const _uuid = Uuid();

  List<WeightEntry> _entries = const [];

  void _load() {
    final stored = _store.readList(StoreKeys.weights) ?? const [];
    _entries = [for (final json in stored) WeightEntry.fromJson(json)]
      ..sort((a, b) => a.at.compareTo(b.at));
    _controller.add(WeightHistory(_entries));
  }

  @override
  Stream<WeightHistory> watch() async* {
    yield WeightHistory(_entries);
    yield* _controller.stream;
  }

  @override
  Future<void> log(double kg, {DateTime? at}) async {
    final when = at ?? DateTime.now();
    final day = DateTime(when.year, when.month, when.day);

    _entries = [
      // One reading per day. Two an hour apart are the same measurement taken
      // twice; keeping both would weight that day double in the trend.
      ..._entries.where((e) => e.day != day),
      WeightEntry(id: _uuid.v4(), at: when, kg: kg),
    ]..sort((a, b) => a.at.compareTo(b.at));

    await _persist();
    _controller.add(WeightHistory(_entries));
  }

  @override
  Future<void> remove(String id) async {
    _entries = _entries.where((e) => e.id != id).toList();
    await _persist();
    _controller.add(WeightHistory(_entries));
  }

  Future<void> _persist() => _store.writeList(
        StoreKeys.weights,
        _entries.map((e) => e.toJson()).toList(),
      );

  void dispose() => _controller.close();
}
