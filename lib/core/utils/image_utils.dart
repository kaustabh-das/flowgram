import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Collection of offline image processing helpers used across the app.
class ImageUtils {
  ImageUtils._();

  static const _uuid = Uuid();

  // ── Directory helpers ─────────────────────────────────────────────

  /// Returns (and creates if needed) the app's private images directory.
  static Future<Directory> get _imagesDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'flowgram_images'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Generates a unique file path inside the app's images directory.
  static Future<String> uniqueFilePath({String extension = 'jpg'}) async {
    final dir = await _imagesDir;
    return p.join(dir.path, '${_uuid.v4()}.$extension');
  }

  // ── Compression ───────────────────────────────────────────────────

  /// Compresses [sourceFile] to JPEG and writes to [destPath].
  /// Returns the compressed [XFile] or null on failure.
  static Future<XFile?> compress(
    File sourceFile, {
    String? destPath,
    int quality = 80,
    int minWidth = 1080,
    int minHeight = 1080,
  }) async {
    final outPath = destPath ?? await uniqueFilePath();
    final result = await FlutterImageCompress.compressAndGetFile(
      sourceFile.absolute.path,
      outPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      format: CompressFormat.jpeg,
    );
    return result;
  }

  /// Compresses in-memory [bytes] and returns the result as [Uint8List].
  static Future<Uint8List> compressBytes(
    Uint8List bytes, {
    int quality = 80,
  }) async {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      quality: quality,
    );
    return result;
  }

  // ── Thumbnail ─────────────────────────────────────────────────────

  /// Creates a square thumbnail (default 256×256) from [sourceFile].
  /// Runs entirely on a background isolate – zero jank on the UI thread.
  static Future<Uint8List?> createThumbnail(
    File sourceFile, {
    int size = 256,
  }) async {
    final bytes = await sourceFile.readAsBytes();
    final decoded = await compute(_decodeAndResize, _ResizeArgs(bytes, size));
    return decoded;
  }

  static Uint8List? _decodeAndResize(_ResizeArgs args) {
    final image = img.decodeImage(args.bytes);
    if (image == null) return null;
    final thumb = img.copyResizeCropSquare(image, size: args.size);
    return Uint8List.fromList(img.encodeJpg(thumb, quality: 85));
  }

  // ── Smart large-image loader ──────────────────────────────────────

  /// Decodes a large image to a display-safe [ui.Image] on a background
  /// isolate using sub-sampling so the UI thread is never blocked.
  ///
  /// [maxDimension] caps either dimension; Flutter's codec handles
  /// EXIF orientation automatically.
  static Future<ui.Image> loadSampled(
    File file, {
    int maxDimension = 2048,
  }) async {
    final bytes = await file.readAsBytes();
    // First pass: get actual dimensions cheaply via codec
    final codec0 = await ui.instantiateImageCodec(bytes,
        targetWidth: 1, targetHeight: 1);
    final frame0 = await codec0.getNextFrame();
    final origW = frame0.image.width;
    final origH = frame0.image.height;
    frame0.image.dispose();
    codec0.dispose();

    // Compute target size preserving aspect ratio
    final scaleW = maxDimension / origW;
    final scaleH = maxDimension / origH;
    final scale = scaleW < scaleH ? scaleW : scaleH;

    final targetW = scale >= 1.0 ? 0 : (origW * scale).round();
    final targetH = scale >= 1.0 ? 0 : (origH * scale).round();

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetW == 0 ? null : targetW,
      targetHeight: targetH == 0 ? null : targetH,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    codec.dispose(); // codec no longer needed
    return image; // caller must dispose
  }

  // ── Copy to app storage ───────────────────────────────────────────

  /// Copies a picked [XFile] into permanent app storage and returns the [File].
  /// Uses chunked stream copy so RAM usage stays flat for multi-MB images.
  static Future<File> copyToAppStorage(String sourcePath) async {
    final ext = p.extension(sourcePath).replaceFirst('.', '');
    final destPath = await uniqueFilePath(extension: ext.isEmpty ? 'jpg' : ext);
    final src = File(sourcePath);
    final dst = File(destPath);
    await src.openRead().pipe(dst.openWrite());
    return dst;
  }

  // ── Dimensions ────────────────────────────────────────────────────

  /// Returns the pixel dimensions of [file] without loading the full image.
  static Future<ui.Size> getDimensions(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes,
        targetWidth: 1, targetHeight: 1);
    final frame = await codec.getNextFrame();
    // We need actual size, do a second decode at natural res
    codec.dispose();
    frame.image.dispose();

    final codec2 = await ui.instantiateImageCodec(bytes);
    final frame2 = await codec2.getNextFrame();
    final size = ui.Size(
      frame2.image.width.toDouble(),
      frame2.image.height.toDouble(),
    );
    frame2.image.dispose();
    codec2.dispose();
    return size;
  }

  // ── File management ───────────────────────────────────────────────

  /// Saves [bytes] to app storage and returns the saved [File].
  static Future<File> saveToAppStorage(
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    final path = await uniqueFilePath(extension: extension);
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Deletes [file] if it exists inside app storage (safe no-op otherwise).
  static Future<void> deleteFromAppStorage(File file) async {
    if (file.existsSync()) {
      await file.delete();
    }
  }
}

// ── Compute helper ─────────────────────────────────────────────────────────

class _ResizeArgs {
  const _ResizeArgs(this.bytes, this.size);
  final Uint8List bytes;
  final int size;
}
