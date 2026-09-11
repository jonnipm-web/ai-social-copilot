import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = Supabase.instance.client;

  // IVE-COMMERCIAL-GOOGLE-AUTH-01 — instância PRÓPRIA e completamente
  // separada da usada em drive_service.dart. Sem `scopes` aqui: pede só as
  // scopes de identidade padrão do pacote (openid/email/profile), nunca
  // drive.readonly. Login com Google e autorização do Drive são dois
  // consent boundaries diferentes por design -- nunca devem compartilhar
  // instância nem escopo.
  GoogleSignIn? _googleAuthSignIn;

  GoogleSignIn _resolveGoogleAuthSignIn() {
    final serverClientId = dotenv.env['GOOGLE_CLIENT_ID'];
    if (serverClientId == null ||
        serverClientId.isEmpty ||
        serverClientId == 'placeholder.apps.googleusercontent.com') {
      throw Exception('Login com Google não está configurado neste ambiente.');
    }
    return _googleAuthSignIn ??= GoogleSignIn(serverClientId: serverClientId);
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    if (response.user == null) {
      throw Exception('Cadastro falhou. Tente novamente.');
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // IVE-COMMERCIAL-GOOGLE-AUTH-01 — Web usa o fluxo baseado em navegador do
  // próprio Supabase (signInWithOAuth); Android usa o fluxo nativo
  // (signInWithIdToken) via google_sign_in, conforme a documentação oficial
  // atual do Supabase para Flutter (verificada nesta missão, não memória
  // desatualizada) recomenda para cada plataforma. Nenhuma das duas rotas
  // pede permissão de Drive -- essa continua sendo pedida separadamente,
  // só quando o usuário escolhe "Importar do Google Drive".
  //
  // Cancelamento do usuário (fecha o popup/seletor de conta) retorna
  // normalmente, sem sessão criada e sem lançar exceção -- não é um erro,
  // é uma escolha válida do usuário. Quem chama este método deve checar
  // `currentUser`/sessão após o retorno para saber se de fato logou.
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _client.auth.signInWithOAuth(OAuthProvider.google);
      return;
    }

    final googleSignIn = _resolveGoogleAuthSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return; // usuário cancelou

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null || accessToken == null) {
      throw Exception('Não foi possível obter as credenciais do Google.');
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
