import 'dart:convert';
import 'dart:io';

void main() {
  final templates = [];

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
  templates.add({
    "id": "car_seamless_pano",
    "name": "Seamless Scroll Panorama",
    "category": "Carousel",
    "frames": 3,
    "aspect_ratio": "4:5",
    "background": "#1A1A1A",
    "layers": [
      makeLayer("image", 0.1, 0.1, 0.4, 0.8),
      makeLayer("image", 0.6, 0.2, 0.3, 0.6),
    ]
  });

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

  templates.add({
    "id": "car_split_image",
    "name": "Split Image Carousel",
    "category": "Carousel",
    "frames": 4,
    "aspect_ratio": "4:5",
    "background": "#E0E0E0",
    "layers": [
      makeLayer("image", 0.0, 0.0, 0.5, 1.0),
      makeLayer("image", 0.5, 0.2, 0.4, 0.6),
    ]
  });

  templates.add({
    "id": "car_zoom_effect",
    "name": "Zoom Effect Carousel",
    "category": "Carousel",
    "frames": 2,
    "aspect_ratio": "1:1",
    "background": "#000000",
    "layers": [
      makeLayer("image", 0.1, 0.1, 0.8, 0.8),
      makeLayer("text", 0.4, 0.8, 0.2, 0.1, zIndex: 1),
    ]
  });

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


  List<String> categories = ["Aesthetic", "Creator", "Creative", "Advanced"];
  List<String> names = ["Film Strip", "Polaroid Stack", "Vintage Scrapbook", "Soft Grid", "Torn Paper",
                        "Travel Story", "Fashion Lookbook", "Product Showcase", "Portfolio Grid", "Lifestyle Feed",
                        "Diagonal Split", "Overlapping Layers", "Abstract Shapes", "Gradient Grid", "Cutout Shadow",
                        "Video Hybrid", "Cinematic Multi-slide"];
  
  int nameIdx = 0;
  for (int c = 0; c < categories.length; c++) {
    int target = categories[c] == "Advanced" ? 2 : (categories[c] == "Creator" || categories[c] == "Creative" ? 5 : 6);
    if (categories[c] == "Aesthetic") target = 5;

    for (int i=0; i<target; i++) {
       String catName = categories[c].toLowerCase();
       String cid = "id_${catName}_$i";
       
       String rHex = (c*20 + 100).toRadixString(16).padLeft(2, '0');
       String gHex = (i*20 + 100).toRadixString(16).padLeft(2, '0');
       String bg = "#${rHex}${gHex}FF";

       templates.add({
          "id": cid,
          "name": names[nameIdx++ % names.length],
          "category": categories[c],
          "frames": 3,
          "aspect_ratio": "4:5",
          "background": bg,
          "layers": [
            makeLayer("image", 0.02, 0.1, 0.25, 0.8, br: 8),
            makeLayer("image", 0.35, 0.3, 0.25, 0.6, br: 8),
            makeLayer("image", 0.68, 0.1, 0.25, 0.8, br: 8),
          ]
       });
    }
  }

  while(templates.length < 30) {
    templates.add({
       "id": "fallback_${templates.length}",
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
  print('Successfully saved ${templates.length} templates format');
}
