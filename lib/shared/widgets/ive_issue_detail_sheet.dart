import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/ive_issue.dart';

class IveIssueDetailSheet extends StatefulWidget {
  const IveIssueDetailSheet({super.key, required this.issue});
  final IveIssue issue;

  @override
  State<IveIssueDetailSheet> createState() => _IveIssueDetailSheetState();
}

class _IveIssueDetailSheetState extends State<IveIssueDetailSheet> {
  bool _showTechnical = false;

  IveIssue get issue => widget.issue;

  static const _bg     = Color(0xFF0E0B1E);
  static const _card   = Color(0xFF1A1535);
  static const _purple = Color(0xFF7B5CF6);
  static const _red    = Color(0xFFFF3D5A);
  static const _amber  = Color(0xFFFFB020);
  static const _green  = Color(0xFF00E875);
  static const _text   = Color(0xFFE8E4FF);
  static const _sub    = Color(0xFF8B85AD);

  Color get _accentColor => switch (issue.severity) {
    IveIssueSeverity.critical => _red,
    IveIssueSeverity.error    => _red,
    IveIssueSeverity.warning  => _amber,
    IveIssueSeverity.info     => _purple,
  };

  String get _severityLabel => switch (issue.severity) {
    IveIssueSeverity.critical => 'Crítico',
    IveIssueSeverity.error    => 'Erro',
    IveIssueSeverity.warning  => 'Aviso',
    IveIssueSeverity.info     => 'Info',
  };

  String get _stageLabel => switch (issue.stage) {
    IveIssueStage.download   => 'Download de arquivo',
    IveIssueStage.processing => 'Processamento',
    IveIssueStage.analysis   => 'Análise por IA',
    IveIssueStage.sync       => 'Sincronização',
    IveIssueStage.network    => 'Conexão de rede',
    IveIssueStage.auth       => 'Autenticação',
    IveIssueStage.unknown    => 'Desconhecido',
  };

  String get _dataPreservationNote => switch (issue.stage) {
    IveIssueStage.download   => 'Nenhum dado foi corrompido. O arquivo original permanece íntegro.',
    IveIssueStage.processing => 'Os dados originais não foram alterados. A falha ocorreu só no processamento.',
    IveIssueStage.analysis   => 'Seus dados estão seguros. Apenas o resultado da análise não foi gerado.',
    IveIssueStage.sync       => 'Os dados locais estão preservados. A sincronização pode ser refeita.',
    IveIssueStage.network    => 'Nenhuma alteração foi confirmada no servidor. Estado consistente.',
    IveIssueStage.auth       => 'Sua sessão expirou. Seus dados não foram afetados.',
    IveIssueStage.unknown    => 'Estado dos dados: sem alterações confirmadas.',
  };

  String _formatTimestamp(DateTime dt) {
    final h  = dt.hour.toString().padLeft(2, '0');
    final m  = dt.minute.toString().padLeft(2, '0');
    final d  = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year} às $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize:     0.4,
      maxChildSize:     0.92,
      expand:           false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color:        _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _handle(),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _header(),
                  const SizedBox(height: 20),
                  _section('O que aconteceu', issue.userMessage, icon: Icons.info_outline_rounded),
                  const SizedBox(height: 12),
                  _metaRow(),
                  const SizedBox(height: 12),
                  _section('O que foi preservado', _dataPreservationNote,
                      icon: Icons.shield_outlined, accentOverride: _green),
                  const SizedBox(height: 20),
                  _actionsSection(),
                  const SizedBox(height: 16),
                  _technicalSection(),
                  const SizedBox(height: 16),
                  _timestampRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40, height: 4,
      decoration: BoxDecoration(
        color: _sub.withOpacity(0.5),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _header() => Row(
    children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color:  _accentColor.withOpacity(0.15),
          shape:  BoxShape.circle,
          border: Border.all(color: _accentColor.withOpacity(0.5)),
        ),
        child: Icon(
          issue.severity == IveIssueSeverity.warning
              ? Icons.warning_amber_rounded
              : Icons.error_outline_rounded,
          color: _accentColor, size: 20,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.entityName != null
                  ? 'Falha: ${issue.entityName}'
                  : 'Diagnóstico IVE',
              style: const TextStyle(
                color: _text, fontSize: 16, fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              issue.errorCode,
              style: TextStyle(color: _sub, fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _metaRow() => Row(
    children: [
      _chip(_stageLabel, Icons.layers_outlined, _purple),
      const SizedBox(width: 8),
      _chip(_severityLabel, Icons.flag_outlined, _accentColor),
      const SizedBox(width: 8),
      if (issue.recoverable)
        _chip('Recuperável', Icons.refresh_rounded, _green),
    ],
  );

  Widget _chip(String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:        color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border:       Border.all(color: color.withOpacity(0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _section(String title, String body, {required IconData icon, Color? accentOverride}) {
    final accent = accentOverride ?? _accentColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        _card,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: accent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: _text, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _actionsSection() {
    if (issue.recommendedActions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Como resolver',
          style: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...issue.recommendedActions.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ActionTile(action: a, accentColor: _accentColor),
        )),
      ],
    );
  }

  Widget _technicalSection() => GestureDetector(
    onTap: () => setState(() => _showTechnical = !_showTechnical),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        _card,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: _sub.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.terminal_rounded, size: 14, color: _sub),
            const SizedBox(width: 6),
            const Text('Detalhes técnicos',
                style: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(_showTechnical ? Icons.expand_less : Icons.expand_more,
                size: 16, color: _sub),
          ]),
          if (_showTechnical) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:        Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                issue.technicalMessage,
                style: const TextStyle(
                  color: Color(0xFF9B8FFF), fontSize: 11,
                  fontFamily: 'monospace', height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: issue.technicalMessage)),
              child: const Text(
                'Copiar para área de transferência',
                style: TextStyle(color: _purple, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _timestampRow() => Row(
    children: [
      const Icon(Icons.access_time_rounded, size: 12, color: _sub),
      const SizedBox(width: 4),
      Text(
        'Ocorreu em ${_formatTimestamp(issue.occurredAt)}',
        style: const TextStyle(color: _sub, fontSize: 11),
      ),
    ],
  );
}

// ── Tile para cada ação de recuperação ────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.accentColor});
  final IveIssueAction action;
  final Color          accentColor;

  IconData get _icon => switch (action.actionKey) {
    'retry'        => Icons.refresh_rounded,
    'update_link'  => Icons.edit_outlined,
    'send_file'    => Icons.upload_file_outlined,
    'view_details' => Icons.search_rounded,
    'dismiss'      => Icons.close_rounded,
    _              => Icons.arrow_forward_rounded,
  };

  String get _hint => switch (action.actionKey) {
    'retry'        => 'Reinicia o processo automaticamente',
    'update_link'  => 'Abre o formulário de edição do item',
    'send_file'    => 'Navega para o Cofre de Conhecimento',
    'view_details' => 'Mostra este diagnóstico',
    'dismiss'      => 'Fecha o aviso da IVE',
    _              => '',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 16, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.label,
                    style: TextStyle(
                        color: accentColor, fontSize: 13, fontWeight: FontWeight.w600)),
                if (_hint.isNotEmpty)
                  Text(_hint, style: const TextStyle(color: Color(0xFF8B85AD), fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: accentColor.withOpacity(0.5)),
        ],
      ),
    );
  }
}
