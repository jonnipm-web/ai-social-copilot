// ── IVE Avatar Lab — Entrypoint Isolado ──────────────────────────────────────
//
// Entrypoint exclusivo para avaliação visual do IVE Avatar V2.
//
// NÃO inicializa: Supabase, autenticação, Google Drive, Edge Functions ou
// qualquer serviço de produção. Abre diretamente no showcase.
//
// Uso:
//   flutter run  --target lib/main_ive_avatar_lab.dart
//   flutter build apk --debug --target lib/main_ive_avatar_lab.dart \
//       --dart-define=APP_FLAVOR=iveAvatarLab

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared/ive_avatar/lab/ive_avatar_lab_app.dart';

void main() {
  runZonedGuarded(_boot, _onError);
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientação: portrait e landscape permitidos para o showcase
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Sistema de status bar transparente para maximizar a área de visualização
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    // ProviderScope necessário para iveAvatarV2StateProvider nos widgets do Avatar
    const ProviderScope(child: IveAvatarLabApp()),
  );
}

void _onError(Object error, StackTrace stack) {
  // Erros não tratados ficam no log sem crashar — lab deve ser resiliente
  debugPrint('[IVE Avatar Lab] Unhandled error: $error');
  debugPrintStack(stackTrace: stack, maxFrames: 12);
}
