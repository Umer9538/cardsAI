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
