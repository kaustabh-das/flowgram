import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum HslColor {
  red,
  orange,
  yellow,
  green,
  aqua,
  blue,
  purple,
  magenta,
}

extension HslColorExt on HslColor {
  String get displayName {
    switch (this) {
      case HslColor.red: return 'Red';
      case HslColor.orange: return 'Orange';
      case HslColor.yellow: return 'Yellow';
      case HslColor.green: return 'Green';
      case HslColor.aqua: return 'Aqua';
      case HslColor.blue: return 'Blue';
      case HslColor.purple: return 'Purple';
      case HslColor.magenta: return 'Magenta';
    }
  }

  Color get displayColor {
    switch (this) {
      case HslColor.red: return Colors.red;
      case HslColor.orange: return Colors.orange;
      case HslColor.yellow: return Colors.yellow;
      case HslColor.green: return Colors.green;
      case HslColor.aqua: return Colors.cyanAccent;
      case HslColor.blue: return Colors.blue;
      case HslColor.purple: return Colors.deepPurpleAccent;
      case HslColor.magenta: return Colors.pinkAccent;
    }
  }
}

class HslAdjustment extends Equatable {
  final double hue;
  final double saturation;
  final double luminance;

  const HslAdjustment({
    this.hue = 0.0,
    this.saturation = 0.0,
    this.luminance = 0.0,
  });

  HslAdjustment copyWith({
    double? hue,
    double? saturation,
    double? luminance,
  }) {
    return HslAdjustment(
      hue: hue ?? this.hue,
      saturation: saturation ?? this.saturation,
      luminance: luminance ?? this.luminance,
    );
  }

  @override
  List<Object?> get props => [hue, saturation, luminance];

  bool get isModified => hue != 0.0 || saturation != 0.0 || luminance != 0.0;
}
