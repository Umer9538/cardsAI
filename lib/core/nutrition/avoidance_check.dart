import '../models/taste_profile.dart';

/// The client-side twin of `violations()` in `workers/src/planner.ts`.
///
/// Same semantics, kept in one place so the local planner, the tests and
/// anything else that needs to ask "does this name an excluded food" agree
/// with the server:
///
/// 1. lowercase the text;
/// 2. blank out every [Avoidance.except] phrase — the safe compounds, "oat
///    milk", "corn tortilla" — as whole words, plural-tolerant. A phrase
///    that ends in `free` or starts with `non-` is a qualifier and takes the
///    word after it with it: "gluten-free bread" is not bread;
/// 3. hit if any [Avoidance.words] entry starts a word: `\bcream` catches
///    "cream", "creamy" and "creamed"; `\bcod` catches "cod" and not
///    "avocado".
///
/// Word-start rather than whole-word because the misses were worse than the
/// hits: "Creamy korma", "Buttered toast" and "Cheeseburger" all passed a
/// whole-word scan, and for an allergen a false pass reaches the person. The
/// false positives that a prefix introduces ("eggplant", "hamburger" for
/// pork) are enumerated in `except`, where they can be reviewed.
abstract final class AvoidanceCheck {
  static final Map<Avoidance, RegExp> _words = {
    for (final a in Avoidance.values)
      a: RegExp(
        r'\b(?:' + a.words.map(RegExp.escape).join('|') + r')\w*',
        caseSensitive: false,
      ),
  };

  static final Map<Avoidance, RegExp?> _except = {
    for (final a in Avoidance.values)
      a: a.except.isEmpty
          ? null
          : RegExp(
              r'\b(?:' + a.except.map(_exception).join('|') + r')',
              caseSensitive: false,
            ),
  };

  static bool isQualifier(String phrase) =>
      phrase.endsWith('free') || phrase.startsWith('non-');

  /// One exception as a pattern: the phrase, a plural, and — for a
  /// qualifier — the word it qualifies.
  static String _exception(String phrase) =>
      RegExp.escape(phrase) +
      (isQualifier(phrase) ? r'(?:[ -]+\w+)?' : r'(?:s|es)?') +
      r'\b';

  /// Whether [text] names [avoidance].
  static bool mentions(String text, Avoidance avoidance) {
    var t = text.toLowerCase();
    final except = _except[avoidance];
    if (except != null) t = t.replaceAll(except, ' ');
    return _words[avoidance]!.hasMatch(t);
  }

  /// The avoidances in [avoid] that any of [texts] names, in [avoid]'s
  /// iteration order, each at most once.
  static List<Avoidance> violations(
    Iterable<String> texts,
    Iterable<Avoidance> avoid,
  ) {
    final list = texts.toList();
    return [
      for (final a in avoid)
        if (list.any((t) => mentions(t, a))) a,
    ];
  }
}
