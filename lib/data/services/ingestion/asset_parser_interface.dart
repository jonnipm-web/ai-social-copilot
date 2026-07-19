import 'dart:typed_data';

import '../../models/ingestion_source.dart';
import '../../models/parsed_content.dart';

/// Contrato base para todos os parsers de ingestão.
/// Cada implementação lida com um ou mais formatos de entrada.
abstract class AssetParserInterface {
  /// Versão do parser — incluída no provenance de todo conteúdo extraído.
  String get parserVersion;

  /// Formatos suportados por este parser.
  List<IngestionSource> get supportedSources;

  /// Verifica se este parser suporta a fonte dada.
  bool supports(IngestionSource source) => supportedSources.contains(source);

  /// Faz o parse de bytes brutos.
  /// [fileName] é usado apenas para hinting — nunca como fonte de confiança para MIME.
  Future<ParsedContent> parseBytes(
    Uint8List bytes, {
    required IngestionSource source,
    String? fileName,
    Map<String, dynamic> hints = const {},
  });

  /// Faz o parse de uma string (texto já decodificado).
  Future<ParsedContent> parseText(
    String text, {
    required IngestionSource source,
    String? title,
    Map<String, dynamic> hints = const {},
  });
}

/// Exceção de parsing com detalhes suficientes para diagnóstico.
class AssetParserException implements Exception {
  const AssetParserException(this.message, {this.source, this.cause});

  final String          message;
  final IngestionSource? source;
  final Object?         cause;

  @override
  String toString() => 'AssetParserException: $message'
      '${source != null ? " (source: ${source!.dbValue})" : ""}'
      '${cause  != null ? " — cause: $cause" : ""}';
}

/// Exceção de segurança (path traversal, ZIP bomb, MIME inválido, etc.)
class IngestionSecurityException implements Exception {
  const IngestionSecurityException(this.message, {this.detail});

  final String  message;
  final String? detail;

  @override
  String toString() => 'IngestionSecurityException: $message'
      '${detail != null ? " — $detail" : ""}';
}
