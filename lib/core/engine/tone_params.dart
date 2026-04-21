/// Immutable value class holding all cinematic tone parameters.
/// All scalar values are in the range –1.0 … +1.0 (0.0 = neutral).
library;

import 'dart:ui' show Offset;
import 'hsl_params.dart';

enum ToneCurvePreset { none, softGlow, matteFade, cinematic }

class ToneParams {
  const ToneParams({
    this.exposure = 0.0,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.highlights = 0.0,
    this.shadows = 0.0,
    this.whites = 0.0,
    this.blacks = 0.0,
    this.blackPoint = 0.0,
    this.fade = 0.0,
    this.brilliance = 0.0,
    this.clarity = 0.0,
    this.sharpen = 0.0,
    this.texture = 0.0,
    this.luminanceNoiseReduction = 0.0,
    this.colorNoiseReduction = 0.0,
    this.grain = 0.0,
    this.saturation = 0.0,
    this.vibrance = 0.0,
    this.warmth = 0.0,
    this.isVintage = false,
    this.highlightProtection = true,
    this.toneCurve = ToneCurvePreset.none,
    this.curvePoints,
    this.hslAdjustments = const {},
  });

  /// Global luminance shift (-1 dark .. +1 bright) — ±2 EV equivalent.
  final double exposure;

  /// True midtone luminance shift (30–70%).
  final double brightness;

  /// Overall contrast S-curve strength (-1 flat .. +1 punchy).
  final double contrast;

  /// Compress (–) or expand (+) bright areas (luminance > 65%).
  final double highlights;

  /// Lift (+) or deepen (–) dark areas (luminance < 35%).
  final double shadows;

  /// Adjust extreme top luminance.
  final double whites;

  /// Adjust extreme bottom luminance.
  final double blacks;

  /// Shifts the minimum black threshold point without completely crushing details.
  final double blackPoint;

  /// Lifts blacks aggressively with an exponential curve to create a matte/film look.
  final double fade;

  /// Smart contrast: boosts midtone vibrancy while gently compressing highlights.
  final double brilliance;

  /// Local midtone contrast (high-pass approximation).
  final double clarity;

  /// Edge sharpening.
  final double sharpen;

  /// Fine micro-contrast and surface details.
  final double texture;

  /// Reduces brightness noise in dark or plain areas.
  final double luminanceNoiseReduction;

  /// Removes color speckles while preserving structure.
  final double colorNoiseReduction;

  /// Adds an organic film-grain overlay.
  final double grain;

  /// Chroma saturation: –1 monochrome .. +1 vivid.
  final double saturation;

  /// Smart saturation: boosts less-saturated colours more (Lightroom-style).
  final double vibrance;

  /// Colour temperature: –1 cool (teal) .. +1 warm (amber).
  final double warmth;

  /// Vintage film simulation (sepia + grain character).
  final bool isVintage;

  /// When true, applies a shoulder rolloff to prevent highlight blowout.
  final bool highlightProtection;

  /// Tone curve shape preset (used when [curvePoints] is null).
  final ToneCurvePreset toneCurve;

  /// Optional custom Bezier control point deltas for the tone curve editor.
  /// 4 points: [shadows, low-mids, high-mids, highlights].
  /// Each Offset is a delta from the neutral diagonal, range –0.4…+0.4.
  /// When non-null, overrides [toneCurve].
  final List<Offset>? curvePoints;

  /// Per-color HSL adjustments (8 channels).
  final Map<HslColor, HslAdjustment> hslAdjustments;

  ToneParams copyWith({
    double? exposure,
    double? brightness,
    double? contrast,
    double? highlights,
    double? shadows,
    double? whites,
    double? blacks,
    double? blackPoint,
    double? fade,
    double? brilliance,
    double? clarity,
    double? sharpen,
    double? texture,
    double? luminanceNoiseReduction,
    double? colorNoiseReduction,
    double? grain,
    double? saturation,
    double? vibrance,
    double? warmth,
    bool? isVintage,
    bool? highlightProtection,
    ToneCurvePreset? toneCurve,
    List<Offset>? curvePoints,
    bool clearCurvePoints = false,
    Map<HslColor, HslAdjustment>? hslAdjustments,
  }) =>
      ToneParams(
        exposure: exposure ?? this.exposure,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        highlights: highlights ?? this.highlights,
        shadows: shadows ?? this.shadows,
        whites: whites ?? this.whites,
        blacks: blacks ?? this.blacks,
        blackPoint: blackPoint ?? this.blackPoint,
        fade: fade ?? this.fade,
        brilliance: brilliance ?? this.brilliance,
        clarity: clarity ?? this.clarity,
        sharpen: sharpen ?? this.sharpen,
        texture: texture ?? this.texture,
        luminanceNoiseReduction: luminanceNoiseReduction ?? this.luminanceNoiseReduction,
        colorNoiseReduction: colorNoiseReduction ?? this.colorNoiseReduction,
        grain: grain ?? this.grain,
        saturation: saturation ?? this.saturation,
        vibrance: vibrance ?? this.vibrance,
        warmth: warmth ?? this.warmth,
        isVintage: isVintage ?? this.isVintage,
        highlightProtection: highlightProtection ?? this.highlightProtection,
        toneCurve: toneCurve ?? this.toneCurve,
        curvePoints: clearCurvePoints ? null : (curvePoints ?? this.curvePoints),
        hslAdjustments: hslAdjustments ?? this.hslAdjustments,
      );

  ToneParams reset() => const ToneParams();

  bool get isNeutral =>
      exposure == 0 &&
      brightness == 0 &&
      contrast == 0 &&
      highlights == 0 &&
      shadows == 0 &&
      whites == 0 &&
      blacks == 0 &&
      blackPoint == 0 &&
      fade == 0 &&
      brilliance == 0 &&
      clarity == 0 &&
      sharpen == 0 &&
      texture == 0 &&
      luminanceNoiseReduction == 0 &&
      colorNoiseReduction == 0 &&
      grain == 0 &&
      saturation == 0 &&
      vibrance == 0 &&
      warmth == 0 &&
      !isVintage &&
      toneCurve == ToneCurvePreset.none &&
      curvePoints == null &&
      hslAdjustments.values.every((adj) => !adj.isModified);
}
