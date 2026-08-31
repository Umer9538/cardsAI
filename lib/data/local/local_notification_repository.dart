import 'dart:async';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'json_store.dart';
import 'seed_data.dart';

class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this._store, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now {
    _load();
  }

  final JsonStore _store;
  final DateTime Function() _now;
  final _controller = StreamController<List<AppNotification>>.broadcast();

  List<AppNotification> _items = const [];
  bool _loaded = false;

  void _load() {
    final stored = _store.readList(StoreKeys.notifications);
    _items = stored == null
        ? SeedData.notifications(_now())
        : stored.map(AppNotification.fromJson).toList();
    if (stored == null) unawaited(_persist());
    _loaded = true;
    _controller.add(_items);
  }

  Future<void> _persist() => _store.writeList(
        StoreKeys.notifications,
        _items.map((n) => n.toJson()).toList(),
      );

  Future<void> _ready() async {
    while (!_loaded) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  @override
  Stream<List<AppNotification>> watch() async* {
    await _ready();
    yield _sorted;
    yield* _controller.stream.map((_) => _sorted);
  }

  List<AppNotification> get _sorted =>
      [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> markRead(String id) async {
    await _ready();
    _items = [
      for (final item in _items)
        if (item.id == id) item.copyWith(read: true) else item,
    ];
    await _persist();
    _controller.add(_items);
  }

  @override
  Future<void> markAllRead() async {
    await _ready();
    _items = [for (final item in _items) item.copyWith(read: true)];
    await _persist();
    _controller.add(_items);
  }

  @override
  Future<void> clear() async {
    await _ready();
    _items = const [];
    await _persist();
    _controller.add(_items);
  }
}

class LocalNotificationSettingsRepository
    implements NotificationSettingsRepository {
  LocalNotificationSettingsRepository(this._store) {
    _load();
  }

  final JsonStore _store;
  final _controller = StreamController<Map<String, bool>>.broadcast();

  Map<String, bool> _settings = const {};
  bool _loaded = false;

  void _load() {
    final stored = _store.readMap(StoreKeys.notificationSettings);
    _settings = stored == null
        ? SeedData.notificationSettings
        : stored.map((key, value) => MapEntry(key, value == true));
    if (stored == null) unawaited(_persist());
    _loaded = true;
    _controller.add(_settings);
  }

  Future<void> _persist() =>
      _store.writeMap(StoreKeys.notificationSettings, _settings);

  @override
  Stream<Map<String, bool>> watch() async* {
    while (!_loaded) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    yield _settings;
    yield* _controller.stream;
  }

  @override
  Future<void> setEnabled(String key, {required bool enabled}) async {
    _settings = {..._settings, key: enabled};
    await _persist();
    _controller.add(_settings);
  }
}
