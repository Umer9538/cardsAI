import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';

/// Writes a one-day plan from the user's own targets.
///
/// The screen asks for one thing only: what they actually eat. Everything else
/// the plan is built against — calories, macros, meals a day, diet preference —
/// the server already knows, and asking again would be a second quiz on top of
/// the one they have already answered.
///
/// The examples are not decoration. An empty text box is the main reason this
/// kind of input goes unused, and each one names something the app cannot infer
/// from a calorie target: a cuisine, an allergy, a constraint on time or money.
class PlanBuilderScreen extends ConsumerStatefulWidget {
  const PlanBuilderScreen({super.key, this.onBack, this.onCreated});

  final VoidCallback? onBack;

  /// Fired with the saved plan, so the caller can open it.
  final ValueChanged<DietPlan>? onCreated;

  @override
  ConsumerState<PlanBuilderScreen> createState() => _PlanBuilderScreenState();
}

class _PlanBuilderScreenState extends ConsumerState<PlanBuilderScreen> {
  final _notes = TextEditingController();
  bool _busy = false;
  String? _error;

  static const List<String> _examples = [
    'Pakistani food',
    'Vegetarian',
    'No dairy',
    'Quick to cook',
    'On a budget',
    'I skip breakfast',
  ];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _addExample(String example) {
    final current = _notes.text.trim();
    setState(() {
      _notes.text = current.isEmpty ? example : '$current, $example';
      _notes.selection =
          TextSelection.collapsed(offset: _notes.text.length);
      _error = null;
    });
  }

  Future<void> _build() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final plan = await ref
          .read(plannerRepositoryProvider)
          .generate(notes: _notes.text.trim());

      // Saved before it is shown. A plan someone waited eight seconds for and
      // then lost by pressing back is worse than not offering one.
      final saved = await ref.read(dietRepositoryProvider).add(plan);
      if (!mounted) return;
      widget.onCreated?.call(saved);
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'The plan could not be built. Try again in a moment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = ref.watch(targetsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: DesignCanvas(
        background: AppColors.background,
        children: [
          Positioned(
            left: 20,
            top: 71,
            width: 40,
            height: 40,
            child: BackCircleButton(onTap: widget.onBack),
          ),
          Positioned(
            left: 20,
            top: 130,
            width: 388,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Build my plan', style: AppTypography.authTitle()),
                const SizedBox(height: 8),
                Text(
                  'A day of meals that adds up to '
                  '${NutritionFormat.calories(targets.calories)}, '
                  '${NutritionFormat.grams(targets.protein)} protein.',
                  style: AppTypography.body(color: AppColors.placeholder),
                ),
                const SizedBox(height: 26),
                Text('What do you eat?', style: AppTypography.cardHeading()),
                const SizedBox(height: 4),
                Text(
                  'Cuisine, anything you avoid, how much time you have.',
                  style: AppTypography.meta(color: AppColors.placeholder),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppColors.inkMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.outline),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: TextField(
                    controller: _notes,
                    maxLines: 4,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.body(),
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Pakistani food, no beef, quick dinners…',
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
                        onTap: _busy ? null : () => _addExample(example),
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
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    _error!,
                    style: AppTypography.errorMessage(),
                  ),
                ],
              ],
            ),
          ),

          Positioned(
            left: 20,
            top: 761,
            width: 388,
            height: 50,
            child: PrimaryButton(
              label: 'Build my plan',
              busy: _busy,
              onPressed: _busy ? null : _build,
            ),
          ),
          Positioned(
            left: 20,
            top: 823,
            width: 388,
            height: 40,
            child: Text(
              // Said before they wait, not after. The model writes the plan;
              // the numbers it is hitting are the app's own.
              'Written for your targets. It is a suggestion, not medical '
              'advice.',
              style: AppTypography.meta(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
