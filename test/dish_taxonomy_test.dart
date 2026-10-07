import 'dart:io';

import 'package:carbsai/core/models/models.dart';
import 'package:carbsai/core/nutrition/dish_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

/// The taxonomy exists twice — `dish_taxonomy.dart` and
/// `workers/src/taxonomy.ts` — and the client sends ids and names the server
/// resolves against its own copy. A value one side knows and the other does
/// not is a tap that changes nothing, silently. This reads the TypeScript as
/// text and diffs the vocabularies, so the drift fails here rather than on a
/// phone.
///
/// Runs with the repo root as the working directory, which is where
/// `flutter test` puts it.
void main() {
  late String ts;

  setUpAll(() {
    ts = File('workers/src/taxonomy.ts').readAsStringSync();
  });

  /// The body of `export const <name> ... = { ... };`.
  String block(String name) {
    final start = ts.indexOf('export const $name');
    expect(start, isNonNegative, reason: '$name is not in taxonomy.ts');
    final open = ts.indexOf('{', start);
    final close = ts.indexOf('\n};', open);
    expect(close, isNonNegative, reason: '$name has no closing brace');
    return ts.substring(open + 1, close);
  }

  /// Top-level keys of a record literal — `"chicken-karahi": {` or
  /// `biryani: {` — quoted or bare, one per line.
  final objectKey = RegExp(
    r'^\s*(?:"([^"]+)"|([A-Za-z_$][\w$-]*))\s*:\s*\{',
    multiLine: true,
  );

  Set<String> objectKeys(String body) => {
        for (final m in objectKey.allMatches(body)) (m.group(1) ?? m.group(2))!,
      };

  final quoted = RegExp(r'"([^"]+)"');
  List<String> strings(String s) =>
      [for (final m in quoted.allMatches(s)) m.group(1)!];

  test('every dish id exists on both sides', () {
    final serverIds = objectKeys(block('DISHES'));
    final clientIds = {for (final d in DishTaxonomy.all) d.id};

    expect(serverIds, isNotEmpty);
    expect(serverIds, clientIds);
  });

  test('every axis answers with the same poles on both sides', () {
    final axisLine = RegExp(r'^\s*(\w+):\s*\[([^\]]*)\]', multiLine: true);
    final server = {
      for (final m in axisLine.allMatches(block('AXES')))
        m.group(1)!: strings(m.group(2)!),
    };
    final client = {
      for (final axis in TasteAxis.values)
        axis.name: [for (final p in axis.poles) p.name],
    };

    expect(server.keys.toSet(), client.keys.toSet());
    for (final entry in client.entries) {
      expect(server[entry.key], entry.value, reason: 'axis ${entry.key}');
    }
  });

  test('every avoidance scans for the same words on both sides', () {
    final body = block('AVOIDANCES');
    final keys = objectKey.allMatches(body).toList();
    final server = <String, List<String>>{};
    final serverExcept = <String, List<String>>{};
    for (var i = 0; i < keys.length; i++) {
      final end = i + 1 < keys.length ? keys[i + 1].start : body.length;
      final entry = body.substring(keys[i].start, end);
      final words = RegExp(r'words:\s*\[([^\]]*)\]').firstMatch(entry);
      final except = RegExp(r'except:\s*\[([^\]]*)\]').firstMatch(entry);
      expect(words, isNotNull, reason: 'no words on ${keys[i].group(0)}');
      expect(except, isNotNull, reason: 'no except on ${keys[i].group(0)}');
      final key = (keys[i].group(1) ?? keys[i].group(2))!;
      server[key] = strings(words!.group(1)!);
      serverExcept[key] = strings(except!.group(1)!);
    }

    expect(
      server.keys.toSet(),
      {for (final a in Avoidance.values) a.name},
    );
    for (final a in Avoidance.values) {
      expect(server[a.name], a.words, reason: 'avoidance ${a.name}');
      expect(serverExcept[a.name], a.except, reason: 'except ${a.name}');
    }
  });

  test('every cook time exists on both sides', () {
    expect(
      objectKeys(block('COOK_TIMES')),
      {for (final c in CookTime.values) c.name},
    );
  });

  test('the two grids are 3×3, disjoint, and resolve', () {
    expect(DishTaxonomy.gridA, hasLength(9));
    expect(DishTaxonomy.gridB, hasLength(9));
    expect(DishTaxonomy.gridA.toSet(), hasLength(9), reason: 'gridA repeats');
    expect(DishTaxonomy.gridB.toSet(), hasLength(9), reason: 'gridB repeats');
    expect(
      DishTaxonomy.gridA.toSet().intersection(DishTaxonomy.gridB.toSet()),
      isEmpty,
      reason: 'the second grid is for exploration, not confirmation',
    );
    for (final id in [...DishTaxonomy.gridA, ...DishTaxonomy.gridB]) {
      expect(DishTaxonomy.byId(id), isNotNull, reason: '$id in a grid');
    }
    expect(DishTaxonomy.grid(DishTaxonomy.gridA), hasLength(9));
    expect(DishTaxonomy.grid(DishTaxonomy.gridB), hasLength(9));
  });

  test('every this-or-that pair resolves', () {
    for (final axis in TasteAxis.values) {
      expect(DishTaxonomy.byId(axis.left), isNotNull, reason: axis.left);
      expect(DishTaxonomy.byId(axis.right), isNotNull, reason: axis.right);
      expect(axis.left, isNot(axis.right), reason: '${axis.name} pairs a dish with itself');
      expect(axis.leftPole, isNot(axis.rightPole));
      expect(axis.poles.length, axis.neither == null ? 2 : 3);
    }
  });

  test('ids are unique and every dish is described', () {
    final ids = DishTaxonomy.all.map((d) => d.id).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate dish id');
    for (final dish in DishTaxonomy.all) {
      expect(dish.tags, isNotEmpty, reason: '${dish.id} has no tags');
      expect(dish.name, isNotEmpty, reason: '${dish.id} has no name');
      expect(dish.minutes, greaterThan(0), reason: '${dish.id} takes no time');
      expect(DishTaxonomy.byId(dish.id), same(dish));
    }
  });

  test('every photo that is named exists', () {
    // A tile with a photo that fails to load falls back to its name, which
    // is the same thing as having no photo — but a path that is wrong in
    // the source is a mistake, not a fallback.
    for (final dish in DishTaxonomy.all) {
      final asset = dish.asset;
      if (asset == null) continue;
      expect(File(asset).existsSync(), isTrue, reason: '${dish.id}: $asset');
    }
  });

  test('dish content matches the server copy', () {
    // Names, cuisines and minutes are what the prompt is given, so a dish
    // renamed on one side is a prompt that describes a different food.
    final body = block('DISHES');
    final keys = objectKey.allMatches(body).toList();
    for (var i = 0; i < keys.length; i++) {
      final end = i + 1 < keys.length ? keys[i + 1].start : body.length;
      final entry = body.substring(keys[i].start, end);
      final id = (keys[i].group(1) ?? keys[i].group(2))!;
      final dish = DishTaxonomy.byId(id)!;

      final name = RegExp(r'name:\s*"([^"]+)"').firstMatch(entry)!.group(1);
      final cuisine =
          RegExp(r'cuisine:\s*"([^"]+)"').firstMatch(entry)!.group(1);
      final minutes = RegExp(r'minutes:\s*(\d+)').firstMatch(entry)!.group(1);
      final tags = strings(
        RegExp(r'tags:\s*\[([^\]]*)\]').firstMatch(entry)!.group(1)!,
      );

      expect(name, dish.name, reason: '$id name');
      expect(cuisine, dish.cuisine.label, reason: '$id cuisine');
      expect(int.parse(minutes!), dish.minutes, reason: '$id minutes');
      expect(tags.toSet(), dish.tags.map((t) => t.name).toSet(),
          reason: '$id tags');
    }
  });
}
