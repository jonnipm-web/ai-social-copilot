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

  // T12 — budget adaptativo: cada excerpt usa até maxChunkSize chars (sem cota fixa por documento)
  test('T12: buildGrounding() — excerpt usa até maxChunkSize chars (budget adaptativo)', () {
    final longContent = 'palavra ' * 200; // ~1400 chars → múltiplos chunks
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'c', content: longContent),
    ]);
    // Cada excerpt individual é no máximo um chunk (maxChunkSize)
    for (final e in g.excerpts) {
      expect(e.charCount, lessThanOrEqualTo(DocumentContextBuilder.maxChunkSize));
    }
    expect(g.hasContent, isTrue);
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

  // ── Budget Adaptativo (SHOW-01A.2) ───────────────────────────────────────────

  // T22
  test('T22: adaptive budget — sem cota fixa, excerpt pode exceder 500 chars', () {
    // Conteúdo de ~960 chars → primeiro chunk = 800 chars (maxChunkSize)
    final content = 'palavra ' * 120; // 8 chars × 120 = 960 chars
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'ad1', content: content),
    ]);
    // No algoritmo antigo o excerpt seria truncado a 500 chars.
    // No novo, usa o chunk completo (até maxChunkSize = 800 chars).
    expect(g.excerpts.first.charCount, greaterThan(500));
    expect(g.excerpts.first.charCount,
        lessThanOrEqualTo(DocumentContextBuilder.maxChunkSize));
    expect(g.hasContent, isTrue);
  });

  // T23
  test('T23: Pass 1 cobre todos os docs usáveis antes do Pass 2', () {
    final items = [
      _item(id: 'd1', content: 'flutter mobile desenvolvimento android ios apps'),
      _item(id: 'd2', content: 'receita bolo chocolate delicioso sobremesa doce'),
      _item(id: 'd3', content: 'investimento renda variável bolsa valores fundos'),
    ];
    final g = DocumentContextBuilder.buildGrounding(
      items,
      projectContext: 'flutter mobile',
    );
    // Todos os 3 docs têm content → todos devem ter excerpt (diversidade de Pass 1)
    final excerptIds = g.excerpts.map((e) => e.documentId).toSet();
    expect(excerptIds, containsAll({'d1', 'd2', 'd3'}));
    expect(g.coverage.used, 3);
  });

  // T24
  test('T24: Pass 2 adiciona chunks extras quando budget sobra após Pass 1', () {
    // Conteúdo longo → gera múltiplos chunks; budget amplo → Pass 2 adiciona chunk extra
    final content = 'flutter mobile android desenvolvimento ' * 35; // ~1330 chars → 2 chunks
    final g = DocumentContextBuilder.buildGrounding(
      [_item(id: 'p2a', content: content)],
      projectContext: 'flutter mobile',
    );
    // Pass 1 adiciona chunk 0; Pass 2 adiciona chunk 1 (budget restante = ~7200 chars)
    expect(g.excerpts.length, greaterThan(1));
    expect(g.excerpts.every((e) => e.documentId == 'p2a'), isTrue);
  });

  // T25
  test('T25: Pass 2 — doc altamente relevante acumula mais chars que doc irrelevante', () {
    final highRelevance = 'flutter mobile android desenvolvimento ios ' * 32; // ~1344 chars
    final lowRelevance  = 'receita bolo chocolate sobremesa doce culinária ' * 32;
    final g = DocumentContextBuilder.buildGrounding(
      [
        _item(id: 'hr1', content: highRelevance),
        _item(id: 'lr1', content: lowRelevance),
      ],
      projectContext: 'flutter mobile android',
      maxChars: 2500,
    );
    final hrChars = g.excerpts
        .where((e) => e.documentId == 'hr1')
        .fold(0, (s, e) => s + e.charCount);
    final lrChars = g.excerpts
        .where((e) => e.documentId == 'lr1')
        .fold(0, (s, e) => s + e.charCount);
    // Após Pass 2, o doc mais relevante deve ter mais ou igual chars
    expect(hrChars, greaterThanOrEqualTo(lrChars));
  });

  // T26 — Source Manifest Invariant com multi-excerpt
  test('T26: Source Manifest Invariant com multi-excerpt', () {
    final items = [
      _item(id: 'sm1', content: 'conteúdo real do documento um para análise grounded'),
      _item(id: 'sm2', content: ''), // vazio — não deve aparecer no manifest
      _item(id: 'sm3', content: 'conteúdo real do documento três para análise grounded'),
    ];
    final g = DocumentContextBuilder.buildGrounding(items);
    final excerptIds  = g.excerpts.map((e) => e.documentId).toSet();
    final usableIds   = items
        .where((i) => i.content.trim().isNotEmpty)
        .map((i) => i.id)
        .toSet();
    // Todos os excerpts devem vir de items com content
    for (final id in excerptIds) {
      expect(usableIds, contains(id));
    }
    // Item sem content NÃO deve aparecer no manifest
    expect(excerptIds, isNot(contains('sm2')));
    // coverage.used == docs únicos com excerpt (não total de excerpts)
    expect(g.coverage.used, excerptIds.length);
  });

  // T27
  test('T27: coverage.used conta documentos únicos, não número de excerpts', () {
    // Documento com múltiplos chunks → gera múltiplos excerpts, mas used = 1
    final content = 'flutter mobile android desenvolvimento ' * 35; // ~1330 chars → 2 chunks
    final g = DocumentContextBuilder.buildGrounding(
      [_item(id: 'cu1', content: content)],
      projectContext: 'flutter mobile',
    );
    expect(g.coverage.used, 1); // 1 doc único, não importa quantos excerpts
    expect(g.excerpts.every((e) => e.documentId == 'cu1'), isTrue);
  });

  // T28
  test('T28: selectedCharacterCount == soma dos charCounts dos excerpts', () {
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'sc1', content: 'Conteúdo real para verificar selectedCharacterCount no coverage'),
      _item(id: 'sc2', content: 'Outro conteúdo real também para verificar o campo selectedCharCount'),
    ]);
    final totalExcerptChars = g.excerpts.fold(0, (s, e) => s + e.charCount);
    expect(g.coverage.selectedCharacterCount, totalExcerptChars);
  });

  // T29
  test('T29: availableContentCharCount == soma do content.trim().length dos itens usáveis', () {
    final items = [
      _item(id: 'ac1', content: 'Conteúdo um com texto real e mensurável para teste'),
      _item(id: 'ac2', content: ''), // vazio — não conta
      _item(id: 'ac3', content: 'Conteúdo três com texto real e mensurável para teste'),
    ];
    final g = DocumentContextBuilder.buildGrounding(items);
    final expectedAvailable = items
        .where((i) => i.content.trim().isNotEmpty)
        .fold(0, (s, i) => s + i.content.trim().length);
    expect(g.coverage.availableContentCharCount, expectedAvailable);
  });

  // T30
  test('T30: BUDGET_EXCEEDED gerado quando budget é insuficiente para todos os docs', () {
    final items = List.generate(
      10,
      (i) => _item(id: 'be$i', title: 'Doc $i', content: 'a' * 300),
    );
    // Budget = 600 chars → cabe apenas 2 docs de 300 chars cada
    final g = DocumentContextBuilder.buildGrounding(items, maxChars: 600);
    expect(g.warnings.any((w) => w.code == 'BUDGET_EXCEEDED'), isTrue);
    expect(g.coverage.used, lessThan(items.length));
  });

  // T21 — Source Manifest Invariant
  // SET(excerpts in manifest) == SET(docs with content that entered LLM prompt)
  // Garante: nenhuma fonte aparece como "usada" se seu trecho não entrou no contexto.
  test('T21: Source Manifest Invariant — excerpts correspond exactly to items passed in', () {
    final items = [
      _item(id: 'si1', title: 'Doc 1', content: 'Conteúdo real do documento um'),
      _item(id: 'si2', title: 'Doc 2', content: ''),              // sem content
      _item(id: 'si3', title: 'Doc 3', content: 'Conteúdo real do documento três'),
    ];

    final g = DocumentContextBuilder.buildGrounding(items);

    // IDs que efetivamente têm excerpt no manifest
    final excerptIds = g.excerpts.map((e) => e.documentId).toSet();

    // IDs que têm content e deveriam estar no manifest
    final usableIds = items
        .where((i) => i.content.trim().isNotEmpty)
        .map((i) => i.id)
        .toSet();

    // Invariant: todos os usable items cujo excerpt foi criado estão no manifest
    // e todos os itens no manifest vieram dos items passados
    for (final id in excerptIds) {
      expect(usableIds, contains(id),
          reason: 'Excerpt para "$id" não veio dos items passados ao builder');
    }

    // Itens sem content NÃO aparecem no manifest
    expect(excerptIds, isNot(contains('si2')),
        reason: 'Item si2 tem content vazio e não deve aparecer no manifest');

    // coverage.used == número de documentos únicos representados pelos excerpts
    // NÃO é igual ao número total de excerpts (que pode ser maior com multi-chunk).
    expect(g.coverage.used, excerptIds.length,
        reason: 'coverage.used deve contar documentos únicos, não total de excerpts');
  });

  // ── Delivery Budget (SHOW-01A.4) ─────────────────────────────────────────────
  // Verifica o contrato AVAILABLE → SELECTED → DELIVERED e as métricas de coverage.

  // T31
  test('T31: deliveredCharacterCount == selectedCharacterCount dentro do budget', () {
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'dl1', content: 'Conteúdo real do documento para verificar delivery budget'),
      _item(id: 'dl2', content: 'Outro conteúdo real para confirmar que delivered equals selected'),
    ]);
    expect(g.coverage.deliveredCharacterCount, g.coverage.selectedCharacterCount);
  });

  // T32
  test('T32: deliveredCharacterCount <= selectedCharacterCount (invariante)', () {
    final content = 'flutter mobile android desenvolvimento ' * 35; // 2 chunks
    final g = DocumentContextBuilder.buildGrounding(
      [_item(id: 'dc1', content: content)],
      projectContext: 'flutter mobile',
    );
    expect(
      g.coverage.deliveredCharacterCount,
      lessThanOrEqualTo(g.coverage.selectedCharacterCount),
    );
  });

  // T33
  test('T33: delivered == selected quando todo conteúdo está dentro do budget', () {
    // 3 docs breves → << 8000 chars → tudo cabe no budget → delivered == selected
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'w1', content: 'Documento um com conteúdo breve para verificar o budget'),
      _item(id: 'w2', content: 'Documento dois com conteúdo breve para verificar o budget'),
      _item(id: 'w3', content: 'Documento três com conteúdo breve para verificar o budget'),
    ]);
    expect(g.coverage.deliveredCharacterCount, g.coverage.selectedCharacterCount);
  });

  // T34
  test('T34: selectedCharacterCount e deliveredCharacterCount nunca excedem maxChars', () {
    const maxChars = 3000;
    final items = List.generate(
      20,
      (i) => _item(id: 'tb$i', content: 'conteúdo do documento $i com texto suficiente para o teste'),
    );
    final g = DocumentContextBuilder.buildGrounding(items, maxChars: maxChars);
    expect(g.coverage.selectedCharacterCount, lessThanOrEqualTo(maxChars));
    expect(g.coverage.deliveredCharacterCount, lessThanOrEqualTo(maxChars));
  });

  // T35
  test('T35: Pass 2 — conteúdo do segundo excerpt está presente nos excerpts entregues', () {
    // Chunk 1: flutter-heavy → alta relevância → selecionado no Pass 1
    // Chunk 2: conteúdo diferente → selecionado no Pass 2 (budget amplo)
    // Verifica que o texto do 2.º chunk aparece nos excerpts (entregue ao LLM)
    final chunk1 = 'flutter mobile android desenvolvimento ' * 30; // 30*38 ≈ 1140 chars
    final chunk2 = 'receita culinaria chocolate bolo ingrediente ' * 20; // 20*44 ≈ 880 chars
    final content = chunk1 + chunk2; // ~2020 chars → 3 chunks

    final g = DocumentContextBuilder.buildGrounding(
      [_item(id: 'me1', content: content)],
      projectContext: 'flutter mobile',
    );

    // Pass 2 deve ter adicionado chunk(s) com conteúdo de 'receita'
    expect(g.excerpts.length, greaterThan(1));
    final allExcerptText = g.excerpts.map((e) => e.text).join(' ');
    expect(allExcerptText, contains('receita'));
  });

  // T36
  test('T36: diversidade documental preservada — todos os docs com content têm excerpt', () {
    final items = [
      _item(id: 'dv1', content: 'conteúdo do documento um sobre marketing digital e vendas'),
      _item(id: 'dv2', content: 'conteúdo do documento dois sobre produto digital e growth'),
      _item(id: 'dv3', content: 'conteúdo do documento três sobre growth hacking e otimização'),
      _item(id: 'dv4', content: ''), // vazio — não deve ter excerpt
    ];
    final g = DocumentContextBuilder.buildGrounding(items);
    final excerptIds = g.excerpts.map((e) => e.documentId).toSet();
    expect(excerptIds, containsAll({'dv1', 'dv2', 'dv3'}));
    expect(excerptIds, isNot(contains('dv4')));
  });

  // T37
  test('T37: documento sem content não conta como delivered', () {
    final g = DocumentContextBuilder.buildGrounding([
      _item(id: 'nd1', content: 'conteúdo real presente e processável para grounding'),
      _item(id: 'nd2', content: ''),
      _item(id: 'nd3', content: '   '),
    ]);
    expect(g.coverage.used, 1); // somente nd1
    expect(g.coverage.deliveredCharacterCount, greaterThan(0));
    expect(g.coverage.deliveredCharacterCount, g.coverage.selectedCharacterCount);
  });

  // T38
  test('T38: coverage.used == documentos únicos com excerpt (independente de multi-excerpt)', () {
    final content = 'flutter mobile android desenvolvimento ' * 35; // 2 chunks
    final g = DocumentContextBuilder.buildGrounding(
      [
        _item(id: 'ud1', content: content),
        _item(id: 'ud2', content: 'outro conteúdo real para segundo documento do teste de cobertura'),
      ],
      projectContext: 'flutter mobile',
    );
    final uniqueDocIds = g.excerpts.map((e) => e.documentId).toSet();
    expect(g.coverage.used, uniqueDocIds.length);
    expect(g.excerpts.length, greaterThanOrEqualTo(g.coverage.used));
  });

  // T39
  test('T39: entrega é determinística — mesmo input produz exatamente mesmo output', () {
    final items = [
      _item(id: 'det1', content: 'flutter mobile android desenvolvimento ios aplicativo'),
      _item(id: 'det2', content: 'conteúdo do segundo documento para verificar determinismo'),
    ];
    const ctx = 'flutter mobile';
    final g1 = DocumentContextBuilder.buildGrounding(items, projectContext: ctx);
    final g2 = DocumentContextBuilder.buildGrounding(items, projectContext: ctx);

    expect(g1.excerpts.length, g2.excerpts.length);
    for (var i = 0; i < g1.excerpts.length; i++) {
      expect(g1.excerpts[i].documentId, g2.excerpts[i].documentId);
      expect(g1.excerpts[i].text,       g2.excerpts[i].text);
      expect(g1.excerpts[i].charCount,  g2.excerpts[i].charCount);
    }
    expect(g1.coverage.selectedCharacterCount,  g2.coverage.selectedCharacterCount);
    expect(g1.coverage.deliveredCharacterCount, g2.coverage.deliveredCharacterCount);
  });

  // T40
  test('T40: truncagem de budget é explícita e mensurável', () {
    // 5 docs × 1000 chars, budget=2000 → 2 docs cabem; os demais ficam de fora
    final items = List.generate(
      5,
      (i) => _item(id: 'lg$i', title: 'Doc $i', content: 'x' * 1000),
    );
    final g = DocumentContextBuilder.buildGrounding(items, maxChars: 2000);

    expect(g.warnings.any((w) => w.code == 'BUDGET_EXCEEDED'), isTrue);
    expect(g.coverage.selectedCharacterCount, lessThanOrEqualTo(2000));
    expect(g.coverage.deliveredCharacterCount, lessThanOrEqualTo(2000));

    // A diferença entre available e delivered é mensurável
    final gap = g.coverage.availableContentCharCount - g.coverage.deliveredCharacterCount;
    expect(gap, greaterThan(0)); // há conteúdo disponível não entregue
  });
}
