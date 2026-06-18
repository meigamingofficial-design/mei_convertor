import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/conversion_record.dart';
import '../../../core/services/storage/storage_service.dart';

/// Global conversion history provider backed by SharedPreferences.
/// Used by Home (recent section), RecentFilesScreen, and all converters.
class HistoryNotifier extends AsyncNotifier<List<ConversionRecord>> {
  @override
  Future<List<ConversionRecord>> build() => StorageService.getAllRecords();

  /// Add a record and persist it.
  Future<void> add(ConversionRecord record) async {
    await StorageService.saveRecord(record);
    state = AsyncData([record, ...?state.value]);
  }

  /// Delete a record by id.
  Future<void> remove(String id) async {
    await StorageService.deleteRecord(id);
    state = AsyncData(
      (state.value ?? []).where((r) => r.id != id).toList(),
    );
  }

  /// Toggle favourite.
  Future<void> toggleFavourite(String id) async {
    await StorageService.toggleFavourite(id);
    state = AsyncData(
      (state.value ?? [])
          .map((r) => r.id == id ? r.copyWith(isFavorite: !r.isFavorite) : r)
          .toList(),
    );
  }

  /// Clear all history.
  Future<void> clearAll() async {
    await StorageService.clearAll();
    state = const AsyncData([]);
  }

  /// Reload from storage (e.g. after app resume).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await StorageService.getAllRecords());
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<ConversionRecord>>(
  HistoryNotifier.new,
);
