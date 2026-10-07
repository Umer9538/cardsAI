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
class NotificationsScreen extends ConsumerStatefulWidget {
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
  static double _contentHeight(List<AppNotification> items) {
    if (items.isEmpty) return DesignCanvas.designHeight;
    final listBottom =
        _listTop +
        items.length * _cardHeight +
        (items.length - 1) * _cardGap +
        20;
    return listBottom < DesignCanvas.designHeight
        ? DesignCanvas.designHeight
        : listBottom;
  }

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// The ids that were unread when this screen opened.
  ///
  /// Opening the screen is still the read receipt, but marking everything read
  /// in a post-frame callback erased the only evidence of which rows were new
  /// *before the person had read any of them* — three identical welcome cards
  /// with nothing to tell them apart, which is what was reported. Captured
  /// once, held for the whole visit, so the rows keep their treatment while
  /// the repository is updated underneath: the badge clears and the next visit
  /// is clean.
  final Set<String> _unreadOnEntry = {};
  bool _captured = false;

  @override
  Widget build(BuildContext context) {
    final messages =
        widget.items ??
        ref.watch(notificationsProvider).value ??
        const <AppNotification>[];

    if (widget.items == null && !_captured && messages.isNotEmpty) {
      _captured = true;
      _unreadOnEntry.addAll(messages.where((n) => !n.read).map((n) => n.id));
      if (_unreadOnEntry.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(notificationRepositoryProvider).markAllRead(),
        );
      }
    }

    // A pinned list renders its own `read` flags, so a preview can show both
    // states; the live screen uses the snapshot taken on entry.
    bool isUnread(AppNotification n) =>
        widget.items == null ? _unreadOnEntry.contains(n.id) : !n.read;

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
          height: NotificationsScreen._contentHeight(messages),
          children: [
            PremiumTopBar(title: 'Notifications', onBack: widget.onBack),
            if (messages.isEmpty)
              const _EmptyState()
            else
              Positioned(
                left: 20,
                top: NotificationsScreen._listTop,
                width: 388,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, message) in messages.indexed) ...[
                      if (i > 0)
                        const SizedBox(height: NotificationsScreen._cardGap),
                      _NotificationCard(
                        text: message.body,
                        unread: isUnread(message),
                      ),
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
  const _NotificationCard({required this.text, this.unread = false});

  final String text;

  /// Was this one new when the screen opened.
  ///
  /// Three things carry it, because one is not enough on a dark card: the
  /// border takes the brand orange, the bell sits on it rather than on the
  /// outline grey, and the body is full white against the read rows' muted
  /// placeholder. Colour alone would also be invisible to anyone who cannot
  /// separate orange from grey, so the *weight* of the text differs too.
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: unread ? 'Unread. $text' : text,
      excludeSemantics: true,
      child: Container(
        // The artboard fixes this at 92, which fits two lines of the design's
        // font. Ours sets wider and can reach three, so the height is a floor.
        constraints: const BoxConstraints(minHeight: 92),
        decoration: BoxDecoration(
          color: AppColors.inkMuted,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: unread ? AppColors.primary : AppColors.outline,
          ),
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
              decoration: BoxDecoration(
                color: unread ? AppColors.primary : AppColors.outline,
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
              child: Text(
                text,
                style: unread
                    ? AppTypography.socialLabel().copyWith(
                        fontWeight: FontWeight.w600,
                      )
                    : AppTypography.socialLabel(color: AppColors.placeholder),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
