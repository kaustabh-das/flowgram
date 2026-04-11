import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

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
  /// If frames > 1, automatically slices the panoramic image into identical pieces.
  Future<bool> saveImageToGallery(Uint8List imageBytes, {int frames = 1}) async {
    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      // If we don't have permission we can't save.
      return false;
    }

    try {
      if (frames <= 1) {
        await Gal.putImageBytes(imageBytes, name: 'Flowgram_${DateTime.now().millisecondsSinceEpoch}');
        return true;
      }

      // ── Splitting panoramic carousel ──
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) return false;

      final sliceWidth = decodedImage.width ~/ frames;
      
      for (int i = 0; i < frames; i++) {
        final slice = img.copyCrop(
          decodedImage,
          x: i * sliceWidth,
          y: 0,
          width: sliceWidth,
          height: decodedImage.height,
        );
        
        final sliceBytes = img.encodePng(slice);
        // Add artificial delay to ensure sequential timestamps in gallery
        await Future.delayed(const Duration(milliseconds: 100)); 
        await Gal.putImageBytes(
          sliceBytes,
          name: 'Flowgram_${DateTime.now().millisecondsSinceEpoch}_part_${i + 1}',
        );
      }
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
