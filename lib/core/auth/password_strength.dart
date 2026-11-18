/// What makes a password acceptable, and how strong it is beyond that.
///
/// A pure function of its inputs — no providers, no I/O — like
/// `TargetCalculator`, and for the same reason: it is a rule the whole app
/// depends on, so it is the kind of thing that gets exact unit tests rather
/// than a render diff.
///
/// ---------------------------------------------------------------------------
/// THE RULES ARE LENGTH AND A BLOCKLIST, NOT A CHARACTER-CLASS OBSTACLE COURSE
/// ---------------------------------------------------------------------------
/// The obvious thing to write here is "one uppercase, one number, one symbol".
/// **NIST SP 800-63B explicitly advises against it** (§5.1.1.2: verifiers
/// "SHOULD NOT impose other composition rules"), because people satisfy those
/// rules the same handful of ways — `Password1!`, a capital on the first
/// letter, a `!` on the end — which makes the result *more* guessable while
/// feeling stricter. The same section says what to do instead, and it is what
/// is implemented here: require real length, and refuse passwords already known
/// to attackers or derived from the person's own details.
///
/// So the three hard rules are 8 characters, not a common password, and nothing
/// built out of the name or email the person just typed into the form above.
/// Firebase enforces a 6-character minimum server-side and nothing else; this
/// is what the app adds in front of it, and it is checked before the network
/// call so a weak password is refused instantly rather than after a round trip.
///
/// The meter on top of that is **advice, not a gate**. Passing the three rules
/// lets someone sign up; the meter is there to make length feel worth adding,
/// which is the only lever in this file that reliably buys entropy.
library;

/// How strong a password is once it is already acceptable.
enum PasswordStrength {
  /// Fails at least one hard rule. Sign-up is blocked.
  unusable,
  weak,
  fair,
  good,
  strong;

  /// The word shown beside the meter.
  String get label => switch (this) {
        PasswordStrength.unusable => 'Too weak',
        PasswordStrength.weak => 'Weak',
        PasswordStrength.fair => 'Fair',
        PasswordStrength.good => 'Good',
        PasswordStrength.strong => 'Strong',
      };

  /// How much of the meter is filled, 0–1.
  double get fraction => switch (this) {
        PasswordStrength.unusable => 0.12,
        PasswordStrength.weak => 0.34,
        PasswordStrength.fair => 0.58,
        PasswordStrength.good => 0.8,
        PasswordStrength.strong => 1,
      };
}

/// One requirement, and whether this password meets it.
///
/// Carried as a list rather than collapsed into a single error string because
/// the screen shows them as a live checklist: a person who can see which of
/// three rules they have already satisfied is being told how to finish, while
/// "Password is not strong enough" tells them only that they failed.
class PasswordRule {
  const PasswordRule({required this.label, required this.met});

  final String label;
  final bool met;
}

/// The verdict on one password.
class PasswordCheck {
  const PasswordCheck({required this.rules, required this.strength});

  final List<PasswordRule> rules;
  final PasswordStrength strength;

  /// True when every hard rule passes. The meter does not gate anything.
  bool get isAcceptable => rules.every((r) => r.met);

  /// The first unmet rule, as a sentence to put under the field. Null when the
  /// password is acceptable.
  String? get error {
    for (final rule in rules) {
      if (!rule.met) return rule.message;
    }
    return null;
  }

  /// Minimum length. Eight rather than Firebase's six: six is four hours of
  /// offline guessing, and eight is the floor NIST sets for a user-chosen
  /// secret.
  static const int minLength = 8;

  /// The length at which the meter reads "Strong". A passphrase gets here
  /// without any of the symbol theatre.
  static const int strongLength = 16;

  /// Checks [password], optionally against the [name] and [email] from the
  /// same form.
  ///
  /// Both are optional so the reset-password screen — which has neither on
  /// screen — can use the identical rules rather than a looser copy of them.
  static PasswordCheck of(
    String password, {
    String? name,
    String? email,
  }) {
    final personal = _personalWords(name: name, email: email);

    final rules = <PasswordRule>[
      PasswordRule(
        label: 'At least $minLength characters',
        met: password.length >= minLength,
      ),
      PasswordRule(
        label: 'Not a commonly used password',
        met: password.isNotEmpty && !_isCommon(password),
      ),
      PasswordRule(
        label: 'Does not contain your name or email',
        met: password.isNotEmpty && !_containsAny(password, personal),
      ),
    ];

    final acceptable = rules.every((r) => r.met);
    return PasswordCheck(
      rules: rules,
      strength: acceptable
          ? _strengthOf(password)
          : PasswordStrength.unusable,
    );
  }

