/// Generates 30 UNIQUE, visually distinct templates into assets/templates.json
/// Each template has a different layout concept, composition, and visual style.
import 'dart:convert';
import 'dart:io';

int _uid = 0;
String _id() => 'l${++_uid}';

// Image layer helper
Map<String, dynamic> img(double x, double y, double w, double h, {
  double r = 0.0, double op = 1.0, int br = 0, int z = 0,
}) => {
  'id': _id(), 'type': 'image',
  'x': x, 'y': y, 'width': w, 'height': h,
  'rotation': r, 'opacity': op, 'borderRadius': br, 'zIndex': z,
};

// Text layer helper
Map<String, dynamic> txt(double x, double y, double w, double h, String text, {
  double r = 0.0, double fs = 22.0, int color = 0xFFFFFFFF,
}) => {
  'id': _id(), 'type': 'text',
  'x': x, 'y': y, 'width': w, 'height': h,
  'rotation': r, 'opacity': 1.0, 'borderRadius': 0, 'zIndex': 10,
  'text': text, 'fontSize': fs, 'color': color,
};

// Template helper
Map<String, dynamic> t(
  String id, String name, String cat, int frames, String ar, String bg,
  List<Map<String, dynamic>> layers,
) => {
  'id': id, 'name': name, 'category': cat,
  'frames': frames, 'aspect_ratio': ar, 'background': bg, 'layers': layers,
};

