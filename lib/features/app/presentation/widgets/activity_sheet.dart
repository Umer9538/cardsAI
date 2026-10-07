import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/models.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Records a bout of exercise.
///
/// Two taps and a number: pick the thing, pick the minutes. The energy figure
/// is computed and shown while you choose, so nobody has to know their own
/// MET values — and it stays editable, because a figure off a treadmill or a
/// watch beats anything a table can derive.
Future<void> showActivitySheet(
  BuildContext context, {
  ActivityEntry? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _ActivitySheet(existing: existing),
  );
}

class _ActivitySheet extends ConsumerStatefulWidget {
  const _ActivitySheet({this.existing});

  final ActivityEntry? existing;

  @override
  ConsumerState<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends ConsumerState<_ActivitySheet> {
  static const List<int> _minuteChoices = [10, 15, 20, 30, 45, 60, 90];

  late ActivityKind _kind;
  late int _minutes;
  late TextEditingController _kcal;

  /// Set once the person types in the energy field. After that the estimate
  /// stops overwriting it — the same rule the item edit sheet uses for a macro
  /// someone has corrected by hand.
  bool _kcalPinned = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = (existing == null
            ? null
            : ActivityCatalogue.byName(existing.name)) ??
        ActivityCatalogue.kinds.first;
    _minutes = existing?.minutes ?? 30;
    _kcal = TextEditingController();
    if (existing != null) {
      _kcal.text = existing.kcal.round().toString();
      _kcalPinned = true;
    }
  }

  @override
  void dispose() {
    _kcal.dispose();
    super.dispose();
  }

  double get _estimate => ActivityCatalogue.kcalFor(
        met: _kind.met,
        minutes: _minutes,
        weightKg: ref.read(profileProvider).value?.weightKg,
      );

  void _refreshEstimate() {
    if (_kcalPinned) return;
    _kcal.text = _estimate.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_kcal.text.isEmpty) _refreshEstimate();

    return Padding(
      // resizeToAvoidBottomInset has no effect inside a sheet: the keyboard
      // covers the save button unless the sheet lifts itself.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.inkMuted,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.existing == null ? 'Log activity' : 'Edit activity',
                style: AppTypography.cardHeading(),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in ActivityCatalogue.kinds)
                    _Chip(
                      label: kind.name,
                      selected: kind.name == _kind.name,
                      onTap: () => setState(() {
                        _kind = kind;
                        _refreshEstimate();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Minutes', style: AppTypography.meta(
                color: AppColors.placeholder,
              )),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in _minuteChoices)
                    _Chip(
                      label: '$minutes',
                      selected: minutes == _minutes,
                      onTap: () => setState(() {
                        _minutes = minutes;
                        _refreshEstimate();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Estimated energy',
                      style: AppTypography.body(),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _kcal,
                      keyboardType: TextInputType.number,
                      // Letters used to be typable here and then silently
                      // reverted to the estimate, with nothing said.
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      textAlign: TextAlign.end,
                      style: AppTypography.body(),
                      onChanged: (_) => _kcalPinned = true,
                      decoration: InputDecoration(
                        isDense: true,
                        suffixText: 'kcal',
                        suffixStyle: AppTypography.meta(
                          color: AppColors.placeholder,
                        ),
                        border: const UnderlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'An estimate from your weight and how long you went for. '
                'It is not added to your calorie budget.',
                style: AppTypography.meta(color: AppColors.placeholder),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.existing != null) ...[
                    Expanded(
                      child: _Action(
                        label: 'Delete',
                        filled: false,
                        onTap: () {
                          ref
                              .read(activityRepositoryProvider)
                              .remove(widget.existing!.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _Action(label: 'Save', filled: true, onTap: _save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final typed = double.tryParse(_kcal.text.trim());
    final existing = widget.existing;
    ref.read(activityRepositoryProvider).log(
          ActivityEntry(
            id: existing?.id ?? const Uuid().v4(),
            // Editing keeps the original time: the bout happened when it
            // happened, and re-stamping it would move it in the day's list.
            at: existing?.at ?? DateTime.now(),
            name: _kind.name,
            minutes: _minutes,
            kcal: typed ?? _estimate,
          ),
        );
    Navigator.of(context).pop();
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.meta(
              color: selected ? AppColors.ink : AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: filled ? AppColors.primary : AppColors.outline,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.buttonLabel(
              color: filled ? AppColors.ink : AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}
