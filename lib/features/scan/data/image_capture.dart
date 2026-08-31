import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/repositories/repositories.dart';

/// Prepares a captured image for the scan pipeline.
///
/// Full-resolution photos are pointless here and expensive: a modern phone
/// shoots 12MP, while plate recognition is just as accurate at 1280px long edge
/// — and the upload is what the user waits on. Downsizing to ~150–300KB before
/// it leaves the device keeps a scan fast and keeps the per-scan image token
/// cost down once a real model is behind it.
class ImageCapture {
  const ImageCapture();

  /// Long edge, in pixels, of what gets uploaded.
  static const int maxEdge = 1280;

  /// JPEG quality. 80 is the knee: below it, compression artefacts start
  /// showing up on food texture.
  static const int quality = 80;

  /// Picks one image from the library and prepares it.
  ///
  /// Null when the picker was dismissed — a cancellation, not a failure, so it
  /// must not surface as an error.
  Future<String?> pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: maxEdge.toDouble(),
      maxHeight: maxEdge.toDouble(),
      imageQuality: quality,
    );
    if (picked == null) return null;

    // The picker has already resized, but re-running keeps one code path
    // responsible for the final size and strips the metadata below.
    return prepare(picked.path);
  }

  /// Downsizes and re-encodes [sourcePath], returning the new file's path.
  ///
  /// Re-encoding also drops EXIF, which is where the GPS coordinates of
  /// someone's kitchen live. That has to happen before the file leaves the
  /// device — the server stripping it later is too late.
  Future<String> prepare(String sourcePath) async {
    final directory = await getTemporaryDirectory();
    final target =
        '${directory.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      target,
      minWidth: maxEdge,
      minHeight: maxEdge,
      quality: quality,
      // Honour the camera's rotation flag, then discard it: a sideways plate
      // measurably confuses portion estimates.
      autoCorrectionAngle: true,
      keepExif: false,
    );

    if (result == null) {
      throw const RepositoryException(
        'That photo could not be read. Try taking it again.',
        code: 'compress-failed',
      );
    }
    return result.path;
  }

  /// Removes a prepared capture once it has been logged or discarded.
  ///
  /// These land in the OS temp directory, which is cleared eventually, but a
  /// heavy day of scanning would otherwise leave dozens of files behind.
  Future<void> discard(String? path) async {
    if (path == null || path.startsWith('assets/')) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Already gone, or not ours to delete. Nothing depends on this.
    }
  }
}
