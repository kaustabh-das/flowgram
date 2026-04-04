import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/image_utils.dart';
import 'gallery_provider.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(galleryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.galleryTitle),
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
              ),
            ),
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
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
      return;
    }

    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null || !context.mounted) return;

    final file = File(xFile.path);
    final thumb = await ImageUtils.createThumbnail(
      file,
      size: AppSizes.thumbnailSize,
    );

    if (thumb != null) {
      ref.read(galleryProvider.notifier).addProject(
            imagePath: xFile.path,
            thumbnail: thumb,
          );
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
  const _GalleryTile({required this.project, required this.onTap});

  final GalleryProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
}
