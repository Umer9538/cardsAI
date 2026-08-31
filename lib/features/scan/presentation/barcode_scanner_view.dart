import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/design/design_canvas.dart';
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

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
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
  void dispose() {
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
    _controller.stop();
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
