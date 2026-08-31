import 'dart:async';

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import 'json_store.dart';

class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._store);

  final JsonStore _store;
  final _controller = StreamController<UserProfile?>.broadcast();

  UserProfile? _cached;
  bool _loaded = false;

  @override
  Stream<UserProfile?> watch() async* {
    yield await load();
    yield* _controller.stream;
  }

  @override
  Future<UserProfile?> load() async {
    if (_loaded) return _cached;
    final stored = _store.readMap(StoreKeys.profile);
    _cached = stored == null ? null : UserProfile.fromJson(stored);
    _loaded = true;
    return _cached;
  }

  @override
  Future<UserProfile> save(UserProfile profile) async {
    await _store.writeMap(StoreKeys.profile, profile.toJson());
    _cached = profile;
    _loaded = true;
    _controller.add(profile);
    return profile;
  }

  void dispose() => _controller.close();
}
