import 'package:carbsai/features/favorites/presentation/favorites_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('fav40 matches the design artboard', (tester) async {
    await renderScreen(tester, const FavoritesScreen(plans: []), outputName: 'fav40_actual.png');
  });
}
