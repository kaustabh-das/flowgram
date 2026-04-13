import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:colorfilter_generator/addons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/image_picker_service.dart';
import '../../../core/services/export_service.dart';
import '../../../core/widgets/glass_card.dart';
import '../../gallery/presentation/gallery_provider.dart';
import '../domain/collage_layout.dart';
import '../data/template_repository.dart';
import 'state/story_editor_state.dart';

class StoryEditorScreen extends ConsumerStatefulWidget {
  const StoryEditorScreen({super.key, required this.layoutId, this.projectId, this.filterName});

  final String layoutId;
  final String? projectId;
  final String? filterName;

  @override
  ConsumerState<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends ConsumerState<StoryEditorScreen> {
  final GlobalKey _boundaryKey = GlobalKey();  // offscreen export canvas
  final GlobalKey _thumbnailKey = GlobalKey(); // visible frame for thumbnail
  TemplateModel? _layout;
  late final PageController _pageController;
  int _currentFrame = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      await ref.read(templatesInitializationProvider.future);
      if (!mounted) return;

      final repo = ref.read(templateRepositoryProvider);
      setState(() {
        String queryId = widget.layoutId;
        // Fallbacks for legacy projects saved prior to the JSON template upgrade
        if (queryId == 'story_split') queryId = 'min_split_layout';
        if (queryId == 'story_filmstrip') queryId = 'min_storyboard';

        _layout = repo.templates.firstWhere(
          (t) => t.id == queryId,
          orElse: () => repo.templates.first, 
        );
      });

      if (widget.projectId != null) {
        final projects = ref.read(galleryProvider);
        final proj = projects.where((p) => p.id == widget.projectId).firstOrNull;
        if (proj != null && proj.templateSlots != null) {
          ref.read(storyEditorProvider.notifier).initFromProject(proj.id, proj.templateSlots!, _layout!.layers);
        }
      } else {
        ref.read(storyEditorProvider.notifier).reset();
      }
    } catch (e) {
      debugPrint('Error initializing editor: $e');
    }
  }

  Future<void> _exportCollage() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exporting…'), duration: Duration(seconds: 10)),
        );
      }

      // Give Offstage canvas a frame to fully paint
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
        return;
      }

      // _FullCanvas renders at 1350px height — pixelRatio:1 keeps exact resolution
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final success = await ref.read(exportServiceProvider)
          .saveImageToGallery(pngBytes, frames: _layout!.frames);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ Saved to gallery!' : 'Failed to save.'),
            backgroundColor: success ? AppColors.accentCyan : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _autoSaveTemplate() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || _layout == null) return;

    final state = ref.read(storyEditorProvider);
    final validSlots = <String, String>{};
    for (final entry in state.layers.entries) {
      // Technically "imagePath" is just data. For text we should persist "text" field too,
      // but for now we hook it into existing DB slot behavior which holds Strings.
      if (entry.value.imagePath != null) validSlots[entry.key] = entry.value.imagePath!;
      if (entry.value.text != null) validSlots["${entry.key}_txt"] = entry.value.text!;
    }
    if (validSlots.isEmpty) return;

    Uint8List thumbnailBytes = Uint8List(0);
    try {
      // Capture thumbnail from the VISIBLE frame (not the 1px offscreen canvas)
      final thBoundary = _thumbnailKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (thBoundary != null) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final ui.Image thImage = await thBoundary.toImage(pixelRatio: 0.6);
        final ByteData? thData = await thImage.toByteData(format: ui.ImageByteFormat.png);
        thumbnailBytes = thData!.buffer.asUint8List();
        thImage.dispose();
      }
    } catch (_) {}

    final newId = await ref.read(galleryProvider.notifier).saveTemplateProject(
      existingId: state.projectId,
      layoutId: _layout!.id,
      slots: validSlots,
      thumbnail: thumbnailBytes,
    );

    if (state.projectId == null && mounted) {
      ref.read(storyEditorProvider.notifier).setProjectId(newId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep provider alive so it isn't disposed before children mount
    ref.watch(storyEditorProvider);

    if (_layout == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF141414),
        body: Center(child: CircularProgressIndicator(color: AppColors.accentCyan)),
      );
    }

    final isDark = _layout!.backgroundColor.computeLuminance() < 0.5;

    final frames = _layout!.frames;

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _layout!.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (frames > 1)
              Text(
                'Frame ${_currentFrame + 1} of $frames',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, color: Colors.white),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _autoSaveTemplate();
              if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Saved to Projects!'), backgroundColor: AppColors.accentCyan));
            },
            tooltip: 'Save to Projects',
          ),
          TextButton(
            onPressed: _exportCollage,
            child: const Text('Export', style: TextStyle(color: AppColors.accentCyan)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Offscreen export canvas (renders at full 1350px resolution) ──────
          // UnconstrainedBox lets _FullCanvas use its natural SizedBox dimensions
          // instead of being squashed to 1×1 by a parent constraint.
          Offstage(
            child: UnconstrainedBox(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: _FullCanvas(layout: _layout!, filterName: widget.filterName, isDark: isDark),
              ),
            ),
          ),

          // ── Per-frame PageView ───────────────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Fit the frame inside available space (like BoxFit.contain)
                final maxW = constraints.maxWidth - 32; // horizontal padding
                final maxH = constraints.maxHeight - 24; // vertical padding

                double frameW = maxW;
                double frameH = frameW / _layout!.aspectRatio;

                if (frameH > maxH) {
                  frameH = maxH;
                  frameW = frameH * _layout!.aspectRatio;
                }

                final totalW = frameW * frames;

                return Center(
                  child: RepaintBoundary(
                    key: _thumbnailKey,
                    child: SizedBox(
                      width: frameW,
                      height: frameH,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: frames,
                        onPageChanged: (i) => setState(() => _currentFrame = i),
                        itemBuilder: (context, frameIndex) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: _layout!.backgroundColor,
                              child: ClipRect(
                                child: OverflowBox(
                                  maxWidth: totalW,
                                  maxHeight: frameH,
                                  alignment: Alignment.centerLeft,
                                  child: Transform.translate(
                                    offset: Offset(-frameIndex * frameW, 0),
                                    child: SizedBox(
                                      width: totalW,
                                      height: frameH,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: _layout!.layers.map((layer) {
                                          if (layer is ImageLayer) {
                                            return _ImageLayerWidget(
                                              layer: layer,
                                              canvasSize: Size(totalW, frameH),
                                              filterName: widget.filterName,
                                              isDarkTheme: isDark,
                                              onAutoSave: _autoSaveTemplate,
                                            );
                                          } else if (layer is TextLayer) {
                                            return _TextLayerWidget(
                                              layer: layer,
                                              canvasSize: Size(totalW, frameH),
                                              onAutoSave: _autoSaveTemplate,
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Frame dot indicators ─────────────────────────────────────────────
          if (frames > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(frames, (i) {
                  final active = i == _currentFrame;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: active ? AppColors.accentCyan : Colors.white24,
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Widget Layers ─────────────────────────────────────────────────────────────

/// A full-resolution canvas widget used for the hidden [RepaintBoundary] export.
/// Renders all layers at the correct total width (aspectRatio * frames).
class _FullCanvas extends ConsumerWidget {
  const _FullCanvas({required this.layout, this.filterName, required this.isDark});
  final TemplateModel layout;
  final String? filterName;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storyEditorProvider);
    // Export at a fixed resolution: 1080px per frame
    const frameH = 1350.0; // 4:5 frame height at 1080w
    final frameW = frameH * layout.aspectRatio;
    final totalW = frameW * layout.frames;

    return SizedBox(
      width: totalW,
      height: frameH,
      child: Container(
        color: layout.backgroundColor,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: layout.layers.map((layer) {
            if (layer is ImageLayer) {
              final slotData = state.layers[layer.id];
              final absW = totalW * layer.width;
              final absH = frameH * layer.height;
              final currentOffset = slotData?.offset ?? Offset.zero;
              final currentScale  = slotData?.scale  ?? 1.0;
              if (slotData?.imagePath == null) return const SizedBox.shrink();
              return Positioned(
                left: totalW * layer.x,
                top: frameH * layer.y,
                width: absW,
                height: absH,
                child: ClipRect(
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: currentOffset,
                      child: Transform.scale(
                        scale: currentScale,
                        child: Image.file(File(slotData!.imagePath!), width: absW, height: absH, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              );
            } else if (layer is TextLayer) {
              final slotData = state.layers[layer.id];
              return Positioned(
                left: totalW * layer.x,
                top: frameH * layer.y,
                width: totalW * layer.width,
                height: frameH * layer.height,
                child: Text(
                  slotData?.text ?? layer.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: layer.fontFamily, fontSize: layer.fontSize, color: Color(layer.color)),
                ),
              );
            }
            return const SizedBox.shrink();
          }).toList(),
        ),
      ),
    );
  }
}

// ── Image Layer Widget ────────────────────────────────────────────────────────

class _ImageLayerWidget extends ConsumerStatefulWidget {
  const _ImageLayerWidget({
    required this.layer,
    required this.canvasSize,
    required this.filterName,
    required this.isDarkTheme,
    required this.onAutoSave,
  });

  final ImageLayer layer;
  final Size canvasSize;
  final String? filterName;
  final bool isDarkTheme;
  final VoidCallback onAutoSave;

  @override
  ConsumerState<_ImageLayerWidget> createState() => _ImageLayerWidgetState();
}

class _ImageLayerWidgetState extends ConsumerState<_ImageLayerWidget> {
  // Local gesture tracking — stored per-widget, committed on gesture end
  late Offset _panOrigin;
  late double _scaleOrigin;
  late Offset _offsetOrigin;

  @override
  void initState() {
    super.initState();
    _panOrigin = Offset.zero;
    _scaleOrigin = 1.0;
    _offsetOrigin = Offset.zero;
  }

  Future<String?> _showImportModal(BuildContext context) async {
    final projects = ref.read(galleryProvider);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text('Select Image', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 24),
                PressableCard(
                  onTap: () => Navigator.pop(ctx, 'GALLERY'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: AppColors.accentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentPurple.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Device Gallery', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('Browse all photos', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
                      ],
                    ),
                  ),
                ),
                if (projects.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Text('Recent Edits', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: projects.length,
                      itemBuilder: (context, i) {
                        final p = projects[i];
                        return PressableCard(
                          onTap: () => Navigator.pop(ctx, p.imagePath),
                          child: Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(
                                image: MemoryImage(p.thumbnail),
                                fit: BoxFit.cover,
                              ),
                              border: Border.all(color: Colors.white10),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                              ],
                            ),
                          ),
                        );
                      }
                    )
                  )
                ]
              ],
            ),
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storyEditorProvider);
    final slotData = state.layers[widget.layer.id];

    final absoluteWidth  = widget.canvasSize.width  * widget.layer.width;
    final absoluteHeight = widget.canvasSize.height * widget.layer.height;
    final slotLeft = widget.canvasSize.width  * widget.layer.x;
    final slotTop  = widget.canvasSize.height * widget.layer.y;

    // Current committed transform
    final currentOffset = slotData?.offset ?? Offset.zero;
    final currentScale  = slotData?.scale  ?? 1.0;

    Widget slotContent;

    if (slotData?.imagePath != null) {
      final img = _buildFilteredImage(slotData!.imagePath!, absoluteWidth, absoluteHeight);

      slotContent = GestureDetector(
        onScaleStart: (d) {
          _panOrigin    = d.focalPoint;
          _scaleOrigin  = currentScale;
          _offsetOrigin = currentOffset;
        },
        onScaleUpdate: (d) {
          final delta  = d.focalPoint - _panOrigin;
          final newOff = _offsetOrigin + delta;
          final newSc  = (_scaleOrigin * d.scale).clamp(0.5, 8.0);
          ref.read(storyEditorProvider.notifier).setTransform(
            widget.layer.id, newOff, newSc,
          );
        },
        onScaleEnd: (_) => widget.onAutoSave(),
        child: ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            alignment: Alignment.center,
            child: Transform.translate(
              offset: currentOffset,
              child: Transform.scale(
                scale: currentScale,
                child: img,
              ),
            ),
          ),
        ),
      );

      slotContent = LongPressDraggable<String>(
        data: widget.layer.id,
        delay: const Duration(milliseconds: 400),
        feedback: Opacity(
          opacity: 0.75,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.layer.borderRadius.toDouble()),
            child: SizedBox(
              width: absoluteWidth,
              height: absoluteHeight,
              child: _buildFilteredImage(slotData.imagePath!, absoluteWidth, absoluteHeight),
            ),
          ),
        ),
        child: slotContent,
      );
    } else {
      // Empty tap-to-pick slot
      slotContent = GestureDetector(
        onTap: () async {
          if (slotData?.isLoading == true) return;
          final sourcePath = await _showImportModal(context);
          if (sourcePath == null) return;

          ref.read(storyEditorProvider.notifier).setLoading(widget.layer.id, true);
          if (sourcePath == 'GALLERY') {
            final result = await ref.read(imagePickerServiceProvider).pickFromGallery();
            if (result is PickSuccess) {
              ref.read(storyEditorProvider.notifier).setImage(widget.layer.id, result.file.path);
              widget.onAutoSave();
            } else {
              ref.read(storyEditorProvider.notifier).setLoading(widget.layer.id, false);
            }
          } else {
            // Load from project path
            ref.read(storyEditorProvider.notifier).setImage(widget.layer.id, sourcePath);
            widget.onAutoSave();
          }
        },
        child: Container(
          color: widget.isDarkTheme ? Colors.white12 : Colors.black12,
          child: Center(
            child: slotData?.isLoading == true
                ? const CircularProgressIndicator(color: AppColors.accentCyan)
                : Icon(
                    Icons.add_photo_alternate_rounded,
                    color: widget.isDarkTheme ? Colors.white38 : Colors.black38,
                    size: 32,
                  ),
          ),
        ),
      );
    }

    return Positioned(
      left: slotLeft,
      top: slotTop,
      width: absoluteWidth,
      height: absoluteHeight,
      child: DragTarget<String>(
        onAcceptWithDetails: (details) {
          if (details.data != widget.layer.id) {
            ref.read(storyEditorProvider.notifier).swapImages(details.data, widget.layer.id);
            widget.onAutoSave();
          }
        },
        builder: (context, candidateData, _) {
          final isHovered = candidateData.isNotEmpty;
          return ClipRRect(
            borderRadius: BorderRadius.circular(widget.layer.borderRadius.toDouble()),
            child: Stack(
              fit: StackFit.expand,
              children: [
                slotContent,
                if (isHovered)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accentCyan, width: 3),
                      borderRadius: BorderRadius.circular(widget.layer.borderRadius.toDouble()),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilteredImage(String path, double w, double h) {
    // BoxFit.contain shows the full image → user pans/zooms to frame their shot.
    // Once they've positioned it, the ClipRect in the parent hides overflow.
    Widget imageWidget = Image.file(
      File(path),
      width: w,
      height: h,
      fit: BoxFit.contain,
    );
    final fn = widget.filterName;
    if (fn == null || fn.isEmpty) return imageWidget;

    final filters = <List<double>>[];
    switch (fn) {
      case 'Cinematic Noir':
        filters.add(ColorFilterAddons.grayscale());
        filters.add(ColorFilterAddons.contrast(0.25));
        filters.add(ColorFilterAddons.brightness(-0.1));
        break;
      case 'Vintage Film':
      case 'Golden Hour':
        filters.add(ColorFilterAddons.sepia(0.6));
        filters.add(ColorFilterAddons.saturation(-0.15));
        break;
      case 'Ocean Dreams':
        filters.add(ColorFilterAddons.colorOverlay(20, 100, 200, 0.15));
        break;
      case 'Moody Forest':
        filters.add(ColorFilterAddons.saturation(-0.3));
        filters.add(ColorFilterAddons.colorOverlay(20, 80, 20, 0.15));
        break;
      case 'Dreamy Pastel':
        filters.add(ColorFilterAddons.brightness(0.1));
        filters.add(ColorFilterAddons.colorOverlay(255, 105, 180, 0.1));
        break;
      case 'Neon Nights':
        filters.add(ColorFilterAddons.contrast(0.3));
        filters.add(ColorFilterAddons.saturation(0.4));
        filters.add(ColorFilterAddons.colorOverlay(155, 93, 229, 0.15));
        break;
    }

    if (filters.isEmpty) return imageWidget;
    return ColorFilterGenerator(name: fn, filters: filters).build(imageWidget);
  }
}


class _TextLayerWidget extends ConsumerStatefulWidget {
  const _TextLayerWidget({
    required this.layer,
    required this.canvasSize,
    required this.onAutoSave,
  });

  final TextLayer layer;
  final Size canvasSize;
  final VoidCallback onAutoSave;

  @override
  ConsumerState<_TextLayerWidget> createState() => _TextLayerWidgetState();
}

class _TextLayerWidgetState extends ConsumerState<_TextLayerWidget> {
  // Logic for a tapping a text layer to open bottom sheet editor.
  // In Phase 3, we implement the interactiveBottomSheet. For now, basic editable hook.

  Future<void> _editText(BuildContext context, String currentText) async {
    final controller = TextEditingController(text: currentText);
    
    final newText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 24),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type here...',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                maxLines: null,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(controller.text),
                  child: const Text('Done', style: TextStyle(color: AppColors.accentCyan, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );

    if (newText != null && newText.trim().isNotEmpty) {
      ref.read(storyEditorProvider.notifier).setText(widget.layer.id, newText);
      widget.onAutoSave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storyEditorProvider);
    final slotData = state.layers[widget.layer.id];
    
    final displayText = slotData?.text ?? widget.layer.text;

    final absoluteWidth = widget.canvasSize.width * widget.layer.width;
    final absoluteHeight = widget.canvasSize.height * widget.layer.height;

    return Positioned(
      left: widget.canvasSize.width * widget.layer.x,
      top: widget.canvasSize.height * widget.layer.y,
      width: absoluteWidth,
      height: absoluteHeight,
      child: Transform.rotate(
        angle: widget.layer.rotation,
        child: GestureDetector(
          onTap: () => _editText(context, displayText),
          child: Container(
            color: Colors.transparent, // catch taps
            alignment: Alignment.center,
            child: Text(
              displayText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: widget.layer.fontFamily,
                fontSize: widget.layer.fontSize,
                color: Color(widget.layer.color),
                shadows: const [
                  Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(0, 2))
                ]
              ),
            ),
          ),
        ),
      ),
    );
  }
}
