import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';

class FileImportResult {
  final String text;
  final String fileName;
  final String fileType;
  final int charCount;

  const FileImportResult({
    required this.text,
    required this.fileName,
    required this.fileType,
    required this.charCount,
  });
}

class FileImportService {
  final _client = Supabase.instance.client;

  static const _processFileFunction = 'process-file';

  static const _supportedExtensions = ['pdf', 'docx', 'txt'];

  // IVE-COMMERCIAL-TARGETED-REMEDIATION-04 — nenhum destes tinha timeout
  // antes, o que permitia a UI ficar presa em "Extraindo texto…"
  // indefinidamente (observado em auditoria anterior: zero chamadas ao
  // process-file nos logs do período, ou seja, o travamento aconteceu
  // ANTES de qualquer rede -- no próprio picker/leitura de bytes).
  //
  // _pickTimeout é deliberadamente generoso (um humano real pode demorar
  // para navegar e escolher um arquivo) -- o objetivo não é apressar o
  // usuário, é garantir que um diálogo que nunca resolve (cancelamento
  // mal tratado pelo file_picker no Web, ou uma automação de navegador
  // que não consegue completar a interação com o diálogo nativo) acabe
  // desistindo com um erro claro e reversível em vez de travar para
  // sempre. _readTimeout e _extractTimeout são curtos porque são
  // operações de máquina (ler bytes já em memória do navegador / uma
  // chamada de rede) que devem ser rápidas quando funcionam.
  static const _pickTimeout = Duration(minutes: 5);
  static const _readTimeout = Duration(seconds: 30);
  static const _extractTimeout = Duration(seconds: 60);

  Future<FileImportResult?> pickAndExtract() async {
    // file_picker 12.x: FilePicker.pickFile() returns PlatformFile?
    // PlatformFile.readAsBytes() replaces the removed .bytes getter
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions,
    ).timeout(
      _pickTimeout,
      onTimeout: () => throw Exception(
        'Tempo esgotado ao selecionar o arquivo. Tente novamente.',
      ),
    );

    if (file == null) return null;

    final fileName  = file.name;
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'txt';

    final bytes = await file.readAsBytes().timeout(
      _readTimeout,
      onTimeout: () => throw Exception(
        'Tempo esgotado ao ler o arquivo. Tente novamente.',
      ),
    );
    if (bytes.isEmpty) throw Exception('Não foi possível ler o arquivo.');

    // TXT nunca passa pelo process-file (que já checa tamanho antes de
    // decodificar) -- sem este teto, um .txt gigante seria decodificado e
    // mantido inteiro em memória sem nenhum limite.
    if (extension == 'txt') {
      if (bytes.length > AppConstants.maxLocalImportBytes) {
        throw Exception('Arquivo de texto muito grande. O limite é de aproximadamente 6 MB.');
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      return FileImportResult(
        text:      text,
        fileName:  fileName,
        fileType:  'txt',
        charCount: text.length,
      );
    }

    return _extractViaEdgeFunction(bytes, extension, fileName);
  }

  Future<FileImportResult> _extractViaEdgeFunction(
    Uint8List bytes,
    String extension,
    String fileName,
  ) async {
    final base64Content = base64Encode(bytes);

    final response = await _client.functions.invoke(
      _processFileFunction,
      body: {
        'file_base64': base64Content,
        'file_type':   extension,
      },
    ).timeout(
      _extractTimeout,
      onTimeout: () => throw Exception(
        'O servidor demorou demais para extrair o texto. Tente novamente.',
      ),
    );

    if (response.data == null || response.data is! Map<String, dynamic>) {
      throw Exception('Resposta vazia do serviço de extração.');
    }

    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final text = data['text'] as String? ?? '';
    if (text.trim().length < 20) {
      throw Exception(
        'Conteúdo extraído muito curto. Tente copiar e colar o texto manualmente.',
      );
    }

    return FileImportResult(
      text:      text,
      fileName:  fileName,
      fileType:  extension,
      charCount: (data['char_count'] as int?) ?? text.length,
    );
  }
}
