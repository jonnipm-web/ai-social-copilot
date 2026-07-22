import 'package:flutter/material.dart';

import '../../features/ive/domain/ive_action_proposal.dart';

class IveActionConfirmationCard extends StatefulWidget {
  final IveActionProposal proposal;
  final bool executing;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final void Function({
    required String title,
    required String description,
    required int priority,
    required int impact,
    required int effort,
  }) onEdit;

  const IveActionConfirmationCard({
    super.key,
    required this.proposal,
    required this.executing,
    required this.onConfirm,
    required this.onCancel,
    required this.onEdit,
  });

  @override
  State<IveActionConfirmationCard> createState() =>
      _IveActionConfirmationCardState();
}

class _IveActionConfirmationCardState extends State<IveActionConfirmationCard> {
  bool _showRationale = false;

  @override
  Widget build(BuildContext context) {
    final proposal = widget.proposal;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF27233F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF8B7CFF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.verified_user_rounded,
                color: Color(0xFF8B7CFF), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confirme antes de executar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _field('Projeto', proposal.projectName),
          _field('Ação', proposal.title),
          if (proposal.description.isNotEmpty)
            _field('Descrição', proposal.description),
          _field('Prioridade', '${proposal.priority}/100'),
          _field('Impacto', '${proposal.impact}/100'),
          _field('Esforço', '${proposal.effort}/100'),
          _field(
            'Prazo',
            proposal.suggestedDueDate == null
                ? 'Não definido'
                : _formatDate(proposal.suggestedDueDate!),
          ),
          _field('Origem', proposal.origin),
          TextButton.icon(
            onPressed: widget.executing
                ? null
                : () => setState(() => _showRationale = !_showRationale),
            icon: Icon(
              _showRationale
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
            ),
            label: const Text('Ver justificativa'),
          ),
          if (_showRationale)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                proposal.rationale,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: widget.executing ? null : widget.onCancel,
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: widget.executing ? null : () => _edit(context),
                child: const Text('Editar'),
              ),
              FilledButton.icon(
                onPressed: widget.executing ? null : widget.onConfirm,
                icon: widget.executing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 17),
                label: Text(widget.executing ? 'Criando…' : 'Confirmar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12, height: 1.3),
            children: [
              TextSpan(
                text: '$label: ',
                style: const TextStyle(color: Colors.white38),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );

  Future<void> _edit(BuildContext context) async {
    final title = TextEditingController(text: widget.proposal.title);
    final description =
        TextEditingController(text: widget.proposal.description);
    final priority =
        TextEditingController(text: widget.proposal.priority.toString());
    final impact =
        TextEditingController(text: widget.proposal.impact.toString());
    final effort =
        TextEditingController(text: widget.proposal.effort.toString());

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Text('Editar proposta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título')),
              TextField(
                controller: description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: priority,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Prioridade (0–100)'),
              ),
              TextField(
                controller: impact,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Impacto (0–100)'),
              ),
              TextField(
                controller: effort,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Esforço (0–100)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salvar para confirmar'),
          ),
        ],
      ),
    );

    if (save == true && title.text.trim().isNotEmpty) {
      widget.onEdit(
        title: title.text,
        description: description.text,
        priority: _score(priority.text, widget.proposal.priority),
        impact: _score(impact.text, widget.proposal.impact),
        effort: _score(effort.text, widget.proposal.effort),
      );
    }
    title.dispose();
    description.dispose();
    priority.dispose();
    impact.dispose();
    effort.dispose();
  }

  int _score(String value, int fallback) =>
      (int.tryParse(value) ?? fallback).clamp(0, 100);

  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
