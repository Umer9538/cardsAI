import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/repositories.dart';
import '../data/image_capture.dart';

final imageCaptureProvider = Provider<ImageCapture>((ref) => const ImageCapture());

/// Owns the platform camera while the scanning screen is open.
///
/// Failure here is ordinary, not exceptional: a simulator has no camera, a
/// widget test has no platform channels, and permission can be refused. All
/// three land in the error state, and the scanning screen falls back to the
/// design's still photograph rather than showing a broken viewfinder.
///
/// There is no separate permission package. `CameraController.initialize()`
/// raises the OS prompt itself on both platforms and reports a refusal as a
/// [CameraException], so asking twice would only mean two prompts — and
/// `permission_handler` was pulling in an Android Gradle script that does not
/// build against this project's toolchain.
class CameraSession extends AsyncNotifier<CameraController?> {
  @override
  Future<CameraController?> build() async {
    final cameras = await _availableCameras();
    if (cameras.isEmpty) {
      throw const RepositoryException(
        'No camera available on this device.',
        code: 'no-camera',
      );
    }

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // `high` rather than `max`: the capture is downsized to 1280px anyway, and
    // max resolution measurably slows the shutter on mid-range Android.
    final controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      // Raises the OS permission prompt on first run.
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      throw RepositoryException(_translate(e), code: e.code);
    }

    // Tied to the provider's own lifetime, so leaving the screen releases the
    // camera rather than leaving it warm and draining battery.
    ref.onDispose(controller.dispose);
    return controller;
  }

  /// The plugin's codes differ per platform for the same refusal.
  static String _translate(CameraException e) => switch (e.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'AudioAccessDenied' ||
        'cameraPermission' =>
          'Carbsai needs camera access to scan a meal. You can turn it on in '
              'Settings.',
        'CameraAccessRestricted' =>
          'Camera access is restricted on this device.',
        _ => e.description ?? 'The camera could not be started.',
      };

  /// Takes a photo and returns the path of the prepared (downsized, EXIF-free)
  /// file, ready to upload.
  Future<String> capture() async {
    final controller = state.value;
    if (controller == null || !controller.value.isInitialized) {
      throw const RepositoryException(
        'The camera is not ready yet.',
        code: 'camera-not-ready',
      );
    }
    final shot = await controller.takePicture();
    return ref.read(imageCaptureProvider).prepare(shot.path);
  }

  /// Retries after the user has granted permission in Settings.
  Future<void> retry() async {
    state = const AsyncLoading();
    ref.invalidateSelf();
  }

  Future<List<CameraDescription>> _availableCameras() async {
    try {
      return await availableCameras();
    } on CameraException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}

final cameraSessionProvider =
    AsyncNotifierProvider<CameraSession, CameraController?>(CameraSession.new);
