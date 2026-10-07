import 'package:carbsai/features/splash/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('splash matches the design artboard size', (tester) async {
    await renderScreen(
      tester,
      // Reduced motion, which the screen maps to its *finished* frame.
      //
      // The splash animates in now, and it keeps one element breathing while
      // it stands in for a wait — so a plain render lands on whatever frame
      // the harness's bounded pumps happen to reach, and the golden stops
      // meaning anything. Asking for the end state is both deterministic and
      // the thing worth diffing against the artboard: the artboard is the
      // finished frame.
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: SplashScreen(),
      ),
      outputName: 'splash_actual3x.png',
    );
  });
}
