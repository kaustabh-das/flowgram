/// Async luminance + RGB histogram computed from a ui.Image.
/// Runs pixel reading on a background isolate to avoid jank.
library;

import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class HistogramResult {
  const HistogramResult({
    required this.luminance,
    required this.red,
    required this.green,
    required this.blue,
  });

  /// 256-bucket luminance distribution (Rec.709), 0 = black, 255 = white.
  final List<int> luminance;

  /// 256-bucket per-channel distributions.
  final List<int> red;
  final List<int> green;
  final List<int> blue;

  // ── Derived helpers ──────────────────────────────────────────────────────

  int get peakLuminance => luminance.reduce((a, b) => a > b ? a : b);
  int get peakRed       => red.reduce((a, b) => a > b ? a : b);
  int get peakGreen     => green.reduce((a, b) => a > b ? a : b);
  int get peakBlue      => blue.reduce((a, b) => a > b ? a : b);

  /// Overall peak across all channels (used for normalisation).
  int get peak {
    final p = peakLuminance;
    return p == 0 ? 1 : p;
  }

  /// Normalised luminance fraction for bucket [i] (0–1).
  double normalisedL(int i) => luminance[i] / peak;

  /// Normalised R/G/B fractions.
  double normalisedR(int i) => red[i]   / peak;
  double normalisedG(int i) => green[i] / peak;
  double normalisedB(int i) => blue[i]  / peak;

  /// Total pixel count.
  int get totalPixels => luminance.fold(0, (s, v) => s + v);

  /// Median luminance bucket (0–255).
  int get medianBucket {
    final half = totalPixels ~/ 2;
    int acc = 0;
    for (int i = 0; i < 256; i++) {
      acc += luminance[i];
      if (acc >= half) return i;
    }
    return 127;
  }

  /// Median luminance as 0–1 fraction.
  double get medianLuminance => medianBucket / 255.0;

  /// Mass in the shadow zone (buckets 0–76).
  double get shadowMass {
    final total = totalPixels;
    if (total == 0) return 0;
    int s = 0;
    for (int i = 0; i < 77; i++) { s += luminance[i]; }
    return s / total;
  }

  /// Mass in the highlight zone (buckets 179–255).
  double get highlightMass {
    final total = totalPixels;
    if (total == 0) return 0;
    int h = 0;
    for (int i = 179; i < 256; i++) { h += luminance[i]; }
    return h / total;
  }

  /// Clipping mass: pixels at absolute white (bucket 255).
  double get clipMass {
    final total = totalPixels;
    if (total == 0) return 0;
    return luminance[255] / total;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Computer
// ─────────────────────────────────────────────────────────────────────────────

class HistogramComputer {
  /// Compute a full RGBL histogram from the given [image].
  /// Returns null if the image data is unavailable.
  static Future<HistogramResult?> compute(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;
    final bytes = byteData.buffer.asUint8List();
    final lists = await Isolate.run(() => _compute(bytes));
    return HistogramResult(
      luminance: lists[0],
      red:       lists[1],
      green:     lists[2],
      blue:      lists[3],
    );
  }

  static List<List<int>> _compute(Uint8List bytes) {
    final lum  = List<int>.filled(256, 0);
    final red  = List<int>.filled(256, 0);
    final grn  = List<int>.filled(256, 0);
    final blu  = List<int>.filled(256, 0);

    for (int i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      // Rec.709 perceptual luminance
      final l = (0.2126 * r + 0.7152 * g + 0.0722 * b).round().clamp(0, 255);
      lum[l]++;
      red[r]++;
      grn[g]++;
      blu[b]++;
    }
    return [lum, red, grn, blu];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Analysis layer
// ─────────────────────────────────────────────────────────────────────────────

class HistogramAnalyzer {
  const HistogramAnalyzer._();

  /// Returns true if the image is likely underexposed.
  /// Criterion: shadow mass > 60% of total pixels.
  static bool isUnderexposed(HistogramResult r) => r.shadowMass > 0.60;

  /// Returns true if the image is likely overexposed.
  /// Criterion: highlight mass > 50% OR clip mass > 1%.
  static bool isOverexposed(HistogramResult r) =>
      r.highlightMass > 0.50 || r.clipMass > 0.01;

  /// Returns true if significant highlight clipping is occurring.
  static bool isClipping(HistogramResult r) => r.clipMass > 0.005;

  /// Suggests an exposure correction offset based on histogram centring.
  /// Target: bring the median luminance to 0.45–0.55 (slightly below midtone).
  /// Returns a value in –1.0…+1.0 suitable for [ToneParams.exposure].
  static double suggestExposureCorrection(HistogramResult r) {
    const targetMedian = 0.50;
    final delta = targetMedian - r.medianLuminance;
    // Scale: a 0.50 shift in median ≈ 1.0 EV correction
    return (delta * 2.0).clamp(-1.0, 1.0);
  }

  /// Suggests shadow lift. Returns 0.0–0.6.
  static double suggestShadowLift(HistogramResult r) {
    if (!isUnderexposed(r)) return 0.0;
    return ((r.shadowMass - 0.40) * 1.5).clamp(0.0, 0.6);
  }

  /// Suggests highlight compression. Returns 0.0–0.8 as a negative value.
  static double suggestHighlightCompress(HistogramResult r) {
    if (!isOverexposed(r)) return 0.0;
    final excess = (r.highlightMass - 0.30).clamp(0.0, 0.4);
    return -(excess * 2.0).clamp(0.0, 0.8);
  }
}
