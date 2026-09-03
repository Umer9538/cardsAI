import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import 'barcode_scanner_view.dart';
import 'camera_session.dart';
import 'widgets/barcode_entry_sheet.dart';
import 'widgets/item_edit_sheet.dart';

/// Capture modes offered above the shutter.
enum ScanMode {
  camera('AI Camera', 'assets/images/app/ic_camera.png'),
  barcode('AI Barcode', 'assets/images/app/ic_barcode.png'),
  gallery('AI Gallery', 'assets/images/app/ic_gallery.png');

  const ScanMode(this.label, this.icon);
  final String label;
  final String icon;
}

/// Where a gallery photo comes from.
///
/// Two entries because no single Android picker covers both. See
/// [ImageCapture.pickFromFiles].
enum PhotoSource { photos, files }

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

  /// Fired once an image is in hand: the mode used, the prepared file's path —
  /// null for a mode that produces no image, or when the camera was unavailable
  /// and the design's stand-in is being analysed instead — and the note the
  /// person added, if any.
  final void Function(ScanMode mode, String? imagePath, String? hint)?
      onCaptured;

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

  /// What the person told us the photo cannot show.
  ///
  /// `prompt.ts` calls this "the cheapest accuracy win available on a mixed
  /// dish" and treats it as ground truth — the person was there and the camera
  /// was not. It has been threaded through the Worker, the repositories and the
  /// controller since the pipeline was built, and no screen ever offered a way
  /// to type into it.
  ///
  /// It matters because of what the model provably cannot see: oil, butter and
  /// sauce are invisible in a photograph and are exactly where the measured
  /// underestimation comes from.
  String? _hint;

  /// True while one camera package is handing the device to the other.
  ///
  /// Two packages cannot hold the same camera, and neither releases it
  /// synchronously — `CameraController.dispose` and `MobileScannerController`
  /// teardown are both futures. Rendering the incoming preview in the same
  /// frame as the outgoing one means the second open lands while the first is
  /// still closing, and it fails.
  ///
  /// So the handoff is explicit: for one short beat neither camera is on
  /// screen. This is the "switching modes takes a beat" the design notes
  /// mention — it is deliberate, not latency to be optimised away.
  bool _switching = false;

  static const Duration _handoff = Duration(milliseconds: 350);

  /// Held so it can be cancelled. A bare `Future.delayed` outlives the widget,
  /// which means a `setState` after dispose in the app and a pending-timer
  /// failure in every test that touches this screen.
  Timer? _handoffTimer;

  /// Whether the "where from" chooser is up.
  ///
  /// Opening it on selecting Gallery, rather than waiting for a shutter press,
  /// is deliberate: the shutter is a *camera* control, and the tile that has
  /// just been tapped reads as having done nothing until something opens.
  bool _choosingSource = false;

  /// Viewfinder window, in artboard coordinates.
  static const Rect _window = Rect.fromLTWH(44, 180, 341, 412);
  static const double _windowRadius = 32;

  /// Takes the shot, or picks one, and hands the path up.
  ///
  /// A dismissed gallery picker is a cancellation, not a failure: it just puts
  /// the shutter back and leaves the user where they were.
  Future<void> _shutter() async {
    if (_busy) return;
    // The capture itself takes a moment and the screen does not change until it
    // returns, so without this the shutter is the one tap in the app that gives
    // nothing back.
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    try {
      // Barcode has no shutter: the reader fires as soon as it sees a code.
      if (_mode == ScanMode.barcode) return;

      // Gallery has no shutter of its own either: it reopens the chooser.
      if (_mode == ScanMode.gallery) {
        setState(() => _choosingSource = true);
        return;
      }

      final path = await _takePhoto();
      if (!mounted) return;
      widget.onCaptured?.call(_mode, path, _hint);
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
    if (mode == ScanMode.gallery) {
      setState(() {
        _mode = mode;
        _choosingSource = true;
      });
      return;
    }
    if (mode == _mode) return;

    // Either direction across the barcode boundary swaps camera packages.
    final swapsCamera =
        mode == ScanMode.barcode || _mode == ScanMode.barcode;

    setState(() {
      _mode = mode;
      _choosingSource = false;
      _switching = swapsCamera;
    });

    if (!swapsCamera) return;

    // Dispose ours first. With `_Preview` already off screen there is no
    // watcher left to rebuild it, so this is a real release rather than a
    // release-and-immediately-reopen.
    ref.invalidate(cameraSessionProvider);

    _handoffTimer?.cancel();
    _handoffTimer = Timer(_handoff, () {
      if (mounted) setState(() => _switching = false);
    });
  }

  @override
  void dispose() {
    _handoffTimer?.cancel();
    super.dispose();
  }

  /// Picks an image, with our camera released while the picker is open.
  ///
  /// The system picker is another full-screen activity, and Android is much
  /// more willing to destroy ours while it is showing if we are still holding
  /// the camera. When that happens `pickImage` never returns: the shutter stays
  /// busy and the screen stops responding, which is indistinguishable from the
  /// app having hung.
  ///
  /// Same reasoning as the barcode mode switch, and the same cost — the preview
  /// takes a beat to come back if the picker is dismissed.
  Future<void> _pickFrom(PhotoSource source) async {
    setState(() => _choosingSource = false);
    if (_busy) return;
    setState(() => _busy = true);

    ref.invalidate(cameraSessionProvider);
    try {
      final capture = ref.read(imageCaptureProvider);
      final path = switch (source) {
        PhotoSource.photos => await capture.pickFromGallery(),
        PhotoSource.files => await capture.pickFromFiles(),
      };
      if (!mounted) return;
      // A dismissed picker is a cancellation, not a failure: it just puts the
      // screen back where it was.
      if (path == null) return;
      widget.onCaptured?.call(ScanMode.gallery, path, _hint);
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (error, stack) {
      debugPrint('pick failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That photo could not be opened.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Types a barcode instead of reading one.
  Future<void> _enterCode() async {
    final code = await showBarcodeEntrySheet(context);
    if (!mounted || code == null || code.trim().isEmpty) return;
    widget.onBarcode?.call(code.trim());
  }

  /// Collects the note in a modal sheet rather than a field on the canvas.
  ///
  /// The canvas is `DesignFit.cover` and full-bleed; a focused field inside it
  /// would put the keyboard over the shutter with nothing able to scroll out of
  /// the way. A sheet owns its own inset handling and leaves the camera alone.
  Future<void> _editNote() async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NoteSheet(initial: _hint),
    );
    if (!mounted || note == null) return;
    setState(() => _hint = note.trim().isEmpty ? null : note.trim());
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
            // Not in barcode mode, and this is the whole reason barcode
            // scanning never worked.
            //
            // `_Preview` *watches* `cameraSessionProvider`. Selecting barcode
            // invalidates that provider to hand the camera over — but an
            // invalidated provider with a live watcher is rebuilt immediately,
            // so the photo camera was re-acquired within the same frame it was
            // released and `mobile_scanner` never got a device to open. The
            // release has to be a real release, which means nothing may be
            // watching it.
            if (_mode != ScanMode.barcode && !_switching)
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
            // Blurred everywhere EXCEPT the window, rather than blurred
            // everywhere with a sharp copy of the preview drawn back on top.
            //
            // That copy was a second [_Preview], which meant two CameraPreview
            // widgets driven by one controller — two Texture widgets bound to
            // one texture id. Android does not reliably draw both: where the
            // second one comes up empty the window falls through to the blurred
            // layer beneath it, and the whole screen reads as out of focus.
            //
            // One preview now, and the cut-out is a clip rather than a redraw,
            // which is also what it looks like in the design.
            Positioned.fill(
              child: ClipPath(
                clipper: const _WindowCutout(_window, _windowRadius),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: const ColoredBox(color: Color(0x80000000)),
                ),
              ),
            ),
            // Barcode is a different camera package, so it does get its own
            // view inside the window — ours is released before this appears.
            if (_mode == ScanMode.barcode && !_switching)
              Positioned.fromRect(
                rect: _window,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_windowRadius),
                  child: BarcodeScannerView(
                    onDetected: (code) => widget.onBarcode?.call(code),
                  ),
                ),
              ),
            Positioned.fromRect(rect: _window, child: const _Viewfinder()),

            // Sits in the 59pt gap the artboard leaves between the viewfinder
            // and the mode sheet. Collapsed to a pill until it has something to
            // say, so the camera stays a camera.
            if (_mode != ScanMode.barcode)
              Positioned(
                left: 44,
                top: 604,
                width: 341,
                height: 34,
                child: _NoteChip(
                  note: _hint,
                  onTap: _editNote,
                ),
              ),

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
                top: 770,
                width: 348,
                height: 88,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _switching
                          ? 'Starting the reader…'
                          : 'Point the camera at a product barcode.',
                      style: AppTypography.body(color: AppColors.placeholder),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // A button, not a text link. Barcode has no shutter —
                    // detection is continuous, so there is nothing for one to
                    // trigger — which left this mode as the only one with no
                    // control at all, and no way forward when a code will not
                    // read: a scuffed label, a curved tin, a barcode behind
                    // shrink wrap, a camera that cannot focus that close.
                    // Typing the digits always works, and they are printed
                    // directly under the bars for exactly this reason.
                    SizedBox(
                      height: 44,
                      width: 220,
                      child: GhostButton(
                        label: 'Type the number',
                        onPressed: _enterCode,
                      ),
                    ),
                  ],
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

            // Inside this canvas, not floating above the screen, so it shares
            // the one transform — a separately-positioned overlay drifts out of
            // register the moment the canvas is scaled.
            if (_choosingSource) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _choosingSource = false),
                  child: const ColoredBox(color: Color(0x99000000)),
                ),
              ),
              // No height: the sheet is ours, not the artboard's, so it sizes
              // to its own text rather than to a number that a font metric can
              // quietly overflow.
              Positioned(
                left: 20,
                bottom: DesignCanvas.designHeight - 640,
                width: 388,
                child: _SourceSheet(onPick: _pickFrom),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The two ways into a photo already on the phone.
///
/// Android's system photo picker and its file browser are separate surfaces and
/// neither can reach the other, so the choice has to be made before one opens.
/// Naming what each *reaches* — camera roll versus downloads and folders — is
/// the whole point: "Gallery" and "Files" alone do not tell someone which one
/// holds the photo they are thinking of.
class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.onPick});

  final ValueChanged<PhotoSource> onPick;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.inkMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(19, 20, 19, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a photo', style: AppTypography.cardHeading()),
            const SizedBox(height: 16),
            _SourceRow(
              icon: Icons.photo_library_outlined,
              label: 'Photos',
              detail: 'Your camera roll',
              onTap: () => onPick(PhotoSource.photos),
            ),
            const SizedBox(height: 12),
            _SourceRow(
              icon: Icons.folder_open_outlined,
              label: 'Files',
              detail: 'Downloads, folders, SD card',
              onTap: () => onPick(PhotoSource.files),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.cardTitle()),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: AppTypography.meta(color: AppColors.placeholder),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.placeholder,
            ),
          ],
        ),
      ),
    );
  }
}

