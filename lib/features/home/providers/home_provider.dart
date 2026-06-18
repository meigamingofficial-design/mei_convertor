import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which home tab card the user last tapped (for animated highlight).
final homeLastTappedProvider = StateProvider<String?>((ref) => null);

/// Provides a stub empty list until Isar is initialised.
/// Replace with a real Isar query after `build_runner build`.
final homeRecentProvider = FutureProvider<List<Object>>((ref) async => []);
