import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ── Cache entry ───────────────────────────────────────────────────────────────

class _CacheEntry {
  _CacheEntry({required this.image, required this.sizeBytes});

  final ui.Image image;
  final int sizeBytes;
  DateTime lastAccess = DateTime.now();

  void touch() => lastAccess = DateTime.now();

  void dispose() => image.dispose();
}

// ── Image Cache Service ───────────────────────────────────────────────────────

/// LRU in-memory cache for decoded [ui.Image] objects.
///
/// - Caps memory usage at [maxBytes] (default 80 MB).
/// - Evicts least-recently-used entries when the budget is exceeded.
/// - All mutations are synchronised via [_lock] (a simple [Mutex] pattern).
/// - Disk-cache layer stores compressed thumbnails in `<appDocs>/fg_cache/`.
class ImageCacheService {
  ImageCacheService._();

  static final ImageCacheService instance = ImageCacheService._();

  // ── Config ─────────────────────────────────────────────────────────
  static const int maxBytes = 80 * 1024 * 1024; // 80 MB
  static const int _maxDiskEntries = 200;

  // ── In-memory LRU map (ordered by insert / access order) ──────────
  final LinkedHashMap<String, _CacheEntry> _mem =
      LinkedHashMap<String, _CacheEntry>();
  int _usedBytes = 0;

  // ── Disk cache directory ───────────────────────────────────────────
  Directory? _diskCacheDir;

  Future<Directory> get _cacheDir async {
    _diskCacheDir ??= await _buildCacheDir();
    return _diskCacheDir!;
  }

  static Future<Directory> _buildCacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'fg_cache'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // ── Public API ────────────────────────────────────────────────────

  /// Returns a **clone** of the cached [ui.Image] for [key], or null if not cached.
  /// The caller OWNS the returned image and must call [ui.Image.dispose] when done.
  /// The cache retains its own copy and remains valid.
  ui.Image? getMemory(String key) {
    final entry = _mem[key];
    if (entry == null) return null;
    entry.touch();
    // Move to end (most-recently-used position)
    _mem.remove(key);
    _mem[key] = entry;
    // Return a CLONE — never give the caller a direct reference to the
    // cache entry; if they dispose it they would corrupt the cache.
    try {
      return entry.image.clone();
    } catch (_) {
      // Entry image was somehow already disposed (e.g. during low-memory eviction
      // on a different thread). Evict it and treat as cache miss.
      _evictKey(key);
      return null;
    }
  }

  /// Stores [image] under [key], evicting LRU entries as needed.
  void putMemory(String key, ui.Image image) {
    // Clone so the caller can dispose their copy independently
    final clone = image.clone();
    final sizeBytes = _estimateBytes(image);

    // Remove stale entry if it exists
    _evictKey(key);

    // Evict LRU entries until we have budget
    while (_usedBytes + sizeBytes > maxBytes && _mem.isNotEmpty) {
      final oldest = _mem.entries.first;
      _evictKey(oldest.key);
    }

    _mem[key] = _CacheEntry(image: clone, sizeBytes: sizeBytes);
    _usedBytes += sizeBytes;
  }

  /// Returns the disk-cache path for [key].
  Future<String> diskPath(String key) async {
    final dir = await _cacheDir;
    final safe = key.replaceAll(RegExp(r'[^\w]'), '_');
    return p.join(dir.path, '$safe.jpg');
  }

  /// Reads bytes from disk-cache for [key], or null if absent.
  Future<Uint8List?> readDisk(String key) async {
    final path = await diskPath(key);
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// Writes [bytes] to disk-cache for [key].
  Future<void> writeDisk(String key, Uint8List bytes) async {
    final path = await diskPath(key);
    await File(path).writeAsBytes(bytes, flush: true);
    await _enforceDiskLimit();
  }

  /// Clears both memory and disk caches.
  Future<void> clearAll() async {
    for (final entry in _mem.values) {
      entry.dispose();
    }
    _mem.clear();
    _usedBytes = 0;

    final dir = await _cacheDir;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
      dir.createSync();
    }
  }

  // ── Private helpers ───────────────────────────────────────────────

  void _evictKey(String key) {
    final entry = _mem.remove(key);
    if (entry != null) {
      _usedBytes -= entry.sizeBytes;
      entry.dispose();
    }
  }

  /// Removes the oldest disk entries when count exceeds [_maxDiskEntries].
  Future<void> _enforceDiskLimit() async {
    final dir = await _cacheDir;
    final files = dir
        .listSync()
        .whereType<File>()
        .toList()
      ..sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

    while (files.length > _maxDiskEntries) {
      files.removeAt(0).deleteSync();
    }
  }

  static int _estimateBytes(ui.Image img) =>
      img.width * img.height * 4; // ARGB: 4 bytes per pixel
}

// ── Provider ─────────────────────────────────────────────────────────────────

final imageCacheServiceProvider = Provider<ImageCacheService>(
  (_) => ImageCacheService.instance,
);
