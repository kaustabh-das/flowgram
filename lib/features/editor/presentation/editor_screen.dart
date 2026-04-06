import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/image_cache_service.dart';
import '../../../core/services/image_picker_service.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/services/export_service.dart';
import '../../gallery/presentation/gallery_provider.dart';
import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:colorfilter_generator/addons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

enum EditorStatus { idle, picking, loading, ready, processing, error }

class EditorImageState {
  const EditorImageState({
    this.status = EditorStatus.idle,
    this.sourceFile,
    this.displayImage,
    this.thumbnail,
    this.activeToolIndex = -1,
    this.errorMessage,
    this.imageSizeLabel,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.isVintage = false,
  });

  final EditorStatus status;
  final File? sourceFile;
  final ui.Image? displayImage;
  final Uint8List? thumbnail;
  final int activeToolIndex;
  final String? errorMessage;
  final String? imageSizeLabel;

  final double brightness;
  final double contrast;
  final double saturation;
  final bool isVintage;

  bool get hasImage => sourceFile != null && displayImage != null;

  EditorImageState copyWith({
    EditorStatus? status,
    File? sourceFile,
    ui.Image? displayImage,
    Uint8List? thumbnail,
    int? activeToolIndex,
    String? errorMessage,
    String? imageSizeLabel,
    double? brightness,
    double? contrast,
    double? saturation,
    bool? isVintage,
  }) =>
      EditorImageState(
        status: status ?? this.status,
        sourceFile: sourceFile ?? this.sourceFile,
        displayImage: displayImage ?? this.displayImage,
        thumbnail: thumbnail ?? this.thumbnail,
        activeToolIndex: activeToolIndex ?? this.activeToolIndex,
        errorMessage: errorMessage ?? this.errorMessage,
        imageSizeLabel: imageSizeLabel ?? this.imageSizeLabel,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        isVintage: isVintage ?? this.isVintage,
      );

