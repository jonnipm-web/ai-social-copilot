import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnostics/diagnostic_report_formatter.dart';
import '../../../providers/diagnostic_session_provider.dart';

const _kBg    = Color(0xFF0F0F1A);
const _kCard  = Color(0xFF1A1A2E);
const _kGold  = Color(0xFFFFD700);
const _kRed   = Color(0xFFF44336);
const _kGreen = Color(0xFF4CAF50);

/// IVE-COMMERCIAL-OBSERVABILITY-07A — mission sections 08 ("Admin/Support
/// Log Viewer") + 09 ("Owner Diagnostic Controls") combined into one Admin
/// Panel tab. Both are gated purely by already being inside
/// AdminPanelScreen, which already requires isAdmin (verified in
/// Remediation 06/06R) — this tab adds no new client-side gate of its own
/// (mission section 07: "Do not reuse client-side route guard as security
/// boundary" — the REAL boundary is the RLS policies on diagnostic_
/// sessions/diagnostic_events, which apply regardless of how this screen
/// is reached).
class DiagnosticLogsTab extends StatelessWidget {
  const DiagnosticLogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _DiagnosticControlsCard(),
          SizedBox(height: 16),
          _SessionListSection(),
        ],
      ),
    );
  }
}

// ── Owner controls (mission section 09) ─────────────────────────────────────

class _DiagnosticControlsCard extends ConsumerStatefulWidget {
  const _DiagnosticControlsCard();

  @override
  ConsumerState<_DiagnosticControlsCard> createState() => _DiagnosticControlsCardState();
}

class _DiagnosticControlsCardState extends ConsumerState<_DiagnosticControlsCard> {
  final _labelCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // IVE-COMMERCIAL-OBSERVABILITY-07B (mission section 04) — every time
    // this card mounts (first load, or a fresh mount after a page
    // reload/new tab), ask the server whether the current admin already
    // has an ACTIVE session and adopt it if so, instead of always starting
    // from "Diagnóstico inativo" and risking an orphaned/duplicate session.
    // Scheduled after the first frame so `ref` is safe to use here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(diagnosticSessionProvider.notifier).recover();
    });
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(diagnosticSessionProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: session.isActive ? _kGreen.withOpacity(0.5) : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                session.isActive ? Icons.fiber_manual_record : Icons.circle_outlined,
                color: session.isActive ? _kGreen : Colors.white38,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                session.isActive ? 'DIAGNÓSTICO ATIVO' : 'Diagnóstico inativo',
                style: TextStyle(
                  color: session.isActive ? _kGreen : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (session.isActive) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    'ID: ${session.sessionId}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 16),
                  tooltip: 'Copiar ID da sessão',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: session.sessionId ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ID copiado.')),
                    );
                  },
                ),
              ],
            ),
            if (session.label != null && session.label!.isNotEmpty)
              Text('Rótulo: ${session.label}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _stop,
                icon: const Icon(Icons.stop_circle_rounded, size: 18),
                label: const Text('ENCERRAR SESSÃO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextField(
              controller: _labelCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Rótulo (opcional) — ex: COMMERCIAL-E2E-001',
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Color(0xFF0F0F1A),
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _start,
                icon: const Icon(Icons.fiber_manual_record, size: 16),
                label: const Text('INICIAR SESSÃO DE DIAGNÓSTICO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    final ok = await ref.read(diagnosticSessionProvider.notifier).start(
          label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
        );
    if (mounted) {
      setState(() => _busy = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível iniciar a sessão.')),
        );
      }
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    await ref.read(diagnosticSessionProvider.notifier).stop();
    if (mounted) {
      setState(() => _busy = false);
      ref.invalidate(diagnosticSessionsListProvider);
    }
  }
}

// ── Session list (mission section 08) ────────────────────────────────────

class _SessionListSection extends ConsumerWidget {
  const _SessionListSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(diagnosticSessionsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sessões de Diagnóstico',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 18),
              onPressed: () => ref.invalidate(diagnosticSessionsListProvider),
            ),
          ],
        ),
        sessionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Erro ao carregar sessões: $e',
                style: const TextStyle(color: _kRed, fontSize: 12)),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhuma sessão registrada.',
                    style: TextStyle(color: Colors.white38)),
              );
            }
            return Column(
              children: sessions.map((s) => _SessionTile(session: s)).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});
  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    final startedAt = DateTime.tryParse(session['started_at'] as String? ?? '');
    final endedAt = DateTime.tryParse(session['ended_at'] as String? ?? '');
    final duration = (startedAt != null && endedAt != null) ? endedAt.difference(startedAt) : null;
    final status = session['status'] as String? ?? 'unknown';
    final userId = (session['user_id'] as String? ?? '').substring(0, 8);

    return Card(
      color: _kCard,
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: Icon(
          status == 'active' ? Icons.fiber_manual_record : Icons.check_circle_outline,
          color: status == 'active' ? _kGreen : Colors.white38,
          size: 18,
        ),
        title: Text(
          (session['label'] as String?)?.isNotEmpty == true
              ? session['label'] as String
              : 'Sessão $userId…',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        subtitle: Text(
          '${startedAt?.toLocal() ?? '—'}'
          '${duration != null ? ' · ${duration.inMinutes}min' : ''}'
          ' · ${session['role_snapshot'] ?? '—'} · $status',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _SessionDetailScreen(session: session)),
        ),
      ),
    );
  }
}

