import 'package:carbsai/features/app/presentation/notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('notifempty24 matches the design artboard', (tester) async {
    await renderScreen(tester, const NotificationsScreen(items: []), outputName: 'notifempty24_actual.png');
  });
}
