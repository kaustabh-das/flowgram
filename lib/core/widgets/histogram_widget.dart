/// Premium live histogram widget with RGB channel overlays,
/// zone-gradient background, median luminance marker, and clip indicator.
library;

import 'package:flutter/material.dart';
import '../engine/histogram.dart';

class HistogramWidget extends StatelessWidget {
  const HistogramWidget({
    super.key,
    required this.result,
    this.height = 52,
    this.showChannels = true,
  });

  final HistogramResult? result;
  final double height;

  /// When true, paints translucent R/G/B channel overlays in addition
  /// to the luminance bars. Disable for a cleaner minimal look.
  final bool showChannels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _HistogramPainter(result, showChannels: showChannels),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter(this.result, {required this.showChannels});

  final HistogramResult? result;
  final bool showChannels;

  // Zone boundary fractions (in 0–255 space)
  static const _shadowEnd    = 76.0 / 255.0;
  static const _highlightStart = 178.0 / 255.0;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    final r = result;
    if (r == null) {
      _drawPlaceholder(canvas, size);
      return;
    }
    if (showChannels) _drawChannels(canvas, size, r);
    _drawLuminance(canvas, size, r);
    _drawMedianMarker(canvas, size, r);
    _drawZoneSeparators(canvas, size);
    if (HistogramAnalyzer.isClipping(r)) _drawClipIndicator(canvas, size);
  }

  // ── Background with zone gradient ───────────────────────────────────────
  void _drawBackground(Canvas canvas, Size size) {
    // Zone-coloured gradient: shadow (deep blue) → mid (dark) → highlight (warm amber)
    final grad = LinearGradient(colors: const [
      Color(0xFF0D1B40),
      Color(0xFF18122A),
      Color(0xFF2A1A10),
    ]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = grad,
    );
  }

  // ── Placeholder skeleton when no result yet ──────────────────────────────
  void _drawPlaceholder(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x18FFFFFF);
    const barCount = 8;
    final bw = size.width / barCount;
    final heights = [0.2, 0.5, 0.7, 0.9, 0.8, 0.6, 0.3, 0.15];
    for (int i = 0; i < barCount; i++) {
      final h = heights[i] * size.height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * bw + 2, size.height - h, bw - 4, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  // ── RGB channel overlays ─────────────────────────────────────────────────
  void _drawChannels(Canvas canvas, Size size, HistogramResult r) {
    final barW = size.width / 256;
    for (int i = 0; i < 256; i++) {
      final x = i * barW;

      // Red channel
      final rH = r.normalisedR(i) * size.height;
      if (rH > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - rH, barW + 0.3, rH),
          Paint()..color = const Color(0x40FF4444),
        );
      }
      // Green channel
      final gH = r.normalisedG(i) * size.height;
      if (gH > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - gH, barW + 0.3, gH),
          Paint()..color = const Color(0x3844DD77),
        );
      }
      // Blue channel
      final bH = r.normalisedB(i) * size.height;
      if (bH > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - bH, barW + 0.3, bH),
          Paint()..color = const Color(0x404488FF),
        );
      }
    }
  }

  // ── Luminance bars ───────────────────────────────────────────────────────
  void _drawLuminance(Canvas canvas, Size size, HistogramResult r) {
    final barW = size.width / 256;
    for (int i = 0; i < 256; i++) {
      final norm = r.normalisedL(i);
      if (norm < 0.002) continue;

      final barH = norm * size.height;
      final x = i * barW;
      final t = i / 255.0;

      // Colour: shadows=blue-purple, mids=purple-pink, highlights=pink-gold
      final Color color;
      if (t < _shadowEnd) {
        final zt = t / _shadowEnd;
        color = Color.lerp(const Color(0xFF3066FF), const Color(0xFF9B5DE5), zt)!
            .withAlpha(210);
      } else if (t < _highlightStart) {
        final zt = (t - _shadowEnd) / (_highlightStart - _shadowEnd);
        color = Color.lerp(const Color(0xFF9B5DE5), const Color(0xFFE040FB), zt)!
            .withAlpha(200);
      } else {
        final zt = (t - _highlightStart) / (1.0 - _highlightStart);
        color = Color.lerp(const Color(0xFFE040FB), const Color(0xFFFFD740), zt)!
            .withAlpha(210);
      }

      canvas.drawRect(
        Rect.fromLTWH(x, size.height - barH, barW + 0.5, barH),
        Paint()..color = color,
      );
    }
  }

  // ── Median luminance marker ──────────────────────────────────────────────
  void _drawMedianMarker(Canvas canvas, Size size, HistogramResult r) {
    final x = r.medianLuminance * size.width;
    final paint = Paint()
      ..color = Colors.white.withAlpha(90)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

    // Small label dot
    canvas.drawCircle(Offset(x, 4), 2.5, Paint()..color = Colors.white.withAlpha(140));
  }

  // ── Zone separator lines ─────────────────────────────────────────────────
  void _drawZoneSeparators(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(20)
      ..strokeWidth = 0.75;
    canvas.drawLine(
      Offset(size.width * _shadowEnd,      0),
      Offset(size.width * _shadowEnd,      size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * _highlightStart, 0),
      Offset(size.width * _highlightStart, size.height),
      paint,
    );
  }

  // ── Clip indicator (red flash on far right) ──────────────────────────────
  void _drawClipIndicator(Canvas canvas, Size size) {
    const w = 8.0;
    final rect = Rect.fromLTWH(size.width - w, 0, w, size.height);
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xCCFF1744),
    );
  }

  @override
  bool shouldRepaint(_HistogramPainter old) =>
      old.result != result || old.showChannels != showChannels;
}
