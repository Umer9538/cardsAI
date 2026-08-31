import 'package:carbsai/features/settings/presentation/notification_settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

void main() {
  setUpAll(loadDesignFonts);

  testWidgets('notif37 matches the design artboard', (tester) async {
    await renderScreen(tester, const NotificationSettingsScreen(), outputName: 'notif37_actual.png');
  });
}
