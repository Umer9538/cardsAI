import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';

/// Notifications — Figma frames `24_Notification-Empty` (2002:1327) and
/// `25_Notification` (2002:1316).
///
/// The two artboards are the empty and populated states of one screen, so an
/// empty [items] list renders frame 24 and a non-empty one frame 25.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, this.items, this.onBack});

  /// Overrides the repository, for tests that need a fixed list. Null means
  /// "read the real one"; an empty list renders frame 24.
  final List<AppNotification>? items;

  final VoidCallback? onBack;

  static const double _cardHeight = 92;
  static const double _cardGap = 20;
  static const double _listTop = 147;

  /// The seven-card list ends at y=911, past the 926 frame once more cards
  /// arrive, so the canvas grows with the content and scrolls.
  double _contentHeight(List<AppNotification> items) {
    if (items.isEmpty) return DesignCanvas.designHeight;
    final listBottom = _listTop +
        items.length * _cardHeight +
        (items.length - 1) * _cardGap +
        20;
    return listBottom < DesignCanvas.designHeight
        ? DesignCanvas.designHeight
        : listBottom;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = items ??
        ref.watch(notificationsProvider).value ??
        const <AppNotification>[];

    // Opening the screen is the read receipt — the design has no per-row
    // affordance for it and no unread treatment on the cards.
    if (items == null && messages.any((n) => !n.read)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(notificationRepositoryProvider).markAllRead(),
      );
    }

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
          height: _contentHeight(messages),
          children: [
            PremiumTopBar(title: 'Notifications', onBack: onBack),
            if (messages.isEmpty)
              const _EmptyState()
            else
              Positioned(
                left: 20,
                top: _listTop,
                width: 388,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, message) in messages.indexed) ...[
                      if (i > 0) const SizedBox(height: _cardGap),
                      _NotificationCard(text: message.body),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      clipBehavior: Clip.none,
      children: [
        DesignImage(
          asset: 'assets/images/app/illus_no_notifications.png',
          left: 87,
          top: 289,
          width: 254,
          height: 216,
        ),
        Positioned(
          left: 87,
          top: 545,
          width: 254,
          height: 36,
          child: _EmptyTitle(),
        ),
        Positioned(
          left: 112,
          top: 593,
          width: 204,
          height: 44,
          child: _EmptySubtitle(),
        ),
      ],
    );
  }
}

class _EmptyTitle extends StatelessWidget {
  const _EmptyTitle();

  @override
  Widget build(BuildContext context) => Text(
        'No notifications yet.',
        style: AppTypography.cardTitle(),
        textAlign: TextAlign.center,
      );
}

class _EmptySubtitle extends StatelessWidget {
  const _EmptySubtitle();

  @override
  Widget build(BuildContext context) => Text(
        'Your healthy habits are on track—keep it up!',
        style: AppTypography.socialLabel(),
        textAlign: TextAlign.center,
      );
}

/// One list row — Figma `Notification`: 388x92, radius 24, #232220 on a 1pt
/// #2F2F2F outline, with a 44pt icon disc and 292pt of copy.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      // The artboard fixes this at 92, which fits two lines of the design's
      // font. Ours sets wider and can reach three, so the height is a floor.
      constraints: const BoxConstraints(minHeight: 92),
      decoration: BoxDecoration(
        color: AppColors.inkMuted,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      // Figma strokes this outline inside the 92pt box; Flutter adds a
      // Border to the outside of the padding box, so each inset drops by the
      // 1pt border. Without this every card is 2pt tall and the list drifts.
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 23),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.outline,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/app/icon_bell.png',
              width: 24,
              height: 24,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTypography.socialLabel()),
          ),
        ],
      ),
    );
  }
}
