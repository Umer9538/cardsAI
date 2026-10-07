import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// When a country eats.
///
/// A reminder's whole value is landing near the meal it is about, and there is
/// no hour that does that everywhere: dinner is 17:30 in Stockholm, 19:00 in
/// Chicago, 20:30 in Karachi and 21:30 in Madrid. A single default is therefore
/// wrong for most of the world by one to four hours — late enough to arrive
/// after the meal in Sweden, early enough to arrive before it in Spain, and in
/// both cases useless.
///
/// These are *eating* times. The reminder lands
/// [ReminderSchedule.graceMinutes] later, exactly as it does for the median the
/// app learns from someone's own diary — the point of a reminder is the day the
/// meal is running late, not the moment it usually happens.
///
/// It is a starting point and nothing more. Three logged meals in a slot
/// replace it with that person's own median, and one tap in Settings replaces
/// it with whatever they say. What it has to be is *plausible*, so that the
/// first week of reminders is worth leaving switched on.
@immutable
class MealClock {
  const MealClock({
    required this.region,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  /// What to call this pattern on screen, so a suggested time can explain
  /// itself rather than looking arbitrary.
  final String region;

  /// Minutes from midnight.
  final int breakfast;
  final int lunch;
  final int dinner;

  int operator [](MealSlot slot) => switch (slot) {
        MealSlot.breakfast => breakfast,
        MealSlot.lunch => lunch,
        MealSlot.dinner => dinner,
        // Snacks get no reminder — see ReminderSchedule.slots.
        MealSlot.snack => lunch,
      };

  /// Used when the device does not say where it is, and for any country not
  /// named below. Deliberately mid-range rather than an average of the table:
  /// an average would sit between two real patterns and match neither.
  static const MealClock fallback = MealClock(
    region: 'most places',
    breakfast: 8 * 60,
    lunch: 13 * 60,
    dinner: 19 * 60 + 30,
  );

  static const MealClock _northernEurope = MealClock(
    region: 'Northern Europe',
    breakfast: 8 * 60,
    lunch: 12 * 60,
    dinner: 17 * 60 + 30,
  );
  static const MealClock _northAmerica = MealClock(
    region: 'North America',
    breakfast: 7 * 60 + 30,
    lunch: 12 * 60,
    dinner: 18 * 60,
  );
  static const MealClock _britishIsles = MealClock(
    region: 'the UK, Ireland and Australasia',
    breakfast: 8 * 60,
    lunch: 12 * 60 + 45,
    dinner: 18 * 60 + 30,
  );
  static const MealClock _germanic = MealClock(
    region: 'German-speaking Europe',
    breakfast: 8 * 60,
    lunch: 12 * 60 + 30,
    dinner: 18 * 60 + 30,
  );
  static const MealClock _centralEurope = MealClock(
    region: 'Central and Eastern Europe',
    breakfast: 8 * 60,
    lunch: 13 * 60 + 30,
    dinner: 19 * 60,
  );
  static const MealClock _mediterranean = MealClock(
    region: 'the Mediterranean',
    breakfast: 8 * 60,
    lunch: 13 * 60,
    dinner: 20 * 60,
  );
  static const MealClock _spain = MealClock(
    region: 'Spain',
    breakfast: 8 * 60 + 30,
    lunch: 14 * 60 + 30,
    dinner: 21 * 60 + 30,
  );
  static const MealClock _latinAmerica = MealClock(
    region: 'Latin America',
    breakfast: 8 * 60,
    lunch: 14 * 60,
    dinner: 21 * 60,
  );
  static const MealClock _brazil = MealClock(
    region: 'Brazil',
    breakfast: 7 * 60 + 30,
    lunch: 12 * 60 + 30,
    dinner: 19 * 60 + 30,
  );
  static const MealClock _southAsia = MealClock(
    region: 'South Asia',
    breakfast: 8 * 60 + 30,
    lunch: 13 * 60 + 30,
    dinner: 20 * 60 + 30,
  );
  static const MealClock _mena = MealClock(
    region: 'the Middle East and North Africa',
    breakfast: 8 * 60 + 30,
    lunch: 14 * 60 + 30,
    dinner: 21 * 60,
  );
  static const MealClock _centralAsia = MealClock(
    region: 'Iran and Central Asia',
    breakfast: 8 * 60,
    lunch: 13 * 60 + 30,
    dinner: 20 * 60 + 30,
  );
  static const MealClock _eastAsia = MealClock(
    region: 'East Asia',
    breakfast: 7 * 60 + 30,
    lunch: 12 * 60,
    dinner: 18 * 60 + 45,
  );
  static const MealClock _southeastAsia = MealClock(
    region: 'Southeast Asia',
    breakfast: 7 * 60 + 30,
    lunch: 12 * 60,
    dinner: 19 * 60,
  );
  static const MealClock _africa = MealClock(
    region: 'Sub-Saharan Africa',
    breakfast: 8 * 60,
    lunch: 13 * 60 + 30,
    dinner: 19 * 60 + 30,
  );

  /// The patterns, and the countries on each.
  ///
  /// Grouped by how a country eats rather than by continent, because that is
  /// the only thing this table is for — the Netherlands belongs with the Nordic
  /// countries and not with Germany, and Brazil does not belong with the rest
  /// of South America.
  ///
  /// Every entry is a claim about ordinary evening life somewhere, so it is
  /// wrong for plenty of individuals within each country. That is what the
  /// other two rungs of the ladder are for.
  static const List<(MealClock, Set<String>)> _patterns = [
    (_northernEurope, {'SE', 'NO', 'DK', 'FI', 'IS', 'NL', 'FO', 'GL'}),
    (_northAmerica, {'US', 'CA', 'PR', 'VI', 'GU'}),
    (_britishIsles, {'GB', 'IE', 'AU', 'NZ', 'IM', 'JE', 'GG', 'FJ', 'PG'}),
    (_germanic, {'DE', 'AT', 'CH', 'BE', 'LU', 'LI'}),
    (_centralEurope, {
      'PL', 'CZ', 'SK', 'HU', 'RO', 'BG', 'RS', 'HR', 'SI', 'BA', 'MK',
      'ME', 'AL', 'XK', 'EE', 'LV', 'LT', 'UA', 'RU', 'BY', 'MD',
    }),
    (_mediterranean, {
      'FR', 'IT', 'PT', 'GR', 'MT', 'CY', 'TR', 'IL', 'MC', 'SM', 'AD',
    }),
    (_spain, {'ES'}),
    (_latinAmerica, {
      'MX', 'AR', 'CL', 'CO', 'PE', 'UY', 'VE', 'EC', 'BO', 'PY', 'CR',
      'PA', 'GT', 'DO', 'CU', 'HN', 'NI', 'SV', 'BZ',
    }),
    (_brazil, {'BR'}),
    (_southAsia, {'PK', 'IN', 'BD', 'LK', 'NP', 'AF', 'BT', 'MV'}),
    (_mena, {
      'SA', 'AE', 'QA', 'KW', 'BH', 'OM', 'YE', 'JO', 'LB', 'SY', 'IQ',
      'EG', 'MA', 'TN', 'DZ', 'LY', 'PS', 'SD',
    }),
    (_centralAsia, {'IR', 'AZ', 'AM', 'GE', 'KZ', 'UZ', 'TM', 'KG', 'TJ'}),
    (_eastAsia, {'CN', 'JP', 'KR', 'TW', 'HK', 'MO', 'MN', 'KP'}),
    (_southeastAsia, {
      'TH', 'VN', 'PH', 'ID', 'MY', 'SG', 'KH', 'LA', 'MM', 'BN', 'TL',
    }),
    (_africa, {
      'NG', 'GH', 'KE', 'TZ', 'UG', 'ET', 'ZA', 'ZM', 'ZW', 'CM', 'CI',
      'SN', 'RW', 'BW', 'NA', 'MZ', 'AO', 'MW', 'MU', 'BI', 'ML', 'BF',
      'NE', 'TD', 'SO', 'SS', 'CD', 'CG', 'GA', 'GN', 'BJ', 'TG', 'SL',
      'LR', 'MG', 'MR', 'GM',
    }),
  ];

  /// The same patterns, by IANA time zone.
  ///
  /// **This is the signal that gets checked first, and the locale is the
  /// fallback.** A phone set to English (United States) in Karachi is not
  /// unusual, it is the norm across much of the world — and the first device
  /// this feature was tested on was exactly that: `en-US` locale,
  /// `Asia/Karachi` zone, being offered dinner at 18:45 instead of 21:15. The
  /// locale says which language someone reads. The time zone says where they
  /// are standing, and meal times are a fact about where you are standing.
  ///
  /// Not every zone is listed; the ones omitted fall through to the locale and
  /// then to [fallback]. Aliases are kept where a device is known to report
  /// them (`Asia/Calcutta`, `Asia/Saigon`).
  static const List<(MealClock, Set<String>)> _zones = [
    (_northernEurope, {
      'Europe/Stockholm', 'Europe/Oslo', 'Europe/Copenhagen',
      'Europe/Helsinki', 'Atlantic/Reykjavik', 'Europe/Amsterdam',
      'Atlantic/Faroe', 'America/Nuuk', 'America/Godthab',
    }),
    (_northAmerica, {
      'America/New_York', 'America/Detroit', 'America/Chicago',
      'America/Denver', 'America/Phoenix', 'America/Los_Angeles',
      'America/Anchorage', 'Pacific/Honolulu', 'America/Toronto',
      'America/Vancouver', 'America/Edmonton', 'America/Winnipeg',
      'America/Halifax', 'America/St_Johns', 'America/Puerto_Rico',
      'Pacific/Guam', 'America/Indiana/Indianapolis', 'America/Boise',
    }),
    (_britishIsles, {
      'Europe/London', 'Europe/Dublin', 'Europe/Isle_of_Man',
      'Europe/Jersey', 'Europe/Guernsey', 'Australia/Sydney',
      'Australia/Melbourne', 'Australia/Brisbane', 'Australia/Perth',
      'Australia/Adelaide', 'Australia/Hobart', 'Australia/Darwin',
      'Pacific/Auckland', 'Pacific/Fiji', 'Pacific/Port_Moresby',
    }),
    (_germanic, {
      'Europe/Berlin', 'Europe/Vienna', 'Europe/Zurich', 'Europe/Brussels',
      'Europe/Luxembourg', 'Europe/Vaduz', 'Europe/Busingen',
    }),
    (_centralEurope, {
      'Europe/Warsaw', 'Europe/Prague', 'Europe/Bratislava',
      'Europe/Budapest', 'Europe/Bucharest', 'Europe/Sofia',
      'Europe/Belgrade', 'Europe/Zagreb', 'Europe/Ljubljana',
      'Europe/Sarajevo', 'Europe/Skopje', 'Europe/Podgorica',
      'Europe/Tirane', 'Europe/Tallinn', 'Europe/Riga', 'Europe/Vilnius',
      'Europe/Kyiv', 'Europe/Kiev', 'Europe/Moscow', 'Europe/Minsk',
      'Europe/Chisinau', 'Europe/Kaliningrad', 'Asia/Yekaterinburg',
      'Asia/Novosibirsk', 'Asia/Vladivostok', 'Asia/Krasnoyarsk',
      'Europe/Samara',
    }),
    (_mediterranean, {
      'Europe/Paris', 'Europe/Rome', 'Europe/Lisbon', 'Europe/Athens',
      'Europe/Malta', 'Asia/Nicosia', 'Europe/Nicosia', 'Europe/Istanbul',
      'Asia/Istanbul', 'Asia/Jerusalem', 'Asia/Tel_Aviv', 'Europe/Monaco',
      'Europe/San_Marino', 'Europe/Andorra', 'Atlantic/Azores',
      'Atlantic/Madeira',
    }),
    (_spain, {'Europe/Madrid', 'Atlantic/Canary', 'Africa/Ceuta'}),
    (_latinAmerica, {
      'America/Mexico_City', 'America/Monterrey', 'America/Tijuana',
      'America/Cancun', 'America/Chihuahua', 'America/Merida',
      'America/Argentina/Buenos_Aires', 'America/Santiago',
      'America/Bogota', 'America/Lima', 'America/Montevideo',
      'America/Caracas', 'America/Guayaquil', 'America/La_Paz',
      'America/Asuncion', 'America/Costa_Rica', 'America/Panama',
      'America/Guatemala', 'America/Santo_Domingo', 'America/Havana',
      'America/Tegucigalpa', 'America/Managua', 'America/El_Salvador',
      'America/Belize',
    }),
    (_brazil, {
      'America/Sao_Paulo', 'America/Bahia', 'America/Fortaleza',
      'America/Recife', 'America/Manaus', 'America/Belem',
      'America/Cuiaba', 'America/Porto_Velho', 'America/Rio_Branco',
    }),
    (_southAsia, {
      'Asia/Karachi', 'Asia/Kolkata', 'Asia/Calcutta', 'Asia/Dhaka',
      'Asia/Colombo', 'Asia/Kathmandu', 'Asia/Katmandu', 'Asia/Kabul',
      'Asia/Thimphu', 'Indian/Maldives',
    }),
    (_mena, {
      'Asia/Riyadh', 'Asia/Dubai', 'Asia/Qatar', 'Asia/Kuwait',
      'Asia/Bahrain', 'Asia/Muscat', 'Asia/Aden', 'Asia/Amman',
      'Asia/Beirut', 'Asia/Damascus', 'Asia/Baghdad', 'Africa/Cairo',
      'Africa/Casablanca', 'Africa/Tunis', 'Africa/Algiers',
      'Africa/Tripoli', 'Asia/Hebron', 'Asia/Gaza', 'Africa/Khartoum',
      'Africa/El_Aaiun',
    }),
    (_centralAsia, {
      'Asia/Tehran', 'Asia/Baku', 'Asia/Yerevan', 'Asia/Tbilisi',
      'Asia/Almaty', 'Asia/Tashkent', 'Asia/Ashgabat', 'Asia/Bishkek',
      'Asia/Dushanbe', 'Asia/Qostanay', 'Asia/Aqtobe', 'Asia/Samarkand',
    }),
    (_eastAsia, {
      'Asia/Shanghai', 'Asia/Chongqing', 'Asia/Urumqi', 'Asia/Tokyo',
      'Asia/Seoul', 'Asia/Pyongyang', 'Asia/Taipei', 'Asia/Hong_Kong',
      'Asia/Macau', 'Asia/Ulaanbaatar', 'Asia/Harbin',
    }),
    (_southeastAsia, {
      'Asia/Bangkok', 'Asia/Ho_Chi_Minh', 'Asia/Saigon', 'Asia/Manila',
      'Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura', 'Asia/Pontianak',
      'Asia/Kuala_Lumpur', 'Asia/Kuching', 'Asia/Singapore',
      'Asia/Phnom_Penh', 'Asia/Vientiane', 'Asia/Yangon', 'Asia/Rangoon',
      'Asia/Brunei', 'Asia/Dili',
    }),
    (_africa, {
      'Africa/Lagos', 'Africa/Accra', 'Africa/Nairobi',
      'Africa/Dar_es_Salaam', 'Africa/Kampala', 'Africa/Addis_Ababa',
      'Africa/Johannesburg', 'Africa/Lusaka', 'Africa/Harare',
      'Africa/Douala', 'Africa/Abidjan', 'Africa/Dakar', 'Africa/Kigali',
      'Africa/Gaborone', 'Africa/Windhoek', 'Africa/Maputo',
      'Africa/Luanda', 'Africa/Blantyre', 'Indian/Mauritius',
      'Africa/Bujumbura', 'Africa/Bamako', 'Africa/Ouagadougou',
      'Africa/Niamey', 'Africa/Ndjamena', 'Africa/Mogadishu',
      'Africa/Juba', 'Africa/Kinshasa', 'Africa/Lubumbashi',
      'Africa/Brazzaville', 'Africa/Libreville', 'Africa/Conakry',
      'Africa/Porto-Novo', 'Africa/Lome', 'Africa/Freetown',
      'Africa/Monrovia', 'Indian/Antananarivo', 'Africa/Nouakchott',
      'Africa/Banjul',
    }),
  ];

  /// The pattern for an ISO 3166-1 alpha-2 country code.
  static MealClock forCountry(String? code) {
    if (code == null || code.isEmpty) return fallback;
    final upper = code.toUpperCase();
    for (final (clock, countries) in _patterns) {
      if (countries.contains(upper)) return clock;
    }
    return fallback;
  }

  /// The pattern for an IANA time-zone name, such as `Asia/Karachi`.
  static MealClock forTimeZone(String? zone) {
    if (zone == null || zone.isEmpty) return fallback;
    for (final (clock, zones) in _zones) {
      if (zones.contains(zone)) return clock;
    }
    return fallback;
  }

  /// The pattern for this device.
  ///
  /// **Time zone first, locale second.** The locale says which language
  /// someone reads; the time zone says where they are standing, and what time
  /// dinner is depends entirely on the second one. A phone set to English
  /// (United States) outside the United States is the normal case across much
  /// of the world — including the first device this was tested on, which was
  /// `en-US` in `Asia/Karachi` and was being offered dinner at 18:45 instead
  /// of 21:15.
  ///
  /// The locale still earns its place as the fallback: an unlisted zone, or a
  /// platform that cannot report one, leaves it as the only signal there is.
  static MealClock forDevice({
    String? timeZone,
    PlatformDispatcher? dispatcher,
  }) {
    final byZone = forTimeZone(timeZone);
    if (byZone != fallback) return byZone;
    return forLocale(dispatcher);
  }

  /// The pattern for the device's own declared country.
  static MealClock forLocale([PlatformDispatcher? dispatcher]) {
    final locales = (dispatcher ?? PlatformDispatcher.instance).locales;
    for (final locale in locales) {
      final country = locale.countryCode;
      if (country == null || country.isEmpty) continue;
      final clock = forCountry(country);
      // The first locale that names a country we know about.
      if (clock != fallback) return clock;
    }
    return forCountry(
      locales.isEmpty ? null : locales.first.countryCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MealClock &&
      other.region == region &&
      other.breakfast == breakfast &&
      other.lunch == lunch &&
      other.dinner == dinner;

  @override
  int get hashCode => Object.hash(region, breakfast, lunch, dinner);

  @override
  String toString() => 'MealClock($region)';
}
