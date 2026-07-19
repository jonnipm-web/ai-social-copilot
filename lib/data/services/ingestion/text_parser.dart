import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../models/asset_provenance.dart';
import '../../models/ingestion_source.dart';
import '../../models/parsed_content.dart';
import 'asset_parser_interface.dart';

/// Parser para conteúdo de texto simples (TXT, texto colado).
class TextParser extends AssetParserInterface {
  const TextParser();

  @override
  String get parserVersion => '1.0.0';

  @override
  List<IngestionSource> get supportedSources => const [
    IngestionSource.text,
    IngestionSource.txt,
  ];

  @override
  Future<ParsedContent> parseBytes(
    Uint8List bytes, {
    required IngestionSource source,
    String? fileName,
    Map<String, dynamic> hints = const {},
  }) async {
    final text = _decodeBytes(bytes);
    return _buildContent(
      text:     text,
      source:   source,
      title:    fileName,
      bytes:    bytes,
    );
  }

  @override
  Future<ParsedContent> parseText(
    String text, {
    required IngestionSource source,
    String? title,
    Map<String, dynamic> hints = const {},
  }) async {
    return _buildContent(
      text:   text,
      source: source,
      title:  title,
    );
  }

  // ── Private ──────────────────────────────────────────────────────────────

  String _decodeBytes(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      // Fallback to latin-1 for non-UTF-8 files
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  ParsedContent _buildContent({
    required String text,
    required IngestionSource source,
    String? title,
    Uint8List? bytes,
  }) {
    final trimmed   = text.trim();
    final lines     = trimmed.split('\n');
    final firstLine = lines.isNotEmpty ? lines.first.trim() : '';

    final detectedTitle = title ??
        (firstLine.isNotEmpty && firstLine.length <= 120 ? firstLine : null);

    final fingerprint = bytes != null
        ? sha256.convert(bytes).toString()
        : sha256.convert(utf8.encode(text)).toString();

    final encoding = bytes != null ? _detectEncoding(bytes) : 'utf-8';

    return ParsedContent(
      rawText:     trimmed,
      title:       detectedTitle,
      mimeType:    'text/plain',
      sizeBytes:   bytes?.length ?? utf8.encode(text).length,
      fingerprint: fingerprint,
      encoding:    encoding,
      metadata: {
        'line_count': lines.length,
        'char_count': trimmed.length,
        'word_count': trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length,
      },
      provenance: AssetProvenance(
        sourceType:    source,
        importedAt:    DateTime.now(),
        parserVersion: parserVersion,
        confidence:    1.0,
      ),
    );
  }

  String _detectEncoding(Uint8List bytes) {
    // BOM detection
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return 'utf-8-bom';
    }
    try {
      utf8.decode(bytes);
      return 'utf-8';
    } catch (_) {
      return 'latin-1';
    }
  }
}
