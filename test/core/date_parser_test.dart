import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/utils/date_parser.dart';

void main() {
  group('DateParser.parse', () {
    test('parseia string ISO 8601 válida', () {
      final result = DateParser.parse('2024-06-15T10:30:00.000Z');
      expect(result.year, 2024);
      expect(result.month, 6);
      expect(result.day, 15);
    });

    test('retorna DateTime passado diretamente', () {
      final dt = DateTime(2023, 1, 1);
      expect(DateParser.parse(dt), same(dt));
    });

    test('retorna fallback quando valor é null', () {
      final fallback = DateTime(2000, 1, 1);
      final result = DateParser.parse(null, fallback: fallback);
      expect(result, fallback);
    });

    test('retorna fallback quando string é inválida', () {
      final fallback = DateTime(2000, 1, 1);
      final result = DateParser.parse('não-é-data', fallback: fallback);
      expect(result, fallback);
    });

    test('retorna fallback quando valor é tipo desconhecido', () {
      final fallback = DateTime(2000, 1, 1);
      final result = DateParser.parse(42, fallback: fallback);
      expect(result, fallback);
    });

    test('usa DateTime.now().toUtc() como fallback padrão quando null', () {
      final before = DateTime.now().toUtc();
      final result = DateParser.parse(null);
      final after = DateTime.now().toUtc();
      expect(result.isAfter(before) || result.isAtSameMomentAs(before), isTrue);
      expect(result.isBefore(after) || result.isAtSameMomentAs(after), isTrue);
    });

    test('string vazia retorna fallback', () {
      final fallback = DateTime(2000);
      expect(DateParser.parse('', fallback: fallback), fallback);
    });

    test('parseia data sem horário (yyyy-MM-dd)', () {
      final result = DateParser.parse('2025-03-20');
      expect(result.year, 2025);
      expect(result.month, 3);
      expect(result.day, 20);
    });
  });

  group('DateParser.parseOrNull', () {
    test('retorna null para null', () {
      expect(DateParser.parseOrNull(null), isNull);
    });

    test('retorna null para string inválida', () {
      expect(DateParser.parseOrNull('xpto'), isNull);
    });

    test('retorna DateTime para string válida', () {
      final result = DateParser.parseOrNull('2024-01-01T00:00:00Z');
      expect(result, isNotNull);
      expect(result!.year, 2024);
    });

    test('retorna DateTime passado diretamente', () {
      final dt = DateTime(2023, 6, 1);
      expect(DateParser.parseOrNull(dt), same(dt));
    });

    test('retorna null para tipo desconhecido', () {
      expect(DateParser.parseOrNull(99), isNull);
    });
  });

  group('DateParser.toIso', () {
    test('serializa em UTC com sufixo Z', () {
      final dt = DateTime.utc(2024, 12, 25, 8, 0, 0);
      final iso = DateParser.toIso(dt);
      expect(iso, contains('2024-12-25'));
      expect(iso, endsWith('Z'));
    });

    test('converte horário local para UTC', () {
      final dt = DateTime(2024, 1, 1, 12, 0, 0);
      final iso = DateParser.toIso(dt);
      expect(iso, endsWith('Z'));
    });
  });
}
