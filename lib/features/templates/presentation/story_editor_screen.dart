import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/image_picker_service.dart';
import '../../../core/services/export_service.dart';
import '../../gallery/presentation/gallery_provider.dart';
import '../domain/collage_layout.dart';
import 'state/story_editor_state.dart';
import 'package:path_provider/path_provider.dart';

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

      // Extract image as bytes
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final success = await ref.read(exportServiceProvider).saveImageToGallery(pngBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Collage saved to gallery!' : 'Failed to save collage.'),
            backgroundColor: success ? AppColors.accentCyan : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveToProjects() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/project_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      ref.read(galleryProvider.notifier).addProject(
            imagePath: file.path,
            thumbnail: pngBytes,
          );
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to Projects!'),
            backgroundColor: AppColors.accentCyan,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          _layout.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            onPressed: _saveToProjects,
            tooltip: 'Save to Projects',
          ),
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
      child: DragTarget<String>(
        onAcceptWithDetails: (details) {
          final draggedSlotId = details.data;
          if (draggedSlotId != slot.id) {
            ref.read(storyEditorProvider.notifier).swapImages(draggedSlotId, slot.id);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovered = candidateData.isNotEmpty;
          
          final slotContent = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              foregroundDecoration: isHovered
                  ? BoxDecoration(
                      border: Border.all(color: AppColors.accentCyan, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    )
                  : null,
              color: Colors.black12,
              child: slotData?.imagePath != null
                  ? InteractiveViewer(
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 0.5,
                      maxScale: 10.0,
                      clipBehavior: Clip.none,
                      child: Image.file(
                        File(slotData!.imagePath!),
                        fit: BoxFit.contain, // Allows user to see whole image, then pinch to cover
                      ),
                    )
                  : GestureDetector(
                      onTap: () async {
                        // Prevent multiple taps while loading
                        if (slotData?.isLoading == true) return;
                        
                        ref.read(storyEditorProvider.notifier).setLoading(slot.id, true);
                        final result = await ref.read(imagePickerServiceProvider).pickFromGallery();
                        if (result is PickSuccess) {
                          ref.read(storyEditorProvider.notifier).setImage(slot.id, result.file.path);
                        } else {
                          // If cancelled or failed, stop loading
                          ref.read(storyEditorProvider.notifier).setLoading(slot.id, false);
                        }
                      },
                      child: Center(
                        child: slotData?.isLoading == true
                            ? const CircularProgressIndicator(color: AppColors.accentCyan)
                            : const Icon(Icons.add_photo_alternate_rounded, color: Colors.black38, size: 32),
                      ),
                    ),
            ),
          );

          if (slotData?.imagePath != null) {
            return LongPressDraggable<String>(
              data: slot.id,
              delay: const Duration(milliseconds: 300),
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.7,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: absoluteWidth,
                      height: absoluteHeight,
                      color: Colors.black12,
                      child: Image.file(
                        File(slotData!.imagePath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              child: slotContent,
            );
          }

          return slotContent;
        },
      ),
    );
  }
}