  // Cleared state keeps the status but drops all image data.
  EditorImageState cleared() => const EditorImageState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class EditorImageNotifier extends StateNotifier<EditorImageState> {
  EditorImageNotifier(this._pickerService, this._cache)
      : super(const EditorImageState());

  final ImagePickerService _pickerService;
  final ImageCacheService _cache;

  // Cancel token — incremented each time a new pick/load starts so that
  // stale async continuations silently no-op instead of updating state.
  int _token = 0;

  // ── Public methods ────────────────────────────────────────────────

  Future<void> pickFromGallery() => _doPick(() => _pickerService.pickFromGallery());
  Future<void> pickFromCamera() => _doPick(() => _pickerService.pickFromCamera());

  Future<void> compress() async {
    if (state.sourceFile == null) return;
    state = state.copyWith(status: EditorStatus.processing, activeToolIndex: 0);

    final result = await ImageUtils.compress(
      state.sourceFile!,
      quality: AppSizes.compressQuality,
    );

    if (!mounted) return;

    if (result != null) {
      final newFile = File(result.path);
      await _loadFileIntoState(newFile);
    }
    state = state.copyWith(status: EditorStatus.ready, activeToolIndex: -1);
  }

  void setActiveTool(int index) {
    if (!mounted) return;
    state = state.copyWith(activeToolIndex: index == state.activeToolIndex ? -1 : index);
  }

  void setBrightness(double value) {
    if (!mounted) return;
    state = state.copyWith(brightness: value);
  }

  void setContrast(double value) {
    if (!mounted) return;
    state = state.copyWith(contrast: value);
  }

  void setSaturation(double value) {
    if (!mounted) return;
    state = state.copyWith(saturation: value);
  }

  void setVintage(bool value) {
    if (!mounted) return;
    state = state.copyWith(isVintage: value);
  }

  void clear() {
    _token++; // invalidate any in-flight loads
    // Do NOT delete the file here — the gallery provider may still hold a ref.
    state = state.cleared();
  }

  /// Loads an image from an existing [filePath] (e.g. deep-linked from home).
  Future<void> loadFromPath(String filePath) async {
    await _loadFileIntoState(File(filePath));
  }

  // ── Internal helpers ──────────────────────────────────────────────

  Future<void> _doPick(Future<PickResult> Function() picker) async {
    final token = ++_token;
    state = state.copyWith(status: EditorStatus.picking);

    final result = await picker();

    if (!mounted || token != _token) return; // stale or disposed

    switch (result) {
      case PickSuccess(:final file, :final thumbnail):
        state = state.copyWith(
          status: EditorStatus.loading,
          thumbnail: thumbnail,
        );
        await _loadFileIntoState(file, token: token, thumbnail: thumbnail);

      case PickPermissionDenied():
        state = state.copyWith(
          status: EditorStatus.error,
          errorMessage: AppStrings.permGalleryDenied,
        );

      case PickCancelled():
        state = state.copyWith(status: EditorStatus.idle);

      case PickError(:final message):
        state = state.copyWith(
          status: EditorStatus.error,
          errorMessage: message,
        );
    }
  }

  Future<void> _loadFileIntoState(
    File file, {
    int? token,
    Uint8List? thumbnail,
  }) async {
    final myToken = token ?? _token;

    // Check memory cache first
    final cacheKey = file.path;
    final cached = _cache.getMemory(cacheKey);
    if (cached != null) {
      if (!mounted || myToken != _token) return;
      final size = await _sizeLabel(file);
      state = state.copyWith(
        status: EditorStatus.ready,
        sourceFile: file,
        displayImage: cached.clone(), // caller owns this clone
        imageSizeLabel: size,
        thumbnail: thumbnail ?? state.thumbnail,
      );
      cached.dispose(); // dispose our local reference
      return;
    }

    // Load and sub-sample on a background isolate (max 2048 px)
    final ui.Image image;
    try {
      image = await ImageUtils.loadSampled(file, maxDimension: 2048);
    } catch (e) {
      if (!mounted || myToken != _token) return;
      state = state.copyWith(
        status: EditorStatus.error,
        errorMessage: AppStrings.errImageLoad,
      );
      return;
    }

    if (!mounted || myToken != _token) {
      image.dispose(); // stale — discard immediately
      return;
    }

    // Store a clone in the LRU cache; give another clone to the state.
    _cache.putMemory(cacheKey, image);
    final forState = image.clone();
    image.dispose();

    final size = await _sizeLabel(file);
    if (!mounted || myToken != _token) {
      forState.dispose();
      return;
    }

    state = state.copyWith(
      status: EditorStatus.ready,
      sourceFile: file,
      displayImage: forState,
      imageSizeLabel: size,
      thumbnail: thumbnail ?? state.thumbnail,
    );
  }

  Future<String?> _sizeLabel(File file) async {
    try {
      final sz = await ImageUtils.getDimensions(file);
      return '${sz.width.toInt()} × ${sz.height.toInt()}';
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    // Dispose the displayed image to free GPU texture memory.
    state.displayImage?.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final editorImageProvider =
    StateNotifierProvider<EditorImageNotifier, EditorImageState>((ref) {
  return EditorImageNotifier(
    ref.watch(imagePickerServiceProvider),
    ref.watch(imageCacheServiceProvider),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.imagePath});

  final String? imagePath;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final GlobalKey _previewBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // If launched with a deep-link path, load it after first frame.
    if (widget.imagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(editorImageProvider.notifier).loadFromPath(widget.imagePath!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorImageProvider);
    final notifier = ref.read(editorImageProvider.notifier);
    final topPad = MediaQuery.of(context).padding.top;

    // Show permission-denied snackbar once
    ref.listen<EditorImageState>(editorImageProvider, (prev, next) {
      if (next.status == EditorStatus.error && next.errorMessage != null) {
        _showErrorSnack(context, next.errorMessage!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D0D1A), AppColors.background],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          Column(
            children: [
              // ── App bar ──────────────────────────────────────────
              _EditorAppBar(
                topPad: topPad,
                state: state,
                onClear: notifier.clear,
              ),

              // ── Preview area ─────────────────────────────────────
              Expanded(
                child: _buildBody(state, notifier),
              ),

              // ── Toolbar ──────────────────────────────────────────
              if (state.hasImage)
                Column(
                  children: [
                    if (state.activeToolIndex == 2)
                      _AdjustPanel(state: state, notifier: notifier),
                    if (state.activeToolIndex == 3)
                      _FilterPanel(state: state, notifier: notifier),
                    _EditorToolbar(
                      activeIndex: state.activeToolIndex,
                      isProcessing: state.status == EditorStatus.processing,
                      onCompress: notifier.compress,
                      onCrop: () => notifier.setActiveTool(1),
                      onAdjust: () => notifier.setActiveTool(2),
                      onFilter: () => notifier.setActiveTool(3),
                      onText: () => notifier.setActiveTool(4),
                      onExport: () => _onExport(context, state),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(EditorImageState state, EditorImageNotifier notifier) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: switch (state.status) {
        EditorStatus.picking => const _StatusOverlay(
            key: ValueKey('picking'),
            icon: Icons.photo_library_rounded,
            label: 'Opening gallery…',
          ),
        EditorStatus.loading => _LoadingPreview(
            key: const ValueKey('loading'),
            thumbnail: state.thumbnail,
          ),
        EditorStatus.processing => const _StatusOverlay(
            key: ValueKey('proc'),
            icon: Icons.auto_fix_high_rounded,
            label: 'Processing…',
            showSpinner: true,
          ),
        EditorStatus.ready when state.hasImage => RepaintBoundary(
            key: _previewBoundaryKey,
            child: _ImagePreview(
              key: ValueKey(state.sourceFile!.path),
              state: state,
            ),
          ),
        EditorStatus.error => _ErrorPreview(
            key: const ValueKey('error'),
            message: state.errorMessage ?? AppStrings.errGeneric,
            onRetry: notifier.pickFromGallery,
          ),
        _ => _EmptyPreview(
            key: const ValueKey('empty'),
            onPickGallery: notifier.pickFromGallery,
            onPickCamera: notifier.pickFromCamera,
          ),
      },
    );
  }

  void _showErrorSnack(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: message == AppStrings.permGalleryDenied
            ? SnackBarAction(
                label: AppStrings.permOpenSettings,
                onPressed: openAppSettings,
              )
            : null,
      ),
    );
  }

  Future<void> _onExport(BuildContext context, EditorImageState state) async {
    if (state.sourceFile == null) return;
    
    try {
      final boundary = _previewBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 4.0); // Ultra-high resolution export
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final success = await ref.read(exportServiceProvider).saveImageToGallery(pngBytes);

      // Save to gallery provider for the home screen recent-edits grid
      if (success && state.thumbnail != null) {
        ref.read(galleryProvider.notifier).addProject(
              imagePath: state.sourceFile!.path,
              thumbnail: state.thumbnail!,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image flawlessly exported to Gallery! ✓')),
          );
        }
      } else if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save to Gallery!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

// ── App Bar ──────────────────────────────────────────────────────────────────

class _EditorAppBar extends StatelessWidget {
  const _EditorAppBar({
    required this.topPad,
    required this.state,
    required this.onClear,
  });

  final double topPad;
  final EditorImageState state;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPad + 8, left: 16, right: 16, bottom: 8),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => AppColors.accentGradient.createShader(b),
            blendMode: BlendMode.srcIn,
            child: const Icon(Icons.auto_fix_high_rounded, size: 26),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editor',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              if (state.imageSizeLabel != null)
                Text(
                  state.imageSizeLabel!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
            ],
          ),
          const Spacer(),
          if (state.hasImage) ...[
            _GlassIconButton(icon: Icons.undo_rounded, onTap: () {}),
            const SizedBox(width: 8),
            _GlassIconButton(icon: Icons.redo_rounded, onTap: () {}),
            const SizedBox(width: 8),
            _GlassIconButton(icon: Icons.delete_outline_rounded, onTap: onClear),
          ],
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(8),
        borderRadius: 12,
        blur: 8,
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

// ── Image Preview ─────────────────────────────────────────────────────────────

/// Displays a [ui.Image] using [RawImage] inside a [RepaintBoundary].
/// [RepaintBoundary] isolates repaints caused by InteractiveViewer so the
/// rest of the widget tree doesn't repaint on every pinch-zoom frame.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({super.key, required this.state});
  final EditorImageState state;

  @override
  Widget build(BuildContext context) {
    final filters = [
      if (state.isVintage) ...[
        ColorFilterAddons.sepia(0.6),
        ColorFilterAddons.saturation(-0.15),
        ColorFilterAddons.contrast(0.05),
      ],
      if (state.brightness != 0) ColorFilterAddons.brightness(state.brightness),
      if (state.contrast != 0) ColorFilterAddons.contrast(state.contrast),
      if (state.saturation != 0) ColorFilterAddons.saturation(state.saturation),
    ];

    final generator = filters.isEmpty 
        ? null 
        : ColorFilterGenerator(name: 'Custom', filters: filters);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPurple.withValues(alpha: 0.2),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: RepaintBoundary(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 8.0,
            child: Builder(
              builder: (context) {
                final raw = RawImage(
                  image: state.displayImage!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  width: double.infinity,
                );
                return generator == null ? raw : generator.build(raw);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loading Preview ───────────────────────────────────────────────────────────

/// Shows the blurred thumbnail (if available) with a shimmer overlay while
/// the full image decodes in the background — perceived performance win.
class _LoadingPreview extends StatefulWidget {
  const _LoadingPreview({super.key, this.thumbnail});
  final Uint8List? thumbnail;

  @override
  State<_LoadingPreview> createState() => _LoadingPreviewState();
}

class _LoadingPreviewState extends State<_LoadingPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surfaceMid,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred thumbnail as placeholder
            if (widget.thumbnail != null)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Image.memory(
                  widget.thumbnail!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),

            // Shimmer overlay
            AnimatedBuilder(
              animation: _shimmer,
              builder: (context, _) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment(-1.5 + _shimmer.value * 3, 0),
                      end: Alignment(-0.5 + _shimmer.value * 3, 0),
                      colors: const [
                        Colors.transparent,
                        Color(0x22FFFFFF),
                        Colors.transparent,
                      ],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcOver,
                  child: Container(color: Colors.white.withValues(alpha: 0.05)),
                );
              },
            ),

            // Center spinner
            Center(
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                borderRadius: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.accentPurple),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Loading image…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty Preview ─────────────────────────────────────────────────────────────

class _EmptyPreview extends StatefulWidget {
  const _EmptyPreview({
    super.key,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  @override
  State<_EmptyPreview> createState() => _EmptyPreviewState();
}

class _EmptyPreviewState extends State<_EmptyPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing import icon
            ScaleTransition(
              scale: _scale,
              child: GestureDetector(
                onTap: widget.onPickGallery,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentPurple.withValues(alpha: 0.15),
                        AppColors.accentCyan.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppColors.accentPurple.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.accentGradient.createShader(b),
                    blendMode: BlendMode.srcIn,
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No image selected',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a photo to start editing',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 36),
            // Two action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PickButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  gradient: AppColors.accentGradient,
                  onTap: widget.onPickGallery,
                ),
                const SizedBox(width: 16),
                _PickButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF007AFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  onTap: widget.onPickCamera,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status Overlay ────────────────────────────────────────────────────────────

class _StatusOverlay extends StatelessWidget {
  const _StatusOverlay({
    super.key,
    required this.icon,
    required this.label,
    this.showSpinner = false,
  });

  final IconData icon;
  final String label;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPurple),
                ),
              )
            else
              ShaderMask(
                shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                blendMode: BlendMode.srcIn,
                child: Icon(icon, size: 44),
              ),
            const SizedBox(height: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error Preview ─────────────────────────────────────────────────────────────

class _ErrorPreview extends StatelessWidget {
  const _ErrorPreview({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            PressableCard(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Editor Toolbar ────────────────────────────────────────────────────────────

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.activeIndex,
    required this.isProcessing,
    required this.onCompress,
    required this.onCrop,
    required this.onAdjust,
    required this.onFilter,
    required this.onText,
    required this.onExport,
  });

  final int activeIndex;
  final bool isProcessing;
  final VoidCallback onCompress;
  final VoidCallback onCrop;
  final VoidCallback onAdjust;
  final VoidCallback onFilter;
  final VoidCallback onText;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final tools = [
      _Tool(Icons.compress_rounded, 'Compress', onCompress),
      _Tool(Icons.crop_rounded, 'Crop', onCrop),
      _Tool(Icons.tune_rounded, 'Adjust', onAdjust),
      _Tool(Icons.filter_rounded, 'Filter', onFilter),
      _Tool(Icons.text_fields_rounded, 'Text', onText),
    ];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.only(bottom: 20, top: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tool row
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: tools.length,
                  itemBuilder: (context, i) => _ToolButton(
                    tool: tools[i],
                    isActive: activeIndex == i,
                    isDisabled: isProcessing,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Export button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PressableCard(
                  onTap: isProcessing ? () {} : onExport,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: isProcessing
                          ? const LinearGradient(
                              colors: [AppColors.surfaceLight, AppColors.surfaceMid])
                          : AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isProcessing
                          ? []
                          : [
                              BoxShadow(
                                color:
                                    AppColors.accentPurple.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: isProcessing
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.ios_share_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Export',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tool {
  const _Tool(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.isActive,
    required this.isDisabled,
  });

  final _Tool tool;
  final bool isActive;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : tool.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive
              ? AppColors.accentPurple.withValues(alpha: 0.2)
              : Colors.transparent,
          border: isActive
              ? Border.all(
                  color: AppColors.accentPurple.withValues(alpha: 0.5),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isActive
                  ? ShaderMask(
                      key: const ValueKey('a'),
                      shaderCallback: (b) =>
                          AppColors.accentGradient.createShader(b),
                      blendMode: BlendMode.srcIn,
                      child: Icon(tool.icon, size: 24),
                    )
                  : Icon(
                      key: const ValueKey('i'),
                      tool.icon,
                      size: 22,
                      color: isDisabled
                          ? AppColors.textDisabled
                          : AppColors.textSecondary,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              tool.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppColors.accentPurple
                    : isDisabled
                        ? AppColors.textDisabled
                        : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Adjust Panel ──────────────────────────────────────────────────────────────

class _AdjustPanel extends StatefulWidget {
  const _AdjustPanel({required this.state, required this.notifier});
  final EditorImageState state;
  final EditorImageNotifier notifier;

  @override
  State<_AdjustPanel> createState() => _AdjustPanelState();
}

class _AdjustPanelState extends State<_AdjustPanel> {
  int _selectedTab = 0; // 0: Brightness, 1: Contrast, 2: Saturation

  @override
  Widget build(BuildContext context) {
    double value = 0;
    ValueChanged<double> onChanged = (v) {};

    if (_selectedTab == 0) {
      value = widget.state.brightness;
      // Slider will give values from -1.0 to 1.0, convert mapped logic
      onChanged = widget.notifier.setBrightness;
    } else if (_selectedTab == 1) {
      value = widget.state.contrast;
      onChanged = widget.notifier.setContrast;
    } else {
      value = widget.state.saturation;
      onChanged = widget.notifier.setSaturation;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMid.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TabItem(label: 'Brightness', isSelected: _selectedTab == 0, onTap: () => setState(() => _selectedTab = 0)),
              _TabItem(label: 'Contrast', isSelected: _selectedTab == 1, onTap: () => setState(() => _selectedTab = 1)),
              _TabItem(label: 'Saturation', isSelected: _selectedTab == 2, onTap: () => setState(() => _selectedTab = 2)),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.accentPurple,
              inactiveTrackColor: AppColors.surfaceLight,
              thumbColor: Colors.white,
              overlayColor: AppColors.accentPurple.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: -1.0,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Filter Panel ──────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({required this.state, required this.notifier});
  final EditorImageState state;
  final EditorImageNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMid.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PresetCard(
            label: 'Normal',
            isSelected: !state.isVintage,
            onTap: () => notifier.setVintage(false),
          ),
          const SizedBox(width: 16),
          _PresetCard(
            label: 'Vintage',
            isSelected: state.isVintage,
            onTap: () => notifier.setVintage(true),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.accentGradient : null,
          color: isSelected ? null : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
              ? Border.all(color: AppColors.accentPurple.withValues(alpha: 0.5), width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
