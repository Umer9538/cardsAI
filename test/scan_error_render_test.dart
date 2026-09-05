import 'package:carbsai/core/app_config.dart';
import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/features/scan/presentation/scan_controller.dart';
import 'package:carbsai/features/scan/presentation/scan_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_reminder_service.dart';

/// A failure the pipeline did not translate must still reach the screen as a
/// sentence a person can read.
///
/// Found by running a release APK: it had been built by hand, without
/// `--dart-define=WORKER_URL`, so [AppConfig.workerUri] threw a bare
/// `StateError`. `ScanController.errorCode` cast that to
/// `RepositoryException?`, the cast threw a `TypeError`, and it threw from
/// inside `ScanResultScreen.build` — so Flutter replaced the entire route with
/// an `ErrorWidget`. That widget assembles its message inside an `assert`, so
/// in a release build it is a plain grey rectangle with no text at all.
///
/// The only screen that could have explained the failure was the one the
/// failure destroyed. Every error path through this screen is now exercised
/// with something that is *not* a [RepositoryException], because that is the
/// case the cast got wrong and the case nobody thinks to try.
class _ThrowingScanRepository implements ScanRepository {
  const _ThrowingScanRepository(this.error);

  final Object error;

  @override
  Future<ScanResult> analyzePhoto({
    required String imagePath,
    String? hint,
    ScanInput input = ScanInput.photo,
  }) async =>
      throw error;

  @override
  Future<ScanResult> analyzeText(String description) async => throw error;

  @override
  Future<ScanResult> lookupBarcode(String barcode) async => throw error;

  @override
  Future<List<ScanResult>> history({int limit = 50}) async => throw error;
}

void main() {
  testWidgets(
    'an untranslated failure renders as a message, not Flutter’s error box',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = await JsonStore.open();

      // The exact failure the device hit: no WORKER_URL, so building the
      // endpoint throws before any request is made.
      final failure = StateError(
        'WORKER_URL is not set. Build with --dart-define=WORKER_URL=…',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jsonStoreProvider.overrideWithValue(store),
            backendProvider.overrideWithValue(AppBackend.local),
            reminderServiceProvider.overrideWithValue(FakeReminderService()),
            scanRepositoryProvider
                .overrideWithValue(_ThrowingScanRepository(failure)),
          ],
          child: const MaterialApp(home: ScanResultScreen()),
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ScanResultScreen)),
      );
      final notifier = container.read(scanControllerProvider.notifier);

      await notifier.analyzePhoto('/tmp/plate.jpg');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(scanControllerProvider).hasError, isTrue);

      // Reading the code must not throw just because the error came from
      // somewhere the repositories do not own. This is the line that failed.
      expect(notifier.errorCode, isNull);
      expect(notifier.outOfScans, isFalse);
      expect(notifier.errorMessage, isNotNull);

      // And the route must still be the screen rather than the grey box.
      expect(
        find.byType(ErrorWidget),
        findsNothing,
        reason: 'the route was replaced by an ErrorWidget — the grey rectangle '
            'a release build shows when a widget throws during build',
      );
      expect(find.text(notifier.errorMessage!), findsOneWidget);
    },
  );
}
