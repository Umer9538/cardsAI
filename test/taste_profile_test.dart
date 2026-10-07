import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/nutrition/dish_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

/// The taste profile is the wire shape between the quiz and the Worker, so
/// what matters is that it survives the trip unchanged, ignores what it does
/// not recognise, and reads back in the order a person would say it.
void main() {
  const full = TasteProfile(
    liked: ['chicken-karahi', 'dal-tadka', 'greek-salad'],
    leaning: {
      TasteAxis.spice: TastePole.hot,
      TasteAxis.breakfast: TastePole.skipBreakfast,
    },
    avoid: {Avoidance.dairy, Avoidance.nuts},
    cookTime: CookTime.under15,
    notes: '  extra spicy, no coriander  ',
  );

  group('json', () {
    test('round-trips every field, including a skipped breakfast', () {
      final json = full.toJson();
      final back = TasteProfile.fromJson(json);

      expect(back.liked, full.liked);
      expect(back.leaning, full.leaning);
      expect(back.leaning[TasteAxis.breakfast], TastePole.skipBreakfast);
      expect(back.avoid, full.avoid);
      expect(back.cookTime, CookTime.under15);
      // Notes are trimmed on the way out; that is the only change allowed.
      expect(back.notes, 'extra spicy, no coriander');
      expect(back, full.copyWith(notes: 'extra spicy, no coriander'));
    });

    test('sends names and ids, never labels', () {
      final json = full.toJson();
      expect(json['leaning'], {'spice': 'hot', 'breakfast': 'skipBreakfast'});
      expect(json['avoid'], ['dairy', 'nuts']);
      expect(json['cookTime'], 'under15');
      expect(json['liked'], ['chicken-karahi', 'dal-tadka', 'greek-salad']);
    });

    test('an empty profile round-trips as empty', () {
      final back = TasteProfile.fromJson(TasteProfile.empty.toJson());
      expect(back.isEmpty, isTrue);
      expect(back, TasteProfile.empty);
      expect(back.cookTime, isNull);
    });

    test('drops what it does not recognise, silently', () {
      final back = TasteProfile.fromJson({
        'liked': ['greek-salad', 'unicorn-steak'],
        'leaning': {
          'spice': 'hot',
          // A pole that exists, on an axis it does not belong to.
          'starch': 'hot',
          // A pole that does not exist at all.
          'protein': 'insects',
          // An axis that does not exist.
          'texture': 'crunchy',
        },
        'avoid': ['dairy', 'gluten', 'sunlight'],
        'cookTime': 'never',
      });

      expect(back.leaning, {TasteAxis.spice: TastePole.hot});
      expect(back.avoid, {Avoidance.dairy, Avoidance.gluten});
      expect(back.cookTime, isNull);
      expect(back.notes, '');
      // An unknown dish id is carried through as a string but resolves to
      // nothing: it contributes no cuisine and appears in no chip.
      expect(back.cuisines, [Cuisine.mediterranean]);
      expect(back.summary, ['Mediterranean', 'Loves heat', 'No dairy, gluten']);
    });

    test('tolerates a missing or malformed body', () {
      expect(TasteProfile.fromJson(const {}).isEmpty, isTrue);
      expect(
        TasteProfile.fromJson(const {'leaning': null, 'avoid': null}).isEmpty,
        isTrue,
      );
    });
  });

  group('summary', () {
    test('reads cuisines, then leanings, then avoidances, then cook time', () {
      expect(full.summary, [
        'South Asian & Mediterranean',
        'Loves heat',
        'Skips breakfast',
        'No dairy, nuts',
        'Under 15 min',
      ]);
    });

    test('says nothing about liking to cook', () {
      // "I like cooking" is the absence of a constraint; a chip for it would
      // be a chip for nothing.
      const profile = TasteProfile(cookTime: CookTime.likesCooking);
      expect(profile.summary, isEmpty);
      expect(
        profile.copyWith(cookTime: CookTime.eatingOut).summary,
        ['Mostly eating out'],
      );
    });

    test('is empty for an empty profile', () {
      expect(TasteProfile.empty.summary, isEmpty);
    });

    test('names at most two cuisines', () {
      const profile = TasteProfile(
        liked: ['chicken-karahi', 'greek-salad', 'sushi', 'taco-bowl'],
      );
      expect(profile.summary.single, 'South Asian & Mediterranean');
    });
  });

  group('cuisines', () {
    test('ranks by how many liked dishes each one has', () {
      expect(full.cuisines, [Cuisine.southAsian, Cuisine.mediterranean]);

      const profile = TasteProfile(
        liked: ['greek-salad', 'chicken-karahi', 'hummus-plate'],
      );
      expect(profile.cuisines, [Cuisine.mediterranean, Cuisine.southAsian]);
    });

    test('breaks a tie by which was tapped first', () {
      const a = TasteProfile(liked: ['greek-salad', 'chicken-karahi']);
      expect(a.cuisines, [Cuisine.mediterranean, Cuisine.southAsian]);

      const b = TasteProfile(liked: ['chicken-karahi', 'greek-salad']);
      expect(b.cuisines, [Cuisine.southAsian, Cuisine.mediterranean]);

      // Three-way tie, first appearance throughout.
      const c = TasteProfile(liked: ['sushi', 'taco-bowl', 'greek-salad']);
      expect(c.cuisines, [Cuisine.eastAsian, Cuisine.latin, Cuisine.mediterranean]);
    });

    test('ignores ids it cannot resolve', () {
      const profile = TasteProfile(liked: ['nope', 'sushi']);
      expect(profile.cuisines, [Cuisine.eastAsian]);
    });
  });

  group('copyWith', () {
    test('clears the cook time only when told to', () {
      expect(full.copyWith().cookTime, CookTime.under15);
      expect(full.copyWith(clearCookTime: true).cookTime, isNull);
      expect(
        full.copyWith(cookTime: CookTime.upTo30).cookTime,
        CookTime.upTo30,
      );
    });
  });
}
