import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

// ── BuildContext extensions ───────────────────────────────────────────────────

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  void showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
        duration: MeiDurations.snackbarShow,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }
}

// ── String extensions ─────────────────────────────────────────────────────────

extension StringX on String {
  /// Returns `true` when this string equals any of [values] (case-insensitive).
  bool equalsAnyIgnoreCase(List<String> values) =>
      values.any((v) => v.toLowerCase() == toLowerCase());

  /// Capitalises the first letter.
  String get capitalised =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Returns the file extension without the dot, lowercase.
  String get fileExtension {
    final dot = lastIndexOf('.');
    return dot == -1 ? '' : substring(dot + 1).toLowerCase();
  }

  /// Trims the file extension from a filename string.
  String get withoutExtension {
    final dot = lastIndexOf('.');
    return dot == -1 ? this : substring(0, dot);
  }
}

// ── int / num extensions ──────────────────────────────────────────────────────

extension IntX on int {
  /// Formats bytes into a human-readable string: "1.4 MB", "320 KB", etc.
  String get readableBytes {
    if (this < 1024) return '$this B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(1)} KB';
    if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// ── DateTime extensions ───────────────────────────────────────────────────────

extension DateTimeX on DateTime {
  /// e.g. "Today", "Yesterday", "28 May"
  String get relativeLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(year, month, day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '$day ${_monthName(month)}';
  }

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m];
}

// ── File extensions ───────────────────────────────────────────────────────────

extension FileX on File {
  /// Returns the file name without directory prefix.
  String get name => path.split(Platform.pathSeparator).last;

  /// Returns the extension without the dot, lowercase.
  String get extension => name.fileExtension;

  /// Returns the file size as a human-readable string.
  String get readableSize {
    final stat = statSync();
    return stat.size.readableBytes;
  }
}

// ── List extensions ───────────────────────────────────────────────────────────

extension ListX<T> on List<T> {
  /// Returns `null` instead of throwing when the index is out-of-range.
  T? safeGet(int index) => (index >= 0 && index < length) ? this[index] : null;
}
