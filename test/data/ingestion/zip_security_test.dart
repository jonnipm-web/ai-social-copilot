/// Testes de segurança do ZipIngestionService.
///
/// Cenários:
///   1.  ZIP válido simples — lista conteúdo corretamente
///   2.  ZIP com múltiplos arquivos — conta corretamente
///   3.  Path traversal (../) — deve lançar IngestionSecurityException
///   4.  Path traversal (/../) — deve lançar IngestionSecurityException
///   5.  Path com null byte — deve lançar IngestionSecurityException
///   6.  Path absoluto (/etc/passwd) — deve lançar IngestionSecurityException
///   7.  ZIP bomb — tamanho total excede limite
///   8.  ZIP com muitos arquivos — excede maxFileCount
///   9.  Bytes não-ZIP — magic bytes incorretos
///  10.  Arquivo único muito grande — aviso, não erro
///  11.  extractFile — arquivo existente retorna bytes corretos
///  12.  extractFile — arquivo inexistente lança AssetParserException
///  13.  _detectMime — PNG magic bytes detectado
///  14.  _detectMime — PDF magic bytes detectado
///  15.  parseText lança AssetParserException (não suportado)
///  16.  Cancelamento antes da confirmação — nenhum dado criado

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/services/ingestion/zip_ingestion_service.dart';
import 'package:ai_social_copilot/data/services/ingestion/asset_parser_interface.dart';
import 'package:ai_social_copilot/data/models/ingestion_source.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Uint8List _buildZip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    final content = Uint8List.fromList(entry.value);
    archive.addFile(ArchiveFile(entry.key, content.length, content));
  }
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) throw StateError('ZipEncoder returned null');
  return Uint8List.fromList(encoded);
}

