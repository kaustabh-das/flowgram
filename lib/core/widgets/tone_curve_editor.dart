/// Interactive Bezier Tone Curve Editor.
///
/// Renders a luminance-input vs luminance-output curve with 4 draggable
/// control points. Outputs [List<Offset>] deltas via [onCurveChanged].
///
/// Design:
///   • Dark glass background with subtle grid
///   • 45° neutral diagonal (dashed, white 20%)
///   • Purple-to-gold gradient curve line
///   • Shadow (blue) and highlight (gold) zone backgrounds
///   • Gold thumb handles with glow
library;

import 'package:flutter/material.dart';

class ToneCurveEditor extends StatefulWidget {
  const ToneCurveEditor({
    super.key,
    this.initialPoints,
    required this.onCurveChanged,
    this.height = 200,
  });

  /// Initial control point deltas, or null for neutral (straight line).
  final List<Offset>? initialPoints;

  /// Called with the new 4-point delta list on each drag.
  final ValueChanged<List<Offset>> onCurveChanged;

  final double height;

  @override
  State<ToneCurveEditor> createState() => _ToneCurveEditorState();
}

class _ToneCurveEditorState extends State<ToneCurveEditor> {
  // 4 control points anchored at x positions: 0.15, 0.38, 0.62, 0.85
  static const _xAnchors = [0.15, 0.38, 0.62, 0.85];

  // Deltas from the neutral diagonal (dy offsets, negative = darker output).
  late List<double> _deltas;

  @override
  void initState() {
    super.initState();
    final pts = widget.initialPoints;
    if (pts != null && pts.length == 4) {
      _deltas = pts.map((p) => p.dy.clamp(-0.4, 0.4)).toList();
    } else {
      _deltas = [0.0, 0.0, 0.0, 0.0];
    }
  }

  List<Offset> get _points => List.generate(
    4,
    (i) => Offset(_xAnchors[i], _deltas[i]),
  );

  void _onDrag(int index, Offset localPos, Size size) {
    final newDy = ((-(localPos.dy / size.height - (1.0 - _xAnchors[index])))) ;
    final clamped = newDy.clamp(-0.4, 0.4);
    setState(() => _deltas[index] = clamped);
    widget.onCurveChanged(_points);
  }

