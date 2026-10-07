import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/providers/providers.dart';
import 'package:carbsai/core/repositories/repositories.dart';
import 'package:carbsai/data/local/json_store.dart';
import 'package:carbsai/features/settings/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// My Profile accepted "188gjfiv" as a height and "xyz" as a gender, and then
/// threw both away: `copyWith` reads null as "keep what you had", so anything
/// the parser could not read was dropped — while `_save` popped the screen
/// regardless, so the app reported success and showed the old value when you
/// came back. Every assertion here is that failure mode.
class _Profiles implements ProfileRepository {
  _Profiles(this.profile);
  UserProfile profile;
  UserProfile? saved;

  @override
  Stream<UserProfile?> watch() => Stream.value(profile);
  @override
  Future<UserProfile?> load() async => profile;
  @override
  Future<UserProfile> save(UserProfile p) async {
    saved = p;
    return profile = p;
  }
}

final _seed = UserProfile(
  id: 'u1',
  name: 'Abdullah Ramzan',
  email: 'a@example.com',
  dateOfBirth: DateTime(2002, 1, 1),
  gender: Gender.male,
  heightCm: 188,
  weightKg: 76,
);

Future<_Profiles> _pump(
  WidgetTester tester, {
  UnitSystem units = UnitSystem.metric,
  VoidCallback? onSave,
}) async {
  tester.view.physicalSize = const Size(428 * 3, 926 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  // Pinned both ways. UnitSystem defaults from the *device* locale, so an
  // en-US test host silently runs every case in imperial.
  SharedPreferences.setMockInitialValues(<String, Object>{
    StoreKeys.units: units.name,
  });
  final repo = _Profiles(_seed);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        jsonStoreProvider.overrideWithValue(await JsonStore.open()),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(home: ProfileScreen(onSave: onSave)),
    ),
  );
  // profileProvider yields the (null) session copy first and the repository
  // stream second, so the seed lands a frame later than the first build.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  return repo;
}

Finder _field(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(Column),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the number fields carry their unit and no stray text',
      (tester) async {
    await _pump(tester);

    // The unit moved into the label so the value is unambiguous; it used to
    // live inside the field as "188cm" and be parsed back out with a loose
    // regex, which is where a height could contain letters at all.
    expect(find.text('Height (cm)'), findsOneWidget);
    expect(find.text('Weight (kg)'), findsOneWidget);
    expect(find.text('188'), findsOneWidget);
    expect(find.text('76'), findsOneWidget);
  });

  testWidgets('a height with letters cannot even be typed', (tester) async {
    await _pump(tester);

    await tester.enterText(_field('Height (cm)').first, '188gjfiv');
    await tester.pump();

    // FilteringTextInputFormatter drops them at the source.
    expect(find.text('188gjfiv'), findsNothing);
    expect(find.text('188'), findsOneWidget);
  });

  testWidgets('an out-of-range height is refused and says so', (tester) async {
    var saved = false;
    final repo = await _pump(tester, onSave: () => saved = true);

    await tester.enterText(_field('Height (cm)').first, '900');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Height must be between'), findsOneWidget);
    // The two things that made this "not saveable": nothing was written, and
    // the screen left anyway as though it had been.
    expect(repo.saved, isNull);
    expect(saved, isFalse);
  });

  testWidgets('an empty name is refused', (tester) async {
    final repo = await _pump(tester);

    await tester.enterText(_field('Name').first, '   ');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(repo.saved, isNull);
  });

  testWidgets('a valid change is written and the screen reports success',
      (tester) async {
    var saved = false;
    final repo = await _pump(tester, onSave: () => saved = true);

    await tester.enterText(_field('Name').first, 'Abdullah R');
    await tester.enterText(_field('Height (cm)').first, '181');
    await tester.enterText(_field('Weight (kg)').first, '80');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(repo.saved, isNotNull);
    expect(repo.saved!.name, 'Abdullah R');
    expect(repo.saved!.heightCm, 181);
    expect(repo.saved!.weightKg, 80);
    expect(saved, isTrue);
  });

  testWidgets('pounds are stored as kilograms, not as pounds', (tester) async {
    final repo = await _pump(tester, units: UnitSystem.imperial);

    expect(find.text('Weight (lb)'), findsOneWidget);
    await tester.enterText(_field('Weight (lb)').first, '170');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    // The old parser understood `ft` for height and nothing at all for
    // weight, so 170 lb was stored as 170 kg — a 2.2x corruption of the one
    // number every calorie target is computed from.
    expect(repo.saved!.weightKg, closeTo(77.1, 0.2));
  });

  testWidgets('gender and date of birth cannot be typed at all',
      (tester) async {
    await _pump(tester);

    await tester.enterText(_field('Gender').first, 'xyz');
    await tester.pump();

    // Both are chosen from a picker now: a free-text gender accepted "xyz"
    // and then dropped it, because the value has to resolve to an enum case.
    expect(find.text('xyz'), findsNothing);
    expect(find.text('Male'), findsOneWidget);
  });
}
