// Utilitário central de parsing seguro de datas.
// Use sempre este helper em vez de DateTime.parse() diretamente nos modelos.
// DateTime.parse() lança FormatException se o valor for null ou malformado.

abstract final class DateParser {
  /// Faz parse de [value] de forma segura.
  /// Aceita String, DateTime ou null.
  /// Retorna [fallback] (padrão: DateTime.now().toUtc()) se não conseguir parsear.
  static DateTime parse(dynamic value, {DateTime? fallback}) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback ?? DateTime.now().toUtc();
  }

  /// Versão nullable: retorna null se [value] for null ou inválido.
  static DateTime? parseOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Serializa DateTime para string ISO 8601 UTC (para persistência no banco).
  static String toIso(DateTime dt) => dt.toUtc().toIso8601String();
}
