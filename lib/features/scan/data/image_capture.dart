import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
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

  /// Opts into Android's system photo picker.
  ///
  /// The plugin still defaults to the legacy `ACTION_GET_CONTENT` intent, which
  /// hands the request to whichever app claims it — usually Google Photos,
  /// which shows the camera roll and offers no way out of it. Someone with a
  /// meal photo saved in Downloads, or synced from another app, simply cannot
  /// reach it.
  ///
  /// The system picker shows the same photos and carries a **Browse** entry
  /// into device storage, so both are reachable from one screen. It is also the
  /// picker Android grants without a storage permission at all.
  ///
  /// Set once, on the platform instance, so it applies to every later call.
  static void _useSystemPicker() {
    if (kIsWeb || !Platform.isAndroid) return;
    final platform = ImagePickerPlatform.instance;
    if (platform is ImagePickerAndroid) {
      platform.useAndroidPhotoPicker = true;
    }
  }

  /// Picks one image out of device storage and prepares it.
  ///
  /// This exists because **neither** picker the photo plugin can open reaches a
  /// file browser. The system photo picker is media-only by design, and the
  /// legacy `ACTION_GET_CONTENT` path is fired with `startActivityForResult`
  /// rather than through a chooser, so it goes straight to whichever app is the
  /// registered default — Google Photos on most phones, which shows the camera
  /// roll and nothing else. A meal photo in Downloads, on an SD card, saved
  /// from WhatsApp or sitting in Drive was unreachable either way.
  ///
  /// `FilePicker` goes to the Storage Access Framework on Android and Files on
  /// iOS, which is the one surface that sees all of those. It needs no storage
  /// permission: the user granting a document *is* the grant.
  ///
  /// `pickFile` rather than `pickFiles` so nothing has to reject a multi-select
  /// after the fact, and no bytes are requested — pulling a 12MP file through
  /// the platform channel only to write it straight back out is a large,
  /// pointless copy, and [prepare] wants a path anyway.
  Future<String?> pickFromFiles() async {
    final picked = await FilePicker.pickFile(
      type: FileType.image,
      dialogTitle: 'Choose a meal photo',
    );
    final path = picked?.path;
    if (path == null) return null;
    return prepare(path);
  }

  /// Picks one image from the photo library and prepares it.
  ///
  /// Null when the picker was dismissed — a cancellation, not a failure, so it
  /// must not surface as an error.
  Future<String?> pickFromGallery() async {
    _useSystemPicker();
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
