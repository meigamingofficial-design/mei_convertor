/// Base failure class for all domain errors in Mei Convertor.
///
/// All errors that bubble up to the UI layer should be wrapped in a
/// [MeiFailure] so the UI can display them consistently.
sealed class MeiFailure {
  const MeiFailure({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' ($cause)' : ''}';
}

// ── File Failures ─────────────────────────────────────────────────────────────

/// The user tried to open/convert a file that doesn't exist on disk.
final class FileNotFoundFailure extends MeiFailure {
  const FileNotFoundFailure({required super.message, super.cause});
}

/// The selected file is larger than [MeiFormats.maxFileSizeBytes].
final class FileTooLargeFailure extends MeiFailure {
  const FileTooLargeFailure({required super.message, super.cause});
}

/// The file format is not supported by any registered converter.
final class UnsupportedFormatFailure extends MeiFailure {
  const UnsupportedFormatFailure({required super.message, super.cause});
}

// ── Conversion Failures ───────────────────────────────────────────────────────

/// A conversion task failed mid-way (codec error, OOM, etc.)
final class ConversionFailure extends MeiFailure {
  const ConversionFailure({required super.message, super.cause});
}

/// Output could not be written to the target path.
final class OutputWriteFailure extends MeiFailure {
  const OutputWriteFailure({required super.message, super.cause});
}

// ── Storage Failures ──────────────────────────────────────────────────────────

/// Isar database read/write failure.
final class StorageFailure extends MeiFailure {
  const StorageFailure({required super.message, super.cause});
}

// ── Permission Failures ───────────────────────────────────────────────────────

/// The user denied a required permission (e.g. storage on Android < 13).
final class PermissionDeniedFailure extends MeiFailure {
  const PermissionDeniedFailure({required super.message, super.cause});
}

// ── Unknown / Catch-all ───────────────────────────────────────────────────────

/// A failure whose type is not yet categorised.
final class UnknownFailure extends MeiFailure {
  const UnknownFailure({required super.message, super.cause});
}
