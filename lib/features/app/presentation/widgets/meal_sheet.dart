import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';
import '../../../scan/presentation/widgets/item_edit_sheet.dart';

/// Opens the actions for one logged meal.
///
/// Until this existed a meal in the diary could not be touched: the only way to
/// fix a portion was to delete it and scan again, which also cost another scan
/// from the quota. Reviewers of every app in this category describe that trap
/// and rate one star for it — a wrong number is forgiven, a wrong number you
/// cannot reach is not.
///
/// It also carries **Log again**, which answers the other complaint people make
/// daily: *"I end up having to photo my yogurt pot every day despite the fact
/// it's identical every time."*
Future<void> showMealSheet(BuildContext context, WidgetRef ref, Meal meal) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MealSheet(meal: meal),
  );
}

class _MealSheet extends ConsumerStatefulWidget {
  const _MealSheet({required this.meal});

  final Meal meal;

  @override
  ConsumerState<_MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends ConsumerState<_MealSheet> {
  late List<FoodItem> _items = List.of(widget.meal.items);
  bool _busy = false;

  static final DateFormat _time = DateFormat('h:mm a');
  static const _uuid = Uuid();

  bool get _changed =>
      _items.length != widget.meal.items.length ||
      !_items.asMap().entries.every((e) {
        final original = widget.meal.items[e.key];
        return original.name == e.value.name &&
            original.nutrition == e.value.nutrition &&
            original.portionGrams == e.value.portionGrams;
      });

  Nutrition get _total => Nutrition.sum(_items.map((f) => f.nutrition));

  Future<void> _editItem(FoodItem food) async {
    final edit = await showItemEditSheet(context, food);
    if (edit == null || !mounted) return;
    setState(() {
      _items = [
        for (final item in _items)
          if (item.id != food.id)
            item
          else
            item.copyWith(
              name: edit.name.trim().isEmpty ? item.name : edit.name.trim(),
              nutrition: edit.nutrition,
              portionGrams: edit.grams,
              userEdited: true,
            ),
      ];
    });
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  /// Writes the corrections back to the same meal.
  void _save() => _run(
        () => ref
            .read(diaryRepositoryProvider)
            .updateMeal(widget.meal.copyWith(items: _items)),
        'That could not be saved. Try again.',
      );

  /// Logs the same food again, now.
  ///
  /// Built rather than copied, because `copyWith` cannot clear a field and two
  /// of them must be cleared. **`scanId` is dropped** — this is a copy, not a
  /// second reading of the original scan, and pointing two meals at one scan
  /// record would make the cost log overstate how many scans were run. The
  /// slot is recomputed from the clock, so yesterday's dinner re-logged at
  /// breakfast time is breakfast.
  void _logAgain() {
    final now = DateTime.now();
    _run(
      () => ref.read(diaryRepositoryProvider).addMeal(
            Meal(
              id: _uuid.v4(),
              eatenAt: now,
              items: _items,
              slot: MealSlot.forTime(now),
              photoPath: widget.meal.photoPath,
              title: widget.meal.title,
            ),
          ),
      'That could not be logged. Try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return Container(
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
              Text(
                meal.title ?? meal.slot.label,
                style: AppTypography.cardHeading(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${_time.format(meal.eatenAt)} · '
                '${NutritionFormat.calories(_total.calories)}',
                style: AppTypography.meta(color: AppColors.placeholder),
              ),
              const SizedBox(height: 16),
              for (final food in _items) ...[
                _ItemRow(
                  food: food,
                  onTap: () => _editItem(food),
                  onRemove: _items.length == 1
                      ? null
                      : () => setState(
                            () => _items = _items
                                .where((f) => f.id != food.id)
                                .toList(),
                          ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: GhostButton(
                        label: 'Log again',
                        onPressed: _busy ? null : _logAgain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: PrimaryButton(
                        label: 'Save',
                        busy: _busy,
                        onPressed: _busy || !_changed ? null : _save,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One food inside the meal sheet: tap to correct, ✕ to drop.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.food, required this.onTap, this.onRemove});

  final FoodItem food;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: AppTypography.body(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    NutritionFormat.calories(food.nutrition.calories),
                    style: AppTypography.meta(color: AppColors.placeholder),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_outlined,
              size: 16,
              color: AppColors.placeholder,
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.placeholder,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
