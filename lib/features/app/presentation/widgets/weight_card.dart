import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';

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
  const WeightCard({super.key, required this.top, this.onLog});

  final double top;
  final VoidCallback? onLog;

  static const double width = 388;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(weightHistoryProvider).value ?? WeightHistory.empty;
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
    final typed = double.tryParse(_field.text.trim().replaceAll(',', '.'));
    if (typed == null || typed <= 0) return;

    // Typed in whatever they read off the scale; stored in kilograms, like
    // every other body measurement here.
    final kg = units.isMetric ? typed : typed / 2.2046226218;
    if (kg < 25 || kg > 350) return;

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
              const SizedBox(height: 20),
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
