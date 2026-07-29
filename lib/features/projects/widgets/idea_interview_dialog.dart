import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/knowledge_item.dart';
import '../../../data/models/project.dart';
import '../../../data/models/project_event.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/project_event_provider.dart';

enum _QuestionType { freeText, multiChoice, urlOptional, textAndNumber }

class _Question {
  final int number;
  final String category;
  final String text;
  final String hint;
  final _QuestionType type;
  final List<String> choices;

  const _Question(
    this.number,
    this.category,
    this.text,
    this.hint,
    this.type, {
    this.choices = const [],
  });
}

const _questions = <_Question>[
  _Question(1,  'Problema',     'Qual problema específico este projeto resolve?',
      'Ex: Pequenos empreendedores perdem tempo gerenciando redes sociais manualmente.',
      _QuestionType.freeText),
  _Question(2,  'Público',      'Quem é o cliente ideal? (idade, cargo, situação)',
      'Ex: Freelancers de 25-40 anos que vendem serviços digitais.',
      _QuestionType.freeText),
  _Question(3,  'Competição',   'Quais são os 3 principais concorrentes ou alternativas?',
      'Ex: Buffer, Hootsuite, agendamento manual em planilhas.',
      _QuestionType.freeText),
  _Question(4,  'Monetização',  'Como o projeto vai gerar receita?',
      'Selecione o modelo principal.',
      _QuestionType.multiChoice,
      choices: ['Assinatura (SaaS)', 'Venda única', 'Publicidade/Ads', 'Serviço/Consultoria', 'Marketplace', 'Freemium']),
  _Question(5,  'Mercado',      'Qual o mercado-alvo?',
      'Selecione o foco geográfico principal.',
      _QuestionType.multiChoice,
      choices: ['Brasil', 'EUA', 'Europa', 'América Latina', 'Global', 'Outro']),
  _Question(6,  'Estágio',      'Em que estágio está o projeto?',
      'Selecione o estágio atual.',
      _QuestionType.multiChoice,
      choices: ['Ideia (apenas conceito)', 'Validando (pesquisando)', 'MVP pronto (funciona)', 'Com primeiros clientes', 'Escalando']),
  _Question(7,  'MVP',          'O que seria o MVP mínimo para testar a ideia?',
      'Ex: Landing page + lista de espera, app com 3 funcionalidades, piloto com 10 clientes.',
      _QuestionType.freeText),
  _Question(8,  'Clientes',     'Já tem clientes ou usuários? Se sim, quantos?',
      'Ex: 0 ainda, 50 usuários beta, 3 clientes pagantes.',
      _QuestionType.textAndNumber),
  _Question(9,  'Link',         'Tem um site, app ou link para o projeto? (opcional)',
      'Ex: https://meu-projeto.com — deixe em branco se ainda não tem.',
      _QuestionType.urlOptional),
  _Question(10, 'Intenção',     'Qual o objetivo principal deste projeto?',
      'Selecione o objetivo mais importante.',
      _QuestionType.multiChoice,
      choices: ['Gerar receita pessoal', 'Aprendizado/experimento', 'Impacto social', 'Vender a empresa (exit)', 'Complementar trabalho atual']),
];

class IdeaInterviewDialog extends ConsumerStatefulWidget {
  final Project project;
  final VoidCallback onCompleted;

  const IdeaInterviewDialog({
    super.key,
    required this.project,
    required this.onCompleted,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required Project project,
    required VoidCallback onCompleted,
  }) =>
      showDialog<void>(
        context:    context,
        barrierDismissible: false,
        builder:    (_) => IdeaInterviewDialog(project: project, onCompleted: onCompleted),
      );

  @override
  ConsumerState<IdeaInterviewDialog> createState() => _IdeaInterviewDialogState();
}

class _IdeaInterviewDialogState extends ConsumerState<IdeaInterviewDialog> {
  int _current = 0;
  final Map<int, String> _answers = {};
  final _ctrl = TextEditingController();
  bool _saving = false;
  bool _skipped = false;

  _Question get _q => _questions[_current];
  bool get _isLast => _current == _questions.length - 1;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _selectChoice(String choice) {
    setState(() {
      _answers[_current] = choice;
      _ctrl.text = choice;
    });
  }

  void _next() {
    final answer = _ctrl.text.trim();
    if (answer.isEmpty && _q.type != _QuestionType.urlOptional) return;

    setState(() {
      _answers[_current] = answer;
      _ctrl.clear();
      if (!_isLast) _current++;
    });
  }