Uint8List _text(String s) => Uint8List.fromList(utf8.encode(s));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  final svc = ZipIngestionService();

  group('ZipIngestionService — listContents', () {
    test('1. ZIP válido simples lista conteúdo', () async {
      final zip = _buildZip({'readme.txt': _text('Hello world')});
      final listing = await svc.listContents(zip);
      expect(listing.totalFiles, 1);
      expect(listing.items.any((i) => i.name == 'readme.txt'), isTrue);
    });

    test('2. ZIP com múltiplos arquivos conta corretamente', () async {
      final zip = _buildZip({
        'a.txt':  _text('aaa'),
        'b.txt':  _text('bbb'),
        'c.txt':  _text('ccc'),
      });
      final listing = await svc.listContents(zip);
      expect(listing.totalFiles, 3);
    });

    test('7. ZIP bomb — excede limite de tamanho descompactado', () async {
      final smallLimits = ZipSecurityLimits(
        maxTotalUncompressedBytes: 100,
        maxFileCount:              500,
      );
      final svcSmall = ZipIngestionService(limits: smallLimits);

      // Conteúdo de 200 bytes (excede limite de 100)
      final bigContent = Uint8List(200);
      final zip = _buildZip({'big.txt': bigContent});

      await expectLater(
        () => svcSmall.listContents(zip),
        throwsA(isA<IngestionSecurityException>()
            .having((e) => e.message, 'message', contains('Tamanho total'))),
      );
    });

    test('8. ZIP com muitos arquivos excede maxFileCount', () async {
      final smallLimits = ZipSecurityLimits(maxFileCount: 2);
      final svcSmall    = ZipIngestionService(limits: smallLimits);
      final files       = <String, List<int>>{};
      for (var i = 0; i < 5; i++) {
        files['file_$i.txt'] = _text('content $i');
      }
      final zip = _buildZip(files);

      await expectLater(
        () => svcSmall.listContents(zip),
        throwsA(isA<IngestionSecurityException>()
            .having((e) => e.message, 'message', contains('muitos arquivos'))),
      );
    });
  });

  group('ZipIngestionService — path security', () {
    test('3. path traversal com ../ lança IngestionSecurityException', () {
      final svcInstance = ZipIngestionService();
      expect(
        () => svcInstance.extractFile(Uint8List(0), '../etc/passwd'),
        throwsA(isA<IngestionSecurityException>()
            .having((e) => e.message, 'message', contains('traversal'))),
      );
    });

    test('4. path traversal /../ é bloqueado', () {
      final svcInstance = ZipIngestionService();
      expect(
        () => svcInstance.extractFile(Uint8List(0), 'folder/../../../etc/shadow'),
        throwsA(isA<IngestionSecurityException>()),
      );
    });

    test('5. path com null byte é bloqueado', () {
      final svcInstance = ZipIngestionService();
      expect(
        () => svcInstance.extractFile(Uint8List(0), 'file\x00.txt'),
        throwsA(isA<IngestionSecurityException>()
            .having((e) => e.message, 'message', contains('Null byte'))),
      );
    });

    test('6. path absoluto é bloqueado', () {
      final svcInstance = ZipIngestionService();
      expect(
        () => svcInstance.extractFile(Uint8List(0), '/etc/passwd'),
        throwsA(isA<IngestionSecurityException>()
            .having((e) => e.message, 'message', contains('absoluto'))),
      );
    });
  });

  group('ZipIngestionService — magic bytes', () {
    test('9. bytes não-ZIP lançam IngestionSecurityException', () async {
      final notZip = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      await expectLater(
        () => svc.parseBytes(notZip, source: IngestionSource.zip),
        throwsA(isA<IngestionSecurityException>()
            .having((e) => e.message, 'message', contains('magic bytes'))),
      );
    });

    test('9b. arquivo vazio lança IngestionSecurityException', () async {
      await expectLater(
        () => svc.parseBytes(Uint8List(0), source: IngestionSource.zip),
        throwsA(isA<IngestionSecurityException>()),
      );
    });
  });

  group('ZipIngestionService — extractFile', () {
    test('11. extrai arquivo existente com conteúdo correto', () async {
      final expected = 'Conteúdo do arquivo de teste';
      final zip      = _buildZip({'test.txt': _text(expected)});
      final bytes    = await svc.extractFile(zip, 'test.txt');
      expect(utf8.decode(bytes), expected);
    });

    test('12. arquivo inexistente lança AssetParserException', () async {
      final zip = _buildZip({'exists.txt': _text('hi')});
      await expectLater(
        () => svc.extractFile(zip, 'nao_existe.txt'),
        throwsA(isA<AssetParserException>()
            .having((e) => e.message, 'message', contains('não encontrado'))),
      );
    });
  });

  group('ZipIngestionService — parseBytes resultado', () {
    test('10. arquivo único muito grande gera aviso, não erro', () async {
      final limits = ZipSecurityLimits(
        maxSingleFileSizeBytes:    10,  // 10 bytes
        maxTotalUncompressedBytes: 10000000,
      );
      final svcSmall  = ZipIngestionService(limits: limits);
      final bigContent = Uint8List(100); // 100 bytes > limite de 10
      final zip        = _buildZip({'grande.txt': bigContent});

      final listing = await svcSmall.listContents(zip);
      expect(listing.warnings, isNotEmpty);
      expect(listing.warnings.any((w) => w.contains('grande')), isTrue);
      expect(listing.totalFiles, 0); // arquivo ignorado pela lista
    });

    test('parseBytes retorna ParsedContent com mimeType zip', () async {
      final zip = _buildZip({'a.txt': _text('hello')});
      final c   = await svc.parseBytes(zip, source: IngestionSource.zip, fileName: 'pkg.zip');
      expect(c.mimeType, 'application/zip');
      expect(c.title,    'pkg.zip');
      expect(c.fingerprint, isNotEmpty);
    });
  });

  group('ZipIngestionService — parseText', () {
    test('15. parseText lança AssetParserException', () async {
      await expectLater(
        () => svc.parseText('qualquer texto', source: IngestionSource.zip),
        throwsA(isA<AssetParserException>()),
      );
    });
  });
}
