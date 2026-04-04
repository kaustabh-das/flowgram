import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/glass_card.dart';

// ── Provider ───────────────────────────────────────────────────────────────

final editorImageProvider =
    StateNotifierProvider<EditorImageNotifier, EditorImageState>(
  (_) => EditorImageNotifier(),
);

class EditorImageState {
  const EditorImageState({
    this.file,
    this.thumbnail,
    this.isProcessing = false,
    this.activeToolIndex = -1,
  });

  final File? file;
  final Uint8List? thumbnail;
  final bool isProcessing;
  final int activeToolIndex;

  EditorImageState copyWith({
    File? file,
    Uint8List? thumbnail,
    bool? isProcessing,
    int? activeToolIndex,
  }) =>
      EditorImageState(
        file: file ?? this.file,
        thumbnail: thumbnail ?? this.thumbnail,
        isProcessing: isProcessing ?? this.isProcessing,
        activeToolIndex: activeToolIndex ?? this.activeToolIndex,
      );
}

class EditorImageNotifier extends StateNotifier<EditorImageState> {
  EditorImageNotifier() : super(const EditorImageState());

  Future<void> pickFromGallery() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) return;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;

    state = state.copyWith(isProcessing: true);
    final file = File(xFile.path);
    final thumb = await ImageUtils.createThumbnail(file);
    state = EditorImageState(file: file, thumbnail: thumb);
  }

  Future<void> compress() async {
    if (state.file == null) return;
    state = state.copyWith(isProcessing: true, activeToolIndex: 0);
    final compressed = await ImageUtils.compress(
      state.file!,
      quality: AppSizes.compressQuality,
    );
    if (compressed != null) {
      state = state.copyWith(
        file: File(compressed.path),
        isProcessing: false,
        activeToolIndex: -1,
      );
    } else {
      state = state.copyWith(isProcessing: false, activeToolIndex: -1);
    }
  }

  void setActiveTool(int index) =>
      state = state.copyWith(activeToolIndex: index);

  void clear() => state = const EditorImageState();
}

// ── Screen ─────────────────────────────────────────────────────────────────

class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key, this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editorState = ref.watch(editorImageProvider);
    final notifier = ref.read(editorImageProvider.notifier);
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Background gradient ─────────────────────────────────
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
                hasImage: editorState.file != null,
                onClear: notifier.clear,
              ),

              // ── Preview area ─────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: editorState.isProcessing
                      ? const _ProcessingOverlay(key: ValueKey('proc'))
                      : editorState.file != null
                          ? _PreviewArea(
                              key: ValueKey(editorState.file!.path),
                              file: editorState.file!,
                            )
                          : _EmptyPreview(
                              key: const ValueKey('empty'),
                              onPick: notifier.pickFromGallery,
                            ),
                ),
              ),

              // ── Toolbar ──────────────────────────────────────────
              if (editorState.file != null)
                _EditorToolbar(
                  activeIndex: editorState.activeToolIndex,
                  onCompress: notifier.compress,
                  onCrop: () => notifier.setActiveTool(1),
                  onAdjust: () => notifier.setActiveTool(2),
                  onFilter: () => notifier.setActiveTool(3),
                  onText: () => notifier.setActiveTool(4),
                  onExport: () {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── App Bar ─────────────────────────────────────────────────────────────────

class _EditorAppBar extends StatelessWidget {
  const _EditorAppBar({
    required this.topPad,
    required this.hasImage,
    required this.onClear,
  });

  final double topPad;
  final bool hasImage;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPad + 8, left: 16, right: 16, bottom: 8),
      child: Row(
        children: [
          // Icon logo
          ShaderMask(
            shaderCallback: (b) => AppColors.accentGradient.createShader(b),
            blendMode: BlendMode.srcIn,
            child: const Icon(Icons.auto_fix_high_rounded, size: 26),
          ),
          const SizedBox(width: 10),
          Text(
            'Editor',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
          const Spacer(),
          if (hasImage) ...[
            _AppBarButton(
              icon: Icons.undo_rounded,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            _AppBarButton(
              icon: Icons.redo_rounded,
              onTap: () {},
            ),
            const SizedBox(width: 8),
            _AppBarButton(
              icon: Icons.delete_outline_rounded,
              onTap: onClear,
            ),
          ],
        ],
      ),
    );
  }
}

class _AppBarButton extends StatelessWidget {
  const _AppBarButton({required this.icon, required this.onTap});
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

// ── Preview Area ─────────────────────────────────────────────────────────────

class _PreviewArea extends StatelessWidget {
  const _PreviewArea({super.key, required this.file});
  final File file;

  @override
  Widget build(BuildContext context) {
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
        child: InteractiveViewer(
          child: Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}

// ── Empty Preview ────────────────────────────────────────────────────────────

class _EmptyPreview extends StatefulWidget {
  const _EmptyPreview({super.key, required this.onPick});
  final VoidCallback onPick;

  @override
  State<_EmptyPreview> createState() => _EmptyPreviewState();
}

class _EmptyPreviewState extends State<_EmptyPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: GestureDetector(
              onTap: widget.onPick,
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
                  shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                  blendMode: BlendMode.srcIn,
                  child: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No image selected',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to import from gallery',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          PressableCard(
            onTap: widget.onPick,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentPurple.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Choose Photo',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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

// ── Processing overlay ───────────────────────────────────────────────────────

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPurple),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Processing...',
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

// ── Editor Toolbar ────────────────────────────────────────────────────────────

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.activeIndex,
    required this.onCompress,
    required this.onCrop,
    required this.onAdjust,
    required this.onFilter,
    required this.onText,
    required this.onExport,
  });

  final int activeIndex;
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
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Export button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PressableCard(
                  onTap: onExport,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentPurple.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ios_share_rounded, color: Colors.white, size: 18),
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
  const _ToolButton({required this.tool, required this.isActive});

  final _Tool tool;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tool.onTap,
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
                      key: const ValueKey('active'),
                      shaderCallback: (b) =>
                          AppColors.accentGradient.createShader(b),
                      blendMode: BlendMode.srcIn,
                      child: Icon(tool.icon, size: 24),
                    )
                  : Icon(
                      key: const ValueKey('inactive'),
                      tool.icon,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              tool.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color:
                    isActive ? AppColors.accentPurple : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
