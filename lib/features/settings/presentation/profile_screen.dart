import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';
import '../../../core/design/app_toast.dart';

/// My Profile — Figma frame `34_My Profile` (2002:966).
///
/// Name and Email are full-width; DOB/Gender and Height/Weight pair into two
/// columns at x=20 and x=224.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.onBack, this.onSave, this.onEditGoal});

  final VoidCallback? onBack;

  /// Opens the onboarding quiz again. The goal, the motivation and everything
  /// the calorie target is computed from were answered once at sign-up, and
  /// nothing else in the app could change them — so someone who signed up to
  /// lose weight and later wanted to build muscle was stuck with a deficit
  /// and a fat-loss plan. The quiz already saves the profile and recomputes
  /// the targets; re-running it is the honest way to change purpose.
  final VoidCallback? onEditGoal;
  final VoidCallback? onSave;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _dob = TextEditingController();
  final _gender = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();

  bool _seeded = false;
  bool _busy = false;

  /// The unit the numeric fields are being *shown* in. Captured when the
  /// fields are seeded so a later toggle elsewhere cannot make the number on
  /// screen mean something different from the number that gets parsed.
  UnitSystem _units = UnitSystem.metric;

  Gender _genderValue = Gender.unspecified;
  DateTime? _dobValue;

  static const double _cmPerInch = 2.54;
  static const double _lbPerKg = 2.2046226218;

  /// Fills the fields the first time a profile arrives, and not again — the
  /// stream re-emits on save, and re-seeding then would fight the keyboard.
  void _seed(UserProfile profile, UnitSystem units) {
    if (_seeded) return;
    _seeded = true;
    _units = units;
    _name.text = profile.name;
    _email.text = profile.email;

    _dobValue = profile.dateOfBirth;
    _dob.text = _dobValue == null ? '' : _dateFormat.format(_dobValue!);

    _genderValue = profile.gender;
    _gender.text = _genderLabel(profile.gender);

    // The number only, with the unit in the label. The field used to carry
    // its own unit text ("188cm") and parse it back with a loose regex, which
    // is where "188gjfiv" came from — and worse, the parser only understood
    // `ft` for height and nothing at all for weight, so an imperial user
    // typing their weight in pounds had it stored as that many *kilograms*.
    final cm = profile.heightCm;
    _height.text = cm == null
        ? ''
        : (units.isMetric ? cm.round() : (cm / _cmPerInch).round()).toString();

    final kg = profile.weightKg;
    _weight.text = kg == null
        ? ''
        : (units.isMetric ? kg.round() : (kg * _lbPerKg).round()).toString();
  }

  static String _genderLabel(Gender g) => g == Gender.unspecified
      ? ''
      : g.name[0].toUpperCase() + g.name.substring(1);

  String get _heightUnit => _units.isMetric ? 'cm' : 'in';
  String get _weightUnit => _units.isMetric ? 'kg' : 'lb';

  /// The first thing wrong with the form, or null when it is ready to save.
  ///
  /// Every one of these used to fail *silently*. `copyWith` treats null as
  /// "keep what you had", so an unparseable height, weight or date was simply
  /// dropped — and `_save` popped the screen either way, so the app reported
  /// success and showed the old value when you came back. That is what "the
  /// profile is not saveable" was.
  String? _problem() {
    if (_name.text.trim().isEmpty) return 'Enter your name.';

    final height = double.tryParse(_height.text.trim());
    if (_height.text.trim().isNotEmpty) {
      if (height == null) return 'Height must be a number.';
      final cm = _units.isMetric ? height : height * _cmPerInch;
      if (cm < 80 || cm > 250) {
        return _units.isMetric
            ? 'Height must be between 80 and 250 cm.'
            : 'Height must be between 32 and 98 in.';
      }
    }

    final weight = double.tryParse(_weight.text.trim());
    if (_weight.text.trim().isNotEmpty) {
      if (weight == null) return 'Weight must be a number.';
      final kg = _units.isMetric ? weight : weight / _lbPerKg;
      // The same 25-350 kg band the weight sheet uses.
      if (kg < 25 || kg > 350) {
        return _units.isMetric
            ? 'Weight must be between 25 and 350 kg.'
            : 'Weight must be between 55 and 770 lb.';
      }
    }

    final dob = _dobValue;
    if (dob != null) {
      final age = DateTime.now().difference(dob).inDays / 365.2425;
      if (age < 13) return 'You must be at least 13 to use Carbs AI.';
      if (age > 120) return 'Check the date of birth.';
    }
    return null;
  }

  Future<void> _save() async {
    final current = ref.read(profileProvider).value;
    if (current == null || _busy) return;

    final problem = _problem();
    if (problem != null) {
      // Named, and the screen stays put. It used to pop regardless.
      showToast(context, problem, tone: ToastTone.error);
      return;
    }

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final height = double.tryParse(_height.text.trim());
      final weight = double.tryParse(_weight.text.trim());

      await ref.read(profileRepositoryProvider).save(
            current.copyWith(
              name: _name.text.trim(),
              // Deliberately not written — the field is read-only and the
              // address belongs to the auth user, not to this document.
              dateOfBirth: _dobValue,
              gender: _genderValue,
              heightCm: height == null
                  ? null
                  : (_units.isMetric ? height : height * _cmPerInch),
              weightKg: weight == null
                  ? null
                  : (_units.isMetric ? weight : weight / _lbPerKg),
            ),
          );
      if (!mounted) return;
      widget.onSave?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        appToast('That could not be saved. Try again.', tone: ToastTone.error),
      );
    }
  }

  /// Chosen, never typed. A free-text gender field accepted "xyz" and then
  /// dropped it, because the value has to resolve to one of four enum cases.
  Future<void> _pickGender() async {
    final picked = await showModalBottomSheet<Gender>(
      context: context,
      backgroundColor: AppColors.inkMuted,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            for (final g in Gender.values)
              ListTile(
                title: Text(
                  g == Gender.unspecified ? 'Prefer not to say' : _genderLabel(g),
                  style: AppTypography.body(),
                ),
                trailing: g == _genderValue
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(sheet).pop(g),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _genderValue = picked;
      _gender.text = _genderLabel(picked);
    });
  }

  /// A real date picker, so "01-01-20oh" cannot be entered at all.
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dobValue ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      // 13 is the floor the Terms already set.
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'Date of birth',
      // The picker is a Material dialog and this app is dark everywhere else.
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.inkMuted,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dobValue = picked;
      _dob.text = _dateFormat.format(picked);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _dob, _gender, _height, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final units = ref.watch(unitSystemProvider);
    if (profile != null) _seed(profile, units);

    return Scaffold(
      backgroundColor: AppColors.background,
      // The keyboard must be allowed to shrink the viewport.
      //
      // With this false — which is what fidelity to the artboard wanted — the
      // canvas keeps its full height behind the keyboard and the submit
      // button, which the design pins near the bottom, becomes physically
      // unreachable while typing. Letting the viewport shrink makes
      // DesignCanvas taller than its space, which turns it into a scroll, so
      // the button is always reachable.
      resizeToAvoidBottomInset: true,
      body: DesignCanvas(
        background: AppColors.background,
        children: [
          PremiumTopBar(title: 'My Profile', onBack: widget.onBack),
          DesignImage(
            asset: profile?.avatar ?? 'assets/images/app/avatar.png',
            left: 174,
            top: 147,
            width: 80,
            height: 80,
          ),
          Positioned(
            left: 20,
            top: 285,
            width: 388,
            child: AuthTextField(
              label: 'Name',
              keyboardType: TextInputType.name,
              hint: 'Full name',
              controller: _name,
            ),
          ),
          Positioned(
            left: 20,
            top: 384,
            width: 388,
            // Shown, never edited. The email is the sign-in credential, and
            // nothing on this screen can change that — there is no
            // `updateEmail` call anywhere in the app. Typing here used to
            // persist the new string to the profile document, where it did
            // three unhelpful things and nothing useful: the account row in
            // Settings started showing an address the person cannot sign in
            // with, the next real sign-in silently overwrote it again, and on
            // `BACKEND=local` it was destructive — `LocalAuthRepository`
            // matches the stored profile *by email*, so the next sign-in
            // failed to find it and minted a fresh profile with a new id, no
            // height, no weight, no goal and no targets.
            child: AuthTextField(
              label: 'Email',
              hint: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              readOnly: true,
            ),
          ),
          Positioned(
            left: 20,
            top: 483,
            width: 184,
            child: AuthTextField(
              label: 'DOB',
              hint: 'Tap to choose',
              controller: _dob,
              readOnly: true,
              onTap: _pickDob,
            ),
          ),
          Positioned(
            left: 224,
            top: 483,
            width: 184,
            child: AuthTextField(
              label: 'Gender',
              hint: 'Tap to choose',
              controller: _gender,
              readOnly: true,
              onTap: _pickGender,
            ),
          ),
          Positioned(
            left: 20,
            top: 582,
            width: 184,
            child: AuthTextField(
              label: 'Height ($_heightUnit)',
              hint: _units.isMetric ? '175' : '69',
              controller: _height,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // A letter cannot be typed, so "188gjfiv" cannot happen and
              // never has to be rejected afterwards.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(5),
              ],
            ),
          ),
          Positioned(
            left: 224,
            top: 582,
            width: 184,
            child: AuthTextField(
              label: 'Weight ($_weightUnit)',
              hint: _units.isMetric ? '72' : '159',
              controller: _weight,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(5),
              ],
            ),
          ),
          // Not on the artboard. Sits in the gap the design leaves between
          // the last field row (582–662) and Save (810).
          Positioned(
            left: 20,
            top: 690,
            width: 388,
            height: 66,
            child: _GoalRow(profile: profile, onTap: widget.onEditGoal),
          ),
          Positioned(
            left: 20,
            top: 810,
            width: 388,
            height: 50,
            child: PrimaryButton(
              label: 'Save',
              busy: _busy,
              onPressed: _busy ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the plan is for, and the way to change it.
class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.profile, required this.onTap});

  final UserProfile? profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final goal = profile?.goal;
    final motivation = profile?.motivation;
    // Goal and motivation share a label when both are "Lose weight"; saying
    // it twice read as a bug on the phone.
    final detail = goal == null
        ? 'Not set yet — answer a few questions'
        : {goal.label, ?motivation?.label}.join(' · ');

    return Semantics(
      button: true,
      label: 'Goal and targets, $detail',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.inkMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
          ),
          // 8, not 10: the two lines are 25 and 19 with a 2pt gap, which is
          // exactly what 66 less 10 top and bottom leaves — see the search
          // result row, which shipped two pixels over its box that way.
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Goal & targets',
                      style: AppTypography.body(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: AppTypography.meta(color: AppColors.placeholder),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: AppColors.placeholder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
