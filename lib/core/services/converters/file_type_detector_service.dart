/// Supported file categories in Mei Convertor
enum MeiFileCategory {
  image,
  pdf,
  document,
  text,
  unknown,
}

/// A detected file type with metadata
final class MeiFileType {
  const MeiFileType({
    required this.extension,
    required this.mimeType,
    required this.category,
    required this.displayName,
    required this.availableConversions,
  });

  final String extension;
  final String mimeType;
  final MeiFileCategory category;
  final String displayName;
  final List<String> availableConversions;

  bool get isSupported => category != MeiFileCategory.unknown;

  @override
  String toString() => 'MeiFileType($extension, $category)';
}

/// Central file type detection service
/// 
/// All conversion logic depends on this service for routing decisions.
abstract final class FileTypeDetectorService {
  /// Detect file type from a file path
  static MeiFileType detectFromPath(String filePath) {
    final ext = filePath.split('.').last.toLowerCase().trim();
    return _detectFromExtension(ext);
  }

  /// Detect file type from just an extension string
  static MeiFileType detectFromExtension(String extension) {
    return _detectFromExtension(extension.toLowerCase().trim().replaceAll('.', ''));
  }

  /// Get all supported extensions
  static List<String> get supportedExtensions => _registry.keys.toList();

  /// Get supported extensions by category
  static List<String> extensionsForCategory(MeiFileCategory category) {
    return _registry.entries
        .where((e) => e.value.category == category)
        .map((e) => e.key)
        .toList();
  }

  /// Check if a file is supported
  static bool isSupported(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return _registry.containsKey(ext);
  }

  static MeiFileType _detectFromExtension(String ext) {
    return _registry[ext] ??
        const MeiFileType(
          extension: 'unknown',
          mimeType: 'application/octet-stream',
          category: MeiFileCategory.unknown,
          displayName: 'Unknown File',
          availableConversions: [],
        );
  }

  // === File Type Registry ===
  static const Map<String, MeiFileType> _registry = {
    // Images
    'jpg': MeiFileType(
      extension: 'jpg',
      mimeType: 'image/jpeg',
      category: MeiFileCategory.image,
      displayName: 'JPEG Image',
      availableConversions: ['png', 'webp', 'pdf', 'compress', 'resize'],
    ),
    'jpeg': MeiFileType(
      extension: 'jpeg',
      mimeType: 'image/jpeg',
      category: MeiFileCategory.image,
      displayName: 'JPEG Image',
      availableConversions: ['png', 'webp', 'pdf', 'compress', 'resize'],
    ),
    'png': MeiFileType(
      extension: 'png',
      mimeType: 'image/png',
      category: MeiFileCategory.image,
      displayName: 'PNG Image',
      availableConversions: ['jpg', 'webp', 'pdf', 'compress', 'resize'],
    ),
    'webp': MeiFileType(
      extension: 'webp',
      mimeType: 'image/webp',
      category: MeiFileCategory.image,
      displayName: 'WebP Image',
      availableConversions: ['jpg', 'png', 'pdf', 'compress'],
    ),
    'gif': MeiFileType(
      extension: 'gif',
      mimeType: 'image/gif',
      category: MeiFileCategory.image,
      displayName: 'GIF Image',
      availableConversions: ['jpg', 'png', 'webp'],
    ),
    'bmp': MeiFileType(
      extension: 'bmp',
      mimeType: 'image/bmp',
      category: MeiFileCategory.image,
      displayName: 'BMP Image',
      availableConversions: ['jpg', 'png', 'webp', 'pdf'],
    ),
    'heic': MeiFileType(
      extension: 'heic',
      mimeType: 'image/heic',
      category: MeiFileCategory.image,
      displayName: 'HEIC Image',
      availableConversions: ['jpg', 'png', 'pdf'],
    ),

    // PDF
    'pdf': MeiFileType(
      extension: 'pdf',
      mimeType: 'application/pdf',
      category: MeiFileCategory.pdf,
      displayName: 'PDF Document',
      availableConversions: ['compress'],
    ),

    // Documents
    'txt': MeiFileType(
      extension: 'txt',
      mimeType: 'text/plain',
      category: MeiFileCategory.text,
      displayName: 'Text File',
      availableConversions: ['pdf', 'docx'],
    ),
    'docx': MeiFileType(
      extension: 'docx',
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      category: MeiFileCategory.document,
      displayName: 'Word Document',
      availableConversions: ['pdf', 'txt'],
    ),
    'doc': MeiFileType(
      extension: 'doc',
      mimeType: 'application/msword',
      category: MeiFileCategory.document,
      displayName: 'Word Document (Legacy)',
      availableConversions: ['pdf', 'txt'],
    ),
  };
}
