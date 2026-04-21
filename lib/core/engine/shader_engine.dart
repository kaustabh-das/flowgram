import 'dart:ui';
import 'package:flutter/widgets.dart';

class ShaderEngine {
  static FragmentProgram? _program;

  static Future<void> init() async {
    if (_program != null) return;
    try {
      _program = await FragmentProgram.fromAsset('shaders/light_engine.frag');
    } catch (e) {
      debugPrint('Failed to load fragment program: $e');
    }
  }

  static FragmentProgram get program {
    if (_program == null) {
      throw StateError('ShaderEngine not initialized. Call init() first.');
    }
    return _program!;
  }
}
