import 'package:carbsai/features/favorites/presentation/favorites_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('fav41 matches the design artboard', (tester) async {
    await renderScreen(tester, const FavoritesScreen(), outputName: 'fav41_actual.png');
  });
}
