import 'dart:io';

import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/notifications/meal_clock.dart';
import 'package:carbsai/core/notifications/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// A reminder's whole value is landing near the meal it is about, and no single
/// hour does that everywhere. These tests hold the table to the shape of the
/// claim it makes — not to specific minutes, which are judgement calls, but to
/// the orderings that would make a default actively wrong.
void main() {
  int dinner(String country) => MealClock.forCountry(country).dinner;
  int lunch(String country) => MealClock.forCountry(country).lunch;

  group('the table says something true about each place', () {
    test('dinner runs early in the north and late in the south', () {
      // Sweden eats before six, Spain after nine. A default that suits one is
      // three and a half hours out for the other.
      expect(dinner('SE'), lessThan(dinner('GB')));
      expect(dinner('GB'), lessThan(dinner('PK')));
      expect(dinner('PK'), lessThan(dinner('ES')));
      expect(dinner('ES') - dinner('SE'), greaterThan(3 * 60));
    });

    test('the countries with a large midday meal eat lunch later', () {
      // Spain, the Gulf and Latin America all put the main meal in the
      // afternoon; the US and East Asia put it at noon.
      for (final late in ['ES', 'SA', 'MX', 'AE']) {
        expect(lunch(late), greaterThanOrEqualTo(14 * 60), reason: late);
      }
      for (final early in ['US', 'CN', 'JP', 'SE']) {
        expect(lunch(early), lessThanOrEqualTo(12 * 60), reason: early);
      }
    });

    test('Brazil is not filed with the rest of Latin America', () {
      // It eats roughly an hour and a half earlier, which is the difference
      // between a reminder before dinner and one after it.
      expect(dinner('BR'), lessThan(dinner('AR')));
      expect(MealClock.forCountry('BR'), isNot(MealClock.forCountry('AR')));
    });

    test('every pattern is in order and inside the day', () {
      for (final country in [
        'SE', 'US', 'GB', 'DE', 'PL', 'FR', 'ES', 'MX', 'BR', 'PK', 'SA',
        'IR', 'CN', 'TH', 'NG', 'ZZ',
      ]) {
        final clock = MealClock.forCountry(country);
        expect(clock.breakfast, lessThan(clock.lunch), reason: country);
        expect(clock.lunch, lessThan(clock.dinner), reason: country);
        expect(clock.breakfast, greaterThanOrEqualTo(5 * 60), reason: country);
        // Plus the grace, a reminder must still land before midnight or
        // ReminderSchedule drops the slot entirely.
        expect(
          clock.dinner + ReminderSchedule.graceMinutes,
          lessThan(24 * 60),
          reason: country,
        );
        expect(clock.region, isNotEmpty, reason: country);
      }
    });

    test('no country is claimed by two patterns', () {
      // Read out of the source the way dish_taxonomy_test reads the
      // TypeScript, rather than from a list copied here: a hand-kept copy
      // stops being evidence the moment somebody edits one side of it.
      //
      // Two entries holding one code would make the answer depend on the order
      // of the list, which nothing in the file suggests matters.
      final source = File(
        'lib/core/notifications/meal_clock.dart',
      ).readAsStringSync();
      final table = source.substring(source.indexOf('_patterns = ['));

      final codes = RegExp("'([A-Z]{2})'")
          .allMatches(table)
          .map((m) => m.group(1)!)
          .toList();

      expect(codes.length, greaterThan(120), reason: 'the table was not read');
      final seen = <String>{};
      final twice = codes.where((c) => !seen.add(c)).toSet();
      expect(twice, isEmpty, reason: 'listed under two patterns: $twice');
    });

    test('the countries this app is actually launching into are covered', () {
      // A country missing from the table is not an error — it falls back — but
      // silently falling back for the launch markets would defeat the point of
      // having written it.
      for (final country in ['PK', 'IN', 'BD', 'US', 'GB', 'AE', 'SA', 'CA']) {
        expect(
          MealClock.forCountry(country),
          isNot(MealClock.fallback),
          reason: country,
        );
      }
    });
  });

  group('reading it off the device', () {
    test('the time zone wins over the locale', () {
      // The case this was built for and got wrong first time: an `en-US`
      // phone standing in Karachi. The locale says which language someone
      // reads; the zone says where they are, and dinner is a fact about where
      // they are. Measured on the first real device: 18:45 offered instead of
      // 21:15.
      expect(
        MealClock.forDevice(timeZone: 'Asia/Karachi'),
        MealClock.forCountry('PK'),
      );
      expect(
        MealClock.forDevice(timeZone: 'Europe/Madrid'),
        MealClock.forCountry('ES'),
      );
      expect(
        MealClock.forDevice(timeZone: 'Europe/Stockholm').dinner,
        lessThan(MealClock.forDevice(timeZone: 'Asia/Dubai').dinner),
      );
    });

    test('an unlisted or missing zone falls through to the locale', () {
      // Not an error: the locale is a real signal, just a weaker one.
      expect(MealClock.forTimeZone('Antarctica/Troll'), MealClock.fallback);
      expect(MealClock.forTimeZone(null), MealClock.fallback);
      expect(MealClock.forTimeZone(''), MealClock.fallback);
    });

    test('no zone is claimed by two patterns', () {
      final source = File(
        'lib/core/notifications/meal_clock.dart',
      ).readAsStringSync();
      final table = source.substring(source.indexOf('_zones = ['));

      final zones = RegExp("'([A-Za-z_]+/[A-Za-z_+\\-]+)'")
          .allMatches(table)
          .map((m) => m.group(1)!)
          .toList();

      expect(zones.length, greaterThan(180), reason: 'the table was not read');
      final seen = <String>{};
      final twice = zones.where((z) => !seen.add(z)).toSet();
      expect(twice, isEmpty, reason: 'listed under two patterns: \$twice');
    });

    test('the zones a launch market actually reports are covered', () {
      for (final zone in [
        'Asia/Karachi', 'Asia/Kolkata', 'Asia/Calcutta', 'Asia/Dhaka',
        'America/New_York', 'America/Los_Angeles', 'Europe/London',
        'Asia/Dubai', 'Asia/Riyadh', 'America/Toronto',
      ]) {
        expect(MealClock.forTimeZone(zone), isNot(MealClock.fallback),
            reason: zone);
      }
    });

    test('an unknown or missing country falls back', () {
      expect(MealClock.forCountry(null), MealClock.fallback);
      expect(MealClock.forCountry(''), MealClock.fallback);
      expect(MealClock.forCountry('ZZ'), MealClock.fallback);
    });

    test('the code is matched whatever case it arrives in', () {
      expect(MealClock.forCountry('pk'), MealClock.forCountry('PK'));
      expect(MealClock.forCountry('Es'), MealClock.forCountry('ES'));
    });

    test('the fallback reads correctly in the caption it appears in', () {
      // Rendered as "Suggested for <region>", so a region that is a noun
      // phrase is not optional.
      expect('Suggested for ${MealClock.fallback.region}',
          'Suggested for most places');
    });

    test('the slot lookup agrees with the fields', () {
      final clock = MealClock.forCountry('PK');
      expect(clock[MealSlot.breakfast], clock.breakfast);
      expect(clock[MealSlot.lunch], clock.lunch);
      expect(clock[MealSlot.dinner], clock.dinner);
    });
  });
}
