/// Testes do TextParser.
///
/// Cenários:
///   1.  parseText retorna rawText correto
///   2.  parseText detecta título na primeira linha
///   3.  parseText conta palavras e linhas
///   4.  parseText com texto vazio
///   5.  parseBytes decodifica UTF-8
///   6.  parseBytes decodifica UTF-8 BOM (detecta encoding correto)
///   7.  parseBytes gera fingerprint SHA-256
///   8.  parseBytes fingerprint estável para mesmo conteúdo
///   9.  mimeType sempre text/plain
///  10.  provenance.sourceType reflete a fonte passada
///  11.  provenance.parserVersion não vazia
///  12.  primeira linha longa (>120 chars) não vira título

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/services/ingestion/text_parser.dart';
import 'package:ai_social_copilot/data/models/ingestion_source.dart';

void main() {
  const parser = TextParser();

  group('TextParser — parseText', () {
    test('1. rawText retornado corretamente', () async {
      final c = await parser.parseText('Olá mundo', source: IngestionSource.text);
      expect(c.rawText, 'Olá mundo');
    });

    test('2. primeira linha vira título quando <= 120 chars', () async {
      final c = await parser.parseText(
        'Meu Livro Incrível\nConteúdo do livro aqui.',
        source: IngestionSource.text,
      );
      expect(c.title, 'Meu Livro Incrível');
    });

    test('3. metadata conta palavras e linhas', () async {
      final c = await parser.parseText(
        'linha um\nlinha dois\nlinha três',
        source: IngestionSource.text,
      );
      expect(c.metadata['line_count'], 3);
      expect((c.metadata['word_count'] as int) > 0, isTrue);
    });

    test('4. texto vazio retorna rawText vazio sem erro', () async {
      final c = await parser.parseText('', source: IngestionSource.text);
      expect(c.rawText, '');
      expect(c.metadata['char_count'], 0);
    });

    test('9. mimeType sempre text/plain', () async {
      final c = await parser.parseText('test', source: IngestionSource.txt);
      expect(c.mimeType, 'text/plain');
    });

    test('10. provenance.sourceType reflete fonte passada', () async {
      final c = await parser.parseText('test', source: IngestionSource.txt);
      expect(c.provenance.sourceType, IngestionSource.txt);
    });

    test('11. provenance.parserVersion não vazia', () async {
      final c = await parser.parseText('test', source: IngestionSource.text);
      expect(c.provenance.parserVersion, isNotEmpty);
    });

    test('12. primeira linha longa não vira título', () async {
      final longLine = 'a' * 150;
      final c = await parser.parseText(
        '$longLine\nOutra linha',
        source: IngestionSource.text,
      );
      expect(c.title, isNull);
    });
  });

  group('TextParser — parseBytes', () {
    test('5. decodifica UTF-8 corretamente', () async {
      final bytes = utf8.encode('Texto com acentuação: café');
      final c = await parser.parseBytes(
        Uint8List.fromList(bytes),
        source: IngestionSource.txt,
        fileName: 'test.txt',
      );
      expect(c.rawText, 'Texto com acentuação: café');
    });

    test('6. UTF-8 BOM — detecta encoding correto', () async {
      // UTF-8 BOM: EF BB BF
      final bom   = [0xEF, 0xBB, 0xBF];
      final text  = utf8.encode('Conteúdo com BOM');
      final bytes = Uint8List.fromList([...bom, ...text]);
      final c = await parser.parseBytes(bytes, source: IngestionSource.txt);
      expect(c.encoding, 'utf-8-bom');
      expect(c.rawText, contains('Conteúdo'));
    });

    test('7. gera fingerprint SHA-256 não vazio', () async {
      final bytes = Uint8List.fromList(utf8.encode('conteúdo'));
      final c = await parser.parseBytes(bytes, source: IngestionSource.txt);
      expect(c.fingerprint, isNotEmpty);
      expect(c.fingerprint!.length, 64); // SHA-256 hex
    });

    test('8. fingerprint estável para mesmo conteúdo', () async {
      final bytes = Uint8List.fromList(utf8.encode('mesmo conteúdo'));
      final c1 = await parser.parseBytes(bytes, source: IngestionSource.txt);
      final c2 = await parser.parseBytes(bytes, source: IngestionSource.txt);
      expect(c1.fingerprint, c2.fingerprint);
    });

    test('sizeBytes reflete tamanho dos bytes', () async {
      final bytes = Uint8List.fromList(utf8.encode('abc'));
      final c = await parser.parseBytes(bytes, source: IngestionSource.txt);
      expect(c.sizeBytes, bytes.length);
    });
  });
}
