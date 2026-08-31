import 'package:carbsai/features/app/presentation/notifications_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('notif25 matches the design artboard', (tester) async {
    await renderScreen(tester, const NotificationsScreen(), outputName: 'notif25_actual.png');
  });
}
