import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:http/http.dart' as http;

import '../../core/app_config.dart';
import '../../core/repositories/repositories.dart';

/// Meal photos in Cloudflare R2, through the Worker.
///
/// Replaces Cloud Storage. R2 charges nothing for egress, which is the part of
/// an image-heavy app that eventually costs real money — and it removes the
/// last reason this app needed a Google storage bucket at all.
///
/// The upload is a plain authenticated POST rather than a callable: there is no
/// callable shape for a binary body, and base64-ing a photo through JSON would
/// inflate it by a third for nothing. The Worker verifies the same Firebase ID
/// token every other endpoint checks, so the ownership rule is unchanged — you
/// write your own subtree and nothing else.
///
/// Uploaded after the meal is logged, not before it is analysed: the analysis
/// takes the bytes directly and the person may never keep the meal, so
/// uploading first would spend bandwidth on photos that get thrown away.
class R2PhotoRepository implements PhotoRepository {
  R2PhotoRepository(this._auth, {http.Client? client})
      : _client = client ?? http.Client();

  final fb.FirebaseAuth _auth;
  final http.Client _client;

  /// Generous next to a 150-300KB capture, and short enough that a stalled
  /// upload does not sit behind the meal it has already saved.
  static const Duration _timeout = Duration(seconds: 30);

  @override
  Future<String?> upload(String localPath, {required String mealId}) async {
    // The bundled stand-in is not the user's photo and has no business in
    // their bucket.
    if (localPath.startsWith('assets/')) return null;

    final user = _auth.currentUser;
    if (user == null) return null;

    final file = File(localPath);
    if (!file.existsSync()) return null;

    // `getIdToken` is nullable. No token means no session to upload against,
    // which is the same "nothing worth uploading" case as the two above —
    // interpolating a null would just send "Bearer null" and earn a 401.
    final token = await user.getIdToken();
    if (token == null) return null;

    try {
      final response = await _client
          .post(
            AppConfig.workerUri('photos'),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'image/jpeg',
              'x-meal-id': mealId,
            },
            body: await file.readAsBytes(),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw RepositoryException(
          'Your meal was saved, but the photo could not be uploaded.',
          code: 'upload-failed-${response.statusCode}',
        );
      }

      // Null here is normal, not a failure: it means the bucket has no public
      // base URL configured yet. The object is stored, and the diary keeps
      // showing the local file until one exists.
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['url'] as String?;
    } on RepositoryException {
      rethrow;
    } catch (error) {
      // A failed upload must not lose the meal — the numbers are the point and
      // they are already saved.
      throw RepositoryException(
        'Your meal was saved, but the photo could not be uploaded.',
        code: 'upload-failed',
      );
    }
  }

  @override
  Future<void> delete(String mealId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    if (token == null) return;
    try {
      await _client.delete(
        AppConfig.workerUri('photos').replace(
          queryParameters: {'mealId': mealId},
        ),
        headers: {'authorization': 'Bearer $token'},
      ).timeout(_timeout);
    } catch (_) {
      // Already gone, or never uploaded. Nothing depends on this.
    }
  }
}
