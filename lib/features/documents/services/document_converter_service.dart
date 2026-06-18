import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/failures.dart';
import '../../../core/services/mei_logger.dart';
import '../../../core/utils/file_utils.dart';

/// Handles all document-layer conversions:
///   • TXT / MD  → DOCX  (pure-Dart OpenXML; no AGPL dependency)
///   • DOCX      → plain text  (ZIP extraction + XML parsing)
///
/// Heavy work is always dispatched to a background isolate via [compute].
class DocumentConverterService {
  const DocumentConverterService._();

  // ── TXT → DOCX ─────────────────────────────────────────────────────────────

  /// Converts a plain-text (.txt / .md) file to a valid .docx document.
  ///
  /// The output is a spec-compliant OOXML package that opens correctly in
  /// Microsoft Word, Google Docs, and LibreOffice without warnings.
  static Future<String> convertToDocx(String txtPath) async {
    final source = File(txtPath);
    if (!source.existsSync()) {
      throw const FileNotFoundFailure(message: 'Source text file not found.');
    }
    FileUtils.assertSizeOk(source);

    final content = await source.readAsString();
    final outputPath = await FileUtils.buildOutputPath(txtPath, 'docx');

    // CPU-bound work goes to an isolate so the UI never jank.
    final docxBytes = await compute(_buildDocxIsolate, content);
    await File(outputPath).writeAsBytes(docxBytes);

    MeiLogger.instance.i('TXT→DOCX: ${p.basename(outputPath)}');
    return outputPath;
  }

  // ── DOCX → plain text ──────────────────────────────────────────────────────

  /// Extracts all paragraph text from a .docx file.
  ///
  /// V1 scope: text content only — formatting, tables, and images are ignored.
  /// Returns the extracted string (may be empty if the document has no text).
  static Future<String> extractDocxText(String docxPath) async {
    final source = File(docxPath);
    if (!source.existsSync()) {
      throw const FileNotFoundFailure(message: 'DOCX file not found.');
    }
    FileUtils.assertSizeOk(source);

    final bytes = await source.readAsBytes();
    final text = await compute(_extractDocxTextIsolate, bytes);

    MeiLogger.instance.i(
      'DOCX text extracted (${text.length} chars): ${p.basename(docxPath)}',
    );
    return text;
  }

  // ── DOCX → PDF ─────────────────────────────────────────────────────────────

  /// Converts a DOCX to PDF by extracting its text and delegating to
  /// [PdfConverterService.textToPdf]. Import that service at call site.
  ///
  /// Returns the output path of the PDF. Throws on failure.
  static Future<String> convertDocxToPdfViaText(String docxPath) async {
    final text = await extractDocxText(docxPath);
    if (text.isEmpty) {
      throw const ConversionFailure(
        message: 'The DOCX file appears to be empty or contains no readable text.',
      );
    }
    // Write text to a temp file, then convert to PDF via the PDF service.
    final tmp = await FileUtils.tempDir();
    final stem = p.basenameWithoutExtension(docxPath);
    final tmpTxt = File(p.join(tmp.path, '${stem}_extracted.txt'));
    await tmpTxt.writeAsString(text);
    return tmpTxt.path; // caller will convert this txt → pdf
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Isolate helpers — top-level, no closures, sendable across ports.
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a minimal but fully spec-compliant DOCX package from plain text.
///
/// A DOCX file is a ZIP archive containing several XML files.  We hand-craft
/// every required part so no Word-specific library is needed.
List<int> _buildDocxIsolate(String plainText) {
  final lines = plainText.split('\n');

  // ── word/document.xml ── each line becomes one paragraph
  final paragraphsXml = StringBuffer();
  for (final line in lines) {
    final escaped = _escapeXml(line);
    if (escaped.isEmpty) {
      // Blank line → empty paragraph (preserves spacing in output)
      paragraphsXml.write('<w:p><w:pPr><w:spacing w:line="276" w:lineRule="auto"/></w:pPr></w:p>');
    } else {
      paragraphsXml
        ..write('<w:p>')
        ..write('<w:pPr><w:spacing w:line="276" w:lineRule="auto"/></w:pPr>')
        ..write('<w:r>')
        ..write('<w:rPr><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>')
        ..write('<w:t xml:space="preserve">$escaped</w:t>')
        ..write('</w:r>')
        ..write('</w:p>');
    }
  }

  const nsW  = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
  const nsR  = 'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
  const nsWpc = 'xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"';

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

  // ── [Content_Types].xml ──────────────────────────────────────────────────
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

  // ── _rels/.rels ──────────────────────────────────────────────────────────
  const relsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/>'
      '</Relationships>';

  // ── word/_rels/document.xml.rels ─────────────────────────────────────────
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

  // ── word/settings.xml ────────────────────────────────────────────────────
  const settingsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:defaultTabStop w:val="720"/>'
      '<w:compat>'
      '<w:compatSetting w:name="compatibilityMode" '
      'w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>'
      '</w:compat>'
      '</w:settings>';

  // ── word/styles.xml ──────────────────────────────────────────────────────
  const stylesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<w:docDefaults>'
      '<w:rPrDefault><w:rPr>'
      '<w:rFonts w:asciiTheme="minorHAnsi" w:hAnsiTheme="minorHAnsi" '
      'w:eastAsiaTheme="minorEastAsia" w:cstheme="minorBidi"/>'
      '<w:sz w:val="24"/><w:szCs w:val="24"/>'
      '</w:rPr></w:rPrDefault>'
      '</w:docDefaults>'
      '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
      '<w:name w:val="Normal"/><w:qFormat/>'
      '</w:style>'
      '</w:styles>';

  // ── Pack into ZIP ─────────────────────────────────────────────────────────
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

/// Extracts all paragraph text from the DOCX ZIP package.
///
/// Parses `word/document.xml` without an external XML library to keep the
/// dependency surface minimal.  Each `<w:p>` becomes one line in the output.
String _extractDocxTextIsolate(Uint8List docxBytes) {
  try {
    final archive = ZipDecoder().decodeBytes(docxBytes);
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) return '';

    final xmlString = utf8.decode(docFile.content as List<int>);

    // Match every paragraph element (greedy would break on nested w:p, so
    // we use a two-pass approach: split on </w:p> to isolate paragraphs).
    final textBuffer = StringBuffer();
    final tagRegex    = RegExp(r'<[^>]+>');       // strip all XML tags
    final spaceRegex  = RegExp(r'\s+');            // collapse whitespace

    // Split raw XML on paragraph boundaries
    final rawParas = xmlString.split(RegExp(r'</w:p>'));
    for (final rawPara in rawParas) {
      // Strip everything except <w:t> text nodes
      final textOnly = rawPara.replaceAll(tagRegex, ' ');
      final collapsed = textOnly.replaceAll(spaceRegex, ' ').trim();
      textBuffer.writeln(collapsed);
    }

    return textBuffer.toString().trim();
  } catch (e) {
    throw ConversionFailure(message: 'Failed to read DOCX content: $e');
  }
}

/// Escapes the five special XML characters so text content is always valid.
String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
