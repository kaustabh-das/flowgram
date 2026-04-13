import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui' show lerpDouble;
import '../../app/theme/app_colors.dart';

class PrequelSlider extends StatefulWidget {
  const PrequelSlider({
    super.key,
    required this.label,
    required this.value,
    this.min = -1.0,
    this.max = 1.0,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeStart;
  final VoidCallback onChangeEnd;

  @override
  State<PrequelSlider> createState() => _PrequelSliderState();
}

class _PrequelSliderState extends State<PrequelSlider> with SingleTickerProviderStateMixin {
  static const double _rulerWidth = 1200.0;
  
  late Ticker _ticker;
  Simulation? _simulation;
  
  // Real logical position driven by finger or momentum
  double _pixelPos = 0.0;
  
  // Smooth rendered position 
  double _renderPixelPos = 0.0;
  
  // Track velocity internally for smooth LERP prediction
  double _velocity = 0.0;
  double _lastDragPixelPos = 0.0;
  Duration? _lastDragTime;
  
  bool _isDragging = false;
  DateTime _lastBroadcast = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pixelPos = _valueToPixels(widget.value);
    _renderPixelPos = _pixelPos;
    
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(PrequelSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && _simulation == null) {
      _pixelPos = _valueToPixels(widget.value);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _valueToPixels(double val) {
    final t = (val - widget.min) / (widget.max - widget.min);
    return t * _rulerWidth;
  }

  double _pixelsToValue(double pixels) {
    final t = pixels / _rulerWidth;
    return widget.min + t * (widget.max - widget.min);
  }

  void _onTick(Duration elapsed) {
    bool didUpdate = false;

    if (_simulation != null) {
      // Simulate Momentum / Spring
      final double elapsedTime = elapsed.inMicroseconds / 1000000.0;
      _pixelPos = _simulation!.x(elapsedTime);
      _velocity = _simulation!.dx(elapsedTime);
      _renderPixelPos = _pixelPos; // attach tightly during momentum
      didUpdate = true;

      if (_simulation!.isDone(elapsedTime)) {
        _simulation = null;
        _pixelPos = _pixelPos.clamp(0.0, _rulerWidth);
      }
    } else if (_isDragging) {
      // High-Frequency LERP to smooth micro-jitters during slow drags
      if ((_renderPixelPos - _pixelPos).abs() > 0.01) {
         _renderPixelPos = lerpDouble(_renderPixelPos, _pixelPos, 0.4) ?? _pixelPos;
         didUpdate = true;
      }
    } else if ((_renderPixelPos - _pixelPos).abs() > 0.01) {
      // Close any remaining gaps softly
      _renderPixelPos = lerpDouble(_renderPixelPos, _pixelPos, 0.3) ?? _pixelPos;
      didUpdate = true;
    }

    if (didUpdate) {
      _dispatchValueChange();
      setState(() {});
    }
  }

  void _dispatchValueChange() {
    double newVal = _pixelsToValue(_renderPixelPos);
    
    // Soft snap near zero if settled or slow
    if (widget.min < 0 && widget.max > 0 && newVal.abs() < 0.02) {
       if (_simulation == null || _velocity.abs() < 100) {
         newVal = 0.0;
       }
    }

    final double clampedVal = newVal.clamp(widget.min, widget.max);

    // Throttle GPU events during high velocity to ensure 120Hz frame budget
    final now = DateTime.now();
    if (_simulation != null && _velocity.abs() > 800) {
      if (now.difference(_lastBroadcast).inMilliseconds < 16) {
        return; 
      }
    }
    
    _lastBroadcast = now;
    widget.onChanged(clampedVal);
  }

  void _handleDragStart(DragStartDetails details) {
    _simulation = null; // stop physics
    _isDragging = true;
    _lastDragPixelPos = _pixelPos;
    _lastDragTime = null; // reset
    widget.onChangeStart();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    double delta = -details.delta.dx; // dragging right moves ruler right -> value drops
    
    // Non-linear boundary resistance (rubberband spring layer)
    if (_pixelPos < 0 || _pixelPos > _rulerWidth) {
      delta *= 0.35; 
    }
    
    _pixelPos += delta;
    
    // Estimate velocity manually across drag updates for clean handoff
    if (_lastDragTime != null) {
      final elapsed = details.sourceTimeStamp! - _lastDragTime!;
      if (elapsed.inMilliseconds > 0) {
        final currentVel = (_pixelPos - _lastDragPixelPos) / (elapsed.inMicroseconds / 1000000.0);
        // Weighted average velocity smoothing
        _velocity = _velocity * 0.5 + currentVel * 0.5; 
      }
    }
    
    _lastDragPixelPos = _pixelPos;
    _lastDragTime = details.sourceTimeStamp;
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    widget.onChangeEnd();
    
    // Prioritize Flutter's extremely robust multi-event velocity regression, fallback to our manual tracked velocity
    double finalVelocity = -details.velocity.pixelsPerSecond.dx;
    if (finalVelocity.abs() < 10) finalVelocity = _velocity; 

    // BouncingScrollSimulation natively handles exactly iOS-like friction & boundary spring physics
    _simulation = BouncingScrollSimulation(
      position: _pixelPos,
      velocity: finalVelocity,
      leadingExtent: 0,
      trailingExtent: _rulerWidth,
      spring: const SpringDescription(
        mass: 1.0,
        stiffness: 400.0,
        damping: 30.0,
      ),
      constantDeceleration: 0.0,
    );
    
    // Reset ticker time to zero for the simulation
    _ticker.stop();
    _ticker.start();
  }

  void _handleTap(TapUpDetails details, double width) {
    _simulation = null;
    final double center = width / 2;
    final double tapOffsetDx = details.localPosition.dx - center;
    _pixelPos += tapOffsetDx; 
    _pixelPos = _pixelPos.clamp(0.0, _rulerWidth);
    
    widget.onChangeEnd();
  }

  @override
  Widget build(BuildContext context) {
    final logicalVal = _pixelsToValue(_renderPixelPos).clamp(widget.min, widget.max);
    final int displayValue = (logicalVal * 100).round();
    final bool isNeutral = displayValue == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (Label and Value)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                isNeutral ? '0' : '${displayValue > 0 ? '+' : ''}$displayValue',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Interactive Tracker Area
          SizedBox(
            height: 32,
            child: LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                onHorizontalDragCancel: () => widget.onChangeEnd(),
                onTapDown: (_) => widget.onChangeStart(),
                onTapUp: (details) => _handleTap(details, constraints.maxWidth),
                onTapCancel: () => widget.onChangeEnd(),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 32),
                    painter: _RulerPainter(
                      min: widget.min,
                      max: widget.max,
                      pixelPos: _renderPixelPos,
                      rulerWidth: _rulerWidth,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.min,
    required this.max,
    required this.pixelPos,
    required this.rulerWidth,
  });

  final double min;
  final double max;
  final double pixelPos;
  final double rulerWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Unclamped offset to allow visual overscroll bouncing
    final t = pixelPos / rulerWidth; 
    final zeroT = (0.0 - min) / (max - min);

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final zeroTickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final centerThumbPaint = Paint()
      ..color = AppColors.accentCyan
      ..style = PaintingStyle.fill;

    const int numTicks = 101; 
    final double step = rulerWidth / (numTicks - 1);

    final double leftOffset = (size.width / 2) - (t * rulerWidth);

    for (int i = 0; i < numTicks; i++) {
      final double x = leftOffset + (i * step);

      if (x < 0 || x > size.width) continue;

      final bool isZero = min < 0 && max > 0 && i == ((numTicks - 1) * zeroT).round();

      double tickHeight = 10.0;
      if (isZero) tickHeight = 18.0;
      else if (i % 5 == 0) tickHeight = 14.0;

      // Soft fade on edges
      final double distFromCenter = (x - (size.width / 2)).abs();
      final double edgeFade = (1.0 - (distFromCenter / (size.width / 2))).clamp(0.0, 1.0);
      
      final currentPaint = isZero ? zeroTickPaint : tickPaint;
      final originalColor = currentPaint.color;
      currentPaint.color = currentPaint.color.withValues(alpha: originalColor.a * edgeFade);

      final yStart = (size.height / 2) - (tickHeight / 2);
      final yEnd = (size.height / 2) + (tickHeight / 2);

      canvas.drawLine(Offset(x, yStart), Offset(x, yEnd), currentPaint);
      
      currentPaint.color = originalColor;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 3, height: 26),
        const Radius.circular(2),
      ),
      centerThumbPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) {
    return oldDelegate.pixelPos != pixelPos ||
           oldDelegate.min != min ||
           oldDelegate.max != max ||
           oldDelegate.rulerWidth != rulerWidth;
  }
}
