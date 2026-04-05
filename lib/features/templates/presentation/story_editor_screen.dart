import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/image_picker_service.dart';
import '../domain/collage_layout.dart';
import 'state/story_editor_state.dart';

class StoryEditorScreen extends ConsumerStatefulWidget {
  const StoryEditorScreen({super.key, required this.layoutId});

  final String layoutId;

  @override
  ConsumerState<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends ConsumerState<StoryEditorScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  late final CollageLayout _layout;

  @override
  void initState() {
    super.initState();
    _layout = StandardLayouts.all.firstWhere(
      (l) => l.id == widget.layoutId,
      orElse: () => StandardLayouts.storySplit,
    );
  }

  Future<void> _exportCollage() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Unfocus / deselect visually if any UI elements overlay the canvas.
      // E.g., we'll ensure placeholders don't show when exporting.
      // For a truly clean export, you'd toggle a state, delay, then capture.
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      
      // In a full app, you would save it via gallery_saver or similar.
      // For this step, we simply show a success snackbar since the user
      // only requested the export boundary to be functional.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collage successfully captured!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture collage: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onTap: () => context.pop(),
        ),
        title: Text(
          _layout.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: _exportCollage,
            child: const Text('Export', style: TextStyle(color: AppColors.accentCyan)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: AspectRatio(
            aspectRatio: _layout.aspectRatio,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  color: _layout.backgroundColor,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: _layout.slots.map((slot) {
                          return _CollageSlotWidget(
                            slot: slot,
                            canvasSize: Size(constraints.maxWidth, constraints.maxHeight),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollageSlotWidget extends ConsumerWidget {
  const _CollageSlotWidget({
    required this.slot,
    required this.canvasSize,
  });

  final CollageSlot slot;
  final Size canvasSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storyEditorProvider);
    final slotData = state.slots[slot.id];

    // Absolute dimensions on the canvas
    final absoluteWidth = canvasSize.width * slot.width;
    final absoluteHeight = canvasSize.height * slot.height;

    return Positioned(
      left: canvasSize.width * slot.left,
      top: canvasSize.height * slot.top,
      width: absoluteWidth,
      height: absoluteHeight,
      child: GestureDetector(
        onScaleUpdate: (details) {
          if (slotData?.imagePath == null) return;
          ref.read(storyEditorProvider.notifier).updateTransform(
            slot.id, 
            details.focalPointDelta, 
            details.scale,
          );
        },
        onTap: () async {
          if (slotData?.imagePath == null) {
            final result = await ref.read(imagePickerServiceProvider).pickFromGallery();
            if (result is PickSuccess) {
              ref.read(storyEditorProvider.notifier).setImage(slot.id, result.file.path);
            }
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Colors.black12,
            child: slotData?.imagePath != null
                ? SizedBox.expand(
                    child: Transform.translate(
                      offset: slotData!.offset,
                      child: Transform.scale(
                        scale: slotData.scale,
                        child: Image.file(
                          File(slotData.imagePath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.add_photo_alternate_rounded, color: Colors.black38, size: 32),
                  ),
          ),
        ),
      ),
    );
  }
}
