import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/project_event.dart';
import '../../../providers/project_event_provider.dart';
import '../../../shared/widgets/ive_detail_sheet.dart';

const _kFilters = [
  'Todos',
  'Análises',
  'Conhecimento',
  'Decisões',
  'Oportunidades',
  'Ações',
  'Projeto'
];

class ExecutiveTimelineWidget extends ConsumerStatefulWidget {
  final String projectId;

  const ExecutiveTimelineWidget({super.key, required this.projectId});

  @override
  ConsumerState<ExecutiveTimelineWidget> createState() =>
      _ExecutiveTimelineWidgetState();
}

class _ExecutiveTimelineWidgetState
    extends ConsumerState<ExecutiveTimelineWidget> {
  String _activeFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(projectEventsProvider(widget.projectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filtros
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _kFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final f = _kFilters[i];
              final selected = f == _activeFilter;
              return GestureDetector(
                onTap: () => setState(() => _activeFilter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF00BCD4).withOpacity(0.15)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          selected ? const Color(0xFF00BCD4) : Colors.white24,
                    ),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      color:
                          selected ? const Color(0xFF00BCD4) : Colors.white54,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Lista de eventos
        eventsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF00BCD4), strokeWidth: 2)),
          ),
          error: (e, _) => _errorState(context, e.toString()),
          data: (events) {
            final filtered = _activeFilter == 'Todos'
                ? events
                : events.where((e) => e.filterGroup == _activeFilter).toList();
            if (filtered.isEmpty) return _emptyState();
            return Column(
              children: filtered
                  .map((e) => _EventTile(
                      event: e, onTap: () => _showDetail(context, e)))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Text('📋', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              _activeFilter == 'Todos'
                  ? 'Nenhum evento registrado ainda.'
                  : 'Nenhum evento do tipo "$_activeFilter".',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _errorState(BuildContext context, String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Text('⚠️ Falha ao carregar a timeline.',
                style: TextStyle(color: Colors.orange, fontSize: 13)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.invalidate(projectEventsProvider(widget.projectId)),
              child: const Text('Tentar novamente',
                  style: TextStyle(color: Color(0xFF00BCD4))),
            ),
          ],
        ),
      );

  void _showDetail(BuildContext context, ProjectEvent event) {
    final meta = event.metadata;
    IveDetailSheet.show(
      context,
      title: '${event.emoji} ${event.typeLabel}',
      emoji: event.emoji,
      humanExplanation: event.title,
      evidence: [
        IveEvidence(emoji: '📝', label: 'O que aconteceu', value: event.title),
        if (event.description.isNotEmpty)
          IveEvidence(emoji: '💬', label: 'Detalhes', value: event.description),
        if (event.sourceModule != null)
          IveEvidence(emoji: '📦', label: 'Módulo', value: event.sourceModule!),
        IveEvidence(
            emoji: '🕐', label: 'Quando', value: _formatDate(event.createdAt)),
        ...meta.entries.take(4).map(
              (e) => IveEvidence(
                  emoji: '📊', label: e.key, value: e.value.toString()),
            ),
      ],
      expandedData: {
        'Tipo': event.typeLabel,
        'Quando': _formatDate(event.createdAt),
        if (event.sourceModule != null) 'Módulo': event.sourceModule!,
      },
      screenName: 'executive_timeline',
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Agora mesmo';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    if (diff.inDays < 7)
      return 'Há ${diff.inDays} dia${diff.inDays > 1 ? 's' : ''}';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _EventTile extends StatelessWidget {
  final ProjectEvent event;
  final VoidCallback onTap;

  const _EventTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coluna de linha do tempo
              Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E3A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Center(
                      child: Text(event.emoji,
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                  Container(width: 1, height: 20, color: Colors.white10),
                ],
              ),
              const SizedBox(width: 10),
              // Conteúdo do evento
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _shortDate(event.createdAt),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                    if (event.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        event.description,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    _FilterChip(label: event.filterGroup),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  const _FilterChip({required this.label});

  static const _colors = {
    'Análises': Color(0xFF6C63FF),
    'Conhecimento': Color(0xFF00BCD4),
    'Decisões': Color(0xFF6BCB77),
    'Oportunidades': Color(0xFFFFD93D),
    'Ações': Color(0xFFFF9F43),
    'Projeto': Color(0xFFFF6B6B),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[label] ?? Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}
