import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/repositories/repositories.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';
import 'scan_controller.dart';

/// Search the food database and build a meal by hand.
///
/// Not in the design. It is the path that always works: no camera, no model, no
/// quota, and it costs nothing — which makes it the right fallback when a photo
/// fails and the honest option once someone has used up their scans.
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({
    super.key,
    this.onBack,
    this.onDone,
    this.results,
  });

  final VoidCallback? onBack;

  /// Fired once the picked foods are in the controller.
  final VoidCallback? onDone;

  /// Pins the result list, shadowing whatever a search would return.
  ///
  /// Null means "run the real search". Without this the only state a test can
  /// reach is the empty one, which is how a result row shipped two pixels over
  /// its own box.
  final List<FoodItem>? results;

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _query = TextEditingController();
  final _picked = <FoodItem>[];

  Timer? _debounce;
  late List<FoodItem> _results = widget.results ?? const [];
  bool _searching = false;
  String? _error;

  /// Long enough that typing a word does not fire five requests, short enough
  /// that the list does not feel stuck. Open Food Facts rate-limits anonymous
  /// clients, so this is politeness as well as UX.
  static const Duration _debounceFor = Duration(milliseconds: 450);

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(_debounceFor, () => _search(value));
  }

  Future<void> _search(String value) async {
    try {
      final results =
          await ref.read(foodDatabaseProvider).search(value.trim());
      if (!mounted || value != _query.text) return;
      setState(() {
        _results = results;
        _error = results.isEmpty ? 'Nothing found for “${value.trim()}”.' : null;
        _searching = false;
      });
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = e.message;
        _searching = false;
      });
    }
  }

  void _done() {
    if (_picked.isEmpty) return;
    ref.read(scanControllerProvider.notifier).fromSearch(List.of(_picked));
    widget.onDone?.call();
  }

  double get _listTop => _picked.isEmpty ? 300 : 300 + 44.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: DesignCanvas(
        background: AppColors.background,
        height: DesignCanvas.designHeight +
            (_results.length * 78).clamp(0, 900).toDouble(),
        children: [
          PremiumTopBar(title: 'Search Foods', onBack: widget.onBack),

          Positioned(
            left: 20,
            top: 147,
            width: 388,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inkMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      autofocus: true,
                      style: AppTypography.body(),
                      cursorColor: AppColors.primary,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search a food or brand',
                        hintStyle:
                            AppTypography.body(color: AppColors.placeholder),
                      ),
                      onChanged: _onQueryChanged,
                    ),
                  ),
                  if (_searching)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.placeholder),
                      ),
                    ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 20,
            top: 215,
            width: 388,
            height: 60,
            child: Text(
              'Results come from Open Food Facts, a community database of '
              'packaged foods. Loose produce may not be listed.',
              style: AppTypography.meta(color: AppColors.muted),
            ),
          ),

          if (_picked.isNotEmpty)
            Positioned(
              left: 20,
              top: 292,
              width: 388,
              height: 30,
              child: Text(
                '${_picked.length} added · ${NutritionFormat.calories(Nutrition.sum(_picked.map((f) => f.nutrition)).calories)}',
                style: AppTypography.label(color: AppColors.accentGreen),
              ),
            ),

          if (_error != null)
            Positioned(
              left: 20,
              top: _listTop,
              width: 388,
              height: 40,
              child: Text(
                _error!,
                style: AppTypography.socialLabel(color: AppColors.placeholder),
              ),
            ),

          for (final (i, food) in _results.indexed)
            Positioned(
              left: 20,
              top: _listTop + i * 78,
              width: 388,
              child: _ResultRow(
                food: food,
                added: _picked.any((f) => f.name == food.name),
                onTap: () => setState(() {
                  final existing =
                      _picked.indexWhere((f) => f.name == food.name);
                  if (existing >= 0) {
                    _picked.removeAt(existing);
                  } else {
                    _picked.add(food);
                  }
                }),
              ),
            ),

          Positioned(
            left: 20,
            top: 810,
            width: 388,
            height: 50,
            child: PrimaryButton(
              label: _picked.isEmpty
                  ? 'Add to My Diet'
                  : 'Add ${_picked.length} to My Diet',
              onPressed: _picked.isEmpty ? null : _done,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.food, required this.added, this.onTap});

  final FoodItem food;
  final bool added;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: AppColors.inkMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: added ? AppColors.accentGreen : AppColors.outline,
          ),
        ),
        // 8, not 10. The two lines are 25 and 19 with a 2pt gap = 46, which
        // is exactly what 66 less 10 top and bottom leaves — no slack at all,
        // so the fraction a font's line box rounds up by put the column two
        // pixels over its own box on a device. Padding is what yields here;
        // 66 is the row pitch the list geometry is built on.
        padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    food.name,
                    style: AppTypography.body(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${food.portionDescription} · '
                    '${NutritionFormat.calories(food.nutrition.calories)}',
                    style: AppTypography.meta(color: AppColors.placeholder),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              added ? Icons.check_circle : Icons.add_circle_outline,
              size: 24,
              color: added ? AppColors.accentGreen : AppColors.placeholder,
            ),
          ],
        ),
      ),
    );
  }
}
