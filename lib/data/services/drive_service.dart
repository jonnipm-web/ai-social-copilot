import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

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
  static const _webClientId =
      '221504834589-jll1257ccns2sprai9ps949rv21gf7p2.apps.googleusercontent.com';

  static const _supportedMimes =
      "mimeType='application/vnd.google-apps.document' OR "
      "mimeType='application/pdf' OR "
      "mimeType='text/plain' OR "
      "mimeType='application/vnd.openxmlformats-officedocument.wordprocessingml.document'";

  final _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
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

    final Uri uri;
    if (file.isGoogleDoc) {
      uri = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/${file.id}/export'
          '?mimeType=text/plain');
    } else {
      uri = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/${file.id}?alt=media');
    }

    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) {
      throw Exception('Erro ao baixar arquivo: ${res.statusCode}');
    }
    return res.body;
  }
}
