import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
    this.modifiedTime,
  });

  final String id;
  final String name;
  final String mimeType;
  final String? modifiedTime;

  bool get isGoogleDoc =>
      mimeType == 'application/vnd.google-apps.document';
  bool get isPdf => mimeType == 'application/pdf';
  bool get isDocx =>
      mimeType ==
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  bool get isTxt => mimeType.startsWith('text/');

  IconData get icon {
    if (isGoogleDoc) return Icons.description_rounded;
    if (isPdf) return Icons.picture_as_pdf_rounded;
    return Icons.insert_drive_file_rounded;
  }

  String get typeLabel {
    if (isGoogleDoc) return 'Google Doc';
    if (isPdf) return 'PDF';
    if (isDocx) return 'Word';
    return 'Texto';
  }
}

class DriveService {
  static const _supportedMimes =
      "mimeType='application/vnd.google-apps.document' OR "
      "mimeType='application/pdf' OR "
      "mimeType='text/plain' OR "
      "mimeType='application/vnd.openxmlformats-officedocument.wordprocessingml.document'";

  final _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.readonly'],
  );

  Future<bool> get isSignedIn => _googleSignIn.isSignedIn();

  Future<GoogleSignInAccount?> signIn() async {
    var account = await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();
    return account;
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<String?> _token() async {
    final account =
        _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  Future<List<DriveFile>> listFiles({String search = ''}) async {
    final token = await _token();
    if (token == null) throw Exception('Não autenticado com Google');

    var q = '($_supportedMimes) AND trashed=false';
    if (search.isNotEmpty) q += " AND name contains '${search.replaceAll("'", "\\'")}'";

    final uri = Uri.parse('https://www.googleapis.com/drive/v3/files').replace(
      queryParameters: {
        'q': q,
        'fields': 'files(id,name,mimeType,modifiedTime)',
        'orderBy': 'modifiedTime desc',
        'pageSize': '50',
      },
    );

    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) {
      throw Exception('Drive API erro ${res.statusCode}');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    return (data['files'] as List? ?? [])
        .map((f) => DriveFile(
              id:           f['id'] as String,
              name:         f['name'] as String,
              mimeType:     f['mimeType'] as String,
              modifiedTime: f['modifiedTime'] as String?,
            ))
        .toList();
  }

  Future<String> downloadContent(DriveFile file) async {
    final token = await _token();
    if (token == null) throw Exception('Não autenticado com Google');

    // Google Docs → export directly as plain text
    if (file.isGoogleDoc) {
      final uri = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/${file.id}/export'
          '?mimeType=text/plain');
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) {
        throw Exception('Erro ao baixar arquivo: ${res.statusCode}');
      }
      return _stripNulls(res.body);
    }

    // DOCX and PDF → download raw bytes, extract text via Edge Function
    // (same approach as local file import — avoids null bytes from binary data)
    if (file.isDocx || file.isPdf) {
      final uri = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/${file.id}?alt=media');
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) {
        throw Exception('Erro ao baixar arquivo: ${res.statusCode}');
      }
      return _extractTextViaEdgeFunction(
        res.bodyBytes,
        file.isDocx ? 'docx' : 'pdf',
      );
    }

    // TXT and other text formats → download as text, strip any null bytes
    final uri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files/${file.id}?alt=media');
    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) {
      throw Exception('Erro ao baixar arquivo: ${res.statusCode}');
    }
    return _stripNulls(res.body);
  }

  Future<String> _extractTextViaEdgeFunction(
    Uint8List bytes,
    String extension,
  ) async {
    final response = await Supabase.instance.client.functions.invoke(
      'process-file',
      body: {
        'file_base64': base64Encode(bytes),
        'file_type':   extension,
      },
    );

    if (response.data == null) {
      throw Exception('Resposta vazia do serviço de extração de texto.');
    }

    final data = response.data as Map<String, dynamic>;
    if (data.containsKey('error')) throw Exception(data['error']);

    final text = _stripNulls(data['text'] as String? ?? '');
    if (text.trim().length < 20) {
      throw Exception(
        'Conteúdo extraído muito curto. O arquivo pode estar protegido ou corrompido.',
      );
    }
    return text;
  }

  static String _stripNulls(String s) => s.replaceAll('\x00', '');
}
