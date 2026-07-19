import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../models/asset_provenance.dart';
import '../../models/ingestion_source.dart';
import '../../models/parsed_content.dart';
import 'asset_parser_interface.dart';

/// Parser para URLs/links externos.
/// Registra URL, domínio, título e metadados sem duplicar downloads.
class UrlParser implements AssetParserInterface {
  UrlParser({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  @override
  String get parserVersion => '1.0.0';

  @override
  List<IngestionSource> get supportedSources => const [IngestionSource.url];

  @override
  Future<ParsedContent> parseBytes(
    Uint8List bytes, {
    required IngestionSource source,
    String? fileName,
    Map<String, dynamic> hints = const {},
  }) async {
    final urlStr = utf8.decode(bytes).trim();
    return parseText(urlStr, source: source, hints: hints);
  }

  @override
  Future<ParsedContent> parseText(
    String text, {
    required IngestionSource source,
    String? title,
    Map<String, dynamic> hints = const {},
  }) async {
    final urlStr = text.trim();
    final uri    = Uri.tryParse(urlStr);

    if (uri == null || (!uri.hasScheme)) {
      throw AssetParserException(
        'URL inválida: $urlStr',
        source: source,
      );
    }

    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw AssetParserException(
        'Apenas URLs http/https são suportadas. Recebido: ${uri.scheme}',
        source: source,
      );
    }

    final domain     = uri.host;
    final capturedAt = DateTime.now();

    String? fetchedTitle;
    String? fetchedDescription;
    String? mimeType;
    List<String> warnings = [];

    try {
      final metadata = await _fetchMetadata(uri);
      fetchedTitle       = metadata['title']       as String?;
      fetchedDescription = metadata['description'] as String?;
      mimeType           = metadata['mime_type']   as String?;
    } catch (e) {
      warnings.add('Não foi possível buscar metadados da URL: $e');
    }

    return ParsedContent(
      rawText:     urlStr,
      title:       fetchedTitle ?? title ?? domain,
      description: fetchedDescription,
      mimeType:    mimeType ?? 'text/html',
      sizeBytes:   urlStr.length,
      warnings:    warnings,
      structuredData: {
        'url':          urlStr,
        'domain':       domain,
        'scheme':       uri.scheme,
        'path':         uri.path,
        'captured_at':  capturedAt.toIso8601String(),
        'source_type':  'url',
        if (fetchedTitle       != null) 'fetched_title':       fetchedTitle,
        if (fetchedDescription != null) 'fetched_description': fetchedDescription,
      },
      metadata: {
        'domain':      domain,
        'captured_at': capturedAt.toIso8601String(),
      },
      provenance: AssetProvenance(
        sourceType:    source,
        sourceUrl:     urlStr,
        sourceName:    domain,
        importedAt:    capturedAt,
        parserVersion: parserVersion,
        confidence:    fetchedTitle != null ? 0.9 : 0.6,
      ),
    );
  }

  // ── Private ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _fetchMetadata(Uri uri) async {
    final client = _httpClient ?? http.Client();
    try {
      final response = await client.get(
        uri,
        headers: {'User-Agent': 'AI-Social-Copilot/1.0 (metadata-fetch)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return {};
      }

      final contentType = response.headers['content-type'] ?? '';
      final mimeType    = contentType.split(';').first.trim();

      if (!mimeType.contains('html')) {
        return {'mime_type': mimeType};
      }

      final body = response.body;
      return {
        'mime_type':   mimeType,
        'title':       _extractTitle(body),
        'description': _extractDescription(body),
      };
    } finally {
      if (_httpClient == null) client.close();
    }
  }

  String? _extractTitle(String html) {
    final ogTitle = RegExp(
      r'<meta[^>]+property=["\']og:title["\'][^>]+content=["\'](.*?)["\']',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    if (ogTitle != null && ogTitle.isNotEmpty) return _decodeHtml(ogTitle);

    final titleTag = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html)?.group(1);
    if (titleTag != null && titleTag.isNotEmpty) return _decodeHtml(titleTag.trim());

    return null;
  }

  String? _extractDescription(String html) {
    final ogDesc = RegExp(
      r'<meta[^>]+property=["\']og:description["\'][^>]+content=["\'](.*?)["\']',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    if (ogDesc != null && ogDesc.isNotEmpty) return _decodeHtml(ogDesc);

    final metaDesc = RegExp(
      r'<meta[^>]+name=["\']description["\'][^>]+content=["\'](.*?)["\']',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    if (metaDesc != null && metaDesc.isNotEmpty) return _decodeHtml(metaDesc);

    return null;
  }

  String _decodeHtml(String input) => input
      .replaceAll('&amp;',  '&')
      .replaceAll('&lt;',   '<')
      .replaceAll('&gt;',   '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;',  "'")
      .replaceAll('&nbsp;', ' ');
}
