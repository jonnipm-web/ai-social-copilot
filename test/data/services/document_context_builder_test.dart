// SHOW-01A — Testes T01–T20: DocumentContextBuilder
// Lógica pura, sem widgets Flutter, sem rede.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/knowledge_item.dart';
import 'package:ai_social_copilot/data/services/document_context_builder.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

KnowledgeItem _item({
  String id       = 'id1',
  String title    = 'Doc',
  String content  = '',
  String status   = 'analyzed',
  String? projectId,
  int score       = 0,
}) =>
    KnowledgeItem(
      id:              id,
      userId:          'uid',
      projectId:       projectId,
      title:           title,
      content:         content,
      status:          status,
      opportunityScore: score,
      createdAt:       DateTime(2026),
      updatedAt:       DateTime(2026),
    );

void main() {
  // ── chunk() ───────────────────────────────────────────────────────────────

  // T01
  test('T01: chunk() — string vazia retorna lista vazia', () {
    expect(DocumentContextBuilder.chunk(''), isEmpty);
    expect(DocumentContextBuilder.chunk('   '), isEmpty);
  });

  // T02
  test('T02: chunk() — string menor que maxSize retorna um único chunk', () {
    const text = 'Olá mundo';
    final chunks = DocumentContextBuilder.chunk(text, maxSize: 100);
    expect(chunks.length, 1);
    expect(chunks.first, text);
  });

  // T03
  test('T03: chunk() — string maior que maxSize retorna múltiplos chunks', () {
    final text = 'a' * 250;
    final chunks = DocumentContextBuilder.chunk(text, maxSize: 100, overlap: 10);
    expect(chunks.length, greaterThan(1));
  });

  // T04
  test('T04: chunk() — overlap produz sobreposição no início do próximo chunk', () {
    final text = 'A' * 100 + 'B' * 100;
    const maxSize = 120;
    const overlap = 20;
    final chunks = DocumentContextBuilder.chunk(text, maxSize: maxSize, overlap: overlap);
    expect(chunks.length, greaterThanOrEqualTo(2));
    // O segundo chunk deve começar com os últimos `overlap` chars do primeiro chunk
    final endOfFirst   = chunks[0].substring(chunks[0].length - overlap);
    final startOfSecond = chunks[1].substring(0, overlap);
    expect(startOfSecond, endOfFirst);
  });

  // ── relevanceScore() ─────────────────────────────────────────────────────

  // T05
  test('T05: relevanceScore() — contexto vazio retorna 0.0', () {
    expect(DocumentContextBuilder.relevanceScore('flutter dart mobile', ''), 0.0);
  });

  // T06
  test('T06: relevanceScore() — chunk vazio retorna 0.0', () {
    expect(DocumentContextBuilder.relevanceScore('', 'flutter mobile'), 0.0);
  });

  // T07
  test('T07: relevanceScore() — palavras curtas (<=3 chars) ignoradas no contexto', () {
    // Contexto com apenas palavras curtas → contextWords vazio → 0.0
    final score = DocumentContextBuilder.relevanceScore('the at in', 'the at in');
    expect(score, 0.0);
  });

  // T08
  test('T08: relevanceScore() — retorna valor positivo para match parcial', () {
    final score = DocumentContextBuilder.relevanceScore(
      'flutter mobile desenvolvimento',
      'flutter mobile',
    );
    expect(score, greaterThan(0.0));
    expect(score, lessThanOrEqualTo(1.0));
  });

  // ── buildGrounding() ──────────────────────────────────────────────────────

  // T09
  test('T09: buildGrounding() — lista vazia retorna DocumentGrounding.empty', () {
    final g = DocumentContextBuilder.buildGrounding([]);
    expect(g.excerpts, isEmpty);
    expect(g.warnings, isEmpty);
    expect(g.coverage.totalLinked, 0);
    expect(g.hasContent, isFalse);
  });

  // T10
  test('T10: buildGrounding() — item com content vazio gera aviso EMPTY_CONTENT', () {
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'a', title: 'Vazio', content: ''),
    ]);
    expect(g.excerpts, isEmpty);
    expect(g.warnings.any((w) => w.code == 'EMPTY_CONTENT'), isTrue);
    expect(g.coverage.usable, 0);
  });

  // T11
  test('T11: buildGrounding() — item com content produz excerpt', () {
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'b', content: 'Conteúdo real do documento para análise pelo copilot'),
    ]);
    expect(g.excerpts.length, 1);
    expect(g.excerpts.first.text, isNotEmpty);
    expect(g.hasContent, isTrue);
  });

  // T12
  test('T12: buildGrounding() — excerpt é truncado a maxExcerptChars', () {
    final longContent = 'palavra ' * 200; // ~1400 chars
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'c', content: longContent),
    ]);
    expect(g.excerpts.first.charCount,
        lessThanOrEqualTo(DocumentContextBuilder.maxExcerptChars));
  });

  // T13
  test('T13: buildGrounding() — budget esgotado gera aviso BUDGET_EXCEEDED', () {
    final items = List.generate(
      20,
      (i) => _item(
        id:      'id$i',
        title:   'Doc $i',
        content: 'a' * 500,
      ),
    );
    final g = DocumentContextBuilder.buildGrounding(
      items,
      maxChars: 600, // cabe ~1 documento completo
    );
    expect(g.warnings.any((w) => w.code == 'BUDGET_EXCEEDED'), isTrue);
    expect(g.coverage.used, lessThan(items.length));
  });

  // T14
  test('T14: buildGrounding() — métricas de coverage são corretas', () {
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'x1', content: 'Conteúdo válido para grounding'),
      _item(id: 'x2', content: ''),
    ]);
    expect(g.coverage.totalLinked, 2);
    expect(g.coverage.processed, 2);
    expect(g.coverage.usable, 1);
    expect(g.coverage.used, 1);
    expect(g.coverage.documentUsageCoverage, closeTo(0.5, 0.01));
  });

  // T15
  test('T15: buildGrounding() — documentUsageCoverage é 0.0 para lista vazia', () {
    final g = DocumentContextBuilder.buildGrounding([]);
    expect(g.coverage.documentUsageCoverage, 0.0);
  });

  // T16
  test('T16: buildGrounding() — com projectContext seleciona chunk relevante', () {
    final content =
        'bloco irrelevante nada a ver com o projeto ' * 3 +
        ' flutter mobile desenvolvimento android ';
    final g = DocumentContextBuilder.buildGrounding(
      [_item(id: 'y1', content: content)],
      projectContext: 'flutter mobile android',
    );
    expect(g.excerpts.first.text, contains('flutter'));
  });

  // T17
  test('T17: buildGrounding() — múltiplos itens produzem múltiplos excerpts', () {
    final items = [
      _item(id: 'm1', content: 'Conteúdo do documento um sobre marketing digital'),
      _item(id: 'm2', content: 'Conteúdo do documento dois sobre produto e vendas'),
      _item(id: 'm3', content: 'Conteúdo do documento três sobre growth hacking'),
    ];
    final g = DocumentContextBuilder.buildGrounding(items);
    expect(g.excerpts.length, 3);
    expect(g.coverage.used, 3);
  });

  // T18
  test('T18: buildGrounding() — charCount no excerpt bate com text.length', () {
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'z1', content: 'Texto para verificar charCount do excerpt grounded'),
    ]);
    final e = g.excerpts.first;
    expect(e.charCount, e.text.length);
  });

  // T19
  test('T19: buildGrounding() — item status pending com content vazio gera aviso', () {
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'p1', status: 'pending', content: ''),
    ]);
    expect(g.warnings.any((w) => w.code == 'EMPTY_CONTENT'), isTrue);
    expect(g.excerpts, isEmpty);
  });

  // T20
  test('T20: DocumentGrounding.hasContent — false sem excerpts, true com excerpts', () {
    final empty = DocumentContextBuilder.buildGrounding([
      _item(id: 'e1', content: ''),
    ]);
    expect(empty.hasContent, isFalse);

    final filled = DocumentContextBuilder.buildGrounding([
      _item(id: 'f1', content: 'Conteúdo real presente e processável'),
    ]);
    expect(filled.hasContent, isTrue);
  });
}
