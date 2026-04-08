import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollageSlotData {
  const CollageSlotData({
    this.imagePath,
    this.offset = Offset.zero,
    this.scale = 1.0,
    this.isLoading = false,
  });

  final String? imagePath;
  final Offset offset;
  final double scale;
  final bool isLoading;

  CollageSlotData copyWith({
    String? imagePath,
    Offset? offset,
    double? scale,
    bool? isLoading,
  }) {
    return CollageSlotData(
      imagePath: imagePath ?? this.imagePath,
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class StoryEditorState {
  const StoryEditorState({
    this.projectId,
    this.slots = const {},
  });

  // Maps slot IDs to their data (image path, panning offset, scale)
  final Map<String, CollageSlotData> slots;
  // If editing an existing project, track its ID
  final String? projectId;

  StoryEditorState copyWith({
    String? projectId,
    Map<String, CollageSlotData>? slots,
  }) {
    return StoryEditorState(
      projectId: projectId ?? this.projectId,
      slots: slots ?? this.slots,
    );
  }
}

class StoryEditorNotifier extends AutoDisposeNotifier<StoryEditorState> {
  @override
  StoryEditorState build() {
    return const StoryEditorState();
  }

  void setProjectId(String projectId) {
    state = state.copyWith(projectId: projectId);
  }

  void initFromProject(String projectId, Map<String, String> existingSlots) {
    final updatedSlots = <String, CollageSlotData>{};
    for (final entry in existingSlots.entries) {
      updatedSlots[entry.key] = CollageSlotData(imagePath: entry.value);
    }
    state = StoryEditorState(projectId: projectId, slots: updatedSlots);
  }

  void setImage(String slotId, String imagePath) {
    final currentSlot = state.slots[slotId] ?? const CollageSlotData();
    final updatedSlots = Map<String, CollageSlotData>.from(state.slots);
    
    // Reset offset/scale when a new image is loaded into the slot
    updatedSlots[slotId] = currentSlot.copyWith(
      imagePath: imagePath,
      offset: Offset.zero,
      scale: 1.0, 
      isLoading: false,
    );
    state = state.copyWith(slots: updatedSlots);
  }

  void setLoading(String slotId, bool isLoading) {
    final currentSlot = state.slots[slotId] ?? const CollageSlotData();
    final updatedSlots = Map<String, CollageSlotData>.from(state.slots);
    updatedSlots[slotId] = currentSlot.copyWith(isLoading: isLoading);
    state = state.copyWith(slots: updatedSlots);
  }

  void updateTransform(String slotId, Offset deltaOffset, double deltaScale) {
    final currentSlot = state.slots[slotId] ?? const CollageSlotData();
    final updatedSlots = Map<String, CollageSlotData>.from(state.slots);
    
    // Clamp scale to reasonable values
    final newScale = (currentSlot.scale * deltaScale).clamp(0.5, 5.0);
    final newOffset = currentSlot.offset + deltaOffset;
    
    updatedSlots[slotId] = currentSlot.copyWith(
      offset: newOffset,
      scale: newScale,
    );
    state = state.copyWith(slots: updatedSlots);
  }

  void swapImages(String slot1Id, String slot2Id) {
    if (slot1Id == slot2Id) return;
    
    final slot1 = state.slots[slot1Id] ?? const CollageSlotData();
    final slot2 = state.slots[slot2Id] ?? const CollageSlotData();
    
    final updatedSlots = Map<String, CollageSlotData>.from(state.slots);
    
    // Swap the data
    updatedSlots[slot1Id] = slot2;
    updatedSlots[slot2Id] = slot1;
    
    state = state.copyWith(slots: updatedSlots);
  }

  void reset() {
    state = const StoryEditorState();
  }
}

final storyEditorProvider = AutoDisposeNotifierProvider<StoryEditorNotifier, StoryEditorState>(
  StoryEditorNotifier.new,
);
