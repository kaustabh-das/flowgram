import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/image_picker_service.dart';
import 'gallery_provider.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionMode(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete projects?'),
        content: Text('Are you sure you want to delete ${_selectedIds.length} projects?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final notifier = ref.read(galleryProvider.notifier);
    for (final id in _selectedIds) {
      await notifier.removeProject(id);
    }
    _exitSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(galleryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
              ),
              title: Text('${_selectedIds.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                  onPressed: _deleteSelected,
                  tooltip: 'Delete selected',
                ),
              ],
            )
          : AppBar(
              title: const Text('Projects'),
              actions: [
                if (projects.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.checklist_rtl_rounded),
                    onPressed: () {
                      if (projects.isNotEmpty) {
                        setState(() {
                          _isSelectionMode = true;
                        });
                      }
                    },
                    tooltip: 'Select multiple',
                  ),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () async => _pickImage(context, ref),
                  tooltip: 'Add image',
                ),
              ],
            ),
      body: projects.isEmpty
          ? const _EmptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(AppSizes.sm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppSizes.galleryGridCrossAxisCount,
                crossAxisSpacing: AppSizes.galleryGridSpacing,
                mainAxisSpacing: AppSizes.galleryGridSpacing,
              ),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                final isSelected = _selectedIds.contains(project.id);
                
                return _GalleryTile(
                  project: project,
                  isSelectionMode: _isSelectionMode,
                  isSelected: isSelected,
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(project.id);
                    } else {
                      if (project.type == 'template') {
                        context.push(
                          '${AppRoutes.storyEditor}?layoutId=${project.layoutId}&projectId=${project.id}',
                        );
                      } else {
                        context.go(
                          '${AppRoutes.editor}?path=${Uri.encodeComponent(project.imagePath)}',
                        );
                      }
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      _enterSelectionMode(project.id);
                    } else {
                      _toggleSelection(project.id);
                    }
                  },
                );
              },
            ),
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(imagePickerServiceProvider).pickFromGallery();

    switch (result) {
      case PickSuccess(:final file, :final thumbnail):
        if (thumbnail == null) return;
        await ref.read(galleryProvider.notifier).addProject(
              imagePath: file.path,
              thumbnail: thumbnail,
            );

      case PickPermissionDenied():
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(AppStrings.permGalleryDenied),
              action: SnackBarAction(
                label: AppStrings.permOpenSettings,
                onPressed: openAppSettings,
              ),
            ),
          );
        }

      case PickError(:final message):
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $message')),
          );
        }

      case PickCancelled():
        break;
    }
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 72,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            AppStrings.galleryEmpty,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.project,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final GalleryProject project;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            child: Image.memory(
              project.thumbnail,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          
          // Selection overlay
          if (isSelectionMode)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                color: isSelected ? Colors.black54 : Colors.black12,
                border: isSelected 
                    ? Border.all(color: AppColors.accentPurple, width: 3)
                    : null,
              ),
            ),

          // Checkbox indicator
          if (isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.accentPurple : Colors.black26,
                  border: Border.all(
                    color: isSelected ? AppColors.accentPurple : Colors.white,
                    width: 2,
                  ),
                ),
                child: isSelected 
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
