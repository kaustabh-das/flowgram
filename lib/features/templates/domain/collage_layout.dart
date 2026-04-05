import 'package:flutter/material.dart';

/// Defines the geometry for a single image slot within a collage template.
/// The [left], [top], [width], and [height] are relative values from 0.0 to 1.0
/// defining percentage-based layout dimensions against the parent collage container.
class CollageSlot {
  const CollageSlot({
    required this.id,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String id;
  final double left;
  final double top;
  final double width;
  final double height;
}

/// Defines the master layout configuration for a collage.
class CollageLayout {
  const CollageLayout({
    required this.id,
    required this.name,
    required this.aspectRatio,
    required this.slots,
    this.backgroundColor = Colors.white,
  });

  final String id;
  final String name;
  final double aspectRatio; // e.g. 9/16 for Instagram story
  final List<CollageSlot> slots;
  final Color backgroundColor;
}

/// Pre-seeded layouts
class StandardLayouts {
  static const CollageLayout storySplit = CollageLayout(
    id: 'story_split',
    name: 'Story Split',
    aspectRatio: 9 / 16,
    backgroundColor: Color(0xFFF0F0F0),
    slots: [
      CollageSlot(id: 's1', left: 0.05, top: 0.05, width: 0.9, height: 0.425),
      CollageSlot(id: 's2', left: 0.05, top: 0.525, width: 0.9, height: 0.425),
    ],
  );

  static const CollageLayout storyFilmStrip = CollageLayout(
    id: 'story_filmstrip',
    name: 'Film Strip',
    aspectRatio: 9 / 16,
    backgroundColor: Color(0xFF141414),
    slots: [
      CollageSlot(id: 's1', left: 0.1, top: 0.1, width: 0.8, height: 0.23),
      CollageSlot(id: 's2', left: 0.1, top: 0.38, width: 0.8, height: 0.23),
      CollageSlot(id: 's3', left: 0.1, top: 0.66, width: 0.8, height: 0.23),
    ],
  );

  static const List<CollageLayout> all = [storySplit, storyFilmStrip];
}
