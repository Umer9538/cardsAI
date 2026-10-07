import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// What a toast is telling you, which decides its colour and its dwell time.
enum ToastTone {
  /// Something worked. Short — it is a receipt, not a message.
  success,

  /// Something did not. Longer, because it usually asks for an action.
  error,

  /// Neither. In progress, or a plain statement of fact.
  info,
}

/// The app's toast.
///
/// Every message in the app used to be a bare Material `SnackBar`: a light
/// grey bar in Roboto, floating over a #121212 app set in Space Grotesk, with
/// no indication of whether what just happened was good or bad. It read as a
/// piece of a different application, which is exactly the moment you least
/// want that — a toast only ever appears at the end of something the person
/// just did.
///
/// It is still a `SnackBar` underneath, deliberately. `ScaffoldMessenger`
/// already handles queueing, swipe-to-dismiss, the back gesture, and moving
/// out of the way of the keyboard; a hand-rolled overlay would have to
/// reimplement all four and would still not be announced to a screen reader.
/// Only the skin and the entrance are ours.
SnackBar appToast(String message, {ToastTone tone = ToastTone.info}) {
  return SnackBar(
    content: _ToastBody(message: message, tone: tone),
    // The body draws its own surface, so the SnackBar itself is a carrier and
    // nothing else.
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    behavior: SnackBarBehavior.floating,
    // Clear of the floating tab bar, which sits about 84pt off the bottom on
    // the four tab screens. A toast drawn under it is a toast nobody reads.
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 88),
    dismissDirection: DismissDirection.horizontal,
    duration: switch (tone) {
      ToastTone.success => const Duration(milliseconds: 2600),
      ToastTone.info => const Duration(seconds: 3),
      // Long enough to read twice. An error usually names something to do.
      ToastTone.error => const Duration(seconds: 5),
    },
  );
}

/// Shows [message], replacing anything already on screen.
///
/// Replacing rather than queueing: two toasts in a row are a queue the person
/// has to wait out, and the second one is always the more relevant.
void showToast(
  BuildContext context,
  String message, {
  ToastTone tone = ToastTone.info,
}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(appToast(message, tone: tone));
}

class _ToastBody extends StatefulWidget {
  const _ToastBody({required this.message, required this.tone});

  final String message;
  final ToastTone tone;

  @override
  State<_ToastBody> createState() => _ToastBodyState();
}

class _ToastBodyState extends State<_ToastBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _colour => switch (widget.tone) {
        ToastTone.success => AppColors.accentGreen,
        ToastTone.error => AppColors.error,
        ToastTone.info => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final colour = _colour;
    final still = MediaQuery.disableAnimationsOf(context);

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.inkMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 16, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A tinted disc rather than a bare glyph: at 20pt an outlined icon
            // on a dark ground is almost invisible, and the tone is the first
            // thing to read.
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              // Drawn, not an `Icon`.
              //
              // Material's icon font is tree-shaken in release down to the
              // glyphs that are statically referenced, and it is not loaded at
              // all under `flutter test` — so an `Icon` here renders as a tofu
              // box in every render test, which is the one place these would
              // ever be checked. Three strokes are cheaper than the dependency.
              child: CustomPaint(
                size: const Size(16, 16),
                painter: _ToneMark(widget.tone, colour),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                style: AppTypography.socialLabel(),
              ),
            ),
          ],
        ),
      ),
    );

    // Announced to a screen reader as it appears; the icon is decorative and
    // the tone is already in the words.
    final announced = Semantics(
      liveRegion: true,
      container: true,
      child: card,
    );

    if (still) return announced;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Two curves on one controller. The body settles with a little
        // overshoot, which is what makes it feel handed to you rather than
        // drawn; the opacity is linear-ish so it never flickers at the start.
        final settle = Curves.easeOutBack.transform(_controller.value);
        final fade = Curves.easeOut.transform(
          (_controller.value * 1.6).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - settle)),
            child: Transform.scale(
              scale: 0.94 + 0.06 * settle,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: announced,
    );
  }
}


/// The tick, the bang and the dot, at 16x16.
class _ToneMark extends CustomPainter {
  const _ToneMark(this.tone, this.colour);

  final ToastTone tone;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = Paint()
      ..color = colour
      ..strokeWidth = w * 0.135
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = colour;

    switch (tone) {
      case ToastTone.success:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.22, w * 0.52)
            ..lineTo(w * 0.42, w * 0.72)
            ..lineTo(w * 0.79, w * 0.30),
          stroke,
        );
      case ToastTone.error:
        canvas.drawLine(Offset(w / 2, w * 0.22), Offset(w / 2, w * 0.58), stroke);
        canvas.drawCircle(Offset(w / 2, w * 0.79), w * 0.085, fill);
      case ToastTone.info:
        canvas.drawCircle(Offset(w / 2, w * 0.22), w * 0.085, fill);
        canvas.drawLine(Offset(w / 2, w * 0.42), Offset(w / 2, w * 0.79), stroke);
    }
  }

  @override
  bool shouldRepaint(_ToneMark old) =>
      old.tone != tone || old.colour != colour;
}
