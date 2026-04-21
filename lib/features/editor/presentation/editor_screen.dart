import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/engine/auto_brightness.dart';
import '../../../core/engine/histogram.dart';
import '../../../core/engine/tone_engine.dart';
import '../../../core/services/image_cache_service.dart';
import '../../../core/services/image_picker_service.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/services/export_service.dart';
import '../../../core/widgets/prequel_slider.dart';
import '../../../core/widgets/shader_preview_widget.dart';
import '../../gallery/presentation/gallery_provider.dart';
import '../../../core/engine/hsl_params.dart';
import '../../../core/presets/filter_presets.dart';
import 'widgets/hsl_panel.dart';
import 'package:image_cropper/image_cropper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

enum EditorStatus { idle, picking, loading, ready, processing, error }

/// Lightweight snapshot of adjustable properties used by the undo/redo stack.
class _AdjustSnapshot {
  const _AdjustSnapshot({required this.tone});
  final ToneParams tone;
}

class EditorImageState {
  const EditorImageState({
    this.status = EditorStatus.idle,
    this.sourceFile,
    this.displayImage,
    this.thumbnail,
    this.activeToolIndex = -1,
    this.errorMessage,
    this.imageSizeLabel,
    this.tone = const ToneParams(),
    this.histogram,
    this.canUndo = false,
    this.canRedo = false,
    this.activePresetId = 'none',
    this.projectId,
  });

  final EditorStatus status;
  final File? sourceFile;
  final ui.Image? displayImage;
  final Uint8List? thumbnail;
  final int activeToolIndex;
  final String? errorMessage;
  final String? imageSizeLabel;

  /// All cinematic tone parameters (non-destructive)
  final ToneParams tone;

  /// Live histogram result — null while computing.
  final HistogramResult? histogram;

  final bool canUndo;
  final bool canRedo;

  /// ID of the currently selected [FilterPreset]. 'none' = Original.
  final String activePresetId;

  /// ID of the project in the gallery.
  final String? projectId;

  // Legacy shims so nothing else breaks
  double get contrast    => tone.contrast;
  double get saturation  => tone.saturation;
  bool   get isVintage   => tone.isVintage;

  bool get hasImage => sourceFile != null && displayImage != null;

  EditorImageState copyWith({
    EditorStatus? status,
    File? sourceFile,
    ui.Image? displayImage,
    Uint8List? thumbnail,
    int? activeToolIndex,
    String? errorMessage,
    String? imageSizeLabel,
    ToneParams? tone,
    HistogramResult? histogram,
    bool? canUndo,
    bool? canRedo,
    String? activePresetId,
    String? projectId,
  }) =>
      EditorImageState(
        status: status ?? this.status,
        sourceFile: sourceFile ?? this.sourceFile,
        displayImage: displayImage ?? this.displayImage,
        thumbnail: thumbnail ?? this.thumbnail,
        activeToolIndex: activeToolIndex ?? this.activeToolIndex,
        errorMessage: errorMessage ?? this.errorMessage,
        imageSizeLabel: imageSizeLabel ?? this.imageSizeLabel,
        tone: tone ?? this.tone,
        histogram: histogram ?? this.histogram,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
        activePresetId: activePresetId ?? this.activePresetId,
        projectId: projectId ?? this.projectId,
      );

