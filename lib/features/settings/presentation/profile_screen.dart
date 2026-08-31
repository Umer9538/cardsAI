import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/design_canvas.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../premium/presentation/widgets/premium_widgets.dart';

/// My Profile — Figma frame `34_My Profile` (2002:966).
///
/// Name and Email are full-width; DOB/Gender and Height/Weight pair into two
/// columns at x=20 and x=224.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.onBack, this.onSave});

  final VoidCallback? onBack;
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

  /// Fills the fields the first time a profile arrives, and not again — the
  /// stream re-emits on save, and re-seeding then would fight the keyboard.
  void _seed(UserProfile profile) {
    if (_seeded) return;
    _seeded = true;
    _name.text = profile.name;
    _email.text = profile.email;
    _dob.text =
        profile.dateOfBirth == null ? '' : _dateFormat.format(profile.dateOfBirth!);
    _gender.text = profile.gender == Gender.unspecified
        ? ''
        : profile.gender.name[0].toUpperCase() + profile.gender.name.substring(1);
    _height.text = profile.heightCm == null ? '' : '${profile.heightCm!.round()}cm';
    _weight.text = profile.weightKg == null ? '' : '${profile.weightKg!.round()}kg';
  }

  /// Parses back the loose formats the fields accept — "56kg", "170cm", "5.3ft".
  double? _measure(String text, {required bool asHeight}) {
    final match = RegExp(r'([\d.]+)').firstMatch(text);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    if (asHeight && text.toLowerCase().contains('ft')) return value * 30.48;
    return value;
  }

  Future<void> _save() async {
    final current = ref.read(profileProvider).value;
    if (current == null) return;

    await ref.read(profileRepositoryProvider).save(
          current.copyWith(
            name: _name.text.trim(),
            email: _email.text.trim(),
            dateOfBirth: DateTime.tryParse(_dob.text.trim()) ??
                _tryDayFirst(_dob.text.trim()),
            gender: Gender.values
                    .where((g) =>
                        g.name.toLowerCase() == _gender.text.trim().toLowerCase())
                    .firstOrNull ??
                current.gender,
            heightCm: _measure(_height.text, asHeight: true),
            weightKg: _measure(_weight.text, asHeight: false),
          ),
        );
    if (mounted) widget.onSave?.call();
  }

  /// The field shows dd-MM-yyyy, which [DateTime.tryParse] does not accept.
  DateTime? _tryDayFirst(String text) {
    try {
      return _dateFormat.parseStrict(text);
    } on FormatException {
      return null;
    }
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
    if (profile != null) _seed(profile);

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
              hint: 'Full name',
              controller: _name,
            ),
          ),
          Positioned(
            left: 20,
            top: 384,
            width: 388,
            child: AuthTextField(
              label: 'Email',
              hint: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          Positioned(
            left: 20,
            top: 483,
            width: 184,
            child: AuthTextField(label: 'DOB', hint: 'DOB', controller: _dob),
          ),
          Positioned(
            left: 224,
            top: 483,
            width: 184,
            child: AuthTextField(
              label: 'Gender',
              hint: 'Gender',
              controller: _gender,
            ),
          ),
          Positioned(
            left: 20,
            top: 582,
            width: 184,
            child: AuthTextField(
              label: 'Height',
              hint: 'Height',
              controller: _height,
            ),
          ),
          Positioned(
            left: 224,
            top: 582,
            width: 184,
            child: AuthTextField(
              label: 'Weight',
              hint: 'Weight',
              controller: _weight,
            ),
          ),
          Positioned(
            left: 20,
            top: 810,
            width: 388,
            height: 50,
            child: PrimaryButton(label: 'Save', onPressed: _save),
          ),
        ],
      ),
    );
  }
}
