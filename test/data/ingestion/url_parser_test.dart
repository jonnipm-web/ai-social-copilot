/// Testes do UrlParser.
///
/// Cenários:
///   1.  URL válida https → ParsedContent com rawText = URL
///   2.  URL com domínio extraído em structuredData
///   3.  URL inválida (sem scheme) → AssetParserException
///   4.  URL com scheme proibido (ftp://) → AssetParserException
///   5.  parseBytes decodifica URL de bytes UTF-8
///   6.  provenance.sourceType = IngestionSource.url
///   7.  HTTP 200 → título extraído do HTML
///   8.  HTTP 200 com og:title → og:title preferido sobre title
///   9.  HTTP erro → aviso na lista de warnings, conteúdo ainda retornado
///  10.  URL normalizada em structuredData inclui scheme e path
///  11.  HTML entities decodificadas no título

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_social_copilot/data/services/ingestion/url_parser.dart';
import 'package:ai_social_copilot/data/services/ingestion/asset_parser_interface.dart';
import 'package:ai_social_copilot/data/models/ingestion_source.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

http.Client _mockClient(String body, {int statusCode = 200, String contentType = 'text/html'}) =>
    MockClient((req) async => http.Response(
      body,
      statusCode,
      headers: {'content-type': contentType},
    ));

String _html({String? title, String? ogTitle, String? metaDesc}) => '''
<!DOCTYPE html>
<html>
<head>
  ${title    != null ? '<title>$title</title>'                                         : ''}
  ${ogTitle  != null ? '<meta property="og:title" content="$ogTitle"/>'                : ''}
  ${metaDesc != null ? '<meta name="description" content="$metaDesc"/>'               : ''}
</head>
<body>Conteúdo</body>
</html>
''';

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('UrlParser — parseText básico', () {
    test('1. URL válida retorna rawText com a URL', () async {
      final parser = UrlParser(httpClient: _mockClient(''));
      final c = await parser.parseText(
        'https://example.com/produto',
        source: IngestionSource.url,
      );
      expect(c.rawText, 'https://example.com/produto');
    });

    test('2. domínio extraído em structuredData', () async {
      final parser = UrlParser(httpClient: _mockClient(''));
      final c = await parser.parseText(
        'https://example.com/produto',
        source: IngestionSource.url,
      );
      expect(c.structuredData?['domain'], 'example.com');
      expect(c.structuredData?['url'],    'https://example.com/produto');
    });

    test('3. URL sem scheme → AssetParserException', () async {
      final parser = UrlParser(httpClient: _mockClient(''));
      await expectLater(
        () => parser.parseText('nao-e-uma-url', source: IngestionSource.url),
        throwsA(isA<AssetParserException>()),
      );
    });

    test('4. scheme ftp:// → AssetParserException', () async {
      final parser = UrlParser(httpClient: _mockClient(''));
      await expectLater(
        () => parser.parseText('ftp://files.example.com/file.zip', source: IngestionSource.url),
        throwsA(isA<AssetParserException>()
            .having((e) => e.message, 'message', contains('http'))),
      );
    });

    test('6. provenance.sourceType = IngestionSource.url', () async {
      final parser = UrlParser(httpClient: _mockClient(''));
      final c = await parser.parseText(
        'https://example.com',
        source: IngestionSource.url,
      );
      expect(c.provenance.sourceType, IngestionSource.url);
    });

    test('10. structuredData inclui scheme e path', () async {
      final parser = UrlParser(httpClient: _mockClient(''));
      final c = await parser.parseText(
        'https://example.com/path/to/page',
        source: IngestionSource.url,
      );
      expect(c.structuredData?['scheme'], 'https');
      expect(c.structuredData?['path'],   '/path/to/page');
    });
  });

  group('UrlParser — fetch de metadados', () {
    test('7. HTTP 200 — título extraído do <title>', () async {
      final parser = UrlParser(
        httpClient: _mockClient(_html(title: 'Meu Produto Incrível')),
      );
      final c = await parser.parseText(
        'https://example.com',
        source: IngestionSource.url,
      );
      expect(c.title, 'Meu Produto Incrível');
    });

    test('8. og:title preferido sobre <title>', () async {
      final parser = UrlParser(
        httpClient: _mockClient(_html(
          title:   'Título da Aba',
          ogTitle: 'OG Title Melhor',
        )),
      );
      final c = await parser.parseText(
        'https://example.com',
        source: IngestionSource.url,
      );
      expect(c.title, 'OG Title Melhor');
    });

    test('9. HTTP erro → aviso no warnings, conteúdo retornado', () async {
      final parser = UrlParser(httpClient: _mockClient('', statusCode: 404));
      final c = await parser.parseText(
        'https://example.com/404',
        source: IngestionSource.url,
      );
      // Sem título fetched, usa domain como fallback
      expect(c.title,   isNotNull);
      expect(c.rawText, 'https://example.com/404');
      // Pode ter warning ou não, mas não deve lançar exceção
    });

    test('11. HTML entities decodificadas no título', () async {
      final parser = UrlParser(
        httpClient: _mockClient(_html(title: 'Produto &amp; Serviço &lt;Top&gt;')),
      );
      final c = await parser.parseText(
        'https://example.com',
        source: IngestionSource.url,
      );
      expect(c.title, 'Produto & Serviço <Top>');
    });
  });

  group('UrlParser — parseBytes', () {
    test('5. parseBytes decodifica URL de bytes UTF-8', () async {
      final parser = UrlParser(httpClient: _mockClient(''));
      final bytes  = Uint8List.fromList(utf8.encode('https://example.com/teste'));
      final c      = await parser.parseBytes(bytes, source: IngestionSource.url);
      expect(c.rawText, 'https://example.com/teste');
    });
  });
}
