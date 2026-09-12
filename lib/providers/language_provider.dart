import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — preferência de idioma PT/EN.
/// Fallback determinístico: locale do dispositivo se for 'en', senão 'pt'
/// sempre (nunca um terceiro idioma não suportado, nunca tela mista).
const _kLanguagePrefKey = 'ive_language_code';
const _kSupportedLanguageCodes = {'pt', 'en'};

Locale _deviceDefaultLocale() {
  final deviceCode = PlatformDispatcher.instance.locale.languageCode;
  return Locale(_kSupportedLanguageCodes.contains(deviceCode) ? deviceCode : 'pt');
}

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(_deviceDefaultLocale()) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kLanguagePrefKey);
      if (saved != null && _kSupportedLanguageCodes.contains(saved)) {
        state = Locale(saved);
      }
    } catch (_) {
      // SharedPreferences pode falhar em ambiente de teste -- mantém o
      // fallback determinístico já definido no construtor.
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (!_kSupportedLanguageCodes.contains(languageCode)) return;
    state = Locale(languageCode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLanguagePrefKey, languageCode);
    } catch (_) {
      // Preferência não persistida, mas a sessão atual já reflete a escolha.
    }
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, Locale>(
  (ref) => LanguageNotifier(),
);
