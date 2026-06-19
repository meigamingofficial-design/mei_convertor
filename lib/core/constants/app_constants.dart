// App-wide constants for Mei Convertor.

/// Asset paths
class MeiAssets {
  const MeiAssets._();

  // Fonts
  static const String fontPlusJakartaSans = 'PlusJakartaSans';

  // Images
  static const String imagesDir = 'assets/images/';
  static const String iconsDir = 'assets/icons/';
  static const String animationsDir = 'assets/animations/';
  static const String logo = '${imagesDir}logo.png';

  // Lottie
  static const String lottieEmpty = 'assets/animations/empty.json';
  static const String lottieSuccess = 'assets/animations/success.json';
  static const String lottieLoading = 'assets/animations/loading.json';
}

/// App-level string constants
class MeiStrings {
  const MeiStrings._();

  static const String appName = 'Mei Convertor';
  static const String tagline = 'Convert anything, offline.';
  static const String version = '1.0.0';
}

/// Duration constants used throughout the app
class MeiDurations {
  const MeiDurations._();

  static const Duration animShort = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 350);
  static const Duration animLong = Duration(milliseconds: 600);
  static const Duration snackbarShow = Duration(seconds: 3);
  static const Duration splashMin = Duration(milliseconds: 1200);
}

/// Supported file format groups
class MeiFormats {
  const MeiFormats._();

  static const List<String> imageExtensions = [
    'jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'tiff', 'heic',
  ];

  static const List<String> pdfExtensions = ['pdf'];

  static const List<String> documentExtensions = [
    'doc', 'docx', 'txt', 'rtf', 'odt', 'md',
  ];

  static const List<String> allExtensions = [
    ...imageExtensions,
    ...pdfExtensions,
    ...documentExtensions,
  ];

  /// Max file size allowed for conversion (50 MB)
  static const int maxFileSizeBytes = 50 * 1024 * 1024;
}
