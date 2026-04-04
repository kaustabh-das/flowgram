import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Model ──────────────────────────────────────────────────────────────────

class GalleryProject {
  const GalleryProject({
    required this.id,
    required this.imagePath,
    required this.thumbnail,
    required this.createdAt,
  });

  final String id;
  final String imagePath;
  final Uint8List thumbnail;
  final DateTime createdAt;

  GalleryProject copyWith({
    String? id,
    String? imagePath,
    Uint8List? thumbnail,
    DateTime? createdAt,
  }) =>
      GalleryProject(
        id: id ?? this.id,
        imagePath: imagePath ?? this.imagePath,
        thumbnail: thumbnail ?? this.thumbnail,
        createdAt: createdAt ?? this.createdAt,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────

class GalleryNotifier extends Notifier<List<GalleryProject>> {
  @override
  List<GalleryProject> build() => [];

  void addProject({
    required String imagePath,
    required Uint8List thumbnail,
  }) {
    final project = GalleryProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      imagePath: imagePath,
      thumbnail: thumbnail,
      createdAt: DateTime.now(),
    );
    state = [project, ...state];
  }

  void removeProject(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void reorder(int oldIndex, int newIndex) {
    final updated = [...state];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = updated;
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final galleryProvider =
    NotifierProvider<GalleryNotifier, List<GalleryProject>>(GalleryNotifier.new);
