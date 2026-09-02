import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:carbsai/core/app_config.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Helpers for rendering a screen at its Figma artboard size and writing the
// result to `build/`, so it can be diffed against an export from the design
// file.
//
// Each screen gets its own `*_render_test.dart`. That is deliberate: two of
// these renders in one file deadlock the second `runAsync`/`precacheImage`
// pass, and `flutter test` isolates files in separate processes, which sizes
// the workaround to the problem.

/// A [ProviderScope] backed by an empty in-memory store.
///
/// Screens read their data through providers now, so every render needs one.
/// Starting from empty preferences means the repositories seed themselves, which
/// is exactly the state a fresh install renders in — the same state the
/// artboards were drawn against.
///
/// The backend is pinned to [AppBackend.local]: there is no Firebase in a
/// widget test, and the default would have every repository reach for
/// `FirebaseAuth.instance` and throw.
Future<Widget> designScope(Widget child) async =>
    (await designScopeBuilder())(child);

/// A reusable scope wrapper, holding one set of overrides.
///
/// A test that pumps several screens in a row must build this **once** and
/// reuse it. Calling [designScope] per screen hands `jsonStoreProvider` a new
/// store each time, which tears down every repository and closes its stream
/// controller while the next screen is mid-build — surfacing as
/// "setState() called during build" against whichever screen happened to be
/// building at the time.
///
/// Returns a closure rather than the override list because Riverpod does not
/// export `Override` from its public API, so the list's type cannot be written
/// down — only inferred.
Future<Widget Function(Widget)> designScopeBuilder() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final store = await JsonStore.open();
  final overrides = [
    jsonStoreProvider.overrideWithValue(store),
    backendProvider.overrideWithValue(AppBackend.local),
  ];
  return (child) => ProviderScope(overrides: overrides, child: child);
}

Future<void> loadDesignFonts() async {
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final data = File('assets/fonts/SpaceGrotesk-$f.ttf').readAsBytesSync();
    await (FontLoader('SpaceGrotesk')
          ..addFont(Future.value(ByteData.view(data.buffer))))
        .load();
  }
}

/// Pumps [screen] on a 428x926 viewport, waits for its assets to decode, and
/// writes a 3x PNG to `build/$outputName`.
/// [before] runs after the screen has settled and its images have decoded, but
/// before the capture — for rendering a state that only exists after an
/// interaction, such as an overlay behind a tap.
Future<void> renderScreen(
  WidgetTester tester,
  Widget screen, {
  required String outputName,
  Future<void> Function(WidgetTester tester)? before,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(428, 926);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    await designScope(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(child: screen),
      ),
    ),
  );

  // Repositories seed and emit on a microtask, so the first frame is empty.
  // Bounded pumps rather than pumpAndSettle: a screen with a progress
  // indicator on it never settles, and pumpAndSettle would hang the file for
  // its full timeout rather than failing.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  if (before != null) {
    await before(tester);
    await tester.pump(const Duration(milliseconds: 400));
  }

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );

  // The capture has to run inside runAsync, all of it.
  //
  // `toByteData` hands the layer tree to the engine's raster thread and waits
  // for a real callback. Awaited in the test's fake-async zone that future is
  // never completed — the clock the zone controls is not the one the engine is
  // waiting on — so the test hangs until the process is killed, and the file is
  // never written. `toImage` happens to return anyway, which makes this look
  // like it works right up to the last line.
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    Directory('build').createSync(recursive: true);
    File('build/$outputName').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
