import 'package:flutter/material.dart';

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

  /// EAN-8 through EAN-13/UPC-A. Shorter than 8 is not a product code, and
  /// sending it would spend a lookup to be told so.
  bool get _valid {
    final digits = _controller.text.trim();
    return digits.length >= 8 &&
        digits.length <= 14 &&
        int.tryParse(digits) != null;
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
