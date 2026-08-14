import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<FileImportResult?> pickAndExtract() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) throw Exception('Não foi possível ler o arquivo.');

    final extension = (file.extension ?? 'txt').toLowerCase();
    final fileName  = file.name;

    if (extension == 'txt') {
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
    );

    if (response.data == null) {
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
