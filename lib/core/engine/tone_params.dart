/// Immutable value class holding all cinematic tone parameters.
/// All scalar values are in the range –1.0 … +1.0 (0.0 = neutral).
library;

import 'dart:ui' show Offset;

enum ToneCurvePreset { none, softGlow, matteFade, cinematic }

class ToneParams {
  const ToneParams({
    this.exposure = 0.0,
    this.contrast = 0.0,
    this.highlights = 0.0,
    this.shadows = 0.0,
    this.whites = 0.0,
    this.blacks = 0.0,
    this.saturation = 0.0,
    this.vibrance = 0.0,
    this.warmth = 0.0,
    this.isVintage = false,
    this.highlightProtection = true,
    this.toneCurve = ToneCurvePreset.none,
    this.curvePoints,
  });

  /// Global luminance shift (-1 dark .. +1 bright) — ±2 EV equivalent.
  final double exposure;

  /// Overall contrast S-curve strength (-1 flat .. +1 punchy).
  final double contrast;

  /// Compress (–) or expand (+) bright areas (luminance > 0.65).
  final double highlights;

  /// Lift (+) or deepen (–) dark areas (luminance < 0.35).
  final double shadows;

  /// Adjust extreme top luminance (clipping guard zone > 0.85).
  final double whites;

  /// Adjust extreme bottom luminance (< 0.15).
  final double blacks;

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

  ToneParams copyWith({
    double? exposure,
    double? contrast,
    double? highlights,
    double? shadows,
    double? whites,
    double? blacks,
    double? saturation,
    double? vibrance,
    double? warmth,
    bool? isVintage,
    bool? highlightProtection,
    ToneCurvePreset? toneCurve,
    List<Offset>? curvePoints,
    bool clearCurvePoints = false,
  }) =>
      ToneParams(
        exposure: exposure ?? this.exposure,
        contrast: contrast ?? this.contrast,
        highlights: highlights ?? this.highlights,
        shadows: shadows ?? this.shadows,
        whites: whites ?? this.whites,
        blacks: blacks ?? this.blacks,
        saturation: saturation ?? this.saturation,
        vibrance: vibrance ?? this.vibrance,
        warmth: warmth ?? this.warmth,
        isVintage: isVintage ?? this.isVintage,
        highlightProtection: highlightProtection ?? this.highlightProtection,
        toneCurve: toneCurve ?? this.toneCurve,
        curvePoints: clearCurvePoints ? null : (curvePoints ?? this.curvePoints),
      );

  ToneParams reset() => const ToneParams();

  bool get isNeutral =>
      exposure == 0 &&
      contrast == 0 &&
      highlights == 0 &&
      shadows == 0 &&
      whites == 0 &&
      blacks == 0 &&
      saturation == 0 &&
      vibrance == 0 &&
      warmth == 0 &&
      !isVintage &&
      toneCurve == ToneCurvePreset.none &&
      curvePoints == null;
}
