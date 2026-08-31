import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'barcode_scanner_view.dart';
import 'camera_session.dart';

/// Capture modes offered above the shutter.
enum ScanMode {
  camera('AI Camera', 'assets/images/app/ic_camera.png'),
  barcode('AI Barcode', 'assets/images/app/ic_barcode.png'),
  gallery('AI Gallery', 'assets/images/app/ic_gallery.png');

  const ScanMode(this.label, this.icon);
  final String label;
  final String icon;
}

/// Camera capture — Figma frame `31_Scanning` (2002:1093).
///
/// Shows the live camera when there is one. A simulator, a refused permission
/// and a widget test all land in the same place — the artboard's own photograph
/// stands in — so the screen is always renderable and never shows a dead black
/// viewfinder.
class ScanningScreen extends ConsumerStatefulWidget {
  const ScanningScreen({
    super.key,
    this.mode = ScanMode.camera,
    this.onClose,
    this.onCaptured,
    this.onBarcode,
    this.onDescribe,
    this.onSearch,
  });

  /// The mode the screen opens in.
  final ScanMode mode;

  final VoidCallback? onClose;

  /// Fired once an image is in hand: the mode used, and the prepared file's
  /// path — null for a mode that produces no image, or when the camera was
  /// unavailable and the design's stand-in is being analysed instead.
  final void Function(ScanMode mode, String? imagePath)? onCaptured;

  /// A barcode was read. Separate from [onCaptured] because it produces a
  /// product code rather than a photo, and needs no shutter press.
  final ValueChanged<String>? onBarcode;

  /// The two paths the design has no room for: describing a meal in words, and
  /// searching the food database.
  final VoidCallback? onDescribe;
  final VoidCallback? onSearch;

  @override
  ConsumerState<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends ConsumerState<ScanningScreen> {
  late ScanMode _mode = widget.mode;
  bool _busy = false;

  /// Viewfinder window, in artboard coordinates.
  static const Rect _window = Rect.fromLTWH(44, 180, 341, 412);
  static const double _windowRadius = 32;

  /// Takes the shot, or picks one, and hands the path up.
  ///
  /// A dismissed gallery picker is a cancellation, not a failure: it just puts
  /// the shutter back and leaves the user where they were.
  Future<void> _shutter() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      // Barcode has no shutter: the reader fires as soon as it sees a code.
      if (_mode == ScanMode.barcode) return;

      final path = switch (_mode) {
        ScanMode.camera => await _takePhoto(),
        ScanMode.gallery =>
          await ref.read(imageCaptureProvider).pickFromGallery(),
        ScanMode.barcode => null,
      };

      if (!mounted) return;
      if (_mode == ScanMode.gallery && path == null) return;
      widget.onCaptured?.call(_mode, path);
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (error, stack) {
      // A shutter tap that does nothing at all is the worst failure this screen
      // has: there is no message, nothing to retry against, and no way to tell
      // a dead button from a slow one. The tap is fire-and-forget, so anything
      // not converted to a [RepositoryException] below this point would
      // disappear into an unawaited Future — which is exactly what a raw
      // PlatformException out of the compressor does.
      debugPrint('capture failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That photo could not be taken. Try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Switches mode, releasing the photo camera before the barcode reader takes
  /// over.
  ///
  /// Two packages cannot hold the same camera at once. Invalidating the session
  /// disposes our controller; it is rebuilt lazily the next time the photo
  /// preview is watched.
  void _selectMode(ScanMode mode) {
    if (mode == _mode) return;
    if (mode == ScanMode.barcode) {
      ref.invalidate(cameraSessionProvider);
    }
    setState(() => _mode = mode);
  }

  /// Null when there is no usable camera, which the caller reads as "analyse
  /// the stand-in".
  Future<String?> _takePhoto() async {
    final session = ref.read(cameraSessionProvider);
    if (session.value == null) return null;
    return ref.read(cameraSessionProvider.notifier).capture();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: DesignCanvas(
          background: AppColors.background,
          // Full-bleed preview, and nothing sits at the very bottom edge.
          fit: DesignFit.cover,
          children: [
            const Positioned.fill(child: _Preview()),

            // Black at 50% over the scrim blur, then the same preview redrawn
            // sharp inside the window so it reads as a cut-out rather than an
            // overlay.
            //
            // Figma reports BACKGROUND_BLUR radius 91. That is not a Skia
            // sigma: radius/2 and radius/3 both smear the plate below the
            // window into a brown wash the artboard does not have. 15 was
            // calibrated against the render and takes that band from 45.7% to
            // 8.7% differing.
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: const ColoredBox(color: Color(0x80000000)),
              ),
            ),
            if (_mode == ScanMode.barcode)
              Positioned.fromRect(
                rect: _window,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_windowRadius),
                  child: BarcodeScannerView(
                    onDetected: (code) => widget.onBarcode?.call(code),
                  ),
                ),
              )
            else
              Positioned.fromRect(
                rect: _window,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_windowRadius),
                  child: const OverflowBox(
                  minWidth: DesignCanvas.designWidth,
                  maxWidth: DesignCanvas.designWidth,
                  minHeight: DesignCanvas.designHeight,
                  maxHeight: DesignCanvas.designHeight,
                  alignment: Alignment(-1 + 2 * 44 / (428 - 341),
                      -1 + 2 * 180 / (926 - 412)),
                    child: _Preview(),
                  ),
                ),
              ),
            Positioned.fromRect(rect: _window, child: const _Viewfinder()),