  /// Length first, variety second — in that order and that proportion.
  ///
  /// A 16-character passphrase of nothing but lowercase letters is a far harder
  /// guess than `P@ssw0rd`, and a meter that says otherwise teaches the wrong
  /// lesson. Variety can lift a mid-length password one band; it cannot carry a
  /// short one.
  static PasswordStrength _strengthOf(String password) {
    final length = password.length;
    if (length >= strongLength) return PasswordStrength.strong;

    var classes = 0;
    if (password.contains(RegExp('[a-z]'))) classes++;
    if (password.contains(RegExp('[A-Z]'))) classes++;
    if (password.contains(RegExp('[0-9]'))) classes++;
    if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) classes++;

    // A password made of one repeated character, or a straight run off the
    // keyboard, is long without being any harder to guess.
    if (_isLowVariety(password)) return PasswordStrength.weak;

    if (length >= 12) {
      return classes >= 2 ? PasswordStrength.strong : PasswordStrength.good;
    }
    if (length >= 10) {
      return classes >= 3 ? PasswordStrength.good : PasswordStrength.fair;
    }
    return classes >= 3 ? PasswordStrength.fair : PasswordStrength.weak;
  }

  /// True for `aaaaaaaa` and `12345678` — long, and worth nothing.
  static bool _isLowVariety(String password) {
    final distinct = password.split('').toSet().length;
    if (distinct <= 2) return true;

    final lower = password.toLowerCase();
    const runs = 'abcdefghijklmnopqrstuvwxyz0123456789qwertyuiopasdfghjklzxcvbnm';
    for (var i = 0; i + lower.length <= runs.length; i++) {
      if (runs.substring(i, i + lower.length) == lower) return true;
    }
    return false;
  }

  static bool _containsAny(String password, Iterable<String> words) {
    final lower = password.toLowerCase();
    return words.any(lower.contains);
  }

  /// The words from this person's own details that a password must not be
  /// built out of.
  ///
  /// Only runs of four characters or more. "Al" as a first name would otherwise
  /// refuse every password containing "al" — including `walnutbridge`, which is
  /// a perfectly good one.
  static Set<String> _personalWords({String? name, String? email}) {
    final words = <String>{};

    void add(String? raw) {
      if (raw == null) return;
      for (final part in raw.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
        if (part.length >= 4) words.add(part);
      }
    }

    add(name);
    // The local part only. The domain is `gmail` for most of the world, and
    // refusing every password containing "gmail" helps nobody.
    add(email?.split('@').first);
    return words;
  }

  /// True if [password] is one of the passwords attackers try first.
  ///
  /// A short list on purpose: it is the head of the distribution, where the
  /// return on a guess is enormous, and it ships inside the app rather than
  /// costing a network call on every keystroke. It is matched case-insensitively
  /// and with trailing digits stripped, so `password1` and `Password123` are
  /// caught by the one entry.
  static bool _isCommon(String password) {
    final lower = password.toLowerCase();
    if (_common.contains(lower)) return true;
    final stripped = lower.replaceAll(RegExp(r'[0-9!@#$%^&*]+$'), '');
    return stripped.length >= 4 && _common.contains(stripped);
  }

  static const Set<String> _common = {
    'password', 'passwd', 'pass', 'password1', 'passw0rd', 'p@ssword',
    'qwerty', 'qwertyuiop', 'qwerty123', 'asdfgh', 'zxcvbn', 'qazwsx',
    '123456', '1234567', '12345678', '123456789', '1234567890', '111111',
    'abc123', 'abcd1234', 'a1b2c3', 'letmein', 'welcome', 'admin',
    'iloveyou', 'monkey', 'dragon', 'sunshine', 'princess', 'football',
    'baseball', 'superman', 'batman', 'trustno1', 'master', 'shadow',
    'michael', 'jennifer', 'jordan', 'hunter', 'freedom', 'whatever',
    'starwars', 'computer', 'internet', 'samsung', 'google', 'facebook',
    'secret', 'login', 'root', 'test', 'guest', 'user', 'default',
    'changeme', 'temp', 'access', 'flower', 'charlie', 'ashley',
    // This app's own name is the first thing anyone tries on this app.
    'carbsai', 'carbs', 'nutrition', 'calories', 'healthy', 'fitness',
  };
}

extension on PasswordRule {
  /// The rule restated as something to do, for the single line under the field.
  String get message => switch (label) {
        final l when l.startsWith('At least') =>
          'Use at least ${PasswordCheck.minLength} characters',
        final l when l.startsWith('Not a commonly') =>
          'That password is too common — pick something less guessable',
        _ => 'Do not use your name or email in your password',
      };
}