/// The blur's shape: the whole screen with the viewfinder window knocked out.
///
/// `evenOdd` is what makes the inner rounded rectangle a hole rather than a
/// second filled shape.
class _WindowCutout extends CustomClipper<Path> {
  const _WindowCutout(this.window, this.radius);

  final Rect window;
  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(RRect.fromRectAndRadius(window, Radius.circular(radius)));

  @override
  bool shouldReclip(_WindowCutout oldClipper) =>
      oldClipper.window != window || oldClipper.radius != radius;
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

/// The collapsed affordance for the scan note.
///
/// Reads as a prompt when empty and as the note itself once written, so the
/// thing you typed is visible before you commit a scan to it.
class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.note, required this.onTap});

  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = note != null && note!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: has ? AppColors.primary : AppColors.outline,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              has ? Icons.edit_note : Icons.add,
              size: 16,
              color: has ? AppColors.primary : AppColors.placeholder,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                has ? note! : 'Add a note — oil, sauce, how it was cooked',
                style: AppTypography.meta(
                  color: has ? AppColors.white : AppColors.placeholder,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the note is typed.
///
/// The examples are not decoration. An empty text box is the main reason this
/// kind of input goes unused, and each one names something a photograph
/// genuinely cannot show — which is where the measured underestimation in
/// photo-based estimates actually comes from.
class _NoteSheet extends StatefulWidget {
  const _NoteSheet({this.initial});

  final String? initial;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  static const List<String> _examples = [
    'Fried in 2 tbsp oil',
    'Half of what you see',
    'No sugar',
    'Cooked in ghee',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _append(String example) {
    final current = _controller.text.trim();
    setState(() {
      _controller.text = current.isEmpty ? example : '$current, $example';
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.inkMuted,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        padding: const EdgeInsets.fromLTRB(19, 12, 19, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'What can’t the camera see?',
                style: AppTypography.cardHeading(),
              ),
              const SizedBox(height: 4),
              Text(
                'Oil, butter and sauce are invisible in a photo, and they are '
                'where the estimate usually goes wrong.',
                style: AppTypography.meta(color: AppColors.placeholder),
              ),
              const SizedBox(height: 16),
              Container(
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.body(),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration.collapsed(
                    hintText: 'Grilled, no oil…',
                    hintStyle: AppTypography.body(color: AppColors.muted),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final example in _examples)
                    GestureDetector(
                      onTap: () => _append(example),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Text(
                          example,
                          style: AppTypography.meta(
                            color: AppColors.placeholder,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Done',
                  onPressed: () =>
                      Navigator.of(context).pop(_controller.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
