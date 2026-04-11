import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/collage_layout.dart';

class LayerData {
  const LayerData({
    this.imagePath,
    this.offset = Offset.zero,
    this.scale = 1.0,
    this.isLoading = false,
    this.text,
    this.fontFamily,
    this.color,
  });

  final String? imagePath;
  final Offset offset;
  final double scale;
  final bool isLoading;
  
  final String? text;
  final String? fontFamily;
  final int? color;

  LayerData copyWith({
    String? imagePath,
    Offset? offset,
    double? scale,
    bool? isLoading,
    String? text,
    String? fontFamily,
    int? color,
  }) {
    return LayerData(
      imagePath: imagePath ?? this.imagePath,
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
      isLoading: isLoading ?? this.isLoading,
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      color: color ?? this.color,
    );
  }
}

class StoryEditorState {
  const StoryEditorState({
    this.projectId,
    this.layers = const {},
    this.selectedLayerId,
    this.isDragging = false,
  });

  final Map<String, LayerData> layers;
  final String? projectId;
  final String? selectedLayerId;
  final bool isDragging;

  StoryEditorState copyWith({
    String? projectId,
    Map<String, LayerData>? layers,
    String? selectedLayerId,
    bool? isDragging,
  }) {
    return StoryEditorState(
      projectId: projectId ?? this.projectId,
      layers: layers ?? this.layers,
      selectedLayerId: selectedLayerId ?? this.selectedLayerId,
      isDragging: isDragging ?? this.isDragging,
    );
  }
}

class StoryEditorNotifier extends AutoDisposeNotifier<StoryEditorState> {
  @override
  StoryEditorState build() {
    return const StoryEditorState();
  }

  void setIsDragging(bool val) {
    state = state.copyWith(isDragging: val);
  }

  void setProjectId(String projectId) {
    state = state.copyWith(projectId: projectId);
  }

  void selectLayer(String? layerId) {
    state = state.copyWith(selectedLayerId: layerId);
  }

  void initFromProject(String projectId, Map<String, String> existingSlots, List<TemplateLayer> templateLayers) {
    final updatedLayers = <String, LayerData>{};
    
    final imageSlots = existingSlots.entries.where((e) => !e.key.endsWith('_txt')).toList();
    final textSlots = existingSlots.entries.where((e) => e.key.endsWith('_txt')).toList();

    // Rehydrate texts properly
    for (final entry in textSlots) {
      final rawId = entry.key.replaceAll('_txt', '');
      updatedLayers[rawId] = (updatedLayers[rawId] ?? const LayerData()).copyWith(text: entry.value);
    }

    // Rehydrate images safely mapping old/broken ids to current templated image layers
    int legacyIdx = 0;
    final imageTemplateLayers = templateLayers.whereType<ImageLayer>().toList();

    for (final entry in imageSlots) {
      if (templateLayers.any((l) => l.id == entry.key)) {
        updatedLayers[entry.key] = (updatedLayers[entry.key] ?? const LayerData()).copyWith(imagePath: entry.value);
      } else {
        // Fallback: sequential mapping
        if (legacyIdx < imageTemplateLayers.length) {
          final fallbackId = imageTemplateLayers[legacyIdx].id;
          updatedLayers[fallbackId] = (updatedLayers[fallbackId] ?? const LayerData()).copyWith(imagePath: entry.value);
          legacyIdx++;
        }
      }
    }

    state = StoryEditorState(projectId: projectId, layers: updatedLayers);
  }

  void setImage(String layerId, String imagePath) {
    final current = state.layers[layerId] ?? const LayerData();
    final updated = Map<String, LayerData>.from(state.layers);
    
    updated[layerId] = current.copyWith(
      imagePath: imagePath,
      offset: Offset.zero,
      scale: 1.0, 
      isLoading: false,
    );
    state = state.copyWith(layers: updated, selectedLayerId: layerId);
  }

  void setText(String layerId, String text) {
    final current = state.layers[layerId] ?? const LayerData();
    final updated = Map<String, LayerData>.from(state.layers);
    updated[layerId] = current.copyWith(text: text);
    state = state.copyWith(layers: updated);
  }

  void setLoading(String layerId, bool isLoading) {
    final current = state.layers[layerId] ?? const LayerData();
    final updated = Map<String, LayerData>.from(state.layers);
    updated[layerId] = current.copyWith(isLoading: isLoading);
    state = state.copyWith(layers: updated);
  }

  void setTransform(String layerId, Offset newOffset, double newScale) {
    final current = state.layers[layerId] ?? const LayerData();
    final updated = Map<String, LayerData>.from(state.layers);
    
    updated[layerId] = current.copyWith(
      offset: newOffset,
      scale: newScale.clamp(0.1, 10.0),
    );
    state = state.copyWith(layers: updated);
  }

  void swapImages(String layer1Id, String layer2Id) {
    if (layer1Id == layer2Id) return;
    
    final l1 = state.layers[layer1Id] ?? const LayerData();
    final l2 = state.layers[layer2Id] ?? const LayerData();
    
    final updated = Map<String, LayerData>.from(state.layers);
    updated[layer1Id] = l2;
    updated[layer2Id] = l1;
    
    state = state.copyWith(layers: updated);
  }

  void reset() {
    state = const StoryEditorState();
  }
}

final storyEditorProvider = AutoDisposeNotifierProvider<StoryEditorNotifier, StoryEditorState>(
  StoryEditorNotifier.new,
);
