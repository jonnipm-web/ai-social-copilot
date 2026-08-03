import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../showcase/ive_avatar_showcase_page.dart';

// ── IveAvatarLabApp ───────────────────────────────────────────────────────────
//
// MaterialApp raiz do build de laboratório. Isolado da App de produção.
// Não referencia Supabase, autenticação, GoRouter nem nenhum serviço externo.
// Abre diretamente no showcase, no modo Apresentação por padrão.

class IveAvatarLabApp extends ConsumerWidget {
  const IveAvatarLabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'IVE Avatar Lab',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      // Inicia diretamente no showcase — sem roteamento de produção
      home: const _LabShell(),
    );
  }

  static ThemeData _darkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C63FF),
        secondary: Color(0xFF03DAC6),
        surface: Color(0xFF1A1A2E),
        error: Color(0xFFCF6679),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
    );
  }

  static ThemeData _lightTheme() {
    // Light disponível mas showcase usa dark por padrão
    return ThemeData.light(useMaterial3: true);
  }
}

// ── _LabShell ─────────────────────────────────────────────────────────────────
//
// Wrapper que fornece o AppBar de identidade do Lab e abre o showcase.
// O appBar identifica claramente que este é o APK de laboratório,
// não o InsightValues de produção.

class _LabShell extends StatelessWidget {
  const _LabShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LabBadge(),
            SizedBox(width: 10),
            Text(
              'IVE Avatar Lab',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message:
                  'Versão de laboratório — não é o InsightValues principal',
              child: Chip(
                label: const Text(
                  'v0.1.0-lab',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
                backgroundColor: const Color(0xFF2A2A4A),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ],
      ),
      body: const IveAvatarShowcasePage(),
    );
  }
}

class _LabBadge extends StatelessWidget {
  const _LabBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: const Text(
        'LAB',
        style: TextStyle(
          color: Color(0xFF6C63FF),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