  Future<void> _finish() async {
    final answer = _ctrl.text.trim();
    if (answer.isEmpty && _q.type != _QuestionType.urlOptional) return;
    _answers[_current] = answer;

    setState(() => _saving = true);
    try {
      await _saveAsKnowledge();
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCompleted();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveAsKnowledge() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final content = _buildKnowledgeContent();

    // Extrai nicho da resposta 1 (Problema) — proxy mais próximo disponível
    // O campo niche real será enriquecido pela análise de mercado posterior
    final niche = _answers[0]?.isNotEmpty == true ? _answers[0] : null;

    await ref.read(knowledgeItemNotifierProvider.notifier).create(KnowledgeItem(
      id:         '',
      userId:     uid,
      projectId:  widget.project.id,
      title:      'Entrevista de Ideia — ${widget.project.name}',
      content:    content,
      sourceType: 'manual',
      status:     'analyzed',
      niche:      niche,
      createdAt:  DateTime.now(),
      updatedAt:  DateTime.now(),
    ));

    await ref.read(projectEventNotifierProvider(widget.project.id).notifier).emit(
      ProjectEventType.interviewCompleted,
      'Entrevista de Ideia concluída',
      description: '10 perguntas respondidas. Perfil do projeto enriquecido.',
    );
  }

  String _buildKnowledgeContent() {
    final buffer = StringBuffer();
    buffer.writeln('ENTREVISTA DE IDEIA — ${widget.project.name.toUpperCase()}');
    buffer.writeln('Data: ${DateTime.now().toIso8601String().substring(0, 10)}');
    buffer.writeln('');
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final a = _answers[i] ?? '(não respondida)';
      buffer.writeln('${q.number}. [${q.category.toUpperCase()}] ${q.text}');
      buffer.writeln('   Resposta: $a');
      buffer.writeln('');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_current + 1) / _questions.length;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, progress),
              const SizedBox(height: 24),
              _buildQuestion(theme),
              const SizedBox(height: 16),
              _buildInput(theme),
              const SizedBox(height: 24),
              _buildActions(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🎤', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'IVE precisa entender melhor "${widget.project.name}"',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _skipped = true);
                Navigator.of(context).pop();
                widget.onCompleted();
              },
              child: const Text('Pular', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00BCD4)),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_current + 1}/${_questions.length}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        if (_skipped)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '⚠️ Entrevista pulada — precisão das análises será reduzida.',
              style: TextStyle(color: Colors.orange, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestion(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF00BCD4).withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _q.category.toUpperCase(),
            style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 10, letterSpacing: 1.2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _q.text,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          _q.hint,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInput(ThemeData theme) {
    if (_q.type == _QuestionType.multiChoice) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _q.choices.map((c) {
          final selected = _answers[_current] == c;
          return GestureDetector(
            onTap: () => _selectChoice(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF00BCD4).withOpacity(0.2) : Colors.white10,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? const Color(0xFF00BCD4) : Colors.white24,
                ),
              ),
              child: Text(
                c,
                style: TextStyle(
                  color: selected ? const Color(0xFF00BCD4) : Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return TextField(
      controller:  _ctrl,
      autofocus:   true,
      maxLines:    _q.type == _QuestionType.freeText ? 3 : 1,
      style:       const TextStyle(color: Colors.white),
      keyboardType: _q.type == _QuestionType.urlOptional
          ? TextInputType.url
          : TextInputType.multiline,
      decoration: InputDecoration(
        hintText:        _q.hint,
        hintStyle:       const TextStyle(color: Colors.white24, fontSize: 12),
        filled:          true,
        fillColor:       Colors.white10,
        border:          OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   const BorderSide(color: Color(0xFF00BCD4)),
        ),
        contentPadding: const EdgeInsets.all(12),
        suffixText: _q.type == _QuestionType.urlOptional ? 'opcional' : null,
        suffixStyle: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
      onSubmitted: (_) => _isLast ? _finish() : _next(),
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_current > 0)
          TextButton(
            onPressed: () {
              setState(() {
                _current--;
                _ctrl.text = _answers[_current] ?? '';
              });
            },
            child: const Text('← Anterior', style: TextStyle(color: Colors.white54)),
          )
        else
          const SizedBox.shrink(),
        ElevatedButton(
          onPressed: _saving ? null : (_isLast ? _finish : _next),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BCD4),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  _isLast ? 'Concluir Entrevista ✓' : 'Próxima →',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