            // Sheet holding the mode tiles and shutter.
            Positioned(
              left: 0,
              top: 651,
              width: 428,
              height: 275,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 20,
              top: 73,
              width: 300,
              height: 36,
              child: Text(_mode.label, style: AppTypography.topBarTitle()),
            ),
            Positioned(
              left: 368,
              top: 71,
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: widget.onClose,
                behavior: HitTestBehavior.opaque,
                child: Image.asset(
                  'assets/images/premium/close_button.png',
                  width: 40,
                  height: 40,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),

            // The selected tile sits 2pt lower and is opaque; the others are
            // white at 40% over a 6pt blur.
            for (final (i, m) in ScanMode.values.indexed)
              Positioned(
                left: 20 + i * 133.5,
                top: m == _mode ? 676 : 674,
                width: 121,
                height: 78,
                child: _ModeTile(
                  mode: m,
                  selected: m == _mode,
                  onTap: () => _selectMode(m),
                ),
              ),

            if (_mode == ScanMode.barcode)
              Positioned(
                left: 40,
                top: 789,
                width: 348,
                height: 56,
                child: Center(
                  child: Text(
                    'Point the camera at a product barcode.',
                    style: AppTypography.body(color: AppColors.placeholder),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Positioned(
                left: 187,
                top: 789,
                width: 56,
                height: 56,
                child: GestureDetector(
                  onTap: _shutter,
                  behavior: HitTestBehavior.opaque,
                  child: _ShutterButton(busy: _busy),
                ),
              ),

            // The design leaves this strip empty. It is the only place the two
            // non-photo paths can live without disturbing the artboard — and
            // photos fail often enough in restaurants and low light that
            // leaving them unreachable was the bigger problem.
            Positioned(
              left: 20,
              top: 862,
              width: 388,
              height: 25,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TextAction(label: 'Describe it', onTap: widget.onDescribe),
                  const SizedBox(width: 12),
                  Text('·', style: AppTypography.body(color: AppColors.muted)),
                  const SizedBox(width: 12),
                  _TextAction(label: 'Search foods', onTap: widget.onSearch),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The live camera, or the artboard's photograph when there is not one.
///
/// The preview is forced into the artboard's aspect ratio with a cover fit: the
/// sensor is 4:3 or 16:9 and the frame is neither, and letterboxing the
/// viewfinder would break the cut-out illusion the window depends on.
class _Preview extends ConsumerWidget {
  const _Preview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(cameraSessionProvider).value;

    if (controller == null || !controller.value.isInitialized) {
      return Image.asset(
        'assets/images/app/camera_feed.png',
        width: DesignCanvas.designWidth,
        height: DesignCanvas.designHeight,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    }

    // Cover the frame by hand rather than with FittedBox.
    //
    // FittedBox has to measure its child, and CameraPreview is a Texture with
    // no intrinsic size — so it measures the SizedBox we wrap it in, which does
    // not match what the plugin actually draws. The result was a ~20pt strip of
    // bare background down one edge of the viewfinder. OverflowBox sizes the
    // preview explicitly instead, and never has to guess.
    const frameAspect =
        DesignCanvas.designWidth / DesignCanvas.designHeight;

    // previewSize is reported in sensor orientation, which is landscape even
    // when the phone is not, so the axes are swapped here.
    final preview = controller.value.previewSize;
    final previewAspect = preview == null
        ? frameAspect
        : preview.height / preview.width;

    final wider = previewAspect > frameAspect;

    return SizedBox(
      width: DesignCanvas.designWidth,
      height: DesignCanvas.designHeight,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          maxWidth: wider
              ? DesignCanvas.designHeight * previewAspect
              : DesignCanvas.designWidth,
          maxHeight: wider
              ? DesignCanvas.designHeight
              : DesignCanvas.designWidth / previewAspect,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// The window's corner-bracket outline and the wash across its lower half.
///
/// Figma models the bracket oddly: a full rounded-rect stroke plus two inner
/// stroke rects, 155pt across, sitting over the middle of each edge. In the
/// rendered artboard those inner rects do not draw a rule-of-thirds grid —
/// they knock the middle 155pt out of every edge, leaving four corner
/// brackets. Reading the node tree literally produces a closed rectangle with
/// a white cross through it, which is not the design. Measured from the
/// artboard render: the straight runs are x 32..93 / 248..309 top and bottom,
/// and y 32..129 / 284..380 left and right.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Figma: white 20% -> 100%, with the whole fill at 50% opacity, so the
        // effective alpha runs 0.1 -> 0.5. Taking the stops at face value
        // washes the bottom of the window to pure white.
        Positioned(
          left: 0,
          top: 207,
          right: 0,
          height: 205,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.white.withValues(alpha: 0.1),
                  AppColors.white.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: CustomPaint(painter: _BracketPainter())),
      ],
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  static const double _stroke = 4;
  static const double _radius = 32;

  /// Half the gap knocked out of the centre of each edge (155pt total).
  static const double _gap = 155 / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.butt;

    // The stroke is inside the window, so its centreline is inset by half.
    final inset = _stroke / 2;
    final r = _radius - inset;
    final l = inset, t = inset;
    final rt = size.width - inset, b = size.height - inset;
    final cx = size.width / 2, cy = size.height / 2;

    final path = Path()
      // top-left
      ..moveTo(l, t + r)
      ..arcToPoint(Offset(l + r, t), radius: Radius.circular(r))
      ..lineTo(cx - _gap, t)
      ..moveTo(cx + _gap, t)
      // top-right
      ..lineTo(rt - r, t)
      ..arcToPoint(Offset(rt, t + r), radius: Radius.circular(r))
      ..lineTo(rt, cy - _gap)
      ..moveTo(rt, cy + _gap)
      // bottom-right
      ..lineTo(rt, b - r)
      ..arcToPoint(Offset(rt - r, b), radius: Radius.circular(r))
      ..lineTo(cx + _gap, b)
      ..moveTo(cx - _gap, b)
      // bottom-left
      ..lineTo(l + r, b)
      ..arcToPoint(Offset(l, b - r), radius: Radius.circular(r))
      ..lineTo(l, cy + _gap)
      ..moveTo(l, cy - _gap)
      ..lineTo(l, t + r);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BracketPainter oldDelegate) => false;
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.selected, this.onTap});

  final ScanMode mode;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      decoration: BoxDecoration(
        color: selected
            ? AppColors.white
            : AppColors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(mode.icon,
              width: 24, height: 24, filterQuality: FilterQuality.high),
          const SizedBox(height: 8),
          Text(mode.label,
              style: AppTypography.label(color: AppColors.ink)
                  .copyWith(fontWeight: FontWeight.w400)),
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: selected
          ? tile
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: tile,
              ),
            ),
    );
  }
}

/// An underlined text action, in the same treatment as "Resend code".
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        label,
        style: AppTypography.body(color: AppColors.primary).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary,
        ),
      ),
    );
  }
}

/// 56pt ring with a 44pt disc — Figma `Ellipse 15` over `Ellipse 16`.
///
/// While a capture is in flight the disc shrinks and dims. The design has no
/// busy state, and this reads as pressed rather than as a new control.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({this.busy = false});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 3),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: busy ? 32 : 44,
          height: busy ? 32 : 44,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: busy ? 0.6 : 1),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