// ── Session detail / timeline (mission section 08) ───────────────────────

class _SessionDetailScreen extends ConsumerStatefulWidget {
  const _SessionDetailScreen({required this.session});
  final Map<String, dynamic> session;

  @override
  ConsumerState<_SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<_SessionDetailScreen> {
  String? _severityFilter;
  String? _categoryFilter;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = widget.session['id'] as String;
    final eventsAsync = ref.watch(diagnosticEventsForSessionProvider(sessionId));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text('Sessão ${sessionId.substring(0, 8)}…', style: const TextStyle(fontSize: 14)),
        actions: [
          eventsAsync.maybeWhen(
            data: (events) => IconButton(
              icon: const Icon(Icons.copy_all_rounded),
              tooltip: 'Copiar relatório de diagnóstico',
              onPressed: () => _copyReport(context, events),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por evento, rota ou erro…',
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                    filled: true,
                    fillColor: _kCard,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSeverityDropdown()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCategoryDropdown(eventsAsync.valueOrNull ?? [])),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Erro: $e', style: const TextStyle(color: _kRed)),
              ),
              data: (events) {
                final filtered = _applyFilters(events);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Nenhum evento corresponde aos filtros.',
                        style: TextStyle(color: Colors.white38)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _EventTile(event: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityDropdown() {
    const options = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'CRITICAL'];
    return DropdownButtonFormField<String?>(
      value: _severityFilter,
      dropdownColor: _kCard,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: const InputDecoration(
        labelText: 'Severidade',
        labelStyle: TextStyle(color: Colors.white38, fontSize: 11),
        filled: true,
        fillColor: _kCard,
        border: OutlineInputBorder(borderSide: BorderSide.none),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todas')),
        ...options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
      ],
      onChanged: (v) => setState(() => _severityFilter = v),
    );
  }

  Widget _buildCategoryDropdown(List<Map<String, dynamic>> events) {
    final categories = events.map((e) => e['category'] as String? ?? '').toSet().toList()..sort();
    return DropdownButtonFormField<String?>(
      value: _categoryFilter,
      dropdownColor: _kCard,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: const InputDecoration(
        labelText: 'Categoria',
        labelStyle: TextStyle(color: Colors.white38, fontSize: 11),
        filled: true,
        fillColor: _kCard,
        border: OutlineInputBorder(borderSide: BorderSide.none),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todas')),
        ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
      ],
      onChanged: (v) => setState(() => _categoryFilter = v),
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> events) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return events.where((e) {
      if (_severityFilter != null && e['severity'] != _severityFilter) return false;
      if (_categoryFilter != null && e['category'] != _categoryFilter) return false;
      if (query.isNotEmpty) {
        final haystack = [
          e['event_name'],
          e['route'],
          e['error_message'],
          e['correlation_id'],
        ].where((v) => v != null).join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  void _copyReport(BuildContext context, List<Map<String, dynamic>> events) {
    // Sanitized text/Markdown suitable for Claude analysis (mission section
    // 08) — every field here already passed through the sanitizer/allowlist
    // before it was ever stored, so formatDiagnosticReport is a straight
    // re-serialization, never a second sanitization pass on raw data.
    final report = formatDiagnosticReport(session: widget.session, events: events);
    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Relatório copiado para a área de transferência.')),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final Map<String, dynamic> event;

  Color get _severityColor {
    switch (event['severity']) {
      case 'CRITICAL':
        return _kRed;
      case 'ERROR':
        return _kRed;
      case 'WARN':
        return _kGold;
      default:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: _severityColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(event['severity'] as String? ?? '',
                  style: TextStyle(color: _severityColor, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Text(event['category'] as String? ?? '',
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
              const Spacer(),
              Text(event['occurred_at'] as String? ?? '',
                  style: const TextStyle(color: Colors.white24, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 4),
          Text(event['event_name'] as String? ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          if (event['route'] != null || event['status'] != null || event['build_sha'] != null)
            Text(
              [
                if (event['route'] != null) 'rota: ${event['route']}',
                if (event['status'] != null) 'status: ${event['status']}',
                if (event['duration_ms'] != null) '${event['duration_ms']}ms',
                // IVE-COMMERCIAL-STABILITY-09O-SHA (mission section 08) —
                // the EVENT's own build_sha, not the session's: this is
                // the authoritative value for locating the matching
                // encrypted source-map artifact (sourcemap-<build_sha>)
                // when symbolicating a specific crash.
                if (event['build_sha'] != null) 'build: ${event['build_sha']}',
              ].join(' · '),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          if (event['error_message'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${event['error_type'] ?? 'Erro'}: ${event['error_message']}',
                style: const TextStyle(color: _kRed, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
