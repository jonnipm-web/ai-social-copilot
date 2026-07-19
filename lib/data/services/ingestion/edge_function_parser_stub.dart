import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/asset_provenance.dart';
import '../../models/ingestion_source.dart';
import '../../models/parsed_content.dart';
import 'asset_parser_interface.dart';

/// Parser stub para formatos que dependem de Edge Functions (PDF, DOCX, imagens, XLSX).
///
/// Delega a extração para a Edge Function `process-file` existente.
/// Se a Edge Function não estiver disponível, retorna conteúdo vazio com aviso.
class EdgeFunctionParserStub implements AssetParserInterface {
  const EdgeFunctionParserStub({
    this.functionName = 'process-file',
  });

  final String functionName;

  @override
  String get parserVersion => '1.0.0-stub';

  @override
  List<IngestionSource> get supportedSources => const [
    IngestionSource.pdf,
    IngestionSource.docx,
    IngestionSource.image,
    IngestionSource.xlsx,
  ];

  @override
  Future<ParsedContent> parseBytes(
    Uint8List bytes, {
    required IngestionSource source,
    String? fileName,
    Map<String, dynamic> hints = const {},
  }) async {
    final extension = _extensionFor(source);
    final fingerprint = sha256.convert(bytes).toString();

    try {
      final client   = Supabase.instance.client;
      final encoded  = base64Encode(bytes);
      final response = await client.functions.invoke(
        functionName,
        body: {
          'file':      encoded,
          'extension': extension,
          'filename':  fileName ?? 'import.$extension',
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final text = data?['text'] as String? ?? '';

      return ParsedContent(
        rawText:      text,
        title:        fileName,
        mimeType:     _mimeFor(source),
        sizeBytes:    bytes.length,
        fingerprint:  fingerprint,
        structuredData: data,
        provenance: AssetProvenance(
          sourceType:    source,
          sourceName:    fileName,
          importedAt:    DateTime.now(),
          parserVersion: parserVersion,
          confidence:    text.isNotEmpty ? 0.85 : 0.3,
        ),
      );
    } catch (e) {
      return ParsedContent(
        rawText:  '',
        title:    fileName,
        mimeType: _mimeFor(source),
        sizeBytes: bytes.length,
        fingerprint: fingerprint,
        warnings: [
          'Não foi possível extrair conteúdo via Edge Function: $e',
          'O arquivo foi registrado mas o conteúdo não foi indexado.',
        ],
        provenance: AssetProvenance(
          sourceType:    source,
          sourceName:    fileName,
          importedAt:    DateTime.now(),
          parserVersion: parserVersion,
          confidence:    0.0,
        ),
      );
    }
  }

  @override
  Future<ParsedContent> parseText(
    String text, {
    required IngestionSource source,
    String? title,
    Map<String, dynamic> hints = const {},
  }) async {
    throw AssetParserException(
      'EdgeFunctionParserStub não suporta parseText diretamente',
      source: source,
    );
  }

  String _extensionFor(IngestionSource source) => switch (source) {
    IngestionSource.pdf   => 'pdf',
    IngestionSource.docx  => 'docx',
    IngestionSource.image => 'jpg',
    IngestionSource.xlsx  => 'xlsx',
    _                     => 'bin',
  };

  String _mimeFor(IngestionSource source) => switch (source) {
    IngestionSource.pdf   => 'application/pdf',
    IngestionSource.docx  => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    IngestionSource.image => 'image/jpeg',
    IngestionSource.xlsx  => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    _                     => 'application/octet-stream',
  };
}
