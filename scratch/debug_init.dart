import 'dart:convert';
import 'dart:io';

class LayerData {
  const LayerData({this.imagePath, this.text});
  final String? imagePath;
  final String? text;
  LayerData copyWith({String? imagePath, String? text}) => LayerData(
    imagePath: imagePath ?? this.imagePath,
    text: text ?? this.text,
  );
  @override
  String toString() => "Layer(img: $imagePath, txt: $text)";
}

class TemplateLayer {
  final String id;
  final String type;
  TemplateLayer(this.id, this.type);
}

void main() {
  final templatesStr = File('assets/templates.json').readAsStringSync();
  final data = jsonDecode(templatesStr);
  final dynamic firstTemplate = (data['templates'] as List).first;
  
  final List<TemplateLayer> layers = (firstTemplate['layers'] as List).map((l) => TemplateLayer(l['id'], l['type'])).toList();
  
  Map<String, String> existingSlots = {"s1": "path/to/img1.jpg", "s2": "path/to/img2.jpg"};
  
  final updatedLayers = <String, LayerData>{};
  
  final imageSlots = existingSlots.entries.where((e) => !e.key.endsWith('_txt')).toList();
  final textSlots = existingSlots.entries.where((e) => e.key.endsWith('_txt')).toList();

  for (final entry in textSlots) {
    final rawId = entry.key.replaceAll('_txt', '');
    updatedLayers[rawId] = (updatedLayers[rawId] ?? const LayerData()).copyWith(text: entry.value);
  }

  int legacyIdx = 0;
  final imageTemplateLayers = layers.where((l) => l.type == 'image').toList();

  for (final entry in imageSlots) {
    if (layers.any((l) => l.id == entry.key)) {
      updatedLayers[entry.key] = (updatedLayers[entry.key] ?? const LayerData()).copyWith(imagePath: entry.value);
    } else {
      if (legacyIdx < imageTemplateLayers.length) {
        final fallbackId = imageTemplateLayers[legacyIdx].id;
        updatedLayers[fallbackId] = (updatedLayers[fallbackId] ?? const LayerData()).copyWith(imagePath: entry.value);
        legacyIdx++;
      }
    }
  }
  
  print("Updated Layers: $updatedLayers");
}
