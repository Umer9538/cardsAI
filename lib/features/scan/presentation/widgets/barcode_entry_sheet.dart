import 'package:flutter/material.dart';

import '../../../../core/models/barcode.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/widgets/auth_widgets.dart';

/// Opens the typed-barcode sheet and returns the digits, or null.
Future<String?> showBarcodeEntrySheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const BarcodeEntrySheet(),
  );
}

/// Types a barcode when the reader cannot get one.
///
/// Every barcode on a food package is printed as digits directly under the
/// bars, precisely so it can be read when the scan fails — a scuffed label, a
/// curved tin, shrink wrap, or a phone whose camera cannot focus that close.
/// Without this, barcode mode had no way forward at all when detection did not
/// fire.
class BarcodeEntrySheet extends StatefulWidget {
  const BarcodeEntrySheet({super.key});

  @override
  State<BarcodeEntrySheet> createState() => _BarcodeEntrySheetState();
}

class _BarcodeEntrySheetState extends State<BarcodeEntrySheet> {
  final _controller = TextEditingController();

  String get _digits => _controller.text.trim();

  /// A real GTIN, check digit and all.
  ///
  /// It used to be "8 to 14 digits that parse as an int", which accepts the
  /// 10^8 codes that are the right shape and the wrong number. A tester typed
  /// `88888888`, which is one of them — the valid EAN-8 ends in 0 — and got a
  /// Bordeaux back from Open Food Facts. The checksum is the cheapest possible
  /// way to tell "no such product" from a confident wrong answer, and the
  /// camera path has always had it for free.
  bool get _valid => Barcode.isValid(_digits);

  /// What is wrong with it, once there is enough typed to say.
  ///
  /// Nothing while the field is short: complaining about a number somebody is
  /// halfway through entering is noise.
  String? get _problem {
    final digits = _digits;
    if (digits.isEmpty || _valid) return null;
    if (!RegExp(r'^\d*$').hasMatch(digits)) return 'Digits only.';
    if (digits.length < 8) return null;
    if (!Barcode.lengths.contains(digits.length)) {
      return 'A barcode is 8, 12, 13 or 14 digits.';
    }
    return 'That is not a valid barcode — check the digits.';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Enter the barcode', style: AppTypography.cardHeading()),
              const SizedBox(height: 4),
              Text(
                'The digits printed under the bars.',
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
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  style: AppTypography.body(),
                  cursorColor: AppColors.primary,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (v) {
                    if (_valid) Navigator.of(context).pop(v);
                  },
                  decoration: InputDecoration.collapsed(
                    hintText: '5000112637922',
                    hintStyle: AppTypography.body(color: AppColors.muted),
                  ),
                ),
              ),
              // Says what is wrong rather than leaving a disabled button and
              // no explanation — a dead control reads as a broken app.
              SizedBox(
                height: 22,
                child: _problem == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _problem!,
                          style: AppTypography.meta(color: AppColors.error),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Look it up',
                  onPressed: _valid
                      ? () => Navigator.of(context).pop(_controller.text.trim())
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
