import 'package:flutter/widgets.dart';

/// IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — mapeia o idioma de UI ('pt'/
/// 'en', controlado por languageProvider) para o código de idioma que as
/// Edge Functions de IA esperam no campo `language` do corpo da
/// requisição (mesmo formato já usado por generate-strategy/generate-
/// campaign/extract-knowledge antes desta missão: 'pt-BR'/'en-US').
String backendLanguageCode(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'en' ? 'en-US' : 'pt-BR';
}
