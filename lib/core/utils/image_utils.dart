import 'dart:io';
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

  // ── Dimensions ────────────────────────────────────────────────────

  /// Returns the pixel dimensions of [file] without loading the full image.
  static Future<ui.Size> getDimensions(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return ui.Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
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
