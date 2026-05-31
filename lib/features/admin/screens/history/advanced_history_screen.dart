import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/editorial_history_entry.dart';
import '../../../../data/services/editorial_service.dart';
import '../../../../providers/editorial_provider.dart';
import '../../../../shared/widgets/admin_nav_drawer.dart';
import '../../../../shared/widgets/feature_gate.dart';

class AdvancedHistoryScreen extends ConsumerWidget {
  const AdvancedHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(editorialHistoryProvider);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: const Text('Histórico Avançado')),
        drawer: const AdminNavDrawer(),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
            child: historyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text('Erro: $e',
                      style: const TextStyle(color: Colors.white54))),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_edu_outlined,
                            size: 48, color: Colors.white12),
                        SizedBox(height: 16),
                        Text('Nenhuma geração registrada',
                            style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(editorialHistoryProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _HistoryCard(entry: entries[i]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  final EditorialHistoryEntry entry;

  const _HistoryCard({required this.entry});

  Color get _statusColor => switch (entry.status) {
        'generated' => Colors.white38,
        'approved' => Colors.green,
        'needs_edit' => Colors.orange,
        'rejected' => Colors.red,
        'published' => const Color(0xFF6C63FF),
        _ => Colors.white38,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FeaturePill(feature: entry.featureUsed),
                const Spacer(),
                _StatusDropdown(entry: entry),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.inputText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            if (entry.platform.isNotEmpty || entry.objective.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (entry.platform.isNotEmpty) entry.platform,
                  if (entry.objective.isNotEmpty) entry.objective,
                ].join(' · '),
                style:
                    const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatDate(entry.createdAt),
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white24),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: entry.outputText));
                    showSuccessSnack(context, 'Conteúdo copiado!');
                  },
                  icon: const Icon(Icons.copy, size: 13),
                  label: const Text('Copiar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white38,
                    textStyle: const TextStyle(fontSize: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _FeaturePill extends StatelessWidget {
  final String feature;

  const _FeaturePill({required this.feature});

  String get _label => switch (feature) {
        'excerpt_extractor' => 'Extrator',
        'repurposing' => 'Reaproveitamento',
        'editorial_calendar' => 'Calendário',
        _ => feature,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _label,
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.w600),
        ),
      );
}

class _StatusDropdown extends ConsumerWidget {
  final EditorialHistoryEntry entry;

  const _StatusDropdown({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (status) async {
        await ref
            .read(editorialServiceProvider)
            .updateHistoryStatus(entry.id, status);
        ref.invalidate(editorialHistoryProvider);
        if (context.mounted) {
          showSuccessSnack(context, 'Status: ${_label(status)}');
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'generated', child: Text('Gerado')),
        PopupMenuItem(value: 'approved', child: Text('Aprovado')),
        PopupMenuItem(value: 'needs_edit', child: Text('Precisa editar')),
        PopupMenuItem(value: 'rejected', child: Text('Rejeitado')),
        PopupMenuItem(value: 'published', child: Text('Publicado')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _statusColor(entry.status).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(entry.status),
              style: TextStyle(
                  fontSize: 11,
                  color: _statusColor(entry.status),
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 14, color: _statusColor(entry.status)),
          ],
        ),
      ),
    );
  }

  String _label(String s) => switch (s) {
        'generated' => 'Gerado',
        'approved' => 'Aprovado',
        'needs_edit' => 'Precisa editar',
        'rejected' => 'Rejeitado',
        'published' => 'Publicado',
        _ => s,
      };

  Color _statusColor(String s) => switch (s) {
        'approved' => Colors.green,
        'needs_edit' => Colors.orange,
        'rejected' => Colors.red,
        'published' => const Color(0xFF6C63FF),
        _ => Colors.white38,
      };
}
