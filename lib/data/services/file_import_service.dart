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
    // file_picker 12.x: FilePicker.pickFile() returns PlatformFile?
    // PlatformFile.readAsBytes() replaces the removed .bytes getter
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions,
    );

    if (file == null) return null;

    final fileName  = file.name;
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'txt';

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('Não foi possível ler o arquivo.');

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
