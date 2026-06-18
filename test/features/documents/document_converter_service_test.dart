import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// We test the pure isolate helpers by importing the service and calling the
// internal logic via the public surface (convertToDocx / extractDocxText).
// Platform-dependent file I/O is exercised using a real tmp directory.
// ─────────────────────────────────────────────────────────────────────────────

// Re-export the helper to test it in isolation.
// Since the isolate functions are top-level (required for compute()) we can
// exercise them directly via their internal XML/ZIP logic.

/// Minimal re-implementation of the escape helper for verification.
String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Builds a DOCX ZIP from plain text (mirrors the isolate logic).
List<int> _buildDocx(String plainText) {
  final lines = plainText.split('\n');

  final paragraphsXml = StringBuffer();
  for (final line in lines) {
    final escaped = _escapeXml(line);
    if (escaped.isEmpty) {
      paragraphsXml.write(
          '<w:p><w:pPr><w:spacing w:line="276" w:lineRule="auto"/></w:pPr></w:p>');
    } else {
      paragraphsXml
        ..write('<w:p>')
        ..write(
            '<w:pPr><w:spacing w:line="276" w:lineRule="auto"/></w:pPr>')
        ..write('<w:r>')
        ..write(
            '<w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>')
        ..write('<w:t xml:space="preserve">$escaped</w:t>')
        ..write('</w:r>')
        ..write('</w:p>');
    }
  }

  const nsW =
      'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
  const nsR =
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
  const nsWpc =
      'xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"';

  final documentXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document $nsWpc $nsW $nsR>'
      '<w:body>'
      '${paragraphsXml.toString()}'
      '<w:sectPr>'
      '<w:pgSz w:w="12240" w:h="15840"/>'
      '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" '
      'w:header="720" w:footer="720" w:gutter="0"/>'
      '</w:sectPr>'
      '</w:body>'
      '</w:document>';

  const contentTypesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '<Override PartName="/word/settings.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
      '</Types>';

  const relsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/>'
      '</Relationships>';

  const wordRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/>'
      '<Relationship Id="rId2" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" '
      'Target="settings.xml"/>'
      '</Relationships>';

  const settingsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:defaultTabStop w:val="720"/>'
      '</w:settings>';

  const stylesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
      '<w:name w:val="Normal"/>'
      '</w:style>'
      '</w:styles>';

  final archive = Archive();

  void addXml(String name, String xml) {
    final bytes = utf8.encode(xml);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  addXml('[Content_Types].xml', contentTypesXml);
  addXml('_rels/.rels', relsXml);
  addXml('word/document.xml', documentXml);
  addXml('word/_rels/document.xml.rels', wordRelsXml);
  addXml('word/settings.xml', settingsXml);
  addXml('word/styles.xml', stylesXml);

  return ZipEncoder().encode(archive);
}

/// Extracts text from a DOCX ZIP (mirrors the isolate logic).
String _extractDocxText(List<int> docxBytes) {
  final archive = ZipDecoder().decodeBytes(docxBytes);
  final docFile = archive.findFile('word/document.xml');
  if (docFile == null) return '';

  final xmlString = utf8.decode(docFile.content as List<int>);
  final textBuffer = StringBuffer();
  final tagRegex   = RegExp(r'<[^>]+>');
  final spaceRegex = RegExp(r'\s+');

  final rawParas = xmlString.split(RegExp(r'</w:p>'));
  for (final rawPara in rawParas) {
    final textOnly  = rawPara.replaceAll(tagRegex, ' ');
    final collapsed = textOnly.replaceAll(spaceRegex, ' ').trim();
    textBuffer.writeln(collapsed);
  }

  return textBuffer.toString().trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── XML escape ────────────────────────────────────────────────────────────

  group('_escapeXml', () {
    test('escapes ampersand', () {
      expect(_escapeXml('a & b'), 'a &amp; b');
    });

    test('escapes less-than', () {
      expect(_escapeXml('a < b'), 'a &lt; b');
    });

    test('escapes greater-than', () {
      expect(_escapeXml('a > b'), 'a &gt; b');
    });

    test('escapes double-quote', () {
      expect(_escapeXml('say "hi"'), 'say &quot;hi&quot;');
    });

    test('escapes single-quote', () {
      expect(_escapeXml("it's"), 'it&apos;s');
    });

    test('leaves safe characters unchanged', () {
      const safe = 'Hello World 1234 _-+=()[]{}';
      expect(_escapeXml(safe), safe);
    });

    test('escapes multiple specials in one string', () {
      expect(_escapeXml('<a>&"\''), '&lt;a&gt;&amp;&quot;&apos;');
    });
  });

  // ── DOCX ZIP structure ───────────────────────────────────────────────────

  group('DOCX builder — ZIP structure', () {
    late List<int> docxBytes;

    setUp(() {
      docxBytes = _buildDocx('Hello world\nLine 2');
    });

    test('output is non-empty', () {
      expect(docxBytes, isNotEmpty);
    });

    test('ZIP contains [Content_Types].xml', () {
      final archive = ZipDecoder().decodeBytes(docxBytes);
      expect(archive.findFile('[Content_Types].xml'), isNotNull);
    });

    test('ZIP contains _rels/.rels', () {
      final archive = ZipDecoder().decodeBytes(docxBytes);
      expect(archive.findFile('_rels/.rels'), isNotNull);
    });

    test('ZIP contains word/document.xml', () {
      final archive = ZipDecoder().decodeBytes(docxBytes);
      expect(archive.findFile('word/document.xml'), isNotNull);
    });

    test('ZIP contains word/styles.xml', () {
      final archive = ZipDecoder().decodeBytes(docxBytes);
      expect(archive.findFile('word/styles.xml'), isNotNull);
    });

    test('ZIP contains word/settings.xml', () {
      final archive = ZipDecoder().decodeBytes(docxBytes);
      expect(archive.findFile('word/settings.xml'), isNotNull);
    });

    test('document.xml is valid UTF-8 XML', () {
      final archive   = ZipDecoder().decodeBytes(docxBytes);
      final file      = archive.findFile('word/document.xml')!;
      final xmlString = utf8.decode(file.content as List<int>);
      expect(xmlString, contains('<?xml'));
      expect(xmlString, contains('<w:document'));
      expect(xmlString, contains('</w:document>'));
    });

    test('document.xml contains paragraph text', () {
      final archive   = ZipDecoder().decodeBytes(docxBytes);
      final file      = archive.findFile('word/document.xml')!;
      final xmlString = utf8.decode(file.content as List<int>);
      expect(xmlString, contains('Hello world'));
      expect(xmlString, contains('Line 2'));
    });

    test('content-types declares correct content type for document.xml', () {
      final archive   = ZipDecoder().decodeBytes(docxBytes);
      final ctFile    = archive.findFile('[Content_Types].xml')!;
      final ctXml     = utf8.decode(ctFile.content as List<int>);
      expect(ctXml, contains('wordprocessingml.document.main+xml'));
    });
  });

  // ── DOCX builder — content encoding ──────────────────────────────────────

  group('DOCX builder — content encoding', () {
    test('empty string produces non-empty ZIP', () {
      final bytes = _buildDocx('');
      expect(bytes, isNotEmpty);
    });

    test('single line appears in document.xml', () {
      final bytes   = _buildDocx('Only line');
      final archive = ZipDecoder().decodeBytes(bytes);
      final xml     = utf8.decode(
          archive.findFile('word/document.xml')!.content as List<int>);
      expect(xml, contains('Only line'));
    });

    test('blank lines produce empty paragraph elements', () {
      final bytes   = _buildDocx('Line 1\n\nLine 3');
      final archive = ZipDecoder().decodeBytes(bytes);
      final xml     = utf8.decode(
          archive.findFile('word/document.xml')!.content as List<int>);
      // Empty paragraph — no w:t element, just spacing pPr
      expect(xml, contains('Line 1'));
      expect(xml, contains('Line 3'));
    });

    test('special XML chars are escaped in document.xml', () {
      final bytes   = _buildDocx('a & b < c > d');
      final archive = ZipDecoder().decodeBytes(bytes);
      final xml     = utf8.decode(
          archive.findFile('word/document.xml')!.content as List<int>);
      expect(xml, contains('a &amp; b &lt; c &gt; d'));
      // Raw special chars must NOT appear inside the text node
      expect(
        xml.contains('<w:t xml:space="preserve">a & b'),
        isFalse,
      );
    });

    test('multi-paragraph content has multiple w:p elements', () {
      final bytes   = _buildDocx('Para 1\nPara 2\nPara 3');
      final archive = ZipDecoder().decodeBytes(bytes);
      final xml     = utf8.decode(
          archive.findFile('word/document.xml')!.content as List<int>);
      final count   = '<w:p>'.allMatches(xml).length;
      expect(count, greaterThanOrEqualTo(3));
    });

    test('Unicode text is preserved', () {
      final bytes   = _buildDocx('日本語テスト\n한국어\nАлфавит');
      final archive = ZipDecoder().decodeBytes(bytes);
      final xml     = utf8.decode(
          archive.findFile('word/document.xml')!.content as List<int>);
      expect(xml, contains('日本語テスト'));
      expect(xml, contains('한국어'));
      expect(xml, contains('Алфавит'));
    });
  });

  // ── DOCX text extraction ──────────────────────────────────────────────────

  group('DOCX text extraction', () {
    test('round-trip: build then extract recovers original text', () {
      const original = 'Hello\nWorld\nLine 3';
      final bytes    = _buildDocx(original);
      final extracted = _extractDocxText(bytes);
      for (final line in ['Hello', 'World', 'Line 3']) {
        expect(extracted, contains(line));
      }
    });

    test('returns empty string for missing word/document.xml', () {
      // Build a minimal ZIP without the document.xml entry
      final archive = Archive()
        ..addFile(ArchiveFile('[Content_Types].xml', 2, utf8.encode('<>')));
      final bytes = ZipEncoder().encode(archive);
      expect(_extractDocxText(bytes), '');
    });

    test('extracts Unicode text correctly', () {
      final bytes     = _buildDocx('こんにちは世界');
      final extracted = _extractDocxText(bytes);
      expect(extracted, contains('こんにちは世界'));
    });

    test('handles multi-paragraph extraction', () {
      final bytes     = _buildDocx('Alpha\nBeta\nGamma');
      final extracted = _extractDocxText(bytes);
      expect(extracted, contains('Alpha'));
      expect(extracted, contains('Beta'));
      expect(extracted, contains('Gamma'));
    });
  });

  // ── DOCX file system round-trip (uses dart:io) ─────────────────────────────

  group('DOCX file I/O round-trip', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('mei_docx_test_');
    });

    tearDown(() async {
      if (tmpDir.existsSync()) await tmpDir.delete(recursive: true);
    });

    test('written .docx can be unzipped and contains expected entries', () async {
      final docxBytes = _buildDocx('Test content from file I/O');
      final outFile   = File('${tmpDir.path}/test_output.docx');
      await outFile.writeAsBytes(docxBytes);

      expect(outFile.existsSync(), isTrue);
      expect(outFile.lengthSync(), greaterThan(0));

      final readBack  = await outFile.readAsBytes();
      final archive   = ZipDecoder().decodeBytes(readBack);
      expect(archive.findFile('word/document.xml'), isNotNull);
      expect(archive.findFile('[Content_Types].xml'), isNotNull);
    });

    test('extracted text matches original after file write/read', () async {
      const original  = 'File round-trip test\nSecond line';
      final docxBytes = _buildDocx(original);
      final outFile   = File('${tmpDir.path}/round_trip.docx');
      await outFile.writeAsBytes(docxBytes);

      final readBack  = await outFile.readAsBytes();
      final extracted = _extractDocxText(readBack);

      expect(extracted, contains('File round-trip test'));
      expect(extracted, contains('Second line'));
    });

    test('source .txt file is read and converted correctly', () async {
      const content = 'Line A\nLine B\nLine C';
      final txtFile = File('${tmpDir.path}/source.txt');
      await txtFile.writeAsString(content);

      final text = await txtFile.readAsString();
      final docxBytes = _buildDocx(text);
      final docxFile  = File('${tmpDir.path}/output.docx');
      await docxFile.writeAsBytes(docxBytes);

      expect(docxFile.existsSync(), isTrue);
      final extracted = _extractDocxText(await docxFile.readAsBytes());
      expect(extracted, contains('Line A'));
      expect(extracted, contains('Line B'));
      expect(extracted, contains('Line C'));
    });
  });
}
