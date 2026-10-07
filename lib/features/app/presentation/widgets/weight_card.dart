import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../../../../core/design/app_toast.dart';

/// Weight, on Home.
///
/// Calories are the input; weight is the outcome, and the outcome is the only
/// thing that says whether any of this is working. The quiz already collects a
/// goal weight and the plan screen already renders "On track for X kg by DATE"
/// — so until this existed the app made a falsifiable prediction and gave
/// nobody a way to falsify it.
///
/// It leads with the **trend**, not the last reading. Body weight swings a kilo
/// or more day to day on water alone, so the newest number is the worst
/// estimate of where someone actually is, and it is the number that makes
/// people abandon a plan that is working.
class WeightCard extends ConsumerWidget {
  const WeightCard({super.key, required this.top, this.onLog, this.preview});

  final double top;
  final VoidCallback? onLog;

  /// Pins the history, for tests and previews. Null reads the real one.
  ///
  /// The sibling cards have had this since they were written; this one did
  /// not, so the populated state — the one with a sparkline, and the taller of
  /// the two — could not be rendered by any test. Its reserved height was a
  /// guess nothing checked, and it was 59pt too generous for the empty state,
  /// which is what put a double-sized gap under it on Home.
  final WeightHistory? preview;

  static const double width = 388;

  /// Room Home books for this card, which depends on what is in it.
  ///
  /// A function, like [ActivityCard.reserveFor], because the two states are
  /// not close: empty it is a heading and one sentence, populated it carries a
  /// trend, a change figure and a sparkline. Measured at the 1.15x text
  /// ceiling — empty 119, populated 216 — plus a little slack, which is the
  /// lesson the search result row taught at 2px over.
  ///
  /// It was one constant, 168, and that was wrong in **both** directions: 49pt
  /// too generous when empty, which is the double-sized gap a tester reported
  /// under it, and 48pt too small once anything was logged, at which point the
  /// card silently drew over the water card below it. Two overlapping
  /// `Positioned` children throw nothing.
  static double reserveFor({required bool hasReadings}) =>
      hasReadings ? 220 : 122;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        preview ?? ref.watch(weightHistoryProvider).value ?? WeightHistory.empty;
    final units = ref.watch(unitSystemProvider);
    final goal = ref.watch(profileProvider).value?.goalWeightKg;

    final trend = history.trendKg;
    final change = history.changeOver(const Duration(days: 14));

