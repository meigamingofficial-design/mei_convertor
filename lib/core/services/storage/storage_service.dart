import 'package:shared_preferences/shared_preferences.dart';

import '../../models/conversion_record.dart';
import '../mei_logger.dart';

/// Lightweight SharedPreferences-backed history store.
/// Replaces Isar stub — zero codegen required, works immediately.
class StorageService {
  StorageService._();

  static final _log = MeiLogger.instance;
  static const String _key = 'mei_conversion_history';

  static SharedPreferences? _prefs;

  /// Get string preference.
  static String? getString(String key) => _prefs?.getString(key);

  /// Set string preference.
  static Future<void> setString(String key, String value) async =>
      await _prefs?.setString(key, value);

  /// Initialize the storage layer. Must be called once at startup.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _log.i('StorageService: SharedPreferences initialized.');
  }

  /// Gracefully closes. No-op for SharedPreferences.
  static Future<void> close() async {
    _log.i('StorageService.close() — no-op.');
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Save a new conversion record (prepended to list — newest first).
  static Future<void> saveRecord(ConversionRecord record) async {
    final records = await getAllRecords();
    records.insert(0, record);
    // Keep at most 100 records
    final trimmed = records.length > 100 ? records.sublist(0, 100) : records;
    await _prefs!.setString(_key, ConversionRecord.encode(trimmed));
    _log.i('StorageService: saved record ${record.id}');
  }

  /// Load all saved records, newest first.
  static Future<List<ConversionRecord>> getAllRecords() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return ConversionRecord.decode(raw);
    } catch (e) {
      _log.e('StorageService: failed to parse history', e);
      return [];
    }
  }

  /// Delete a record by id.
  static Future<void> deleteRecord(String id) async {
    final records = await getAllRecords();
    records.removeWhere((r) => r.id == id);
    await _prefs!.setString(_key, ConversionRecord.encode(records));
    _log.i('StorageService: deleted record $id');
  }

  /// Toggle favourite status for a record.
  static Future<void> toggleFavourite(String id) async {
    final records = await getAllRecords();
    final idx = records.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    records[idx] = records[idx].copyWith(isFavorite: !records[idx].isFavorite);
    await _prefs!.setString(_key, ConversionRecord.encode(records));
  }

  /// Clear all history.
  static Future<void> clearAll() async {
    await _prefs!.remove(_key);
    _log.i('StorageService: cleared all records.');
  }
}
