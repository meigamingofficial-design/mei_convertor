import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Dynamic provider for app package metadata (version, build number, etc.)
final packageInfoProvider = Provider<PackageInfo>((ref) {
  throw UnimplementedError('packageInfoProvider was not initialized');
});
