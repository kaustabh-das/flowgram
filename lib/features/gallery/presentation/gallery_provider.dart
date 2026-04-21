import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/hsl_params.dart';
import '../../../core/engine/tone_params.dart';
import '../../../core/storage/hive_service.dart';
import '../../../core/utils/image_utils.dart';

// ── Model ──────────────────────────────────────────────────────────────────

class GalleryProject {
  const GalleryProject({
    required this.id,
    required this.imagePath,
    required this.thumbnail,
    required this.createdAt,
    this.type = 'single',
    this.layoutId,
    this.templateSlots,
    this.toneParams = const ToneParams(),
  });

  final String id;

  /// Absolute path inside permanent app storage (flowgram_images/).
  final String imagePath;

  /// JPEG-encoded thumbnail bytes.
  final Uint8List thumbnail;

  final DateTime createdAt;

  final String type; // 'single' or 'template'
  final String? layoutId;
  final Map<String, String>? templateSlots;

  /// All tone/filter/HSL adjustments applied at save time.
  /// Restored when the project is re-opened in the editor.
  final ToneParams toneParams;

  // ── Serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'imagePath': imagePath,
        // Hive stores List<int> natively; cast back on read.
        'thumbnail': thumbnail.toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'type': type,
        'layoutId': layoutId,
        'templateSlots': templateSlots,
        'toneParams': _serializeTone(toneParams),
      };

  factory GalleryProject.fromMap(Map<dynamic, dynamic> map) => GalleryProject(
        id: map['id'] as String,
        imagePath: map['imagePath'] as String,
        thumbnail:
            Uint8List.fromList((map['thumbnail'] as List).cast<int>()),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAt'] as int),
        type: map['type'] as String? ?? 'single',
        layoutId: map['layoutId'] as String?,
        templateSlots: (map['templateSlots'] as Map?)?.cast<String, String>(),
        toneParams: map['toneParams'] != null
            ? _deserializeTone(map['toneParams'] as Map)
            : const ToneParams(),
      );

  GalleryProject copyWith({
    String? id,
    String? imagePath,
    Uint8List? thumbnail,
    DateTime? createdAt,
    String? type,
    String? layoutId,
    Map<String, String>? templateSlots,
    ToneParams? toneParams,
  }) =>
      GalleryProject(
        id: id ?? this.id,
        imagePath: imagePath ?? this.imagePath,
        thumbnail: thumbnail ?? this.thumbnail,
        createdAt: createdAt ?? this.createdAt,
        type: type ?? this.type,
        layoutId: layoutId ?? this.layoutId,
        templateSlots: templateSlots ?? this.templateSlots,
        toneParams: toneParams ?? this.toneParams,
      );

  // ── ToneParams serialization helpers ──────────────────────────────

  static Map<String, dynamic> _serializeTone(ToneParams t) => {
        'exposure': t.exposure,
        'brightness': t.brightness,
        'contrast': t.contrast,
        'highlights': t.highlights,
        'shadows': t.shadows,
        'whites': t.whites,
        'blacks': t.blacks,
        'blackPoint': t.blackPoint,
        'fade': t.fade,
        'brilliance': t.brilliance,
        'clarity': t.clarity,
        'sharpen': t.sharpen,
        'texture': t.texture,
        'lumaNR': t.luminanceNoiseReduction,
        'colorNR': t.colorNoiseReduction,
        'grain': t.grain,
        'saturation': t.saturation,
        'vibrance': t.vibrance,
        'warmth': t.warmth,
        'isVintage': t.isVintage,
        'highlightProtection': t.highlightProtection,
        'toneCurve': t.toneCurve.name,
        // curvePoints: list of [dx, dy] pairs
        'curvePoints': t.curvePoints
            ?.map((o) => [o.dx, o.dy])
            .toList(),
        // hslAdjustments: map of colorName -> [hue, sat, lum]
        'hsl': t.hslAdjustments.map(
          (color, adj) => MapEntry(
            color.name,
            [adj.hue, adj.saturation, adj.luminance],
          ),
        ),
      };

  static ToneParams _deserializeTone(Map<dynamic, dynamic> raw) {
    double d(String k, [double fallback = 0.0]) =>
        (raw[k] as num?)?.toDouble() ?? fallback;
    bool b(String k, [bool fallback = false]) =>
        raw[k] as bool? ?? fallback;

    // Restore curve points
    List<Offset>? curvePoints;
    final rawCurve = raw['curvePoints'];
    if (rawCurve is List<dynamic> && rawCurve.isNotEmpty) {
      curvePoints = rawCurve
          .whereType<List>()
          .map((pair) => Offset(
                (pair[0] as num).toDouble(),
                (pair[1] as num).toDouble(),
              ))
          .toList();
    }

    // Restore HSL adjustments
    final hsl = <HslColor, HslAdjustment>{};
    final rawHsl = raw['hsl'];
    if (rawHsl is Map) {
      for (final entry in rawHsl.entries) {
        final colorName = entry.key as String;
        final values = entry.value as List;
        try {
          final color = HslColor.values.firstWhere((c) => c.name == colorName);
          hsl[color] = HslAdjustment(
            hue: (values[0] as num).toDouble(),
            saturation: (values[1] as num).toDouble(),
            luminance: (values[2] as num).toDouble(),
          );
        } catch (_) {
          // Unknown color channel — ignore gracefully.
        }
      }
    }

    // Restore tone curve preset enum
    ToneCurvePreset toneCurve = ToneCurvePreset.none;
    final rawCurvePreset = raw['toneCurve'] as String?;
    if (rawCurvePreset != null) {
      toneCurve = ToneCurvePreset.values.firstWhere(
        (e) => e.name == rawCurvePreset,
        orElse: () => ToneCurvePreset.none,
      );
    }

    return ToneParams(
      exposure: d('exposure'),
      brightness: d('brightness'),
      contrast: d('contrast'),
      highlights: d('highlights'),
      shadows: d('shadows'),
      whites: d('whites'),
      blacks: d('blacks'),
      blackPoint: d('blackPoint'),
      fade: d('fade'),
      brilliance: d('brilliance'),
      clarity: d('clarity'),
      sharpen: d('sharpen'),
      texture: d('texture'),
      luminanceNoiseReduction: d('lumaNR'),
      colorNoiseReduction: d('colorNR'),
      grain: d('grain'),
      saturation: d('saturation'),
      vibrance: d('vibrance'),
      warmth: d('warmth'),
      isVintage: b('isVintage'),
      highlightProtection: b('highlightProtection', true),
      toneCurve: toneCurve,
      curvePoints: curvePoints,
      hslAdjustments: hsl,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────

class GalleryNotifier extends Notifier<List<GalleryProject>> {
  @override
  List<GalleryProject> build() {
    // Load all persisted projects from Hive at startup.
    final box = HiveService.projects;
    final projects = <GalleryProject>[];

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) {
        try {
          final project = GalleryProject.fromMap(raw);
          // Skip entries whose image file was externally deleted or corrupt.
          if (File(project.imagePath).existsSync() && project.thumbnail.isNotEmpty) {
            projects.add(project);
          } else {
            // Clean up orphaned Hive entry.
            box.delete(key);
          }
        } catch (_) {
          // Corrupt entry — silently remove.
          box.delete(key);
        }
      }
    }

    // Most recent first.
    projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return projects;
  }

  // ── Public API ───────────────────────────────────────────────────

  /// Adds a project from a raw file path.
  ///
  /// If [imagePath] points outside permanent app storage (e.g. a temp dir or
  /// the original device gallery location), it is first copied into
  /// `flowgram_images/` so it survives OS clean-ups.
  Future<String> addProject({
    String? id,
    required String imagePath,
    required Uint8List thumbnail,
    ToneParams toneParams = const ToneParams(),
  }) async {
    // Ensure we have a permanent copy.
    final permanentPath = await _ensurePermanent(imagePath);

    final projectId = id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final project = GalleryProject(
      id: projectId,
      imagePath: permanentPath,
      thumbnail: thumbnail,
      createdAt: DateTime.now(),
      toneParams: toneParams,
    );

    final index = state.indexWhere((p) => p.id == projectId);
    if (index >= 0) {
      final existing = state[index];
      // Keep original creation time so it doesn't lose its position
      final newProject = project.copyWith(createdAt: existing.createdAt);
      
      await HiveService.projects.put(newProject.id, newProject.toMap());
      
      final updated = [...state];
      updated[index] = newProject;
      state = updated;
    } else {
      // Persist to Hive.
      await HiveService.projects.put(project.id, project.toMap());

      // Update in-memory state (prepend so newest is first).
      state = [project, ...state];
    }
    return projectId;
  }

  /// Automatically saves a template project. Returns the project ID.
  Future<String> saveTemplateProject({
    String? existingId,
    required String layoutId,
    required Map<String, String> slots,
    required Uint8List thumbnail,
  }) async {
    final id = existingId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Ensure all slot images are copied to permanent storage.
    // Text slots (keys ending in '_txt') contain plain strings — not file paths.
    final permanentSlots = <String, String>{};
    for (final entry in slots.entries) {
      if (entry.key.endsWith('_txt')) {
        permanentSlots[entry.key] = entry.value; // text → store as-is
      } else {
        permanentSlots[entry.key] = await _ensurePermanent(entry.value);
      }
    }
    
    // We arbitrarily pick the first slot image as the default imagePath,
    // though the 'thumbnail' byte array represents the template visually.
    final firstPath = permanentSlots.values.isNotEmpty ? permanentSlots.values.first : '';

    final project = GalleryProject(
      id: id,
      imagePath: firstPath,
      thumbnail: thumbnail,
      createdAt: DateTime.now(),
      type: 'template',
      layoutId: layoutId,
      templateSlots: permanentSlots,
    );

    await HiveService.projects.put(project.id, project.toMap());

    final index = state.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final updated = [...state];
      updated[index] = project;
      updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = updated;
    } else {
      state = [project, ...state];
    }
    return id;
  }

  /// Removes a project, deletes its Hive entry, and cleans up its file.
  Future<void> removeProject(String id) async {
    final project = state.firstWhere(
      (p) => p.id == id,
      orElse: () => throw StateError('Project $id not found'),
    );

    // Remove from Hive.
    await HiveService.projects.delete(id);

    // Delete the physical image files.
    if (project.type == 'template' && project.templateSlots != null) {
      for (final path in project.templateSlots!.values) {
        await ImageUtils.deleteFromAppStorage(File(path));
      }
      if (project.imagePath.isNotEmpty) {
        await ImageUtils.deleteFromAppStorage(File(project.imagePath));
      }
    } else {
      await ImageUtils.deleteFromAppStorage(File(project.imagePath));
    }

    state = state.where((p) => p.id != id).toList();
  }

  void reorder(int oldIndex, int newIndex) {
    final updated = [...state];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = updated;
  }

  // ── Helpers ──────────────────────────────────────────────────────

  /// Returns [originalPath] if it is already inside the app's documents dir,
  /// otherwise copies the file to `flowgram_images/` and returns the new path.
  static Future<String> _ensurePermanent(String originalPath) async {
    // We consider a path permanent when it lives inside flowgram_images/.
    if (originalPath.contains('flowgram_images')) return originalPath;
    final permanent = await ImageUtils.copyToAppStorage(originalPath);
    return permanent.path;
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final galleryProvider =
    NotifierProvider<GalleryNotifier, List<GalleryProject>>(GalleryNotifier.new);
