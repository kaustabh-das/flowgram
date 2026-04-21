/// ShaderPreviewWidget — live image preview with full ToneParams applied.
///
/// Previously used a custom GLSL fragment shader which had two critical bugs:
///   1. shouldRepaint used object-identity comparison on ToneParams (always false
///      → the canvas NEVER updated after the first paint, so filter changes were invisible).
///   2. The shader only handled 18 of 24+ ToneParams fields — saturation, vibrance,
///      warmth, toneCurve, curvePoints, and hslAdjustments were silently ignored.
///
/// Replacement: use ToneEngine.buildFilter() which composes a complete 4×5
/// ColorFilter matrix from ALL ToneParams fields via Skia/Impeller's GPU pipeline.
/// • Handles every param: fade, blacks, contrast, saturation, vibrance, warmth,
///   tone curve (preset + custom Bezier), and all 8 HSL channels.
/// • Repaints correctly because ColorFiltered rebuilds on every widget rebuild
///   (driven by Riverpod state changes).
/// • Single GPU draw call — same performance as the shader approach.
library;

import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../engine/tone_engine.dart';
import '../engine/tone_params.dart';

class ShaderPreviewWidget extends StatelessWidget {
  const ShaderPreviewWidget({
    super.key,
    required this.image,
    required this.tone,
  });

  final ui.Image image;
  final ToneParams tone;

  @override
  Widget build(BuildContext context) {
    final colorFilter = ToneEngine.buildFilter(tone);

    return AspectRatio(
      aspectRatio: image.width / image.height,
      child: ColorFiltered(
        colorFilter: colorFilter,
        child: RawImage(
          image: image,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}
