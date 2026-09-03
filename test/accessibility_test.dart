import 'package:carbsai/features/app/presentation/home_screen.dart';
import 'package:carbsai/features/app/presentation/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The app had 39 tappable widgets and zero `Semantics` — every icon-only
/// control was silent to a screen reader, which for a bare glyph means the
/// control does not exist at all for anyone not looking at it.
///
/// This matters more here than for a general app: the launch plan markets into
/// diabetes communities, which skew older.
void main() {
  setUpAll(loadDesignFonts);

  testWidgets('the tab bar announces every tab', (tester) async {
    // Disposed at the end of the body, not via addTearDown: the framework
    // checks for leaked handles before tear-downs run.
    final handle = tester.ensureSemantics();

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await designScope(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    for (final tab in AppTab.values) {
      expect(
        find.bySemanticsLabel(tab.label),
        findsOneWidget,
        reason: '${tab.name} tab is unlabelled',
      );
    }
    handle.dispose();
  });

  testWidgets('the header glyphs say what they do', (tester) async {
    // Disposed at the end of the body, not via addTearDown: the framework
    // checks for leaked handles before tear-downs run.
    final handle = tester.ensureSemantics();

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(428, 926);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await designScope(
        const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: HomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // The crown and the bell are exported images with no text near them.
    expect(find.bySemanticsLabel('Go Premium'), findsOneWidget);
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
    handle.dispose();
  });
}
