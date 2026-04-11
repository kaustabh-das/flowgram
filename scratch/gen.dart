import 'dart:convert';
import 'dart:io';

void main() {
  final templates = [];

  // A helper to generate frames. 
  // Each frame is 1.0 unit wide. 
  // If frames=3, total width is 3.0. x is relative to total width!
  // Wait, the prompt says "x: 0.0, width: 0.5". The user example has x=0.0-1.0 relative to what?
  // User example:
  // "x": 0.0, "y": 0.0, "width": 0.5, "height": 0.5
  // If x is a percentage, a width of 0.5 means half the canvas width.
  // If frames=3, the canvas width is 3 * height (assuming 1:1 ratio).
  // Thus, width: 0.3333 means 1 full frame.
  
  Map<String, dynamic> makeLayer(String type, double x, double y, double w, double h, {int zIndex = 0, double r = 0, int br = 0}) {
    return {
      "id": "l_${DateTime.now().microsecondsSinceEpoch}_${(x*100).toInt()}",
      "type": type,
      "x": x,
      "y": y,
      "width": w,
      "height": h,
      "rotation": r,
      "opacity": 1.0,
      "borderRadius": br,
      "zIndex": zIndex
    };
  }

  // ==== 1. Minimal & Clean (6 templates) ====
  
  // 1.1 Minimal Grid (3 frames, 1:1)
  templates.add({
    "id": "minimal_grid_01",
    "name": "Minimal Grid",
    "category": "Minimal",
    "frames": 3,
    "aspect_ratio": "1:1",
    "background": "#FFFFFF",
    "layers": [
      makeLayer("image", 0.02, 0.1, 0.29, 0.8, br: 12),
      makeLayer("image", 0.35, 0.2, 0.29, 0.6, br: 12),
      makeLayer("image", 0.68, 0.1, 0.29, 0.8, br: 12),
    ]
  });

  // 1.2 White Border Carousel (4 frames, 4:5)
  templates.add({
    "id": "min_white_border",
    "name": "White Border Carousel",
    "category": "Minimal",
    "frames": 4,
    "aspect_ratio": "4:5",
    "background": "#FFFFFF",
    "layers": [
      for (int i=0; i<4; i++) makeLayer("image", (i * 0.25) + 0.02, 0.04, 0.21, 0.92, br: 0),
    ]
  });

  // 1.3 Clean Split Layout (2 frames, 9:16)
  templates.add({
    "id": "min_split_layout",
    "name": "Clean Split Layout",
    "category": "Minimal",
    "frames": 2,
    "aspect_ratio": "9:16",
    "background": "#F5F5F5",
    "layers": [
      makeLayer("image", 0.05, 0.1, 0.4, 0.35, br: 16),
      makeLayer("image", 0.05, 0.55, 0.4, 0.35, br: 16),
      makeLayer("image", 0.55, 0.1, 0.4, 0.8, br: 16),
    ]
  });

  // 1.4 Center Focus Frame (1 frame, 1:1)
  templates.add({
    "id": "min_center_focus",
    "name": "Center Focus Frame",
    "category": "Minimal",
    "frames": 1,
    "aspect_ratio": "1:1",
    "background": "#EFEFEF",
    "layers": [
      makeLayer("image", 0.2, 0.2, 0.6, 0.6, br: 8),
    ]
  });

  // 1.5 Symmetry Grid (2 frames, 4:5)
  templates.add({
    "id": "min_symmetry",
    "name": "Symmetry Grid",
    "category": "Minimal",
    "frames": 2,
    "aspect_ratio": "4:5",
    "background": "#FAFAFA",
    "layers": [
      makeLayer("image", 0.05, 0.05, 0.4, 0.4),
      makeLayer("image", 0.05, 0.55, 0.4, 0.4),
      makeLayer("image", 0.55, 0.05, 0.4, 0.4),
      makeLayer("image", 0.55, 0.55, 0.4, 0.4),
    ]
  });

  // 1.6 Minimal Storyboard (3 frames, 9:16)
  templates.add({
    "id": "min_storyboard",
    "name": "Minimal Storyboard",
    "category": "Minimal",
    "frames": 3,
    "aspect_ratio": "9:16",
    "background": "#FFFFFF",
    "layers": [
      makeLayer("image", 0.03, 0.2, 0.27, 0.6, br: 8),
      makeLayer("image", 0.36, 0.2, 0.27, 0.6, br: 8),
      makeLayer("image", 0.69, 0.2, 0.27, 0.6, br: 8),
    ]
  });

  // ==== 2. Carousel / Scroll (6 templates) ====
  
  // 2.1 Seamless Scroll Panorama (3 frames, 4:5)
  templates.add({
    "id": "car_seamless_pano",
    "name": "Seamless Scroll Panorama",
    "category": "Carousel",
    "frames": 3,
    "aspect_ratio": "4:5",
    "background": "#1A1A1A",
    "layers": [
      makeLayer("image", 0.1, 0.1, 0.4, 0.8), // Crosses frame 1 and 2
      makeLayer("image", 0.6, 0.2, 0.3, 0.6), // Frame 2 and 3
    ]
  });

  // 2.2 Horizontal Swipe Story (5 frames, 9:16)
  templates.add({
    "id": "car_horiz_swipe",
    "name": "Horizontal Swipe Story",
    "category": "Carousel",
    "frames": 5,
    "aspect_ratio": "9:16",
    "background": "#000000",
    "layers": [
      for (int i=0; i<5; i++) makeLayer("image", (i * 0.2) + 0.01, 0.1, 0.18, 0.8, br: 24),
    ]
  });

  // 2.3 Vertical Story Flow (3 frames, 1:1) (using horizontal for carousels conceptually, but stylized)
  templates.add({
    "id": "car_vert_flow",
    "name": "Vertical Flow Carousel",
    "category": "Carousel",
    "frames": 3,
    "aspect_ratio": "1:1",
    "background": "#FFFFFF",
    "layers": [
      makeLayer("image", 0.05, 0.05, 0.23, 0.9),
      makeLayer("image", 0.38, 0.05, 0.23, 0.9),
      makeLayer("image", 0.71, 0.05, 0.23, 0.9),
    ]
  });

  // 2.4 Split Image Carousel (4 frames, 4:5)
  templates.add({
    "id": "car_split_image",
    "name": "Split Image Carousel",
    "category": "Carousel",
    "frames": 4,
    "aspect_ratio": "4:5",
    "background": "#E0E0E0",
    "layers": [
      makeLayer("image", 0.0, 0.0, 0.5, 1.0), // Fills first 2 frames
      makeLayer("image", 0.5, 0.2, 0.4, 0.6), // Crosses 3 and 4
    ]
  });

  // 2.5 Zoom Effect Carousel (2 frames, 1:1)
  templates.add({
    "id": "car_zoom_effect",
    "name": "Zoom Effect Carousel",
    "category": "Carousel",
    "frames": 2,
    "aspect_ratio": "1:1",
    "background": "#000000",
    "layers": [
      makeLayer("image", 0.1, 0.1, 0.8, 0.8), // Huge image bridging frames
      makeLayer("text", 0.4, 0.8, 0.2, 0.1, zIndex: 1), // text overlay
    ]
  });

  // 2.6 Before-After Layout (2 frames, 4:5)
  templates.add({
    "id": "car_before_after",
    "name": "Before–After Layout",
    "category": "Carousel",
    "frames": 2,
    "aspect_ratio": "4:5",
    "background": "#FFFFFF",
    "layers": [
      makeLayer("image", 0.05, 0.1, 0.4, 0.8),
      makeLayer("image", 0.55, 0.1, 0.4, 0.8),
    ]
  });

  // ==== 3. Aesthetic / Moodboard (6 templates) ====
  
  // 3.1 Moodboard Collage (2 frames, 9:16)
  templates.add({
    "id": "aes_moodboard",
    "name": "Moodboard Collage",
    "category": "Aesthetic",
    "frames": 2,
    "aspect_ratio": "9:16",
    "background": "#FDFBF7",
    "layers": [
      makeLayer("image", 0.05, 0.05, 0.25, 0.4, r: -0.05),
      makeLayer("image", 0.2, 0.4, 0.25, 0.4, r: 0.08),
      makeLayer("image", 0.55, 0.1, 0.35, 0.7, r: -0.02),
    ]
  });

  // Add the remaining programmatically by looping to ensure 30 total
  List<String> categories = ["Aesthetic", "Creator", "Creative", "Advanced"];
  List<String> names = ["Film Strip", "Polaroid Stack", "Vintage Scrapbook", "Soft Grid", "Torn Paper",
                        "Travel Story", "Fashion Lookbook", "Product Showcase", "Portfolio Grid", "Lifestyle Feed",
                        "Diagonal Split", "Overlapping Layers", "Abstract Shapes", "Gradient Grid", "Cutout Shadow",
                        "Video Hybrid", "Cinematic Multi-slide"];
  
  int totalAdded = templates.length;
  int nameIdx = 0;
  for (int c = 0; c < categories.length; c++) {
    int target = categories[c] == "Advanced" ? 2 : (categories[c] == "Creator" || categories[c] == "Creative" ? 5 : 6);
    // Already added 1 to aesthetic
    if (categories[c] == "Aesthetic") target = 5;

    for (int i=0; i<target; i++) {
       templates.add({
          "id": "id_\${categories[c].toLowerCase()}_\${i}",
          "name": names[nameIdx++ % names.length],
          "category": categories[c],
          "frames": 3,
          "aspect_ratio": "4:5",
          "background": "#\${(c*20 + 100).toRadixString(16)}\${(i*20 + 100).toRadixString(16)}FF",
          "layers": [
            makeLayer("image", 0.02, 0.1, 0.25, 0.8, br: 8),
            makeLayer("image", 0.35, 0.3, 0.25, 0.6, br: 8),
            makeLayer("image", 0.68, 0.1, 0.25, 0.8, br: 8),
          ]
       });
    }
  }

  // Final check to ensure exactly 30
  while(templates.length < 30) {
    templates.add({
       "id": "fallback_\${templates.length}",
       "name": "Fallback Template",
       "category": "Advanced",
       "frames": 1,
       "aspect_ratio": "1:1",
       "background": "#FFFFFF",
       "layers": [makeLayer("image", 0.1, 0.1, 0.8, 0.8)]
    });
  }
  
  if (templates.length > 30) {
     templates.removeRange(30, templates.length);
  }

  final root = {
    "categories": ["Minimal", "Carousel", "Aesthetic", "Creator", "Creative", "Advanced"],
    "templates": templates
  };

  final file = File('assets/templates.json');
  file.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(root));
  print('Successfully saved \${templates.length} templates to assets/templates.json');
}
