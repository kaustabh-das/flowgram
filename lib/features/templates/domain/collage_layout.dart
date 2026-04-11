import 'package:flutter/material.dart';

abstract class TemplateLayer {
  const TemplateLayer({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.borderRadius = 0.0,
    this.zIndex = 0,
  });

  final String id;
  final String type; // 'image', 'text'
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double opacity;
  final double borderRadius;
  final int zIndex;

  factory TemplateLayer.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'text') {
      return TextLayer.fromJson(json);
    }
    return ImageLayer.fromJson(json);
  }
}

class ImageLayer extends TemplateLayer {
  const ImageLayer({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation = 0.0,
    super.opacity = 1.0,
    super.borderRadius = 0.0,
    super.zIndex = 0,
  }) : super(type: 'image');

  factory ImageLayer.fromJson(Map<String, dynamic> json) {
    return ImageLayer(
      id: json['id'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0.0,
      zIndex: json['zIndex'] as int? ?? 0,
    );
  }
}

class TextLayer extends TemplateLayer {
  const TextLayer({
    required super.id,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    super.rotation = 0.0,
    super.opacity = 1.0,
    super.borderRadius = 0.0,
    super.zIndex = 0,
    this.text = "Tap to edit",
    this.fontFamily = "Roboto",
    this.color = 0xFFFFFFFF,
    this.fontSize = 24.0,
  }) : super(type: 'text');

  final String text;
  final String fontFamily;
  final int color;
  final double fontSize;

  factory TextLayer.fromJson(Map<String, dynamic> json) {
    return TextLayer(
      id: json['id'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0.0,
      zIndex: json['zIndex'] as int? ?? 0,
      text: json['text'] as String? ?? "Tap to edit",
      fontFamily: json['fontFamily'] as String? ?? "Roboto",
      color: json['color'] as int? ?? 0xFFFFFFFF,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 24.0,
    );
  }
}

class TemplateModel {
  const TemplateModel({
    required this.id,
    required this.name,
    required this.category,
    required this.frames,
    required this.aspectRatio,
    required this.backgroundColor,
    required this.layers,
  });

  final String id;
  final String name;
  final String category;
  final int frames;
  final double aspectRatio; // of a SINGLE frame
  final Color backgroundColor;
  final List<TemplateLayer> layers;

  factory TemplateModel.fromJson(Map<String, dynamic> json) {
    // Parse aspect ratio string, e.g. "9:16" -> 9/16
    double parsedAspectRatio = 1.0;
    if (json['aspect_ratio'] is String) {
      final parts = (json['aspect_ratio'] as String).split(':');
      if (parts.length == 2) {
        final w = double.tryParse(parts[0]);
        final h = double.tryParse(parts[1]);
        if (w != null && h != null) parsedAspectRatio = w / h;
      }
    }

    // Parse background hex
    Color bgColor = Colors.white;
    if (json['background'] is String) {
      String hex = json['background'] as String;
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      bgColor = Color(int.parse(hex, radix: 16));
    }

    return TemplateModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      frames: json['frames'] as int? ?? 1,
      aspectRatio: parsedAspectRatio,
      backgroundColor: bgColor,
      layers: (json['layers'] as List? ?? [])
          .map((e) => TemplateLayer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