  EditorImageState cleared() => const EditorImageState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class EditorImageNotifier extends StateNotifier<EditorImageState> {
  EditorImageNotifier(
    this._pickerService,
    this._cache,
    this._galleryNotifier,
  ) : super(const EditorImageState());

  final ImagePickerService _pickerService;
  final ImageCacheService  _cache;
  final GalleryNotifier    _galleryNotifier;

  // Cancel token — incremented each time a new pick/load starts.
  int _token = 0;

  // Histogram debounce timer — avoids recomputing on every slider tick.
  Timer? _histogramTimer;
  // Autosave debounce timer
  Timer? _autoSaveTimer;

  // ── Undo / Redo history ───────────────────────────────────────────
  final List<_AdjustSnapshot> _undoStack = [];
  final List<_AdjustSnapshot> _redoStack = [];

  _AdjustSnapshot get _snapshot => _AdjustSnapshot(tone: state.tone);

  /// Call this BEFORE applying a change to record the previous state.
  void commitToHistory() {
    _undoStack.add(_snapshot);
    _redoStack.clear();
    state = state.copyWith(canUndo: true, canRedo: false);
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_snapshot);
    final prev = _undoStack.removeLast();
    state = state.copyWith(
      tone: prev.tone,
      canUndo: _undoStack.isNotEmpty,
      canRedo: true,
    );
    _scheduleHistogramUpdate();
    _scheduleAutoSave();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_snapshot);
    final next = _redoStack.removeLast();
    state = state.copyWith(
      tone: next.tone,
      canUndo: true,
      canRedo: _redoStack.isNotEmpty,
    );
    _scheduleHistogramUpdate();
    _scheduleAutoSave();
  }

  // ── Tone setters (non-destructive) ────────────────────────────────

  void updateTone(ToneParams t) {
    if (!mounted) return;
    state = state.copyWith(tone: t);
    _scheduleHistogramUpdate();
    _scheduleAutoSave();
  }

  void setExposure(double v)    => updateTone(state.tone.copyWith(exposure: v));
  void setBrightness(double v)  => updateTone(state.tone.copyWith(brightness: v));
  void setContrast(double v)    => updateTone(state.tone.copyWith(contrast: v));
  void setHighlights(double v)  => updateTone(state.tone.copyWith(highlights: v));
  void setShadows(double v)     => updateTone(state.tone.copyWith(shadows: v));
  void setWhites(double v)      => updateTone(state.tone.copyWith(whites: v));
  void setBlacks(double v)      => updateTone(state.tone.copyWith(blacks: v));
  void setBlackPoint(double v)  => updateTone(state.tone.copyWith(blackPoint: v));
  void setFade(double v)        => updateTone(state.tone.copyWith(fade: v));
  void setBrilliance(double v)  => updateTone(state.tone.copyWith(brilliance: v));
  void setClarity(double v)     => updateTone(state.tone.copyWith(clarity: v));
  
  void setSharpen(double v)     => updateTone(state.tone.copyWith(sharpen: v));
  void setTexture(double v)     => updateTone(state.tone.copyWith(texture: v));
  void setLumaNR(double v)      => updateTone(state.tone.copyWith(luminanceNoiseReduction: v));
  void setColorNR(double v)     => updateTone(state.tone.copyWith(colorNoiseReduction: v));
  void setGrain(double v)       => updateTone(state.tone.copyWith(grain: v));

  void setSaturation(double v)  => updateTone(state.tone.copyWith(saturation: v));
  void setVibrance(double v)    => updateTone(state.tone.copyWith(vibrance: v));
  void setWarmth(double v)      => updateTone(state.tone.copyWith(warmth: v));
  void setVintage(bool v) {
    commitToHistory();
    updateTone(state.tone.copyWith(isVintage: v));
  }
  void resetTone() {
    commitToHistory();
    state = state.copyWith(activePresetId: 'none');
    updateTone(const ToneParams());
  }

  /// Applies a [FilterPreset] from the catalog, recording history.
  void applyPreset(FilterPreset preset) {
    commitToHistory();
    state = state.copyWith(activePresetId: preset.id);
    updateTone(preset.params);
  }

  // ── Auto Brightness ───────────────────────────────────────────────

  void autoCorrect() {
    final hist = state.histogram;
    if (hist == null) return;
    commitToHistory();
    final corrected = AutoBrightnessAnalyzer.mergeInto(state.tone, hist);
    updateTone(corrected);
  }

  // ── Histogram computation ─────────────────────────────────────────

  /// Schedule a histogram re-compute 300ms after the last tone change.
  void _scheduleHistogramUpdate() {
    _histogramTimer?.cancel();
    _histogramTimer = Timer(const Duration(milliseconds: 300), _recomputeHistogram);
  }

  Future<void> _recomputeHistogram() async {
    final img = state.displayImage;
    if (img == null || !mounted) return;
    final result = await HistogramComputer.compute(img);
    if (!mounted) return;
    state = state.copyWith(histogram: result);
  }

  // ── Auto-save ─────────────────────────────────────────────────────

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1000), _executeAutoSave);
  }

  Future<void> _executeAutoSave() async {
    if (!mounted || state.sourceFile == null || state.projectId == null) return;
    try {
      await _galleryNotifier.addProject(
        id: state.projectId,
        imagePath: state.sourceFile!.path,
        thumbnail: state.thumbnail ?? Uint8List(0),
        toneParams: state.tone,
      );
    } catch (_) {}
  }

  // ── Public methods ────────────────────────────────────────────────

  Future<void> pickFromGallery() => _doPick(() => _pickerService.pickFromGallery());
  Future<void> pickFromCamera()  => _doPick(() => _pickerService.pickFromCamera());

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
      _executeAutoSave();
    }
    state = state.copyWith(status: EditorStatus.ready, activeToolIndex: -1);
  }

  Future<void> crop() async {
    if (state.sourceFile == null) return;
    state = state.copyWith(status: EditorStatus.processing, activeToolIndex: 1);

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: state.sourceFile!.path,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop & Rotate',
            toolbarColor: const Color(0xFF141414),
            toolbarWidgetColor: const Color(0xFFFFFFFF),
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false),
        IOSUiSettings(
          title: 'Crop & Rotate',
        ),
      ],
    );

    if (!mounted) return;

    if (croppedFile != null) {
      final newFile = File(croppedFile.path);
      await _loadFileIntoState(newFile);
      _executeAutoSave();
    }
    state = state.copyWith(status: EditorStatus.ready, activeToolIndex: -1);
  }

  void setActiveTool(int index) {
    if (!mounted) return;
    state = state.copyWith(activeToolIndex: index == state.activeToolIndex ? -1 : index);
  }

  void clear() {
    _token++;
    _histogramTimer?.cancel();
    _autoSaveTimer?.cancel();
    state = state.cleared();
  }

  /// Loads an image from an existing [filePath] (e.g. deep-linked from home or projects).
  Future<void> loadFromPath(String filePath) async {
    // Grab a token so an in-flight pick or previous load can be cancelled.
    final token = ++_token;
    state = state.copyWith(status: EditorStatus.loading);
    await _loadFileIntoState(File(filePath), token: token);
    // If still our token and load silently fell through, reset to idle.
    if (mounted && _token == token && state.status == EditorStatus.loading) {
      state = state.copyWith(status: EditorStatus.idle);
    }
  }

  /// Loads a [GalleryProject], restoring its image AND all saved adjustments.
  Future<void> loadFromProject(GalleryProject project) async {
    final token = ++_token;
    state = state.copyWith(status: EditorStatus.loading, projectId: project.id, thumbnail: project.thumbnail);
    await _loadFileIntoState(File(project.imagePath), token: token);
    // Restore saved tone params if the load succeeded with our token.
    if (mounted && _token == token && state.status == EditorStatus.ready) {
      // Find matching preset id if the tone matches a known preset.
      final matchedPresetId = kBuiltInPresets
          .where((p) => p.params == project.toneParams)
          .map((p) => p.id)
          .firstOrNull ?? 'none';
      state = state.copyWith(
        tone: project.toneParams,
        activePresetId: matchedPresetId,
      );
    } else if (mounted && _token == token && state.status == EditorStatus.loading) {
      state = state.copyWith(status: EditorStatus.idle);
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────

  Future<void> _doPick(Future<PickResult> Function() picker) async {
    final token = ++_token;
    state = state.copyWith(status: EditorStatus.picking);

    final result = await picker();

    // If a newer pick/load started while the picker was open, discard result
    // but ALWAYS reset status so the UI is never left stuck on 'opening gallery'.
    if (!mounted || token != _token) {
      if (mounted) state = state.copyWith(status: EditorStatus.idle);
      return;
    }

    switch (result) {
      case PickSuccess(:final file, :final thumbnail):
        state = state.copyWith(
          status: EditorStatus.loading,
          thumbnail: thumbnail,
        );
        if (thumbnail != null) {
          final newProjectId = await _galleryNotifier.addProject(
            imagePath: file.path,
            thumbnail: thumbnail,
          );
          if (mounted && token == _token) {
            state = state.copyWith(projectId: newProjectId);
          }
        }
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

    final cacheKey = file.path;
    final cached = _cache.getMemory(cacheKey); // returns a caller-owned clone
    if (cached != null) {
      if (!mounted || myToken != _token) {
        cached.dispose();
        return;
      }
      final size = await _sizeLabel(file);
      if (!mounted || myToken != _token) {
        cached.dispose();
        return;
      }
      state = state.copyWith(
        status: EditorStatus.ready,
        sourceFile: file,
        displayImage: cached, // already a fresh clone from getMemory — use directly
        imageSizeLabel: size,
        thumbnail: thumbnail ?? state.thumbnail,
      );
      _scheduleHistogramUpdate();
      return;
    }

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
      image.dispose();
      return;
    }

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
    _scheduleHistogramUpdate();
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
    _histogramTimer?.cancel();
    _autoSaveTimer?.cancel();
    state.displayImage?.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final editorImageProvider =
    StateNotifierProvider.autoDispose<EditorImageNotifier, EditorImageState>((ref) {
  return EditorImageNotifier(
    ref.watch(imagePickerServiceProvider),
    ref.watch(imageCacheServiceProvider),
    ref.read(galleryProvider.notifier),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.imagePath, this.projectId});

  final String? imagePath;
  final String? projectId;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool _comparing = false;

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final project = ref.read(galleryProvider).firstWhere(
              (p) => p.id == widget.projectId,
              orElse: () => throw StateError('Project missing'),
            );
        ref.read(editorImageProvider.notifier).loadFromProject(project);
      });
    } else if (widget.imagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(editorImageProvider.notifier).loadFromPath(widget.imagePath!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorImageProvider);
    final notifier = ref.read(editorImageProvider.notifier);
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    // padding.bottom is the correct value to use here — it returns 0 on
    // physical-button devices (app already ends before the bar) and returns
    // the real gesture-nav inset on modern devices. No fake fallback needed.
    final bottomPad = mq.padding.bottom;
    final hasPanel = state.activeToolIndex >= 0 && state.hasImage;
    final hasAdjustOrFilter = state.hasImage && (state.activeToolIndex == 2 || state.activeToolIndex == 3);
    final topBarHeight = topPad + 48.0;
    final bottomPanelHeight = (mq.size.height * 0.37) - topBarHeight;
    ref.listen<EditorImageState>(editorImageProvider, (prev, next) {
      if (next.status == EditorStatus.error && next.errorMessage != null) {
        _showErrorSnack(context, next.errorMessage!);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Column(
        children: [
          // ── Top Bar ──────────────────────────────────────────────
          _EditorAppBar(
            topPad: topPad,
            state: state,
            onClear: notifier.clear,
            onClose: () => context.pop(),
            onUndo: notifier.undo,
            onRedo: notifier.redo,
            onReset: notifier.resetTone,
          ),

          // ── Image Area + floating export ─────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Image / Status content
                Positioned.fill(
                  child: _buildBody(state, notifier),
                ),

                // Floating Export button — only when image loaded & no panel open
                if (state.hasImage && !hasPanel)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _FloatingExportButton(
                      isProcessing: state.status == EditorStatus.processing,
                      hasEdit: !state.tone.isNeutral,
                      onTap: () => _onExport(context, state),
                    ),
                  ),


              ],
            ),
          ),

          // ── Bottom Toolbar ────────────────────────────────────────
          if (state.hasImage)
            hasAdjustOrFilter
                ? SizedBox(
                    height: bottomPanelHeight,
                    child: _EditorToolbar(
                      bottomPad: bottomPad,
                      activeIndex: state.activeToolIndex,
                      isProcessing: state.status == EditorStatus.processing,
                      customPanel: state.activeToolIndex == 2
                          ? _AdjustPanel(
                              state: state,
                              notifier: notifier,
                              bottomPad: bottomPad,
                            )
                          : state.activeToolIndex == 3
                              ? _FilterPanel(
                                  state: state,
                                  notifier: notifier,
                                  bottomPad: bottomPad,
                                )
                              : null,
                      onCompress: notifier.compress,
                      onCrop: notifier.crop,
                      onAdjust: () => notifier.setActiveTool(2),
                      onFilter: () => notifier.setActiveTool(3),
                      onText: () => notifier.setActiveTool(4),
                    ),
                  )
                : _EditorToolbar(
                    bottomPad: bottomPad,
                    activeIndex: state.activeToolIndex,
                    isProcessing: state.status == EditorStatus.processing,
                    customPanel: null,
                    onCompress: notifier.compress,
                    onCrop: notifier.crop,
                    onAdjust: () => notifier.setActiveTool(2),
                    onFilter: () => notifier.setActiveTool(3),
                    onText: () => notifier.setActiveTool(4),
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
        EditorStatus.ready when state.hasImage => _ImagePreview(
            key: ValueKey(state.sourceFile!.path),
            state: state,
            isComparing: _comparing,
            onCompare: (val) {
              if (mounted) setState(() => _comparing = val);
            },
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
            onPickFromProjects: () => _showProjectsModal(context, notifier),
            onShowImportOptions: () => _showImportOptions(context, notifier),
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


  Future<void> _showImportOptions(BuildContext context, EditorImageNotifier notifier) async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.accentPurple),
              title: const Text('Device Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'GALLERY'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.accentCyan),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'CAMERA'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_special_rounded, color: Colors.amber),
              title: const Text('Recent Projects', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'PROJECTS'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (selection == 'GALLERY') notifier.pickFromGallery();
    if (selection == 'CAMERA') notifier.pickFromCamera();
    if (selection == 'PROJECTS' && mounted) _showProjectsModal(context, notifier);
  }

  Future<void> _showProjectsModal(BuildContext context, EditorImageNotifier notifier) async {
    final projects = ref.read(galleryProvider);
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No saved projects found.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Select from Projects', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.7,
                ),
                itemCount: projects.length,
                itemBuilder: (context, i) {
                  final p = projects[i];
                  return GestureDetector(
                    onTap: () {
                      notifier.loadFromProject(p);  // restores path + tone
                      Navigator.pop(ctx);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.white10,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(p.thumbnail, fit: BoxFit.cover),
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                  ),
                                ),
                                child: Text(
                                  p.type == 'template' ? 'Story' : 'Photo',
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Exports the image at its original pixel dimensions with ALL ToneParams applied.
  /// Uses ToneEngine.buildFilter() — same engine as the live preview — so what you
  /// see on screen is exactly what gets exported.
  Future<void> _onExport(BuildContext context, EditorImageState state) async {
    if (state.displayImage == null || state.sourceFile == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting…'), duration: Duration(seconds: 10)),
      );

      final src = state.displayImage!;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      if (!state.tone.isNeutral) {
        // Build the complete ColorFilter (all 24+ params via ToneEngine matrix)
        final cf = ToneEngine.buildFilter(state.tone);
        final paint = Paint()..colorFilter = cf;
        canvas.drawImage(src, Offset.zero, paint);
      } else {
        canvas.drawImage(src, Offset.zero, Paint());
      }

      final picture = recorder.endRecording();
      final exportImage = await picture.toImage(src.width, src.height);
      final byteData = await exportImage.toByteData(format: ui.ImageByteFormat.png);
      exportImage.dispose();
      final pngBytes = byteData!.buffer.asUint8List();

      final success = await ref.read(exportServiceProvider).saveImageToGallery(pngBytes);

      // Also update the project record so it reflects the exported edits.
      if (success) {
        ref.read(galleryProvider.notifier).addProject(
          id: state.projectId,
          imagePath: state.sourceFile!.path,
          thumbnail: state.thumbnail ?? pngBytes,
          toneParams: state.tone,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Exported to Gallery! ✓' : 'Failed to save to Gallery!'),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

// ── App Bar ───────────────────────────────────────────────────────────────────

class _EditorAppBar extends StatelessWidget {
  const _EditorAppBar({
    required this.topPad,
    required this.state,
    required this.onClear,
    required this.onClose,
    required this.onUndo,
    required this.onRedo,
    required this.onReset,
  });

  final double topPad;
  final EditorImageState state;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080808),
      padding: EdgeInsets.only(top: topPad + 2, left: 4, right: 8, bottom: 2),
      child: Row(
        children: [
          // Close
          _NavIconBtn(icon: Icons.close_rounded, onTap: onClose),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: const Icon(Icons.auto_fix_high_rounded, size: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  'Editor',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                if (state.imageSizeLabel != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      state.imageSizeLabel!,
                      style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right actions
          if (state.hasImage) ...[
            _NavIconBtn(
              icon: Icons.settings_backup_restore_rounded,
              onTap: !state.tone.isNeutral ? onReset : null,
              dimmed: state.tone.isNeutral,
            ),
            const SizedBox(width: 4),
            _NavIconBtn(
              icon: Icons.undo_rounded,
              onTap: state.canUndo ? onUndo : null,
              dimmed: !state.canUndo,
            ),
            const SizedBox(width: 4),
            _NavIconBtn(
              icon: Icons.redo_rounded,
              onTap: state.canRedo ? onRedo : null,
              dimmed: !state.canRedo,
            ),
            const SizedBox(width: 4),
            _NavIconBtn(icon: Icons.more_vert_rounded, onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF141414),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(width: 36, height: 3,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        title: const Text('Clear Image', style: TextStyle(color: Colors.white, fontSize: 14)),
                        onTap: () { Navigator.pop(context); onClear(); },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            }),
          ] else ...
            const [SizedBox(width: 44)],
        ],
      ),
    );
  }
}

class _NavIconBtn extends StatelessWidget {
  const _NavIconBtn({required this.icon, required this.onTap, this.dimmed = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: dimmed ? 0.35 : 1.0,
        child: SizedBox(
          width: 44, height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ── Image Preview ─────────────────────────────────────────────────────────────

class _ImagePreview extends StatefulWidget {
  const _ImagePreview({super.key, required this.state, this.isComparing = false, this.onCompare});
  final EditorImageState state;
  final bool isComparing;
  final ValueChanged<bool>? onCompare;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  Timer? _compareTimer;

  void _startTimer() {
    _compareTimer?.cancel();
    _compareTimer = Timer(const Duration(milliseconds: 200), () {
      widget.onCompare?.call(true);
    });
  }

  void _cancelTimer() {
    _compareTimer?.cancel();
    widget.onCompare?.call(false);
  }

  @override
  void dispose() {
    _compareTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final raw = RawImage(
      image: widget.state.displayImage!,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      width: double.infinity,
      height: double.infinity,
    );
    final Widget image = widget.isComparing || widget.state.tone.isNeutral
        ? raw
        : ShaderPreviewWidget(
            image: widget.state.displayImage!,
            tone: widget.state.tone,
          );

    return GestureDetector(
      onTapDown: (_) => _startTimer(),
      onTapUp: (_) => _cancelTimer(),
      onTapCancel: () => _cancelTimer(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        child: RepaintBoundary(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 8.0,
            child: Center(child: image),
          ),
        ),
      ),
    );
  }
}

// ── Floating Export Button ────────────────────────────────────────────────────

class _FloatingExportButton extends StatefulWidget {
  const _FloatingExportButton({
    required this.isProcessing,
    required this.hasEdit,
    required this.onTap,
  });
  final bool isProcessing;
  final bool hasEdit;
  final VoidCallback onTap;

  @override
  State<_FloatingExportButton> createState() => _FloatingExportButtonState();
}

class _FloatingExportButtonState extends State<_FloatingExportButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTap: widget.isProcessing ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            decoration: BoxDecoration(
              gradient: widget.hasEdit
                  ? AppColors.accentGradient
                  : const LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF1E1E1E)]),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: (widget.hasEdit ? AppColors.accentPurple : Colors.black).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: widget.isProcessing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.ios_share_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('Export', style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      )),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Loading Preview ───────────────────────────────────────────────────────────

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
      decoration: BoxDecoration(color: AppColors.surfaceMid),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.thumbnail != null)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Image.memory(
                widget.thumbnail!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
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
          Center(
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              borderRadius: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36, height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPurple),
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
    );
  }
}

// ── Empty Preview ─────────────────────────────────────────────────────────────

class _EmptyPreview extends StatefulWidget {
  const _EmptyPreview({
    super.key,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onPickFromProjects,
    required this.onShowImportOptions,
  });

  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onPickFromProjects;
  final VoidCallback onShowImportOptions;

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
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
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
            ScaleTransition(
              scale: _scale,
              child: GestureDetector(
                onTap: widget.onShowImportOptions,
                child: Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentPurple.withValues(alpha: 0.15),
                        AppColors.accentCyan.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: ShaderMask(
                    shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                    blendMode: BlendMode.srcIn,
                    child: const Icon(Icons.add_photo_alternate_outlined, size: 64),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('No image selected',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Pick a photo to start editing',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 40),
            Column(
              children: [
                _PickButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Open Gallery',
                  gradient: AppColors.accentGradient,
                  onTap: widget.onPickGallery,
                  fullWidth: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _PickButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF007AFF)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        onTap: widget.onPickCamera, fullWidth: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _PickButton(
                        icon: Icons.folder_special_rounded,
                        label: 'Projects',
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFA000), Color(0xFFFF6F00)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        onTap: widget.onPickFromProjects, fullWidth: true,
                      ),
                    ),
                  ],
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
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
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
                width: 44, height: 44,
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error Preview ─────────────────────────────────────────────────────────────

class _ErrorPreview extends StatelessWidget {
  const _ErrorPreview({super.key, required this.message, required this.onRetry});
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
            const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            PressableCard(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(12)),
                child: const Text('Try again',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
    required this.bottomPad,
    this.customPanel,
  });

  final Widget? customPanel;
  final int activeIndex;
  final bool isProcessing;
  final double bottomPad;
  final VoidCallback onCompress;
  final VoidCallback onCrop;
  final VoidCallback onAdjust;
  final VoidCallback onFilter;
  final VoidCallback onText;

  @override
  Widget build(BuildContext context) {
    // Secondary panel in place of toolbar
    if (customPanel != null) {
      return Container(
        color: const Color(0xFF0A0A0A),
        child: customPanel!,
      );
    }

    final tools = [
      _Tool(Icons.compress_rounded, 'Compress', onCompress),
      _Tool(Icons.crop_rounded, 'Crop', onCrop),
      _Tool(Icons.tune_rounded, 'Adjust', onAdjust),
      _Tool(Icons.filter_rounded, 'Filter', onFilter),
      _Tool(Icons.text_fields_rounded, 'Text', onText),
    ];

    return Container(
      color: const Color(0xFF0A0A0A),
      // top divider
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(tools.length, (i) => _ToolButton(
                tool: tools[i],
                isActive: activeIndex == i,
                isDisabled: isProcessing,
              )),
            ),
          ),
          SizedBox(height: bottomPad),
        ],
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
  const _ToolButton({required this.tool, required this.isActive, required this.isDisabled});
  final _Tool tool;
  final bool isActive;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : tool.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.35 : 1.0,
        child: SizedBox(
          width: 64,
          height: 70,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isActive
                      ? ShaderMask(
                          shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                          blendMode: BlendMode.srcIn,
                          child: Icon(tool.icon, size: 22),
                        )
                      : Icon(tool.icon, size: 22, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tool.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? Colors.white : Colors.white54,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Adjust Panel ──────────────────────────────────────────────────────────────

class _AdjustPanel extends StatefulWidget {
  const _AdjustPanel({required this.state, required this.notifier, required this.bottomPad});
  final EditorImageState state;
  final EditorImageNotifier notifier;
  final double bottomPad;

  @override
  State<_AdjustPanel> createState() => _AdjustPanelState();
}

class _AdjustPanelState extends State<_AdjustPanel> {
  int _categoryIndex = 0;

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Light', 'icon': Icons.light_mode_rounded},
    {'label': 'Color', 'icon': Icons.color_lens_rounded},
    {'label': 'HSL', 'icon': Icons.tune_rounded},
    {'label': 'Details', 'icon': Icons.change_history_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final tone = widget.state.tone;
    final notifier = widget.notifier;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Sliders Area — compact to give image maximum height
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              children: [
                if (_categoryIndex == 0) ...[
                  PrequelSlider(label: 'Exposure', value: tone.exposure, onChanged: notifier.setExposure, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Brightness', value: tone.brightness, onChanged: notifier.setBrightness, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Contrast', value: tone.contrast, onChanged: notifier.setContrast, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Highlights', value: tone.highlights, onChanged: notifier.setHighlights, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Shadows', value: tone.shadows, onChanged: notifier.setShadows, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Whites', value: tone.whites, onChanged: notifier.setWhites, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Blacks', value: tone.blacks, onChanged: notifier.setBlacks, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Black Point', value: tone.blackPoint, onChanged: notifier.setBlackPoint, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Fade', value: tone.fade, onChanged: notifier.setFade, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Brilliance', value: tone.brilliance, onChanged: notifier.setBrilliance, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Clarity', value: tone.clarity, onChanged: notifier.setClarity, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                ] else if (_categoryIndex == 1) ...[
                  PrequelSlider(label: 'Saturation', value: tone.saturation, onChanged: notifier.setSaturation, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Vibrance', value: tone.vibrance, onChanged: notifier.setVibrance, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Warmth', value: tone.warmth, onChanged: notifier.setWarmth, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                ] else if (_categoryIndex == 2) ...[
                  HslPanel(
                    toneParams: tone,
                    onChanged: (newTone) {
                      notifier.updateTone(newTone);
                    },
                  ),
                ] else if (_categoryIndex == 3) ...[
                  PrequelSlider(label: 'Sharpen', value: tone.sharpen, onChanged: notifier.setSharpen, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Texture', value: tone.texture, onChanged: notifier.setTexture, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Luma NR', value: tone.luminanceNoiseReduction, onChanged: notifier.setLumaNR, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Color NR', value: tone.colorNoiseReduction, onChanged: notifier.setColorNR, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                  PrequelSlider(label: 'Grain', value: tone.grain, onChanged: notifier.setGrain, onChangeStart: notifier.commitToHistory, onChangeEnd: (){}),
                ] else ...[
                  const SizedBox(height: 80),
                  const Center(child: Text('Coming Soon', style: TextStyle(color: Colors.white54, fontSize: 13))),
                ],
              ],
            ),
          ),

          // Secondary Tab Ribbon — pinned at bottom with safe-area padding
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x1FFFFFFF), width: 1)),
            ),
            padding: EdgeInsets.only(bottom: widget.bottomPad),
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  // Back Button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () => notifier.setActiveTool(-1),
                  ),
                  Container(width: 1, height: 24, color: Colors.white24),
                  // Categories
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _categories.length,
                      itemBuilder: (context, i) {
                        final cat = _categories[i];
                        final isActive = i == _categoryIndex;
                        final clr = isActive ? AppColors.accentCyan : Colors.white54;
                        return GestureDetector(
                          onTap: () => setState(() => _categoryIndex = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            color: Colors.transparent,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(cat['icon'] as IconData, color: clr, size: 22),
                                const SizedBox(height: 4),
                                Text(cat['label'] as String, style: TextStyle(color: clr, fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Panel ──────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.state,
    required this.notifier,
    required this.bottomPad,
  });
  final EditorImageState state;
  final EditorImageNotifier notifier;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                  onPressed: () => notifier.setActiveTool(-1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                const Text(
                  'FILTERS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                // Count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${kBuiltInPresets.length} presets',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // ── Preset strip ─────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPad + 10),
              physics: const BouncingScrollPhysics(),
              itemCount: kBuiltInPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final preset = kBuiltInPresets[i];
                final isSelected = state.activePresetId == preset.id;
                return _PresetCard(
                  preset: preset,
                  image: state.displayImage,
                  isSelected: isSelected,
                  onTap: () => notifier.applyPreset(preset),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Preset Card ───────────────────────────────────────────────────────────────

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.isSelected,
    required this.onTap,
    this.image,
  });

  final FilterPreset preset;
  final ui.Image? image;
  final bool isSelected;
  final VoidCallback onTap;

  static const double _thumbSize = 76;

  @override
  Widget build(BuildContext context) {
    // Build the thumbnail — ColorFiltered preview of the user's image.
    // Falls back to a gradient placeholder when no image is loaded yet.
    Widget thumb;
    if (image != null) {
      final filter = ToneEngine.buildFilter(preset.params);
      Widget raw = RawImage(
        image: image!,
        width: _thumbSize,
        height: _thumbSize,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
      );
      thumb = preset.id == 'none'
          ? raw
          : ColorFiltered(colorFilter: filter, child: raw);
    } else {
      // No image yet — show a gradient swatch
      thumb = Container(
        width: _thumbSize,
        height: _thumbSize,
        decoration: BoxDecoration(
          gradient: preset.isPremium
              ? AppColors.accentGradient
              : const LinearGradient(
                  colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: Center(
          child: Icon(
            Icons.photo_filter_rounded,
            color: Colors.white.withValues(alpha: 0.4),
            size: 28,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _thumbSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail with selection ring
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _thumbSize,
              height: _thumbSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentPurple
                      : Colors.white.withValues(alpha: 0.06),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accentPurple.withValues(alpha: 0.45),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.5),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    thumb,
                    // Premium badge
                    if (preset.isPremium)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    // Selected checkmark
                    if (isSelected)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.accentPurple,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 4)
                            ],
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 7),

            // Label
            Text(
              preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 10.5,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pressable Card ────────────────────────────────────────────────────────────

class PressableCard extends StatefulWidget {
  const PressableCard({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
