import 'dart:convert';

/// Plain-Dart model representing one completed conversion.
/// Stored as JSON via SharedPreferences — zero codegen required.
class ConversionRecord {
  ConversionRecord({
    required this.id,
    required this.inputFileName,
    required this.inputPath,
    required this.outputPath,
    required this.inputFormat,
    required this.outputFormat,
    required this.fileSizeBytes,
    required this.convertedAt,
    required this.categoryName,
    this.isFavorite = false,
    this.thumbnailPath,
    this.durationMs,
  });

  final String id;
  final String inputFileName;
  final String inputPath;
  final String outputPath;
  final String inputFormat;
  final String outputFormat;
  final int fileSizeBytes;
  final DateTime convertedAt;
  final String categoryName;
  final bool isFavorite;
  final String? thumbnailPath;
  final int? durationMs;

  // ── Computed helpers ───────────────────────────────────────────────────────

  String get outputFileName => outputPath.split('/').last;

  String get displaySize {
    if (fileSizeBytes < 1024) return '${fileSizeBytes}B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isImage => categoryName == 'image';
  bool get isPdf => categoryName == 'pdf';
  bool get isDocument => categoryName == 'document';

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'inputFileName': inputFileName,
        'inputPath': inputPath,
        'outputPath': outputPath,
        'inputFormat': inputFormat,
        'outputFormat': outputFormat,
        'fileSizeBytes': fileSizeBytes,
        'convertedAt': convertedAt.toIso8601String(),
        'categoryName': categoryName,
        'isFavorite': isFavorite,
        'thumbnailPath': thumbnailPath,
        'durationMs': durationMs,
      };

  factory ConversionRecord.fromJson(Map<String, dynamic> json) =>
      ConversionRecord(
        id: json['id'] as String,
        inputFileName: json['inputFileName'] as String,
        inputPath: json['inputPath'] as String,
        outputPath: json['outputPath'] as String,
        inputFormat: json['inputFormat'] as String,
        outputFormat: json['outputFormat'] as String,
        fileSizeBytes: json['fileSizeBytes'] as int,
        convertedAt: DateTime.parse(json['convertedAt'] as String),
        categoryName: json['categoryName'] as String,
        isFavorite: json['isFavorite'] as bool? ?? false,
        thumbnailPath: json['thumbnailPath'] as String?,
        durationMs: json['durationMs'] as int?,
      );

  static String encode(List<ConversionRecord> records) =>
      jsonEncode(records.map((r) => r.toJson()).toList());

  static List<ConversionRecord> decode(String source) {
    final list = jsonDecode(source) as List<dynamic>;
    return list
        .map((e) => ConversionRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  ConversionRecord copyWith({bool? isFavorite}) => ConversionRecord(
        id: id,
        inputFileName: inputFileName,
        inputPath: inputPath,
        outputPath: outputPath,
        inputFormat: inputFormat,
        outputFormat: outputFormat,
        fileSizeBytes: fileSizeBytes,
        convertedAt: convertedAt,
        categoryName: categoryName,
        isFavorite: isFavorite ?? this.isFavorite,
        thumbnailPath: thumbnailPath,
        durationMs: durationMs,
      );
}
