import 'package:carbsai/core/auth/password_strength.dart';
import 'package:carbsai/core/theme/app_colors.dart';
import 'package:carbsai/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:carbsai/features/auth/presentation/reset_password_screen.dart';
import 'package:carbsai/features/auth/presentation/sign_up_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_render.dart';

/// The password rules, which are a pure function and therefore get exact tests
/// rather than a render diff — same treatment as `TargetCalculator`.
void main() {
  group('hard rules', () {
    test('a short password is refused however varied', () {
      final check = PasswordCheck.of('aB3!x');
      expect(check.isAcceptable, isFalse);
      expect(check.error, 'Use at least 8 characters');
      expect(check.strength, PasswordStrength.unusable);
    });

    test('eight characters is the floor, and it is inclusive', () {
      expect(PasswordCheck.of('walnutsx').isAcceptable, isTrue);
      expect(PasswordCheck.of('walnuts').isAcceptable, isFalse);
    });

    test('a common password is refused even at full length', () {
      final check = PasswordCheck.of('qwertyuiop');
      expect(check.isAcceptable, isFalse);
      expect(check.error, contains('too common'));
    });

    test('the blocklist sees through trailing digits and symbols', () {
      // The whole point of stripping the suffix: `password` and `Password123!`
      // are one guess, not two.
      for (final p in ['password1', 'Password123', 'password!', 'PASSWORD99']) {
        expect(
          PasswordCheck.of(p).isAcceptable,
          isFalse,
          reason: '$p is the same guess as "password"',
        );
      }
    });

    test('the app\'s own name is on the list', () {
      expect(PasswordCheck.of('carbsai2026').isAcceptable, isFalse);
    });

    test('a password built from the name on the form is refused', () {
      final check = PasswordCheck.of(
        'muhammad-river',
        name: 'Muhammad Umer',
        email: 'someone@example.com',
      );
      expect(check.isAcceptable, isFalse);
      expect(check.error, contains('name or email'));
    });

    test('a password built from the email local part is refused', () {
      final check = PasswordCheck.of(
        'abdbinaqeel99x',
        email: 'abdbinaqeel@gmail.com',
      );
      expect(check.isAcceptable, isFalse);
    });

    test('the domain is not personal — "gmail" must not be blocked', () {
      // Refusing every password containing "gmail" helps nobody, and would
      // refuse a perfectly good one for a reason the person cannot see.
      final check = PasswordCheck.of(
        'gmailbridgewalnut',
        email: 'someone@gmail.com',
      );
      expect(check.isAcceptable, isTrue);
    });

    test('a short name does not poison every password', () {
      // "Al" would otherwise refuse "walnut-bridge" for containing "al".
      final check = PasswordCheck.of('walnut-bridge-92', name: 'Al Khan');
      expect(check.isAcceptable, isTrue);
    });

    test('an empty password fails every rule but does not throw', () {
      final check = PasswordCheck.of('');
      expect(check.isAcceptable, isFalse);
      expect(check.rules.where((r) => r.met), isEmpty);
    });
  });

  group('the meter rewards length, not symbol theatre', () {
    test('a long passphrase of plain letters is strong', () {
      expect(
        PasswordCheck.of('correcthorsebatterystaple').strength,
        PasswordStrength.strong,
      );
    });

    test('a short password with every character class is not', () {
      // `Pw9!xkQ2` is eight characters and four classes — acceptable, but it
      // is not as good a secret as the passphrase above, and the meter must
      // not claim otherwise.
      final short = PasswordCheck.of('Pw9!xkQ2');
      expect(short.isAcceptable, isTrue);
      expect(
        short.strength.index,
        lessThan(PasswordStrength.strong.index),
        reason: 'eight characters cannot outrank twenty-five',
      );
    });

    test('a long run of one character is long and worthless', () {
      expect(PasswordCheck.of('aaaaaaaaaaaa').strength, PasswordStrength.weak);
    });

    test('a straight run off the keyboard is caught', () {
      expect(PasswordCheck.of('abcdefghijkl').strength, PasswordStrength.weak);
    });

    test('strength never outranks acceptability', () {
      // Anything failing a hard rule reads as unusable, whatever its shape:
      // `qwertyuiop` is ten characters and four distinct rows of the keyboard,
      // and it is still the password everyone tries second.
      expect(
        PasswordCheck.of('qwertyuiop').strength,
        PasswordStrength.unusable,
      );
    });

    test('the blocklist is an exact match, not a substring ban', () {
      // `password-correct-horse` opens with the worst word in the language and
      // is still a 22-character secret. Banning every password *containing* a
      // listed word would refuse good ones for a reason the person cannot see,
      // which is how a rule teaches people to fight the form.
      expect(PasswordCheck.of('password-correct-horse').isAcceptable, isTrue);
    });
  });

  group('the reveal toggle', () {
    Widget field({bool obscure = true}) => MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.background,
            body: AuthTextField(
              label: 'Password',
              hint: 'Enter Password',
              obscure: obscure,
            ),
          ),
        );

    testWidgets('a password starts hidden and reveals on tap', (tester) async {
      await tester.pumpWidget(field());

      TextField textField() => tester.widget<TextField>(find.byType(TextField));
      expect(textField().obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(textField().obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(textField().obscureText, isTrue);
    });

    testWidgets('an ordinary field has no toggle at all', (tester) async {
      // The toggle must not be reachable on a field that never asked to be
      // obscured — it would be a control that hides readable text.
      await tester.pumpWidget(field(obscure: false));
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets('it is a labelled button, not a bare glyph', (tester) async {
      // 39 tappable widgets in this app once carried zero semantics labels. An
      // icon with no text near it does not exist to a screen reader.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(field());

      expect(
        tester.getSemantics(find.bySemanticsLabel('Show password')),
        matchesSemantics(label: 'Show password', isButton: true, hasTapAction: true),
      );

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the field keeps its 50pt artboard height', (tester) async {
      await tester.pumpWidget(field());
      final box = tester.getSize(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(Container),
        ).first,
      );
      expect(box.height, AuthTextField.fieldHeight);
    });
  });

  group('the guide on screen', () {
    testWidgets('renders every rule, and ticks the ones that pass',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.background,
            body: PasswordStrengthGuide(
              check: PasswordCheck.of('walnut-bridge-92'),
            ),
          ),
        ),
      );

      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('Not a commonly used password'), findsOneWidget);
      expect(find.text('Does not contain your name or email'), findsOneWidget);
      expect(find.text('Strong'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    });

    testWidgets('the meter bar actually renders a filled width',
        (tester) async {
      // A box with no child in a Stack/Row collapses to zero and draws
      // nothing — this codebase has shipped that three times, so the height is
      // asserted rather than assumed.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 388,
              child: PasswordStrengthGuide(check: PasswordCheck.of('short')),
            ),
          ),
        ),
      );

      final bar = tester.getSize(
        find.byWidgetPredicate(
          (w) => w is FractionallySizedBox && w.heightFactor == 1,
        ),
      );
      expect(bar.height, 4);
      expect(bar.width, greaterThan(0));
    });

    testWidgets('it fits its column at the 1.15x text ceiling',
        (tester) async {
      // The guide is invisible on a default render, which is exactly how the
      // search result row shipped 2pt over. 388 is the artboard column width.
      tester.view.physicalSize = const Size(428 * 3, 926 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.15)),
          child: MaterialApp(
            home: Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: SizedBox(width: 388, child: PasswordStrengthGuide.preview()),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(PasswordStrengthGuide));
      expect(size.width, 388);
      // Sign Up has ~230pt between the last field and the CTA; the reset
      // screen has the 20pt artboard gap plus what the column can push down.
      // Sign Up is the tighter of the two screens: its column starts at y=254,
      // three field groups and their gaps take 277, the CTA is pinned at
      // y=761, and 12 of what is left is the gap above the guide — so this is
      // the real budget, not a round number.
      expect(
        size.height,
        lessThan(761 - 254 - 277 - 12),
        reason: 'the guide has to fit under the password field without '
            'pushing the CTA off the artboard',
      );
    });
  });

  /// The guide is invisible until a password is typed, so the overflow sweep —
  /// which renders every screen in its default state — never reaches it. These
  /// two type into the real screens at the sizes and the text scale the sweep
  /// uses, which is the only way this growth is covered at all.
  group('the real screens still fit once the guide is showing', () {
    const devices = <(String, Size)>[
      ('iPhone SE', Size(375, 667)),
      ('iPhone 17 Pro', Size(402, 874)),
      ('artboard', Size(428, 926)),
      ('iPad Pro 13"', Size(1032, 1376)),
    ];

    for (final (name, size) in devices) {
      testWidgets('Sign Up on $name', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          await designScope(
            const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: SignUpScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        await tester.enterText(
          find.byType(TextField).last,
          'walnut-bridge-92',
        );
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'Sign Up overflowed on $name once the guide appeared',
        );
        expect(find.text('Strong'), findsOneWidget);
      });

      testWidgets('Reset Password on $name', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          await designScope(
            const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: ResetPasswordScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        await tester.enterText(
          find.byType(TextField).first,
          'walnut-bridge-92',
        );
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'Reset Password overflowed on $name once the guide appeared',
        );
        // The guide must not have drawn over Confirm Password — the two
        // `Positioned` boxes it replaced would have overlapped in silence.
        expect(find.text('Confirm Password'), findsOneWidget);
      });
    }
  });
}
