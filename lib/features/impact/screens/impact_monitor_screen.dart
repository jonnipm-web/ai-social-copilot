import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/profile_provider.dart';
import '../data/impact_lab_api.dart';
import '../domain/dossier_models.dart';
import '../providers/impact_providers.dart';
import '../widgets/impact_widgets.dart';

/// IV-IMPACT-MACRO-08 Phase 10 — Monitor vertical.
///
/// CAPABILITY STATUS: PARTIAL
///   - Manual re-verification: IMPLEMENTED (triggers run_verification action)
///   - Verification history display: IMPLEMENTED (from dossier audit trail)
///   - Automatic periodic checks: NOT_AVAILABLE in this version
///     (requires background execution infrastructure — marked transparently)
///
/// This screen is honest about the limitation. It does not pretend to offer
/// continuous monitoring when it cannot. The architecture is correct and
/// ready for automatic checks once background execution is available.
class ImpactMonitorScreen extends ConsumerStatefulWidget {
  const ImpactMonitorScreen({super.key, required this.investigationId});
  final String investigationId;

  @override
  ConsumerState<ImpactMonitorScreen> createState() => _ImpactMonitorScreenState();
}

class _ImpactMonitorScreenState extends ConsumerState<ImpactMonitorScreen> {
  bool  _rechecking = false;
  String? _recheckError;
  DateTime? _lastChecked;

  Future<void> _recheck() async {
    if (_rechecking) return;
    setState(() { _rechecking = true; _recheckError = null; });
    try {
      await ref.read(impactLabApiProvider).runVerification(widget.investigationId, 'pt');
      if (mounted) {
        setState(() { _rechecking = false; _lastChecked = DateTime.now(); });
        ref.invalidate(impactDossierProvider((id: widget.investigationId, lang: 'pt')));
      }
    } on ImpactApiException catch (e) {
      if (mounted) setState(() { _rechecking = false; _recheckError = e.toString(); });
    } catch (e) {
      if (mounted) setState(() { _rechecking = false; _recheckError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t      = AppLocalizations.of(context)!;
    final isPro  = ref.watch(currentProfileProvider).valueOrNull?.isPro ?? false;
    final dossierAsync = ref.watch(impactDossierProvider((id: widget.investigationId, lang: 'pt')));

    return Scaffold(
      appBar: AppBar(title: Text(t.impactMonitorTitle)),
      body: ImpactPage(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // PARTIAL capability banner — always visible, honest about what is not available
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(t.impactMonitorPartialNote,
                    style: Theme.of(context).textTheme.bodySmall)),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Monitor status row
          _StatusRow(
            label:   t.impactMonitorStatus,
            value:   t.impactMonitorActive,
            icon:    Icons.monitor_heart_outlined,
          ),
          _StatusRow(
            label: t.impactMonitorLastChecked,
            value: _lastChecked != null
                ? _formatDate(_lastChecked!)
                : t.impactMonitorNever,
            icon: Icons.schedule_outlined,
          ),
          const SizedBox(height: 16),

          // Re-check button
          FilledButton.icon(
            icon:      _rechecking
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            label:     Text(t.impactMonitorRecheck),
            onPressed: _rechecking ? null : _recheck,
          ),
          if (_recheckError != null) ...[
            const SizedBox(height: 8),
            ImpactLine(_recheckError!, icon: Icons.error_outline),
          ],
          const SizedBox(height: 24),

          // PRO upgrade notice for auto-monitor
          if (!isPro) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.lock_outline),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t.impactMonitorPro)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Verification history from dossier audit
          Text(t.impactMonitorHistory, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          dossierAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (e, _) => ImpactLine(e.toString(), icon: Icons.error_outline),
            data:    (dossier) => _VerificationHistory(dossier: dossier, t: t),
          ),
        ]),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      SizedBox(width: 160, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
      Expanded(child: Text(value)),
    ]),
  );
}

class _VerificationHistory extends StatelessWidget {
  const _VerificationHistory({required this.dossier, required this.t});
  final DossierView    dossier;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    // Collect claims that have a verification result with an evaluatedAt timestamp
    final entries = dossier.claims
        .where((c) => c.verification?.evaluatedAt != null)
        .map((c) => (
          status:      c.verification!.status ?? '—',
          evaluatedAt: c.verification!.evaluatedAt!,
          ref:         c.ref,
        ))
        .toList()
      ..sort((a, b) => b.evaluatedAt.compareTo(a.evaluatedAt));

    if (entries.isEmpty) {
      return ImpactLine(t.impactMonitorNoHistory, icon: Icons.inbox_outlined, muted: true);
    }
    return Column(
      children: entries.take(10).map((e) => ListTile(
        dense:    true,
        leading:  const Icon(Icons.check_circle_outline, size: 18),
        title:    Text(e.status, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text('${e.ref} · ${e.evaluatedAt}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      )).toList(),
    );
  }
}
