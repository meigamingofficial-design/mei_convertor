import 'package:flutter_test/flutter_test.dart';
import 'package:mei_convertor/core/models/conversion_record.dart';
import 'package:mei_convertor/core/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

ConversionRecord _makeRecord({
  String id = 'test-1',
  String category = 'image',
}) =>
    ConversionRecord(
      id: id,
      inputFileName: 'photo.jpg',
      inputPath: '/tmp/photo.jpg',
      outputPath: '/tmp/photo.png',
      inputFormat: 'jpg',
      outputFormat: 'png',
      fileSizeBytes: 102400,
      convertedAt: DateTime(2026, 1, 1, 12),
      categoryName: category,
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.clearAll();
  });

  // ─────────────────────────── ConversionRecord ─────────────────────────────

  group('ConversionRecord', () {
    test('JSON round-trip preserves all fields', () {
      final record = _makeRecord();
      final encoded = ConversionRecord.encode([record]);
      final decoded = ConversionRecord.decode(encoded);

      expect(decoded.length, 1);
      final r = decoded.first;
      expect(r.id, record.id);
      expect(r.inputFileName, record.inputFileName);
      expect(r.outputFormat, record.outputFormat);
      expect(r.fileSizeBytes, record.fileSizeBytes);
      expect(r.convertedAt, record.convertedAt);
      expect(r.isFavorite, false);
    });

    test('displaySize formats 102400 bytes as 100.0 KB', () {
      expect(_makeRecord().displaySize, '100.0 KB');
    });

    test('displaySize formats bytes under 1024 as B', () {
      final r = ConversionRecord(
        id: 'x',
        inputFileName: 'a.txt',
        inputPath: '/a.txt',
        outputPath: '/a.pdf',
        inputFormat: 'txt',
        outputFormat: 'pdf',
        fileSizeBytes: 512,
        convertedAt: DateTime(2026),
        categoryName: 'document',
      );
      expect(r.displaySize, '512B');
    });

    test('category helpers are correct', () {
      final img = _makeRecord(category: 'image');
      final pdf = _makeRecord(id: '2', category: 'pdf');
      final doc = _makeRecord(id: '3', category: 'document');

      expect(img.isImage, isTrue);
      expect(img.isPdf, isFalse);
      expect(pdf.isPdf, isTrue);
      expect(doc.isDocument, isTrue);
    });

    test('outputFileName parses from path correctly', () {
      expect(_makeRecord().outputFileName, 'photo.png');
    });

    test('copyWith toggles isFavorite', () {
      final original = _makeRecord();
      final toggled = original.copyWith(isFavorite: true);
      expect(original.isFavorite, false);
      expect(toggled.isFavorite, true);
    });

    test('decode handles empty JSON array', () {
      final records = ConversionRecord.decode('[]');
      expect(records, isEmpty);
    });
  });

  // ─────────────────────────── StorageService ───────────────────────────────

  group('StorageService', () {
    test('getAllRecords returns empty list initially', () async {
      final records = await StorageService.getAllRecords();
      expect(records, isEmpty);
    });

    test('saveRecord persists a record', () async {
      final record = _makeRecord();
      await StorageService.saveRecord(record);

      final records = await StorageService.getAllRecords();
      expect(records.length, 1);
      expect(records.first.id, 'test-1');
    });

    test('multiple saves prepend newest first', () async {
      await StorageService.saveRecord(_makeRecord(id: 'old'));
      await StorageService.saveRecord(_makeRecord(id: 'new'));

      final records = await StorageService.getAllRecords();
      expect(records.first.id, 'new');
      expect(records.last.id, 'old');
    });

    test('deleteRecord removes correct record', () async {
      await StorageService.saveRecord(_makeRecord(id: 'keep'));
      await StorageService.saveRecord(_makeRecord(id: 'delete-me'));

      await StorageService.deleteRecord('delete-me');

      final records = await StorageService.getAllRecords();
      expect(records.length, 1);
      expect(records.first.id, 'keep');
    });

    test('clearAll removes all records', () async {
      await StorageService.saveRecord(_makeRecord(id: '1'));
      await StorageService.saveRecord(_makeRecord(id: '2'));
      await StorageService.clearAll();

      final records = await StorageService.getAllRecords();
      expect(records, isEmpty);
    });

    test('toggleFavourite flips isFavorite on/off', () async {
      await StorageService.saveRecord(_makeRecord(id: 'fav'));

      await StorageService.toggleFavourite('fav');
      var records = await StorageService.getAllRecords();
      expect(records.first.isFavorite, true);

      await StorageService.toggleFavourite('fav');
      records = await StorageService.getAllRecords();
      expect(records.first.isFavorite, false);
    });

    test('caps history at 100 entries', () async {
      for (var i = 0; i < 105; i++) {
        await StorageService.saveRecord(_makeRecord(id: 'r$i'));
      }
      final records = await StorageService.getAllRecords();
      expect(records.length, 100);
    });

    test('getAllRecords handles corrupt JSON gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'mei_conversion_history': 'not-valid-json',
      });
      await StorageService.init();
      final records = await StorageService.getAllRecords();
      expect(records, isEmpty);
    });

    test('getBool and setBool persist boolean values', () async {
      expect(StorageService.getBool('test_bool'), isNull);
      await StorageService.setBool('test_bool', true);
      expect(StorageService.getBool('test_bool'), isTrue);
      await StorageService.setBool('test_bool', false);
      expect(StorageService.getBool('test_bool'), isFalse);
    });
  });
}
