import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the Riverpod behaviour the scan result screen was built on top of.
///
/// A tester photographed their lunch and watched "Estimating portions" sweep
/// over a photograph of someone sitting at a desk — the *previous* scan — then
/// scanned a packet and watched it sweep over the previous product's picture.
///
/// The cause is not obvious from reading the controller, which assigns a plain
/// `state = const AsyncLoading()` and looks like it clears everything. It does
/// not: on an `AsyncNotifier`, that assignment **keeps the previous value**, so
/// `state.value` stays populated for the whole of the next scan. The screen
/// read `scan?.photoPath` off it for both the hero and the progress overlay.
///
/// If a Riverpod upgrade ever changes this, the guard in `scan_result_screen`
/// becomes dead weight rather than load-bearing — and this test is how anyone
/// finds that out, because nothing else in the suite would notice.
class _Probe extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => 'first';

  Future<void> next() async {
    state = const AsyncLoading();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    state = const AsyncData('second');
  }
}

final _probe = AsyncNotifierProvider<_Probe, String?>(_Probe.new);

void main() {
  test('a bare AsyncLoading on an AsyncNotifier keeps the previous value',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(_probe.future);
    expect(container.read(_probe).value, 'first');

    final pending = container.read(_probe.notifier).next();
    final during = container.read(_probe);

    expect(during.isLoading, isTrue);
    // The whole bug, in one line. Reading `.value` while loading hands back
    // the thing that is being replaced.
    expect(during.value, 'first');

    await pending;
    expect(container.read(_probe).value, 'second');
  });
}
