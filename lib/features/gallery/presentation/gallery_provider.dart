import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final String id;

  /// Absolute path inside permanent app storage (flowgram_images/).
  final String imagePath;

  /// JPEG-encoded thumbnail bytes.
  final Uint8List thumbnail;

  final DateTime createdAt;

  final String type; // 'single' or 'template'
  final String? layoutId;
  final Map<String, String>? templateSlots; // slotId -> permanentPath

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
      );

  GalleryProject copyWith({
    String? id,
    String? imagePath,
    Uint8List? thumbnail,
    DateTime? createdAt,
    String? type,
    String? layoutId,
    Map<String, String>? templateSlots,
  }) =>
      GalleryProject(
        id: id ?? this.id,
        imagePath: imagePath ?? this.imagePath,
        thumbnail: thumbnail ?? this.thumbnail,
        createdAt: createdAt ?? this.createdAt,
        type: type ?? this.type,
        layoutId: layoutId ?? this.layoutId,
        templateSlots: templateSlots ?? this.templateSlots,
      );
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
          // Skip entries whose image file was externally deleted.
          if (File(project.imagePath).existsSync()) {
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
  Future<void> addProject({
    required String imagePath,
    required Uint8List thumbnail,
  }) async {
    // Ensure we have a permanent copy.
    final permanentPath = await _ensurePermanent(imagePath);

    final project = GalleryProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imagePath: permanentPath,
      thumbnail: thumbnail,
      createdAt: DateTime.now(),
    );

    // Persist to Hive.
    await HiveService.projects.put(project.id, project.toMap());

    // Update in-memory state (prepend so newest is first).
    state = [project, ...state];
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
    final permanentSlots = <String, String>{};
    for (final entry in slots.entries) {
      permanentSlots[entry.key] = await _ensurePermanent(entry.value);
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