  void _reset() {
    setState(() => _deltas = [0.0, 0.0, 0.0, 0.0]);
    widget.onCurveChanged(_points);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _reset,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Canvas: grid + neutral diagonal + curve
              Positioned.fill(
                child: CustomPaint(
                  painter: _CurvePainter(_deltas),
                ),
              ),
              // Draggable thumb handles
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (ctx, box) {
                    final size = Size(box.maxWidth, box.maxHeight);
                    return Stack(
                      children: List.generate(4, (i) {
                        final x = _xAnchors[i] * size.width;
                        // Output Y = input Y + delta (in canvas space, y is flipped)
                        final inputY  = (1.0 - _xAnchors[i]) * size.height;
                        final deltaY  = -_deltas[i] * size.height;
                        final y       = inputY + deltaY;
                        return Positioned(
                          left: x - 12,
                          top:  y - 12,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (d) => _onDrag(i, Offset(x, y + d.delta.dy), size),
                            child: _ThumbHandle(index: i, delta: _deltas[i]),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              // Reset hint
              Positioned(
                top: 6, right: 10,
                child: Text(
                  'double-tap to reset',
                  style: TextStyle(
                    color: Colors.white.withAlpha(35),
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Zone labels
              Positioned(
                bottom: 6, left: 10,
                child: Text('SHADOWS', style: TextStyle(color: const Color(0xFF6688FF).withAlpha(100), fontSize: 8, letterSpacing: 0.8)),
              ),
              Positioned(
                bottom: 6, right: 10,
                child: Text('HIGHLIGHTS', style: TextStyle(color: const Color(0xFFFFCC44).withAlpha(100), fontSize: 8, letterSpacing: 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Thumb Handle widget ────────────────────────────────────────────────────────

class _ThumbHandle extends StatelessWidget {
  const _ThumbHandle({required this.index, required this.delta});
  final int index;
  final double delta;

  @override
  Widget build(BuildContext context) {
    const size = 24.0;
    final isActive = delta.abs() > 0.02;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isActive
              ? [const Color(0xFFFFD740), const Color(0xFF9B5DE5)]
              : [Colors.white.withAlpha(180), Colors.white.withAlpha(60)],
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD740).withAlpha(120),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
    );
  }
}

// ── Curve Painter ──────────────────────────────────────────────────────────────

class _CurvePainter extends CustomPainter {
  const _CurvePainter(this.deltas);
  final List<double> deltas;

  static const _xAnchors = [0.15, 0.38, 0.62, 0.85];

  @override
  void paint(Canvas canvas, Size sz) {
    _drawZoneBackground(canvas, sz);
    _drawGrid(canvas, sz);
    _drawNeutralDiagonal(canvas, sz);
    _drawCurve(canvas, sz);
  }

  // Zone tinted background
  void _drawZoneBackground(Canvas canvas, Size sz) {
    // Shadow zone (left 30%)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, sz.width * 0.30, sz.height),
      Paint()..color = const Color(0x0C3066FF),
    );
    // Highlight zone (right 30%)
    canvas.drawRect(
      Rect.fromLTWH(sz.width * 0.70, 0, sz.width * 0.30, sz.height),
      Paint()..color = const Color(0x0CFFD740),
    );
  }

  // Subtle grid
  void _drawGrid(Canvas canvas, Size sz) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(10)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      final x = sz.width  * i / 4;
      final y = sz.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, sz.height), paint);
      canvas.drawLine(Offset(0, y), Offset(sz.width, y), paint);
    }
  }

  // 45° neutral reference line (dashed)
  void _drawNeutralDiagonal(Canvas canvas, Size sz) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(30)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    // Simple dashed line via path
    final path = Path();
    const dashLen = 6.0, gapLen = 4.0;
    double dist = 0;
    final total = sz.width;
    bool drawing = true;
    while (dist < total) {
      final p1 = Offset(dist, sz.height - dist * sz.height / sz.width);
      final p2 = Offset(
        (dist + (drawing ? dashLen : gapLen)).clamp(0, total),
        sz.height - (dist + (drawing ? dashLen : gapLen)).clamp(0, total) * sz.height / sz.width,
      );
      if (drawing) {
        path.moveTo(p1.dx, p1.dy);
        path.lineTo(p2.dx, p2.dy);
      }
      dist += drawing ? dashLen : gapLen;
      drawing = !drawing;
    }
    canvas.drawPath(path, paint);
  }

  // Smooth Bezier curve through adjusted control points
  void _drawCurve(Canvas canvas, Size sz) {
    // Build 5 points: corners + 4 anchors
    final pts = <Offset>[
      Offset(0, sz.height), // black point (fixed)
      ...List.generate(4, (i) {
        final x    = _xAnchors[i] * sz.width;
        final baseY = (1.0 - _xAnchors[i]) * sz.height;
        final dy   = -deltas[i] * sz.height;
        return Offset(x, baseY + dy);
      }),
      Offset(sz.width, 0), // white point (fixed)
    ];

    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    // Catmull-Rom through all 6 points → smooth natural curve
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[(i - 1).clamp(0, pts.length - 1)];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[(i + 2).clamp(0, pts.length - 1)];
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    // Draw glow under the curve
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x259B5DE5)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Draw gradient curve line
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFF3066FF), Color(0xFF9B5DE5), Color(0xFFE040FB), Color(0xFFFFD740)],
          stops: const [0.0, 0.33, 0.66, 1.0],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(Rect.fromLTWH(0, 0, sz.width, sz.height))
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.deltas != deltas;
}
