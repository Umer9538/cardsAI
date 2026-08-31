/// Which set of repository implementations the app runs against.
enum AppBackend {
  /// On-device only: [JsonStore]-backed repositories, fake auth, a stub scan.
  /// Everything works offline and nothing leaves the phone. This is what the
  /// widget tests run against.
  local,

  /// Firebase Auth + Cloud Firestore.
  firebase,
}

abstract final class AppConfig {
  /// The backend to use, overridable at build time:
  ///
  /// ```
  /// flutter run --dart-define=BACKEND=local
  /// ```
  ///
  /// Firebase is the default. `local` is the escape hatch for working offline,
  /// or before the sign-in providers are switched on in the console.
  static AppBackend get backend =>
      const String.fromEnvironment('BACKEND', defaultValue: 'firebase') ==
              'local'
          ? AppBackend.local
          : AppBackend.firebase;

  /// Base URL of the Cloudflare Worker that hosts the backend.
  ///
  /// The server leg lives on Workers rather than Cloud Functions so the
  /// Firebase project can stay on the Spark plan: Spark blocks outbound calls
  /// to any non-Google host, which is what made the OpenAI call undeployable
  /// there. See `workers/README.md`.
  ///
  /// ```
  /// flutter run --dart-define=WORKER_URL=https://carbsai-api.<you>.workers.dev
  /// ```
  static const String workerBaseUrl = String.fromEnvironment('WORKER_URL');

  /// The endpoint for [name].
  ///
  /// Throws rather than returning a placeholder: an unset [workerBaseUrl] is a
  /// build misconfiguration, not a runtime condition, and a request to nowhere
  /// would surface as a network error that names the wrong problem.
  static Uri workerUri(String name) {
    if (workerBaseUrl.isEmpty) {
      throw StateError(
        'WORKER_URL is not set. Build with '
        '--dart-define=WORKER_URL=https://carbsai-api.<subdomain>.workers.dev, '
        'or run with --dart-define=BACKEND=local.',
      );
    }
    return Uri.parse('${workerBaseUrl.replaceAll(RegExp(r"/+$"), "")}/$name');
  }
}