    return Positioned(
      left: 20,
      top: top,
      width: width,
      child: GestureDetector(
        onTap: onLog,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(19, 16, 19, 16),
          decoration: BoxDecoration(
            color: AppColors.inkMuted,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Weight', style: AppTypography.cardHeading()),
                  ),
                  Text(
                    trend == null ? 'Add' : 'Update',
                    style: AppTypography.meta(color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (trend == null)
                Text(
                  'No readings yet. One a week is enough to see a direction.',
                  style: AppTypography.meta(color: AppColors.placeholder),
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      units.formatWeight(trend),
                      style: AppTypography.headline().copyWith(fontSize: 34),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      units.weightUnit,
                      style: AppTypography.body(color: AppColors.placeholder),
                    ),
                    const SizedBox(width: 10),
                    if (change != null)
                      Text(
                        _changeLabel(change, units),
                        style: AppTypography.meta(
                          // Neither direction is coloured as good or bad. The
                          // app does not know whether someone is cutting or
                          // gaining, and a red number for going up is how a
                          // tracker starts scolding people.
                          color: AppColors.placeholder,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _caption(trend, goal, units),
                  style: AppTypography.meta(color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (history.entries.length > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: CustomPaint(
                      painter: _Sparkline(history),
                      size: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _changeLabel(double change, UnitSystem units) {
    if (change.abs() < 0.05) return 'steady over 2 weeks';
    final sign = change > 0 ? '+' : '−';
    return '$sign${units.formatWeight(change.abs())} '
        '${units.weightUnit} in 2 weeks';
  }

  static String _caption(double trend, double? goal, UnitSystem units) {
    if (goal == null) return '7-day average';
    final away = (trend - goal).abs();
    if (away < 0.3) return '7-day average · at your goal';
    return '7-day average · ${units.formatWeight(away)} '
        '${units.weightUnit} from your goal';
  }
}

/// The readings, drawn small.
///
/// A line rather than bars, and no axis: at this size the shape is the whole
/// message and a scale would only make it look more precise than a bathroom
/// scale deserves.
class _Sparkline extends CustomPainter {
  const _Sparkline(this.history);

  final WeightHistory history;

  @override
  void paint(Canvas canvas, Size size) {
    final values = history.entries.map((e) => e.kg).toList();
    if (values.length < 2) return;

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    // A flat run must not draw as a wild line through the middle of the box.
    final span = (max - min).abs() < 0.2 ? 1.0 : max - min;

    final path = Path();
    for (final (i, value) in values.indexed) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = size.height - ((value - min) / span) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accentGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final lastX = size.width;
    final lastY =
        size.height - ((values.last - min) / span) * size.height;
    canvas.drawCircle(
      Offset(lastX - 2, lastY),
      3,
      Paint()..color = AppColors.accentGreen,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) =>
      old.history.entries.length != history.entries.length;
}

/// Records today's weight.
Future<void> showWeightSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _WeightSheet(),
  );
}

class _WeightSheet extends ConsumerStatefulWidget {
  const _WeightSheet();

  @override
  ConsumerState<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends ConsumerState<_WeightSheet> {
  late final TextEditingController _field = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final units = ref.read(unitSystemProvider);
    final messenger = ScaffoldMessenger.of(context);
    void refuse(String why) =>
        messenger.showSnackBar(appToast(why, tone: ToastTone.error));

    final typed = double.tryParse(_field.text.trim().replaceAll(',', '.'));
    // Every one of these used to be a bare `return`, so the sheet simply did
    // not close and Save read as broken.
    if (typed == null || typed <= 0) {
      refuse('Enter your weight as a number.');
      return;
    }

    // Typed in whatever they read off the scale; stored in kilograms, like
    // every other body measurement here.
    final kg = units.isMetric ? typed : typed / 2.2046226218;
    if (kg < 25 || kg > 350) {
      refuse(units.isMetric
          ? 'Weight must be between 25 and 350 kg.'
          : 'Weight must be between 55 and 770 lb.');
      return;
    }

    setState(() => _busy = true);
    await ref.read(weightRepositoryProvider).log(kg);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitSystemProvider);

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
              Text("Today's weight", style: AppTypography.cardHeading()),
              const SizedBox(height: 4),
              Text(
                'First thing in the morning is the most comparable, but any '
                'time beats skipping it.',
                style: AppTypography.meta(color: AppColors.placeholder),
              ),
              const SizedBox(height: 16),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _field,
                        autofocus: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          LengthLimitingTextInputFormatter(6),
                        ],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: AppTypography.body(),
                        cursorColor: AppColors.primary,
                        onSubmitted: (_) => _save(),
                        decoration: InputDecoration.collapsed(
                          hintText: units.isMetric ? '80.5' : '177',
                          hintStyle: AppTypography.body(color: AppColors.muted),
                        ),
                      ),
                    ),
                    Text(
                      units.weightUnit,
                      style: AppTypography.body(color: AppColors.placeholder),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // The unit switch belongs here for the same reason it is on the
              // quiz's weight step: this is the moment someone notices they
              // are being asked for a number in a unit they do not think in,
              // and sending them to Settings then is how the sheet loses them.
              // Until now the quiz was the *only* place in the app that could
              // change it, so anyone who skipped onboarding was stuck.
              //
              // It writes the same global preference, so the hint, the suffix
              // and every other weight in the app move together — storage
              // stays metric either way, as everywhere else.
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      ref.read(unitSystemProvider.notifier).toggle(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      units.isMetric ? 'Use pounds' : 'Use kilograms',
                      style: AppTypography.meta(color: AppColors.primary)
                          .copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Save',
                  busy: _busy,
                  onPressed: _busy ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
