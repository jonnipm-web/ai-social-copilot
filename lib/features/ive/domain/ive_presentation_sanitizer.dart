/// Defesa de apresentação: mantém identificadores no estado/evidência,
/// mas impede que detalhes internos apareçam no texto normal da conversa.
String sanitizeIvePresentationText(String value) {
  var result = value
      .replaceAll(
        RegExp(
          r'\[?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\]?',
        ),
        '',
      )
      .replaceAll(RegExp(r'\bPROJECT_SCORES\b', caseSensitive: false),
          'Indicadores estratégicos')
      .replaceAll(RegExp(r'\bproject_id\b', caseSensitive: false), 'projeto');

  result = result
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r'\[\s*\]'), '')
      .replaceAll(RegExp(r' +([,.;:])'), r'$1');
  return result.trim();
}
