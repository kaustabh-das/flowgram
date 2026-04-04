/// App-wide string constants.
abstract class AppStrings {
  static const appName = 'Flowgram';

  // ── Nav labels ────────────────────────────────────────────────────
  static const navHome      = 'Home';
  static const navGallery   = 'Gallery';
  static const navEditor    = 'Editor';
  static const navTemplates = 'Templates';

  // ── Home screen ───────────────────────────────────────────────────
  static const homeTitle          = 'Flowgram';
  static const homeSubtitle       = 'Create. Edit. Flow.';
  static const homeCtaGallery     = 'Open Gallery';
  static const homeCtaNew         = 'New Project';

  // ── Gallery screen ────────────────────────────────────────────────
  static const galleryTitle       = 'Gallery';
  static const galleryEmpty       = 'No projects yet.\nTap + to create one.';

  // ── Editor screen ─────────────────────────────────────────────────
  static const editorTitle        = 'Editor';
  static const editorNoImage      = 'No image selected';

  // ── Permissions ───────────────────────────────────────────────────
  static const permGalleryDenied  = 'Gallery permission is required.';
  static const permOpenSettings   = 'Open Settings';

  // ── Errors ────────────────────────────────────────────────────────
  static const errGeneric         = 'Something went wrong. Please try again.';
  static const errImageLoad       = 'Failed to load image.';
}

/// App-wide numeric / spacing constants.
abstract class AppSizes {
  // Spacing
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  // Border radius
  static const double radiusSm  = 8;
  static const double radiusMd  = 12;
  static const double radiusLg  = 16;
  static const double radiusXl  = 24;
  static const double radiusFull= 999;

  // Icon sizes
  static const double iconSm  = 18;
  static const double iconMd  = 24;
  static const double iconLg  = 32;

  // Gallery
  static const int galleryGridCrossAxisCount = 3;
  static const double galleryGridSpacing     = 2;
  static const int thumbnailSize             = 256;

  // Image processing
  static const int compressQuality           = 82;
  static const int compressMinDimension      = 1080;
}