void main() {
  _uid = 0;

  final templates = <Map<String, dynamic>>[

    // ── MINIMAL ───────────────────────────────────────────────────────────────

    // 1. Broken Grid — unequal 5-slot layout, sharp corners, white
    t('t01_broken_grid', 'Broken Grid', 'Minimal', 1, '4:5', '#FFFFFF', [
      img(0.03, 0.04, 0.44, 0.62),             // tall left hero
      img(0.51, 0.04, 0.46, 0.28),             // wide top-right
      img(0.51, 0.36, 0.22, 0.30),             // small mid-right
      img(0.75, 0.36, 0.22, 0.30),             // tiny far-right
      img(0.03, 0.70, 0.94, 0.26),             // full-width bottom strip
    ]),

    // 2. Pure Minimal — single centred image, vast whitespace
    t('t02_pure_minimal', 'Pure Minimal', 'Minimal', 1, '1:1', '#FFFFFF', [
      img(0.10, 0.10, 0.80, 0.80),
    ]),

    // 3. Asymmetric Grid — 6 unequal slots, 2-column imbalance
    t('t03_asym_grid', 'Asymmetric Grid', 'Minimal', 1, '4:5', '#F5F5F5', [
      img(0.02, 0.02, 0.60, 0.45),             // hero landscape
      img(0.64, 0.02, 0.34, 0.45),             // narrow right portrait
      img(0.02, 0.50, 0.28, 0.48),             // small left
      img(0.33, 0.50, 0.28, 0.22),             // tiny top-center
      img(0.33, 0.75, 0.28, 0.23),             // tiny bottom-center
      img(0.64, 0.50, 0.34, 0.48),             // right tall
    ]),

    // 4. Shadow Depth — 3 overlapping dark panels
    t('t04_shadow_depth', 'Shadow Depth', 'Minimal', 1, '4:5', '#2C2C3E', [
      img(0.04, 0.06, 0.60, 0.52, br: 12, z: 1),
      img(0.60, 0.14, 0.36, 0.40, br: 12, z: 0),
      img(0.04, 0.62, 0.92, 0.32, br: 12, z: 2),
    ]),

    // 5. Gradient Focus — top bleed + two rounded bottom tiles on dark
    t('t05_gradient_focus', 'Gradient Focus', 'Minimal', 1, '9:16', '#0F0F1A', [
      img(0.00, 0.00, 1.00, 0.58),             // full-bleed top
      img(0.03, 0.63, 0.44, 0.32, br: 24),    // round bottom-left
      img(0.53, 0.66, 0.44, 0.28, br: 24),    // round bottom-right
    ]),

    // 6. Center Focus — single image with strong negative space
    t('t06_center_focus', 'Center Focus', 'Minimal', 1, '4:5', '#F9F9F9', [
      img(0.12, 0.18, 0.76, 0.64, br: 4),
    ]),

    // ── AESTHETIC ─────────────────────────────────────────────────────────────

    // 7. Overlapping Collage — 4 images stacked with rotation
    t('t07_overlap_collage', 'Overlapping Collage', 'Aesthetic', 1, '9:16', '#F7F2E7', [
      img(0.05, 0.08, 0.65, 0.52, r: -0.05, z: 0),
      img(0.22, 0.38, 0.60, 0.44, r:  0.07, z: 1),
      img(0.55, 0.05, 0.38, 0.28, r: -0.10, z: 2),
      img(0.03, 0.52, 0.20, 0.20, r:  0.12, z: 3),
    ]),

    // 8. Pinterest Board — 6 varied-height tiles across 2 frames
    t('t08_pinterest_board', 'Pinterest Board', 'Aesthetic', 2, '4:5', '#FDFAF5', [
      img(0.01, 0.02, 0.16, 0.96, br: 6),     // frame1: tall skinny strip
      img(0.19, 0.02, 0.29, 0.55, br: 6),     // frame1: medium portrait
      img(0.19, 0.60, 0.29, 0.38, br: 6),     // frame1: short landscape
      img(0.51, 0.02, 0.46, 0.35, br: 6),     // frame2: wide landscape
      img(0.51, 0.40, 0.22, 0.58, br: 6),     // frame2: tall left
      img(0.76, 0.40, 0.22, 0.58, br: 6),     // frame2: tall right
    ]),

    // 9. Polaroid Stack — 3 rotating overlapping polaroid frames
    t('t09_polaroid_stack', 'Polaroid Stack', 'Aesthetic', 1, '4:5', '#E8E0D5', [
      img(0.08, 0.12, 0.65, 0.62, r:  0.20, br: 2, z: 0),
      img(0.15, 0.08, 0.65, 0.62, r: -0.10, br: 2, z: 1),
      img(0.22, 0.15, 0.65, 0.62, r:  0.04, br: 2, z: 2),
    ]),

    // 10. Scrapbook — 5 irregularly rotated mixed-size images
    t('t10_scrapbook', 'Scrapbook', 'Aesthetic', 1, '4:5', '#FFF8F2', [
      img(0.03, 0.05, 0.42, 0.50, r: -0.12),
      img(0.50, 0.08, 0.45, 0.30, r:  0.06),
      img(0.28, 0.42, 0.28, 0.28, r:  0.18),
      img(0.02, 0.65, 0.58, 0.28, r: -0.04),
      img(0.64, 0.42, 0.32, 0.32, r:  0.10),
    ]),

    // 11. Floating Elements — small tiles scattered on warm paper
    t('t11_floating_elements', 'Floating Elements', 'Aesthetic', 1, '9:16', '#FDF6E3', [
      img(0.08, 0.08, 0.62, 0.48, br: 8),
      img(0.65, 0.04, 0.30, 0.22, br: 8),
      img(0.02, 0.55, 0.24, 0.18, br: 8),
      img(0.70, 0.60, 0.26, 0.20, br: 8),
      img(0.01, 0.07, 0.14, 0.10, br: 8),
    ]),

    // 12. Chaotic Collage — 6 wildly rotated overlapping images, 1:1
    t('t12_chaotic_collage', 'Chaotic Collage', 'Aesthetic', 1, '1:1', '#FFFEF0', [
      img(0.05, 0.05, 0.44, 0.30, r: -0.15),
      img(0.50, 0.02, 0.42, 0.35, r:  0.20),
      img(0.02, 0.38, 0.30, 0.32, r:  0.10),
      img(0.34, 0.40, 0.38, 0.24, r: -0.12),
      img(0.14, 0.65, 0.46, 0.30, r:  0.08),
      img(0.60, 0.58, 0.35, 0.38, r: -0.10),
    ]),

    // ── CAROUSEL ──────────────────────────────────────────────────────────────

    // 13. Full Bleed Carousel — 3 perfectly full frames, edge-to-edge
    t('t13_full_bleed', 'Full Bleed Swipe', 'Carousel', 3, '4:5', '#000000', [
      img(0.000, 0.00, 0.333, 1.00),
      img(0.334, 0.00, 0.333, 1.00),
      img(0.667, 0.00, 0.333, 1.00),
    ]),

    // 14. Film Strip — 4 narrow slots in a dark strip, 1:1
    t('t14_film_strip', 'Film Strip', 'Carousel', 4, '1:1', '#111111', [
      img(0.005, 0.08, 0.240, 0.84),
      img(0.255, 0.08, 0.240, 0.84),
      img(0.505, 0.08, 0.240, 0.84),
      img(0.755, 0.08, 0.240, 0.84),
    ]),

    // 15. Story Sequence — 3 frames each with different composition
    t('t15_story_sequence', 'Story Sequence', 'Carousel', 3, '9:16', '#0A0A0A', [
      img(0.000, 0.05, 0.333, 0.60),           // frame1: tall hero
      img(0.000, 0.68, 0.333, 0.27),           // frame1: caption strip
      img(0.333, 0.00, 0.334, 0.50),           // frame2: top half
      img(0.333, 0.50, 0.334, 0.50),           // frame2: bottom half
      img(0.667, 0.00, 0.333, 1.00),           // frame3: single bleed
    ]),

    // 16. Widescreen Cinema — 5 frames, feel of a filmstrip panorama
    t('t16_widescreen', 'Widescreen Cinema', 'Carousel', 5, '4:5', '#1A1A1A', [
      img(0.00, 0.00, 0.20, 1.00),
      img(0.20, 0.00, 0.20, 1.00),
      img(0.40, 0.00, 0.20, 1.00),
      img(0.60, 0.00, 0.20, 1.00),
      img(0.80, 0.00, 0.20, 1.00),
    ]),

    // 17. Vertical Journey — 3 frames, increasing number of slots
    t('t17_vertical_journey', 'Vertical Journey', 'Carousel', 3, '9:16', '#FAFAFA', [
      img(0.000, 0.04, 0.333, 0.92, br: 12),   // frame1: single portrait
      img(0.334, 0.04, 0.333, 0.44, br: 12),   // frame2: top slot
      img(0.334, 0.52, 0.333, 0.44, br: 12),   // frame2: bottom slot
      img(0.667, 0.04, 0.333, 0.28, br: 8),    // frame3: top third
      img(0.667, 0.36, 0.333, 0.28, br: 8),    // frame3: mid third
      img(0.667, 0.68, 0.333, 0.28, br: 8),    // frame3: bottom third
    ]),

    // 18. Horizontal Flow — 4 frames with mixed internal compositions
    t('t18_horizontal_flow', 'Horizontal Flow', 'Carousel', 4, '4:5', '#0D0D0D', [
      img(0.000, 0.00, 0.250, 1.00),           // frame1: full portrait
      img(0.250, 0.00, 0.250, 0.50),           // frame2: top half
      img(0.250, 0.50, 0.250, 0.50),           // frame2: bottom half
      img(0.502, 0.04, 0.240, 0.92, br: 8),   // frame3: inset portrait
      img(0.750, 0.00, 0.125, 1.00),           // frame4: left thin strip
      img(0.875, 0.00, 0.125, 0.50),           // frame4: right top
      img(0.875, 0.50, 0.125, 0.50),           // frame4: right bottom
    ]),

    // ── CREATOR ───────────────────────────────────────────────────────────────

    // 19. Magazine Cover — full bleed hero + 2 small bottom tiles + text
    t('t19_magazine_cover', 'Magazine Cover', 'Creator', 1, '9:16', '#0D0D0D', [
      img(0.00, 0.00, 1.00, 0.72),             // bleed hero
      img(0.04, 0.76, 0.44, 0.14, br: 4),
      img(0.52, 0.76, 0.44, 0.14, br: 4),
      txt(0.05, 0.730, 0.90, 0.06, 'YOUR STORY', fs: 24.0),
    ]),

    // 20. Text Dominant — 1 image + text overlay focus
    t('t20_text_dominant', 'Text Dominant', 'Creator', 1, '9:16', '#FFFFFF', [
      img(0.20, 0.04, 0.60, 0.36, br: 4),
      txt(0.05, 0.44, 0.90, 0.10, 'ADD YOUR TITLE', fs: 28.0, color: 0xFF111111),
      txt(0.08, 0.57, 0.84, 0.06, 'Your caption goes here', fs: 18.0, color: 0xFF555555),
      img(0.06, 0.68, 0.38, 0.26, br: 4),
      img(0.56, 0.68, 0.38, 0.26, br: 4),
    ]),

    // 21. Cutout Style — full-bleed top + two rounded lower tiles
    t('t21_cutout_style', 'Cutout Style', 'Creator', 1, '4:5', '#EDE8DE', [
      img(0.00, 0.00, 1.00, 0.62),
      img(0.03, 0.66, 0.44, 0.30, br: 32),
      img(0.53, 0.66, 0.44, 0.30, br: 32),
    ]),

    // 22. Luxury Black — hero + text on deep black
    t('t22_luxury_black', 'Luxury Black', 'Creator', 1, '9:16', '#0C0C0C', [
      img(0.06, 0.12, 0.88, 0.58, br: 2),
      txt(0.15, 0.76, 0.70, 0.07, 'LUXURY', fs: 34.0),
      txt(0.20, 0.85, 0.60, 0.05, 'Editorial Collection', fs: 16.0),
    ]),

    // 23. Before & After — two equal halves side by side
    t('t23_before_after', 'Before & After', 'Creator', 2, '1:1', '#FFFFFF', [
      img(0.01, 0.01, 0.48, 0.98),
      img(0.51, 0.01, 0.48, 0.98),
    ]),

    // 24. Gradient Story — single image with text strip at base
    t('t24_gradient_story', 'Gradient Story', 'Creator', 1, '9:16', '#18181B', [
      img(0.00, 0.00, 1.00, 0.80),
      txt(0.06, 0.83, 0.88, 0.09, 'TAP TO EDIT CAPTION', fs: 20.0),
    ]),

    // ── CREATIVE ──────────────────────────────────────────────────────────────

    // 25. Diagonal Drift — 2 large images slightly rotated to cross boundary
    t('t25_diagonal_drift', 'Diagonal Drift', 'Creative', 2, '4:5', '#1A1A1A', [
      img(0.00, 0.05, 0.54, 0.90, r: -0.05, z: 0),
      img(0.46, 0.05, 0.54, 0.90, r:  0.03, z: 1),
    ]),

    // 26. Circular Gallery — 3 fully rounded circles on light bg
    t('t26_circular_gallery', 'Circular Gallery', 'Creative', 1, '1:1', '#F7F7F7', [
      img(0.04, 0.04, 0.42, 0.42, br: 999),
      img(0.54, 0.04, 0.42, 0.42, br: 999),
      img(0.29, 0.54, 0.42, 0.42, br: 999),
    ]),

    // 27. Layered Cards — 4 overlapping rounded cards with depth
    t('t27_layered_cards', 'Layered Cards', 'Creative', 1, '9:16', '#1C1C2E', [
      img(0.12, 0.05, 0.72, 0.42, br: 20, z: 0),
      img(0.07, 0.13, 0.72, 0.42, br: 20, z: 1),
      img(0.02, 0.21, 0.72, 0.42, br: 20, z: 2),
      img(0.05, 0.66, 0.90, 0.30, br: 20, z: 0),
    ]),

    // 28. Parallax Layers — 3 images at different depths
    t('t28_parallax', 'Parallax Layers', 'Creative', 1, '4:5', '#1A1A2E', [
      img(0.00, 0.00, 1.00, 0.68, z: 0),      // far: full-width bg
      img(0.08, 0.30, 0.52, 0.46, br: 8, z: 1), // mid layer
      img(0.52, 0.48, 0.44, 0.40, br: 16, z: 2), // near layer
    ]),

    // ── ADVANCED ──────────────────────────────────────────────────────────────

    // 29. Zoom Illusion — 3 frames with increasingly larger crops
    t('t29_zoom_illusion', 'Zoom Illusion', 'Advanced', 3, '1:1', '#111111', [
      img(0.04, 0.20, 0.26, 0.60),            // frame1: narrow strip
      img(0.36, 0.12, 0.28, 0.76),            // frame2: medium
      img(0.68, 0.04, 0.30, 0.92),            // frame3: large
    ]),

    // 30. Abstract Art — 3 elements with strong rotation on vivid bg
    t('t30_abstract_art', 'Abstract Art', 'Advanced', 1, '9:16', '#2D1B69', [
      img(0.00, 0.12, 0.78, 0.55, r: -0.15, z: 0),
      img(0.72, 0.00, 0.28, 0.45, z: 1),
      img(0.05, 0.72, 0.55, 0.24, r:  0.08, z: 2),
    ]),
  ];

  // Make sure we have exactly 30
  assert(templates.length == 30, 'Expected 30 templates, got ${templates.length}');

  final out = {
    'categories': ['Minimal', 'Aesthetic', 'Carousel', 'Creator', 'Creative', 'Advanced'],
    'templates': templates,
  };

  final file = File('assets/templates.json');
  file.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));

  print('✅ Generated ${templates.length} templates into assets/templates.json');

  // Print a quick summary
  final byCategory = <String, int>{};
  for (final tp in templates) {
    final c = tp['category'] as String;
    byCategory[c] = (byCategory[c] ?? 0) + 1;
  }
  byCategory.forEach((k, v) => print('  $k: $v templates'));
}
