import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/repositories/repositories.dart';

/// Meal photos in Cloud Storage, under `users/{uid}/meals/`.
///
/// Uploaded after the meal is logged, not before it is analysed: the analysis
/// takes the bytes directly and the person may never keep the meal, so
/// uploading first would spend bandwidth and storage on photos that get thrown
/// away. The diary shows the local file until the URL arrives.
class StoragePhotoRepository implements PhotoRepository {
  StoragePhotoRepository(this._storage, this._auth);

  final FirebaseStorage _storage;
  final fb.FirebaseAuth _auth;

  @override
  Future<String?> upload(String localPath, {required String mealId}) async {
    // The bundled stand-in is not the user's photo and has no business in
    // their storage bucket.
    if (localPath.startsWith('assets/')) return null;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final file = File(localPath);
    if (!file.existsSync()) return null;

    try {
      final ref = _storage.ref('users/$uid/meals/$mealId.jpg');
      await ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          // Immutable: the path is keyed by meal id, so a given URL always
          // returns the same bytes and can be cached hard.
          cacheControl: 'public, max-age=31536000, immutable',
        ),
      );
      return ref.getDownloadURL();
    } on FirebaseException catch (e) {
      // A failed upload must not lose the meal — the numbers are the point and
      // they are already saved. The diary keeps the local path.
      throw RepositoryException(
        'Your meal was saved, but the photo could not be uploaded.',
        code: e.code,
      );
    }
  }

  @override
  Future<void> delete(String mealId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _storage.ref('users/$uid/meals/$mealId.jpg').delete();
    } on FirebaseException {
      // Already gone, or never uploaded. Nothing depends on this.
    }
  }
}

/// No bucket on the local backend; the capture stays where it is on disk.
class LocalPhotoRepository implements PhotoRepository {
  const LocalPhotoRepository();

  @override
  Future<String?> upload(String localPath, {required String mealId}) async =>
      localPath.startsWith('assets/') ? null : localPath;

  @override
  Future<void> delete(String mealId) async {}
}
