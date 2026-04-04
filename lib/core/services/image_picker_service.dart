import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/image_utils.dart';

// ── Result types ─────────────────────────────────────────────────────────────

sealed class PickResult {}

class PickSuccess extends PickResult {
  PickSuccess({required this.file, required this.thumbnail});
  final File file;
  final Uint8List? thumbnail;
}

class PickCancelled extends PickResult {}

class PickPermissionDenied extends PickResult {}

class PickError extends PickResult {
  PickError(this.message);
  final String message;
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Encapsulates all image picking logic: permission checks, picker invocation,
/// copying to permanent app storage, and thumbnail generation.
///
/// Using a service class rather than embedding the logic in a Notifier keeps
/// each layer testable in isolation.
class ImagePickerService {
  ImagePickerService(this._picker);

  final ImagePicker _picker;

  // ── Pick from gallery ────────────────────────────────────────────

  Future<PickResult> pickFromGallery() async {
    // 1. Permission check
    final result = await Permission.photos.request();
    if (!result.isGranted) return PickPermissionDenied();

    // 2. Launch picker
    final XFile? xFile;
    try {
      xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        // Do NOT pass imageQuality here — we want the original file
        // and will apply our own controlled compression later.
        imageQuality: null,
      );
    } catch (e) {
      return PickError(e.toString());
    }

    if (xFile == null) return PickCancelled();

    // 3. Copy picked file into permanent app storage (chunked stream copy)
    final File permanentFile;
    try {
      permanentFile = await ImageUtils.copyToAppStorage(xFile.path);
    } catch (e) {
      return PickError('Failed to save image: $e');
    }

    // 4. Generate thumbnail on a background isolate
    final Uint8List? thumbnail = await ImageUtils.createThumbnail(
      permanentFile,
      size: 256,
    );

    return PickSuccess(file: permanentFile, thumbnail: thumbnail);
  }

  // ── Pick from camera ─────────────────────────────────────────────

  Future<PickResult> pickFromCamera() async {
    final result = await Permission.camera.request();
    if (!result.isGranted) return PickPermissionDenied();

    final XFile? xFile;
    try {
      xFile = await _picker.pickImage(source: ImageSource.camera);
    } catch (e) {
      return PickError(e.toString());
    }

    if (xFile == null) return PickCancelled();

    final File permanentFile;
    try {
      permanentFile = await ImageUtils.copyToAppStorage(xFile.path);
    } catch (e) {
      return PickError('Failed to save image: $e');
    }

    final Uint8List? thumbnail = await ImageUtils.createThumbnail(
      permanentFile,
      size: 256,
    );

    return PickSuccess(file: permanentFile, thumbnail: thumbnail);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final imagePickerServiceProvider = Provider<ImagePickerService>(
  (ref) => ImagePickerService(ImagePicker()),
);
