import 'package:carbsai/core/app_config.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/features/app/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/design_render.dart';

/// `unreadNotificationCountProvider` has existed since the inbox did and was
/// read by nothing, so the bell looked identical whether there were six unread
/// messages or none.
class _Notifications implements NotificationRepository {
  _Notifications(this.items);
  final List<AppNotification> items;

  @override
  Stream<List<AppNotification>> watch() => Stream.value(items);
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<void> markAllRead() async {}
  @override
  Future<void> clear() async {}
  @override
  Future<List<AppNotification>> upsertAll(
    List<AppNotification> entries,
  ) async =>
      const [];
}

AppNotification _n(String id, {required bool read}) => AppNotification(
      id: id,
      body: 'Body $id',
      createdAt: DateTime(2026, 10, 6),
      read: read,
    );

Future<void> _pump(WidgetTester tester, List<AppNotification> items) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(428, 926);
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = await JsonStore.open();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonStoreProvider.overrideWithValue(store),
        backendProvider.overrideWithValue(AppBackend.local),
        notificationRepositoryProvider.overrideWithValue(_Notifications(items)),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}

/// The bell, found by its own `Semantics` widget.
///
/// Not `find.bySemanticsLabel`: that matches the *merged* node, and the header
/// buttons merge into their parents, so the label never matches there even
/// though it is plainly in the tree.
Finder _bell(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == label,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Without the real face the test font's fixed-width glyphs overflow an
  // unrelated row further down Home and bury the failure that matters.
  setUpAll(loadDesignFonts);

  testWidgets('the bell carries the unread count', (tester) async {
    await _pump(tester, [
      _n('a', read: false),
      _n('b', read: false),
      _n('c', read: true),
    ]);

    expect(_bell('Notifications, 2 unread'), findsOneWidget);
    expect(
      find.descendant(
        of: _bell('Notifications, 2 unread'),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    // A bare glyph with no text near it: for a screen reader the badge does
    // not otherwise exist at all.
  });

  testWidgets('nothing unread draws no badge', (tester) async {
    await _pump(tester, [_n('a', read: true)]);

    // A badge showing "0" is a notification that there is nothing to notify
    // you about. (Home draws a "0" of its own on the gauge, so this has to
    // look inside the bell rather than at the screen.)
    expect(_bell('Notifications'), findsOneWidget);
    expect(
      find.descendant(of: _bell('Notifications'), matching: find.byType(Text)),
      findsNothing,
    );
  });

  testWidgets('an empty inbox draws no badge', (tester) async {
    await _pump(tester, const []);
    expect(_bell('Notifications'), findsOneWidget);
  });

  testWidgets('it stops counting at 99+', (tester) async {
    await _pump(tester, [
      for (var i = 0; i < 140; i++) _n('n$i', read: false),
    ]);

    // Past that the exact number has stopped being information, and three
    // digits do not fit the disc.
    expect(
      find.descendant(
        of: _bell('Notifications, 140 unread'),
        matching: find.text('99+'),
      ),
      findsOneWidget,
    );
  });
}
