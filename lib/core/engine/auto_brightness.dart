/// Auto Brightness / Exposure Correction Engine.
///
/// Uses histogram statistics from [HistogramResult] to produce
/// a suggested [ToneParams] correction. Purely statistical — no ML required.
library;

import 'histogram.dart';
import 'tone_params.dart';

class AutoBrightnessAnalyzer {
  const AutoBrightnessAnalyzer._();

  /// Returns a [ToneParams] with suggested corrections applied.
  ///
  /// The suggestion is additive — you should apply it on top of the current
  /// params via `state.tone.copyWith(...)`, not replace the entire stack.
  static ToneParams suggest(HistogramResult result) {
    final exposure   = HistogramAnalyzer.suggestExposureCorrection(result);
    final shadowLift = HistogramAnalyzer.suggestShadowLift(result);
    final hlCompress = HistogramAnalyzer.suggestHighlightCompress(result);

    // If well-exposed (no strong suggestion), return neutral delta.
    if (exposure.abs() < 0.05 && shadowLift < 0.05 && hlCompress.abs() < 0.05) {
      return const ToneParams(); // neutral — no change needed
    }

    // Scale exposure down if we're also adjusting zones (avoid double-dipping).
    final scaledExposure = hlCompress != 0
        ? exposure * 0.6
        : (shadowLift > 0 ? exposure * 0.7 : exposure);

    // Clamp to safe ranges.
    return ToneParams(
      exposure:   scaledExposure.clamp(-0.8, 0.8),
      shadows:    shadowLift.clamp(0.0, 0.55),
      highlights: hlCompress.clamp(-0.7, 0.0),
      whites:     (hlCompress * 0.5).clamp(-0.5, 0.0),
      blacks:     (shadowLift * 0.3).clamp(0.0, 0.4),
    );
  }

  /// Merges the auto-correction suggestion into [current] params gracefully.
  /// Only adjusts parameters that are at/near their neutral values so we
  /// don't undo deliberate user adjustments.
  static ToneParams mergeInto(ToneParams current, HistogramResult result) {
    final suggestion = suggest(result);

    // Only apply a correction to a parameter if the user hasn't moved it
    // more than 20% of its range from neutral (i.e. it's still near-default).
    double pick(double cur, double sug) {
      return cur.abs() < 0.20 ? sug : cur;
    }

    return current.copyWith(
      exposure:   pick(current.exposure,   suggestion.exposure),
      shadows:    pick(current.shadows,    suggestion.shadows),
      highlights: pick(current.highlights, suggestion.highlights),
      whites:     pick(current.whites,     suggestion.whites),
      blacks:     pick(current.blacks,     suggestion.blacks),
    );
  }
}
