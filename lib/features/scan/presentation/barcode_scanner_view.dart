import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/route_observer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// The live barcode reader, shown inside the scanning screen's viewfinder when
/// AI Barcode is the selected mode.
///
/// It runs its own camera session rather than sharing the one behind the photo
/// preview: two packages cannot hold the same camera at once, so the scanning
/// screen releases ours before this appears. That is why switching modes takes
/// a beat.
class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({super.key, required this.onDetected});

  /// Fired once, with the first barcode read. The scanner stops itself after —
  /// a reader that keeps firing turns one product into a dozen lookups.
  final ValueChanged<String> onDetected;

  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView>
    with RouteAware {
  late final MobileScannerController _controller = MobileScannerController(
    // Only the symbologies actually printed on food packaging. Narrowing the
    // set measurably speeds up detection and stops QR codes on a menu being
    // read as a product.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    // Null in a widget test that pumps this view bare, and not a PageRoute
    // inside a sheet. Neither needs the subscription.
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  /// The result screen has been pushed over us.
  ///
  /// Nothing to do — [_onDetect] already stopped the reader — but the pairing
  /// with [didPopNext] is the point: this class now has one place that says
  /// what happens when the screen is covered and uncovered.
  @override
  void didPushNext() => _stop();

  /// Back from the result screen, onto a scanner that stopped itself when it
  /// read the code. Without this the viewfinder is black and nothing will ever
  /// restart it — scan once, come back, and the camera is dead for good.
  @override
  void didPopNext() {
    _handled = false;
    unawaited(_controller.start().catchError((Object _) {}));
  }

  void _stop() => unawaited(_controller.stop().catchError((Object _) {}));

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((v) => v.trim().isNotEmpty)
        .firstOrNull;
    if (value == null) return;

    _handled = true;
    // Best effort. If the platform side has already gone away, stopping is
    // moot — and letting it throw here would surface as an unhandled async
    // error on top of a scan that actually succeeded.
    _stop();
    widget.onDetected(value);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: DesignCanvas.designWidth,
      height: DesignCanvas.designHeight,
      child: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        fit: BoxFit.cover,
        errorBuilder: (context, error) => _ScannerError(error: error),
      ),
    );
  }
}

/// A refused permission or an unavailable camera, said plainly.
///
/// The scanning screen's own fallback photograph would be actively misleading
/// here: it looks like a working camera that simply never finds a barcode.
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'Carbsai needs camera access to read a barcode. You can turn it on in '
            'Settings.',
      MobileScannerErrorCode.unsupported =>
        'This device cannot scan barcodes.',
      _ => 'The scanner could not start. Try a photo instead.',
    };

    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            message,
            style: AppTypography.body(color: AppColors.placeholder),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
