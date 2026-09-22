import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import 'drive_stage.dart';

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
  // PLAY-READINESS-18 (Section 14) -- text/csv added. DriveFile.isTxt
  // already matches any "text/*" mimeType (see below), so a CSV file
  // flows through the exact same download-as-text path TXT/Google Docs
  // already use -- no new code, just letting the Drive query surface it.
  static const _supportedMimes =
      "mimeType='application/vnd.google-apps.document' OR "
      "mimeType='application/pdf' OR "
      "mimeType='text/plain' OR "
      "mimeType='text/csv' OR "
      "mimeType='application/vnd.openxmlformats-officedocument.wordprocessingml.document'";

  final _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.readonly'],
  );

  // IVE-COMMERCIAL-TARGETED-REMEDIATION-04 — causa raiz real do
  // "Null check operator used on a null value" reportado no picker do
  // Drive: bug documentado e conhecido do próprio pacote google_sign_in /
  // google_sign_in_web, onde signInSilently() (sem sessão em cache,
  // sobretudo em Web) pode lançar essa exceção internamente em vez de
  // simplesmente retornar null -- o pacote assume, em parte do seu
  // código interno, que "usuário conhecido" implica objeto não-nulo, mas
  // a plataforma Web pode devolver um estado degenerado que rompe essa
  // suposição. Isto não é um bug do nosso código; é uma falha de uma
  // dependência externa. A correção robusta e segura aqui não é reescrever
  // o pacote -- é nunca deixar essa chamada específica propagar uma
  // exceção não tratada para fora do nosso próprio código, tratando
  // "silentSignIn lançou" exatamente como "silentSignIn retornou null"
  // (nenhuma sessão em cache -- cai para o fluxo interativo de login).
  Future<GoogleSignInAccount?> _signInSilentlySafe() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      // IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — mantém o retorno seguro
      // (nenhuma sessão em cache), mas agora deixa um rastro diagnosticável
      // (nunca o token) de que o bug conhecido do pacote realmente disparou
      // aqui, em vez de falhar silenciosamente sem nenhuma pista.
      debugPrint('[drive:silent-signin] falha tratada como "sem sessão": ${redactForLog(e)}');
      return null;
    }
  }

  // Mesma proteção: isSignedIn() pode consultar o mesmo estado
  // problemático internamente. Falha segura para "não conectado" em vez
  // de deixar o erro subir e derrubar a tela (era chamado sem nenhum
  // try/catch em initState() do picker -- exatamente onde o crash
  // relatado acontecia, sem chance de mostrar qualquer mensagem amigável).
  Future<bool> get isSignedIn async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      debugPrint('[drive:is-signed-in] falha tratada como "não conectado": ${redactForLog(e)}');
      return false;
    }
  }

  // IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — causa raiz real do crash
  // físico que sobreviveu à Remediation 04 (confirmado contra o changelog
  // oficial do pacote, não suposição): `google_sign_in: ^6.2.1` fixa
  // `google_sign_in_web: ^0.12.0`, e o próprio changelog dessa versão
  // documenta uma mudança que quebra compatibilidade: "signInSilently now
  // returns an authenticated (but not authorized) user". A partir da
  // migração para Google Identity Services (GIS), "estar autenticado"
  // (identidade) e "estar autorizado" (ter concedido um escopo extra como
  // drive.readonly) deixaram de ser a mesma coisa -- mas a API disponível
  // em `google_sign_in` 6.x (verificado na documentação da versão: única
  // via é `GoogleSignInAccount.authentication`; `authorizeScopes`/
  // `authorizationForScopes` só existem numa major posterior, fora do
  // range fixado aqui) não tem como pedir essa reautorização de escopo
  // separadamente. `isSignedIn()`/`signInSilently()` continuam retornando
  // "true"/uma conta mesmo quando essa conta não tem autorização real para
  // drive.readonly -- exatamente o estado "autenticado mas não autorizado"
  // do changelog -- e é nessa reconciliação interna, dentro do próprio
  // pacote, que a Null check operator exception documentada dispara.
  //
  // IVE-COMMERCIAL-TARGETED-REMEDIATION-06 (Codex adversarial re-check) --
  // a primeira versão desta função ainda tinha o gap real que o crash
  // físico expõe: `account ??= await _googleSignIn.signIn()` só cai para o
  // fluxo interativo quando a conta silenciosa é `null`. No estado
  // "autenticado mas não autorizado", a conta silenciosa NÃO é null -- só
  // não tem um token de Drive utilizável -- então o clique em "Entrar com
  // Google" não fazia nada: devolvia a mesma conta quebrada, sem nunca
  // mostrar a tela de consentimento que de fato concede drive.readonly de
  // novo. resolveUsableAccount() (drive_stage.dart) fecha isso: só reusa a
  // conta silenciosa se um token real para ELA (não currentUser, a mesma
  // conta) funcionar; caso contrário sempre cai para o fluxo interativo.
  Future<GoogleSignInAccount?> signIn() {
    return resolveUsableAccount<GoogleSignInAccount>(
      silentSignIn: _signInSilentlySafe,
      tokenFor: _tokenForAccount,
      interactiveSignIn: () => runDriveStage(
        'signin',
        () => _googleSignIn.signIn(),
        timeout: const Duration(seconds: 60),
      ),
    );
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<String?> _tokenForAccount(GoogleSignInAccount account) {
    return runDriveStage('token', () async {
      final auth = await account.authentication;
      return auth.accessToken;
    });
  }

  Future<String?> _token() async {
    final account = _googleSignIn.currentUser ?? await _signInSilentlySafe();
    if (account == null) return null;
    return _tokenForAccount(account);
  }

  // IVE-COMMERCIAL-TARGETED-REMEDIATION-06 — o check de sessão real, não
  // só de identidade. `isSignedIn` acima responde "esta pessoa está
  // autenticada com o Google?", que sob GIS pode ser `true` mesmo sem
  // autorização de drive.readonly (ver nota em signIn()). Quem decide se a
  // tela do picker deve pular direto para a lista de arquivos precisa da
  // pergunta certa: "um token de Drive utilizável existe agora?" -- só
  // isso garante que o próximo passo (listFiles) não vai falhar no mesmo
  // estado degenerado. Falha (de qualquer tipo, incluindo a exceção
  // documentada do pacote) é tratada como "sessão não utilizável" -- a
  // tela cai para o botão de login, nunca para uma lista de arquivos que
  // sabemos que vai quebrar.
  Future<bool> hasUsableSession() async {
    try {
      final signedIn = await isSignedIn;
      if (!signedIn) return false;
      final token = await _token();
      return token != null;
    } catch (e) {
      debugPrint('[drive:usable-session] falha tratada como "sessão não utilizável": ${redactForLog(e)}');
      return false;
    }
  }

  Future<List<DriveFile>> listFiles({String search = ''}) async {
    final token = await _token();
    if (token == null) throw const DriveStageException('token', 'Não autenticado com Google');

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

    final res = await runDriveStage(
      'list',
      () => http.get(uri, headers: {'Authorization': 'Bearer $token'}),
    );
    if (res.statusCode != 200) {
      throw DriveStageException('list', 'Drive API erro ${res.statusCode}');
    }

    // IVE-COMMERCIAL-TARGETED-REMEDIATION-04 (achado do Codex Gate) --
    // `as String` direto num campo ausente/nulo lança
    // "type 'Null' is not a subtype of type 'String'", derrubando a
    // listagem inteira por causa de UM item malformado. A API do Drive
    // já garante id/name/mimeType quando o campo é devolvido (pedimos
    // exatamente esses no `fields=`), mas nunca confiar cegamente numa
    // resposta externa -- itens sem os campos esperados são
    // silenciosamente ignorados (`whereType`) em vez de derrubar a tela.
    final data = json.decode(res.body) as Map<String, dynamic>;
    final rawFiles = data['files'] as List? ?? [];
    return rawFiles
        .whereType<Map<String, dynamic>>()
        .map((f) {
          final id = f['id'];
          final name = f['name'];
          final mimeType = f['mimeType'];
          if (id is! String || name is! String || mimeType is! String) return null;
          return DriveFile(
            id: id,
            name: name,
            mimeType: mimeType,
            modifiedTime: f['modifiedTime'] as String?,
          );
        })
        .whereType<DriveFile>()
        .toList();
  }

  Future<String> downloadContent(DriveFile file) async {
    final token = await _token();
    if (token == null) throw const DriveStageException('token', 'Não autenticado com Google');

    // Google Docs → export directly as plain text
    if (file.isGoogleDoc) {
      final uri = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/${file.id}/export'
          '?mimeType=text/plain');
      final res = await runDriveStage(
        'download',
        () => http.get(uri, headers: {'Authorization': 'Bearer $token'}),
      );
      if (res.statusCode != 200) {
        throw DriveStageException('download', 'Erro ao baixar arquivo: ${res.statusCode}');
      }
      _assertWithinImportLimit(res.bodyBytes.length);
      return _stripNulls(res.body);
    }

    // DOCX and PDF → download raw bytes, extract text via Edge Function
    // (same approach as local file import — avoids null bytes from binary data)
    if (file.isDocx || file.isPdf) {
      final uri = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/${file.id}?alt=media');
      final res = await runDriveStage(
        'download',
        () => http.get(uri, headers: {'Authorization': 'Bearer $token'}),
      );
      if (res.statusCode != 200) {
        throw DriveStageException('download', 'Erro ao baixar arquivo: ${res.statusCode}');
      }
      return runDriveStage(
        'extract',
        () => _extractTextViaEdgeFunction(
          res.bodyBytes,
          file.isDocx ? 'docx' : 'pdf',
        ),
      );
    }

    // TXT and other text formats → download as text, strip any null bytes
    final uri = Uri.parse(
        'https://www.googleapis.com/drive/v3/files/${file.id}?alt=media');
    final res = await runDriveStage(
      'download',
      () => http.get(uri, headers: {'Authorization': 'Bearer $token'}),
    );
    if (res.statusCode != 200) {
      throw DriveStageException('download', 'Erro ao baixar arquivo: ${res.statusCode}');
    }
    _assertWithinImportLimit(res.bodyBytes.length);
    return _stripNulls(res.body);
  }

  // Nem o export de Google Docs nem o download de TXT passam pelo
  // process-file (que já checa tamanho antes de qualquer parsing) -- sem
  // este teto, um arquivo de texto gigante no Drive do usuário seria
  // mantido inteiro em memória sem nenhum limite.
  void _assertWithinImportLimit(int byteLength) {
    if (byteLength > AppConstants.maxLocalImportBytes) {
      throw Exception('Arquivo muito grande para importar. O limite é de aproximadamente 6 MB.');
    }
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

    if (response.data == null || response.data is! Map<String, dynamic>) {
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
