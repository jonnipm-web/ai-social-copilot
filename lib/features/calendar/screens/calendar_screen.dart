import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/calendar_item.dart';
import '../../../providers/calendar_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(calendarItemsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.routeHome);
            }
          },
        ),
        title: const Text('Calendário Editorial'),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Post'),
        backgroundColor: const Color(0xFF6C63FF),
      ),
      body: Column(
        children: [
          // Filtros de status
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _StatusChip(
                  label: 'Todos',
                  selected: _filterStatus == null,
                  color: Colors.white54,
                  onTap: () => setState(() => _filterStatus = null),
                ),
                ...CalendarItem.statuses.map((s) => _StatusChip(
                      label: CalendarItem.statusLabels[s] ?? s,
                      selected: _filterStatus == s,
                      color: _statusColor(s),
                      onTap: () => setState(() => _filterStatus = s),
                    )),
              ],
            ),
          ),
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(
                child: Text('Erro: $e',
                    style: const TextStyle(color: Colors.white54)),
              ),
              data: (items) {
                final filtered = _filterStatus == null
                    ? items
                    : items
                        .where((i) => i.status == _filterStatus)
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            size: 64, color: Colors.white24),
                        SizedBox(height: 12),
                        Text('Nenhum post agendado.',
                            style: TextStyle(color: Colors.white54)),
                        SizedBox(height: 4),
                        Text('Crie seu primeiro post usando o botão abaixo.',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      _CalendarCard(item: filtered[i], ref: ref),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateCalendarItemSheet(),
    );

    if (result != null && mounted) {
      final item = CalendarItem(
        id:           '',
        userId:       '',
        theme:        result['theme'] as String,
        platform:     result['platform'] as String?,
        format:       result['format'] as String?,
        objective:    result['objective'] as String?,
        status:       'ideia',
        suggestedDate: result['suggestedDate'] as DateTime?,
        createdAt:    DateTime.now(),
        updatedAt:    DateTime.now(),
      );
      await ref.read(calendarNotifierProvider.notifier).create(item);
      ref.invalidate(calendarItemsProvider);
    }
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.item, required this.ref});
  final CalendarItem item;
  final WidgetRef    ref;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.status);
    final statusLabel = CalendarItem.statusLabels[item.status] ?? item.status;

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (item.platform != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.platform!,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 10),
                    ),
                  ),
                ],
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: Colors.white38, size: 18),
                  color: const Color(0xFF1A1A2E),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await ref
                          .read(calendarNotifierProvider.notifier)
                          .delete(item.id);
                      ref.invalidate(calendarItemsProvider);
                    } else {
                      await ref
                          .read(calendarNotifierProvider.notifier)
                          .updateStatus(item.id, value);
                      ref.invalidate(calendarItemsProvider);
                    }
                  },
                  itemBuilder: (_) => [
                    ...CalendarItem.statuses
                        .where((s) => s != item.status)
                        .map((s) => PopupMenuItem(
                              value: s,
                              child: Text(
                                '→ ${CalendarItem.statusLabels[s] ?? s}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            )),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.theme ?? '(sem tema)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (item.objective != null && item.objective!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.objective!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (item.format != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.article_rounded,
                      color: Colors.white24, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    CalendarItem.formatLabels[item.format] ?? item.format!,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
            if (item.suggestedDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: Colors.white38, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(item.suggestedDate!),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'publicado': return Colors.green;
    case 'aprovado':  return Colors.teal;
    case 'gerado':    return const Color(0xFF6C63FF);
    case 'planejado': return const Color(0xFFB44FE8);
    case 'arquivado': return Colors.white24;
    default:          return Colors.orange;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String  label;
  final bool    selected;
  final Color   color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Chip(
          label: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 12,
            ),
          ),
          backgroundColor: selected
              ? color.withOpacity(0.8)
              : Colors.white.withOpacity(0.07),
          side: BorderSide(color: selected ? color : Colors.white12),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _CreateCalendarItemSheet extends StatefulWidget {
  const _CreateCalendarItemSheet();

  @override
  State<_CreateCalendarItemSheet> createState() =>
      _CreateCalendarItemSheetState();
}

class _CreateCalendarItemSheetState
    extends State<_CreateCalendarItemSheet> {
  final _themeCtrl    = TextEditingController();
  final _objectiveCtrl = TextEditingController();
  String?   _platform;
  String?   _format;
  DateTime? _suggestedDate;

  @override
  void dispose() {
    _themeCtrl.dispose();
    _objectiveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Novo Post no Calendário',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _SheetField(
            controller: _themeCtrl,
            label: 'Tema / Assunto do post *',
            hint: 'Ex: Dica de segunda sobre produtividade',
          ),
          const SizedBox(height: 12),
          _SheetField(
            controller: _objectiveCtrl,
            label: 'Objetivo (opcional)',
            hint: 'Ex: Gerar engajamento, Vender produto X',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _platform,
            decoration: _dropDecoration('Plataforma'),
            dropdownColor: const Color(0xFF1A1A2E),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: CalendarItem.platforms
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) => setState(() => _platform = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _format,
            decoration: _dropDecoration('Formato'),
            dropdownColor: const Color(0xFF1A1A2E),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: CalendarItem.formats
                .map((f) => DropdownMenuItem(
                      value: f,
                      child: Text(CalendarItem.formatLabels[f] ?? f),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _format = v),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null && mounted) {
                setState(() => _suggestedDate = picked);
              }
            },
            icon: const Icon(Icons.schedule_rounded,
                color: Colors.white54, size: 16),
            label: Text(
              _suggestedDate == null
                  ? 'Definir data sugerida'
                  : 'Data: ${_suggestedDate!.day}/${_suggestedDate!.month}/${_suggestedDate!.year}',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white12),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_themeCtrl.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'theme':         _themeCtrl.text.trim(),
                'objective':     _objectiveCtrl.text.trim().isEmpty
                    ? null
                    : _objectiveCtrl.text.trim(),
                'platform':      _platform,
                'format':        _format,
                'suggestedDate': _suggestedDate,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Adicionar ao Calendário',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropDecoration(String label) {
    return InputDecoration(
      labelText:  label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
      filled:     true,
      fillColor:  Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white12),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines:   maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText:  hint,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        hintStyle:  const TextStyle(color: Colors.white24, fontSize: 12),
        filled:     true,
        fillColor:  Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6C63FF)),
        ),
      ),
    );
  }
}
