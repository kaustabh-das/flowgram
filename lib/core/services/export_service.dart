import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Service ───────────────────────────────────────────────────────────────────

class ExportService {
  
  /// Requests the necessary storage/gallery permissions out of the box based on the platform.
  Future<bool> _requestPermission() async {
    final hasAccess = await Gal.hasAccess();
    if (hasAccess) return true;
    return await Gal.requestAccess();
  }

  /// Exports the given Uint8List directly to the user's local Media Gallery.
  /// Generates a randomized filename.
  Future<bool> saveImageToGallery(Uint8List imageBytes, {String prefix = 'Flowgram_Export'}) async {
    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      // If we don't have permission we can't save.
      return false;
    }

    try {
      await Gal.putImageBytes(imageBytes);
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});
