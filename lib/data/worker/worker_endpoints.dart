import 'package:cloud_functions/cloud_functions.dart';

import '../../core/app_config.dart';

/// Points a Firebase callable at the Cloudflare Worker.
///
/// The backend moved off Cloud Functions, but the *client* deliberately did
/// not move off `cloud_functions`. `httpsCallableFromUri` keeps the SDK doing
/// the two things worth keeping — attaching the Firebase ID token to every
/// request, and turning a callable error body back into a
/// `FirebaseFunctionsException` — so every message-translation table already
/// written in these repositories keeps working unchanged.
///
/// The Worker's side of that bargain is speaking the callable wire protocol
/// exactly: `{"data": ...}` in, `{"result": ...}` out, and
/// `{"error": {"status", "message"}}` on failure.
extension WorkerCallable on FirebaseFunctions {
  HttpsCallable workerCallable(String name, {HttpsCallableOptions? options}) =>
      httpsCallableFromUri(AppConfig.workerUri(name), options: options);
}

/// True when a [FirebaseFunctionsException]'s message is the transport's own
/// status name rather than a sentence someone wrote for a person to read.
///
/// `cloud_functions` fills `message` with the gRPC status — "UNAVAILABLE",
/// "DEADLINE_EXCEEDED" — whenever the call never reached the Worker, so it is
/// non-null and non-empty exactly when there is nothing worth showing. A
/// repository that prefers `e.message` over its own table therefore shows the
/// user a shouted status code on every network failure, which is the one case
/// the table was written for.
///
/// Seen on a device: a scan whose entire error message was "UNAVAILABLE".
bool looksLikeAStatusCode(String? message) {
  if (message == null) return true;
  final trimmed = message.trim();
  return trimmed.isEmpty || RegExp(r'^[A-Z][A-Z_]*$').hasMatch(trimmed);
}
