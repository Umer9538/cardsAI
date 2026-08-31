import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

import 'widgets/auth_scaffold.dart';
import 'widgets/auth_widgets.dart';

/// Sign up — Figma frames `13_Sign Up-Default` (2002:1812) and
/// `14_Sign Up-Fill` (2002:1798). Frame 14 is the same layout with values
/// entered, so it is this screen's filled state rather than a second build.
///
/// Unlike log in, this artboard has no Google/Apple buttons and no divider.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.onBack, this.onLogIn, this.onSignedUp});

  final VoidCallback? onBack;
  final VoidCallback? onLogIn;
  /// Receives the address the account was created with, so the verification
  /// screen can address it without the caller having to hold on to it.
  final ValueChanged<String>? onSignedUp;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _nameError =
          _name.text.trim().isEmpty ? 'Please enter your full name' : null;
      _emailError =
          _email.text.trim().isEmpty ? 'Please enter your email' : null;
      _passwordError =
          _password.text.isEmpty ? 'Please enter a password' : null;
    });
    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    final ok = await controller.signUp(
      name: _name.text,
      email: _email.text,
      password: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      widget.onSignedUp?.call(_email.text.trim());
    } else {
      setState(() => _emailError = controller.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      onBack: widget.onBack,
      title: 'Create Your Carbsai Account',
      subtitle: 'Eat better. Get back on track.',
      children: [
        // One auto-layout column at y=254 with 20pt gaps, so an inline
        // validation message pushes the fields below it down as in frame 06.
        Positioned(
          left: 20,
          top: 254,
          width: 388,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthTextField(
                label: 'Full Name',
                hint: 'Enter Full Name',
                controller: _name,
                errorText: _nameError,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Email',
                hint: 'Enter Email',
                controller: _email,
                errorText: _emailError,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              AuthTextField(
                label: 'Password',
                hint: 'Enter Password',
                controller: _password,
                errorText: _passwordError,
                obscure: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          top: 761,
          width: 388,
          height: 50,
          child: PrimaryButton(
            label: 'Sign Up',
            onPressed: _submit,
            busy: busy,
          ),
        ),
        Positioned(
          left: 20,
          top: 835,
          width: 388,
          height: 25,
          child: AuthFooterLink(
            text: 'Already have an account? ',
            actionText: 'Log In',
            onTap: widget.onLogIn,
          ),
        ),
      ],
    );
  }
}
