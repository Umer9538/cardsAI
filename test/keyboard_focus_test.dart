import 'package:carbsai/core/design/design_canvas.dart';
import 'package:carbsai/core/theme/app_colors.dart';
import 'package:carbsai/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A text field on a `DesignCanvas` must survive the keyboard opening.
///
/// The canvas used to return `Center(child: …)` when the artboard fitted the
/// viewport and `SingleChildScrollView(child: Center(child: …))` when it did
/// not. Opening the keyboard shrinks the viewport, which flips a screen from
/// one shape to the other — and Flutter cannot reuse an element whose widget
/// type has changed, so it unmounts the whole subtree beneath.
///
/// `AuthTextField` owns its `FocusNode` and disposes it, so being unmounted
/// destroys the node the field is focused on. The keyboard closes the instant
/// it opened. Reported on a Pixel 8, where 926 artboard units scale to 890dp
/// against a 914dp viewport: the canvas fits with the keyboard down and does
/// not with it up.
///
/// The real widget matters here. An externally-owned `FocusNode` survives the
/// remount and hides the bug entirely, which is how the first version of this
/// test passed against the broken canvas.
void main() {
  testWidgets('the sign-in field keeps focus when the keyboard opens',
      (tester) async {
    // A Pixel 8, in logical pixels.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(411.4, 914.3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: true,
          body: DesignCanvas(
            background: AppColors.background,
            children: [
              Positioned(
                left: 20,
                top: 300,
                width: 388,
                child: AuthTextField(label: 'Email', hint: 'Enter Email'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    final before = tester.state<State>(find.byType(AuthTextField));
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

    // The keyboard arrives and the viewport shrinks past the canvas height.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(
      tester.state<State>(find.byType(AuthTextField)),
      same(before),
      reason: 'the field was rebuilt from scratch when the viewport shrank, so '
          'its FocusNode was disposed and the keyboard closed again',
    );
    expect(
      FocusManager.instance.primaryFocus?.hasFocus,
      isTrue,
      reason: 'focus was lost when the keyboard opened',
    );
  });
}
