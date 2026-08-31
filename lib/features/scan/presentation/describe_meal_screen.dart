import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';
import 'scan_controller.dart';

/// Describe a meal in words — the fallback for when a photo will not work.
///
/// Not in the design, and the most important of the missing paths: photos fail
/// in restaurants, in bad light, and for anything already eaten. The PRD calls
/// this a must-have for exactly that reason. It runs the same pipeline as a
/// photo, text-only, which is roughly a tenth of the cost.
class DescribeMealScreen extends ConsumerStatefulWidget {
  const DescribeMealScreen({super.key, this.onBack, this.onAnalysed});

  final VoidCallback? onBack;

  /// Fired once the controller holds a result, so the caller can show it.
  final VoidCallback? onAnalysed;

  @override
  ConsumerState<DescribeMealScreen> createState() => _DescribeMealScreenState();
}

class _DescribeMealScreenState extends ConsumerState<DescribeMealScreen> {
  final _text = TextEditingController();
  String? _error;

  static const List<String> _examples = [
    'Two slices of pepperoni pizza and a side salad with ranch',
    'Large flat white and a blueberry muffin',
    'Chicken burrito, no rice, extra guacamole',
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _analyse() async {
    final description = _text.text.trim();
    if (description.length < 3) {
      setState(() => _error = 'Describe what you ate.');
      return;
    }
    setState(() => _error = null);

    final controller = ref.read(scanControllerProvider.notifier);
    await controller.describe(description);
    if (!mounted) return;

    if (ref.read(scanControllerProvider).hasError) {
      setState(() => _error = controller.errorMessage);
    } else {
      widget.onAnalysed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(scanControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: DesignCanvas(
        background: AppColors.background,
        children: [
          PremiumTopBar(title: 'Describe', onBack: widget.onBack),

          Positioned(
            left: 20,
            top: 147,
            width: 388,
            child: Text(
              'Say what you ate, in your own words. The more detail — how much, '
              'how it was cooked, what was on it — the closer the estimate.',
              style: AppTypography.socialLabel(color: AppColors.placeholder),
            ),
          ),

          Positioned(
            left: 20,
            top: 235,
            width: 388,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inkMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _error == null ? AppColors.outline : AppColors.error,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
              child: TextField(
                controller: _text,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: AppTypography.body(),
                cursorColor: AppColors.primary,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration.collapsed(
                  hintText: 'e.g. two eggs on toast with butter',
                  hintStyle:
                      AppTypography.body(color: AppColors.placeholder),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ),
          ),

          if (_error != null)
            Positioned(
              left: 20,
              top: 403,
              width: 388,
              height: 40,
              child: Text(_error!, style: AppTypography.errorMessage()),
            ),

          Positioned(
            left: 20,
            top: 455,
            width: 388,
            height: 25,
            child: Text('Try something like', style: AppTypography.label()),
          ),

          // Tapping an example fills the field. Staring at an empty box is the
          // main reason this kind of input goes unused.
          //
          // A Column, not one Positioned per chip: an example long enough to
          // wrap makes its chip taller than any fixed step, and fixed steps had
          // the first two sitting flush against each other.
          Positioned(
            left: 20,
            top: 492,
            width: 388,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, example) in _examples.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ExampleChip(
                    text: example,
                    onTap: () => setState(() {
                      _text.text = example;
                      _error = null;
                    }),
                  ),
                ],
              ],
            ),
          ),

          Positioned(
            left: 20,
            top: 810,
            width: 388,
            height: 50,
            child: PrimaryButton(
              label: 'Analyse',
              onPressed: _analyse,
              busy: busy,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: AppColors.inkMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: AppTypography.meta(color: AppColors.placeholder),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
