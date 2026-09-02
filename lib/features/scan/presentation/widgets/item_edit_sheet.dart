import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';

/// Opens the correction sheet for [food] and returns what the user changed.
///
/// Reached from the scan result and from a meal already in the diary — both
/// need the same thing, and a correction that only works before you log is
/// half a feature.
Future<ItemEdit?> showItemEditSheet(BuildContext context, FoodItem food) {
  return showModalBottomSheet<ItemEdit>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ItemEditSheet(food: food),
  );
}

/// What the correction sheet hands back.
class ItemEdit {
  const ItemEdit({
    required this.name,
    required this.nutrition,
    this.grams,
  });

  final String name;
  final Nutrition nutrition;
  final double? grams;
}

/// Correct one item: its name, its weight, and every number.
///
/// This exists because of the sharpest finding in the competitor research —
/// **correction friction, not error rate, is what separates a one-star review
/// from a five-star one.** The same inaccuracy earns either, depending only on
/// whether fixing it is fast and free. Users write five-star reviews that name
/// the error ("I like that I can go back and correct or fill in blanks") and
/// one-star reviews that name the lock ("If calories are clearly wrong on a
/// scan you cannot change them").
///
/// So: every field is editable, nothing here is ever paywalled, and it is two
/// taps from the number being wrong to the number being right.
///
/// **Weight drives the macros.** Typing a new gram figure rescales all four
/// numbers from the per-gram baseline, because that is how someone thinks — "it
/// was more like 180 g" is a statement about the portion, not about protein.
/// Typing into a macro field afterwards overrides just that number and stops
/// the rescaling for it, so a manual correction is never silently undone.
class ItemEditSheet extends StatefulWidget {
  const ItemEditSheet({super.key, required this.food});

  final FoodItem food;

  @override
  State<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<ItemEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.food.name);
  late final TextEditingController _grams = TextEditingController(
    text: widget.food.portionGrams == null
        ? ''
        : _trim(widget.food.portionGrams!),
  );
  late final TextEditingController _calories =
      TextEditingController(text: _trim(widget.food.nutrition.calories));
  late final TextEditingController _protein =
      TextEditingController(text: _trim(widget.food.nutrition.protein));
  late final TextEditingController _carbs =
      TextEditingController(text: _trim(widget.food.nutrition.carbs));
  late final TextEditingController _fat =
      TextEditingController(text: _trim(widget.food.nutrition.fat));

  /// The figures the sheet opened with, and the weight they belong to. Grams
  /// rescale from here rather than from the current field values, so nudging
  /// the weight up and back down returns to where it started instead of
  /// compounding — the same reason `adjustPortion` scales from `_asAnalysed`.
  late final Nutrition _baseline = widget.food.nutrition;
  late final double? _baselineGrams = widget.food.portionGrams;

  /// Macro fields the user has typed into. Rescaling leaves these alone.
  final Set<String> _pinned = {};

  @override
  void dispose() {
    for (final c in [_name, _grams, _calories, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _trim(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  static double _read(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  void _onGramsChanged(String _) {
    final base = _baselineGrams;
    final next = double.tryParse(_grams.text.trim().replaceAll(',', '.'));
    // Nothing to scale from: an item with no weight simply records one.
    if (base == null || base <= 0 || next == null || next <= 0) return;

    final factor = next / base;
    void apply(String key, TextEditingController c, double baseValue) {
      if (_pinned.contains(key)) return;
      c.text = _trim(baseValue * factor);
    }

    setState(() {
      apply('calories', _calories, _baseline.calories);
      apply('protein', _protein, _baseline.protein);
      apply('carbs', _carbs, _baseline.carbs);
      apply('fat', _fat, _baseline.fat);
    });
  }

  void _save() {
    final grams = double.tryParse(_grams.text.trim().replaceAll(',', '.'));
    Navigator.of(context).pop(
      ItemEdit(
        name: _name.text,
        grams: grams != null && grams > 0 ? grams : null,
        // Fibre and sugar are carried through untouched: the sheet does not
        // offer them, so it must not silently zero them.
        nutrition: _baseline.copyWith(
          calories: _read(_calories),
          protein: _read(_protein),
          carbs: _read(_carbs),
          fat: _read(_fat),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The sheet sits above the keyboard rather than behind it. Same lesson as
      // `resizeToAvoidBottomInset` on every other screen with a field.
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
          child: SingleChildScrollView(
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
                Text('Fix this item', style: AppTypography.cardHeading()),
                const SizedBox(height: 4),
                Text(
                  'Change anything the scan got wrong. Nothing here is '
                  'guesswork once you have edited it.',
                  style: AppTypography.meta(color: AppColors.placeholder),
                ),
                const SizedBox(height: 18),
                SheetField(label: 'Food', controller: _name),
                const SizedBox(height: 14),
                SheetField(
                  label: 'Weight (g)',
                  controller: _grams,
                  numeric: true,
                  hint: widget.food.portionDescription.isEmpty
                      ? 'Optional'
                      : widget.food.portionDescription,
                  onChanged: _onGramsChanged,
                ),
                if ((_baselineGrams ?? 0) > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Changing the weight rescales the numbers below.',
                    style: AppTypography.meta(color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SheetField(
                        label: 'Calories',
                        controller: _calories,
                        numeric: true,
                        onChanged: (_) => _pinned.add('calories'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SheetField(
                        label: 'Protein (g)',
                        controller: _protein,
                        numeric: true,
                        onChanged: (_) => _pinned.add('protein'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SheetField(
                        label: 'Carbs (g)',
                        controller: _carbs,
                        numeric: true,
                        onChanged: (_) => _pinned.add('carbs'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SheetField(
                        label: 'Fat (g)',
                        controller: _fat,
                        numeric: true,
                        onChanged: (_) => _pinned.add('fat'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: GhostButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: PrimaryButton(label: 'Save', onPressed: _save),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One labelled field in the correction sheet.
class SheetField extends StatelessWidget {
  const SheetField({
    super.key,
    required this.label,
    required this.controller,
    this.numeric = false,
    this.hint,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool numeric;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.meta(color: AppColors.placeholder)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: AppTypography.body(),
            cursorColor: AppColors.primary,
            decoration: InputDecoration.collapsed(
              hintText: hint ?? '',
              hintStyle: AppTypography.body(color: AppColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}

/// An outline counterpart to [PrimaryButton], for the quieter half of a pair.
///
/// Local to this file: it exists for the correction sheet's Cancel and nothing
/// else uses it yet. Promote it to a shared widget the second time it is needed.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppColors.outline),
        ),
        child: Text(label, style: AppTypography.buttonLabel()),
      ),
    );
  }
}
