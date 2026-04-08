import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/image_picker_service.dart';
import 'gallery_provider.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(galleryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
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
              itemBuilder: (context, index) => _GalleryTile(
                project: projects[index],
                onTap: () {
                  // TODO: navigate to editor with project path
                },
                onDelete: () =>
                    ref.read(galleryProvider.notifier).removeProject(
                          projects[index].id,
                        ),
              ),
            ),
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    // Delegate entirely to ImagePickerService so that:
    //  1. Permission is requested correctly (photos vs. media).
    //  2. The picked file is COPIED into permanent app storage.
    //  3. A thumbnail is generated on a background isolate.
    final result =
        await ref.read(imagePickerServiceProvider).pickFromGallery();

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
        break; // user cancelled — nothing to do
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
    required this.onTap,
    required this.onDelete,
  });

  final GalleryProject project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _confirmDelete(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Image.memory(
          project.thumbnail,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete project?'),
        content: const Text(
            'This will permanently remove the image from your projects.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
