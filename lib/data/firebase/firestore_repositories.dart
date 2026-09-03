import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../local/seed_data.dart';

/// Firestore layout
/// ----------------
/// ```
/// users/{uid}                          profile
/// users/{uid}/meals/{mealId}           the diary
/// users/{uid}/plans/{planId}           the catalogue, per user
/// users/{uid}/notifications/{id}
/// users/{uid}/prefs/notifications      one document of booleans
/// ```
///
/// Everything hangs off `users/{uid}`, which makes the security rules a single
/// rule: a signed-in user reads and writes their own subtree and nothing else.
///
/// The plan catalogue is copied per user rather than shared. With eight plans
/// that costs almost nothing, and it means the favourite and saved flags live
/// on the plan document instead of needing a join against a shared collection
/// on every read. Split it out if the catalogue ever grows or needs editing
/// centrally.
///
/// Offline is Firestore's own: its cache is enabled by default on mobile, so
/// the diary keeps working with no connection and writes replay on reconnect.
mixin _UserScoped {
  FirebaseFirestore get firestore;
  fb.FirebaseAuth get auth;

  /// Throws rather than returning null: every one of these repositories is only
  /// reachable from inside the signed-in shell, so a missing user is a bug in
  /// the routing, not a state to render.
  String get _uid {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw const RepositoryException(
        'You need to be signed in.',
        code: 'not-signed-in',
      );
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> get userDoc =>
      firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> collection(String name) =>
      userDoc.collection(name);

  /// Emits once per auth change so a stream started before sign-in does not
  /// stay stuck on a permission error.
  Stream<T> whenSignedIn<T>(Stream<T> Function() build, T empty) {
    return auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<T>.value(empty);
      return build();
    });
  }
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

class FirestoreProfileRepository with _UserScoped implements ProfileRepository {
  FirestoreProfileRepository(this.firestore, this.auth);

  @override
  final FirebaseFirestore firestore;
  @override
  final fb.FirebaseAuth auth;

  @override
  Stream<UserProfile?> watch() => whenSignedIn(
        () => userDoc.snapshots().map(
              (snap) => snap.data() == null
                  ? null
                  : UserProfile.fromJson(snap.data()!),
            ),
        null,
      );

  @override
  Future<UserProfile?> load() async {
    final snap = await userDoc.get();
    final data = snap.data();
    return data == null ? null : UserProfile.fromJson(data);
  }

  @override
  Future<UserProfile> save(UserProfile profile) async {
    // Deliberately not awaited.
    //
    // Firestore's write future resolves when the SERVER acknowledges, not when
    // the local cache has it. Awaiting it put a server round trip — tens of
    // seconds on a cold connection, forever when offline — directly in front of
    // the sign-up button, which sat spinning the whole time. The local write is
    // synchronous and the SDK guarantees the write eventually lands, so there
    // is nothing to wait for.
    unawaited(
      userDoc.set(profile.toJson(), SetOptions(merge: true)).catchError(
        (Object error) => debugPrint('profile save failed: $error'),
      ),
    );
    return profile;
  }
}

// ---------------------------------------------------------------------------
// Diary
// ---------------------------------------------------------------------------

