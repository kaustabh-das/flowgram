import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CollageSlotData {
  const CollageSlotData({
    this.imagePath,
    this.offset = Offset.zero,
    this.scale = 1.0,
  });

  final String? imagePath;
  final Offset offset;
  final double scale;

  CollageSlotData copyWith({
    String? imagePath,
    Offset? offset,
    double? scale,
  }) {
    return CollageSlotData(
      imagePath: imagePath ?? this.imagePath,
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
    );
  }
}

class StoryEditorState {
  const StoryEditorState({
    this.slots = const {},
  });

  // Maps slot IDs to their data (image path, panning offset, scale)
  final Map<String, CollageSlotData> slots;

  StoryEditorState copyWith({
    Map<String, CollageSlotData>? slots,
  }) {
    return StoryEditorState(
      slots: slots ?? this.slots,
    );
  }
}

class StoryEditorNotifier extends AutoDisposeNotifier<StoryEditorState> {
  @override
  StoryEditorState build() {
    return const StoryEditorState();
  }

  void setImage(String slotId, String imagePath) {
    final currentSlot = state.slots[slotId] ?? const CollageSlotData();
    final updatedSlots = Map<String, CollageSlotData>.from(state.slots);
    
    // Reset offset/scale when a new image is loaded into the slot
    updatedSlots[slotId] = currentSlot.copyWith(
      imagePath: imagePath,
      offset: Offset.zero,
      scale: 1.0, 
    );
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

  void reset() {
    state = const StoryEditorState();
  }
}

final storyEditorProvider = AutoDisposeNotifierProvider<StoryEditorNotifier, StoryEditorState>(
  StoryEditorNotifier.new,
);