class FirestoreDiaryRepository with _UserScoped implements DiaryRepository {
  FirestoreDiaryRepository(this.firestore, this.auth, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  @override
  final FirebaseFirestore firestore;
  @override
  final fb.FirebaseAuth auth;

  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> get _meals => collection('meals');

  /// `eatenAt` is stored twice: as an ISO string inside the model's own JSON,
  /// and as a Firestore [Timestamp] alongside it. Only the Timestamp is
  /// range-queryable; the string keeps [Meal.fromJson] working unchanged.
  Map<String, dynamic> _encode(Meal meal) => {
        ...meal.toJson(),
        'eatenAtTs': Timestamp.fromDate(meal.eatenAt),
      };

  @override
  Stream<List<Meal>> watchDay(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return whenSignedIn(
      () => _meals
          .where('eatenAtTs', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('eatenAtTs', isLessThan: Timestamp.fromDate(end))
          .orderBy('eatenAtTs')
          .snapshots()
          .map((snap) => snap.docs.map((d) => Meal.fromJson(d.data())).toList()),
      const <Meal>[],
    );
  }

  @override
  Future<List<Meal>> mealsBetween(DateTime from, DateTime to) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    final snap = await _meals
        .where('eatenAtTs', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('eatenAtTs', isLessThan: Timestamp.fromDate(end))
        .orderBy('eatenAtTs')
        .get();

    return snap.docs.map((d) => Meal.fromJson(d.data())).toList();
  }

  @override
  Future<Meal> addMeal(Meal meal) async {
    await _meals.doc(meal.id).set(_encode(meal));
    return meal;
  }

  @override
  Future<Meal> updateMeal(Meal meal) async {
    await _meals.doc(meal.id).set(_encode(meal));
    return meal;
  }

  @override
  Future<void> deleteMeal(String id) => _meals.doc(id).delete();

  @override
  Future<int> currentStreak() async {
    // A streak cannot be longer than this without the query getting expensive,
    // and a year is well past the point where the number stops motivating.
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final meals = await mealsBetween(
      today.subtract(const Duration(days: 365)),
      today,
    );

    final counts = <DateTime, int>{};
    for (final meal in meals) {
      counts.update(meal.day, (n) => n + 1, ifAbsent: () => 1);
    }

    var day = today;
    var streak = 0;

    // Today not yet qualifying does not break a running streak — the day is
    // not over. Start from yesterday instead.
    if ((counts[day] ?? 0) < 2) day = day.subtract(const Duration(days: 1));

    while ((counts[day] ?? 0) >= 2) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

// ---------------------------------------------------------------------------
// Plans
// ---------------------------------------------------------------------------

class FirestoreDietRepository with _UserScoped implements DietRepository {
  FirestoreDietRepository(this.firestore, this.auth);

  @override
  final FirebaseFirestore firestore;
  @override
  final fb.FirebaseAuth auth;

  CollectionReference<Map<String, dynamic>> get _plans => collection('plans');

  Stream<List<DietPlan>> _watch(bool Function(DietPlan) where) => whenSignedIn(
        () => _plans.snapshots().asyncMap((snap) async {
          // Not gated on `!snap.metadata.isFromCache`, which is what the
          // seeding used to wait for.
          //
          // Firestore's offline cache serves reads and accepts writes with no
          // server at all, so an app whose database is unreachable — or simply
          // not created yet — runs happily on cached documents and *never*
          // emits a non-cache snapshot. The reconcile behind that condition
          // therefore never ran, and the stale flags it was written to clear
          // stayed exactly where they were. Once per repository instead: the
          // write lands in the cache immediately and replays when a server
          // shows up.
          await _syncOnce();
          if (snap.docs.isEmpty && !snap.metadata.isFromCache) {
            return const <DietPlan>[];
          }
          return snap.docs
              .map((d) => DietPlan.fromJson(d.data()))
              .where(where)
              .toList();
        }),
        const <DietPlan>[],
      );

  @override
  Stream<List<DietPlan>> watchAll() => _watch((_) => true);

  @override
  Stream<List<DietPlan>> watchMine() => _watch((plan) => plan.isMine);

  @override
  Stream<List<DietPlan>> watchFavorites() => _watch((plan) => plan.isFavorite);

  /// A generated plan, written into the user's own plan collection.
  ///
  /// `syncCatalogue` leaves it alone: that walks [SeedData] and only touches
  /// documents whose ids are in it.
  @override
  Future<DietPlan> add(DietPlan plan) async {
    final saved = plan.copyWith(isMine: true);
    await _plans.doc(saved.id).set(saved.toJson());
    return saved;
  }

  @override
  Future<DietPlan> setFavorite(String id, {required bool favorite}) =>
      _update(id, {'isFavorite': favorite});

  @override
  Future<DietPlan> setMine(String id, {required bool mine}) =>
      _update(id, {'isMine': mine});

  Future<DietPlan> _update(String id, Map<String, dynamic> change) async {
    final doc = _plans.doc(id);
    await doc.update(change);
    final snap = await doc.get();
    return DietPlan.fromJson(snap.data()!);
  }

  /// Copies the starter catalogue into a new account.
  ///
  /// Not transactional: worst case two devices race and write the same
  /// documents with the same ids, which is idempotent.
  ///
  /// **This reconciles rather than seeding once.** The old version wrote the
  /// catalogue only when the collection was empty and never looked again, so a
  /// plan added to `SeedData` after a user first signed in never reached them,
  /// and a corrected description never propagated. Every existing account was
  /// frozen on whatever the catalogue looked like the day they joined.
  ///
  /// Content is refreshed from the catalogue; `isMine` and `isFavorite` are
  /// left alone, because those are the user's and the catalogue has no opinion
  /// about them.
  Future<void>? _syncing;

  /// At most one reconcile per repository, shared by all three streams.
  Future<void> _syncOnce() => _syncing ??= syncCatalogue();

  Future<void> syncCatalogue() async {
    final existing = await _plans.get();
    final byId = {for (final doc in existing.docs) doc.id: doc.data()};

    // v1 shipped three plans with `isMine` and `isFavorite` already true, so
    // every account seeded under it opened onto a My Diets tab full of choices
    // nobody had made. Those flags were never a user decision, so clearing them
    // once loses nothing real — but it does have to happen exactly once, or it
    // would wipe the genuine choices made afterwards.
    final marker = await _prefs.doc('plans').get();
    final version = (marker.data()?['seedVersion'] as num?)?.toInt() ?? 1;
    final resetFlags = existing.docs.isNotEmpty && version < _catalogueVersion;

    final batch = firestore.batch();
    for (final plan in SeedData.dietPlans) {
      final stored = byId[plan.id];
      if (stored == null) {
        batch.set(_plans.doc(plan.id), plan.toJson());
        continue;
      }
      batch.set(
        _plans.doc(plan.id),
        plan
            .copyWith(
              isMine: resetFlags ? false : stored['isMine'] as bool? ?? false,
              isFavorite:
                  resetFlags ? false : stored['isFavorite'] as bool? ?? false,
            )
            .toJson(),
      );
    }
    batch.set(
      _prefs.doc('plans'),
      {'seedVersion': _catalogueVersion},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Bumped whenever the catalogue changes in a way that must reach accounts
  /// that already exist.
  static const int _catalogueVersion = 4;

  CollectionReference<Map<String, dynamic>> get _prefs => collection('prefs');
}

// ---------------------------------------------------------------------------
// Weight
// ---------------------------------------------------------------------------

class FirestoreWeightRepository with _UserScoped implements WeightRepository {
  FirestoreWeightRepository(this.firestore, this.auth);

  @override
  final FirebaseFirestore firestore;
  @override
  final fb.FirebaseAuth auth;

  CollectionReference<Map<String, dynamic>> get _weights => collection('weights');

  @override
  Stream<WeightHistory> watch() => whenSignedIn(
        () => _weights.orderBy('at').snapshots().map(
              (snap) => WeightHistory([
                for (final doc in snap.docs) WeightEntry.fromJson(doc.data()),
              ]),
            ),
        WeightHistory.empty,
      );

  @override
  Future<void> log(double kg, {DateTime? at}) async {
    final when = at ?? DateTime.now();
    // The document id *is* the day, which is what makes one reading per day a
    // property of the storage rather than a rule the client has to remember.
    final id = when.toIso8601String().substring(0, 10);
    await _weights
        .doc(id)
        .set(WeightEntry(id: id, at: when, kg: kg).toJson());
  }

  @override
  Future<void> remove(String id) => _weights.doc(id).delete();
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

class FirestoreNotificationRepository
    with _UserScoped
    implements NotificationRepository {
  FirestoreNotificationRepository(this.firestore, this.auth);

  @override
  final FirebaseFirestore firestore;
  @override
  final fb.FirebaseAuth auth;

  CollectionReference<Map<String, dynamic>> get _items =>
      collection('notifications');

  @override
  Stream<List<AppNotification>> watch() => whenSignedIn(
        () => _items
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snap) => snap.docs
                .map((d) => AppNotification.fromJson(d.data()))
                .toList()),
        const <AppNotification>[],
      );

  @override
  Future<void> markRead(String id) => _items.doc(id).update({'read': true});

  @override
  Future<void> markAllRead() async {
    final unread = await _items.where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Future<void> clear() async {
    final all = await _items.get();
    final batch = firestore.batch();
    for (final doc in all.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

// ---------------------------------------------------------------------------
// Notification preferences
// ---------------------------------------------------------------------------

class FirestoreNotificationSettingsRepository
    with _UserScoped
    implements NotificationSettingsRepository {
  FirestoreNotificationSettingsRepository(this.firestore, this.auth);

  @override
  final FirebaseFirestore firestore;
  @override
  final fb.FirebaseAuth auth;

  DocumentReference<Map<String, dynamic>> get _doc =>
      collection('prefs').doc('notifications');

  @override
  Stream<Map<String, bool>> watch() => whenSignedIn(
        () => _doc.snapshots().map((snap) {
          final data = snap.data();
          if (data == null) return SeedData.notificationSettings;
          return data.map((key, value) => MapEntry(key, value == true));
        }),
        SeedData.notificationSettings,
      );

  @override
  Future<void> setEnabled(String key, {required bool enabled}) =>
      _doc.set({key: enabled}, SetOptions(merge: true));
}
