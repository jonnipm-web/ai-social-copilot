import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/profile_provider.dart';
import '../data/impact_lab_api.dart';
import '../domain/dossier_models.dart';
import '../providers/impact_providers.dart';
import '../widgets/impact_widgets.dart';

/// IV-IMPACT-MACRO-08 Phase 7 — Discover vertical.
///
/// Allows users to search for an organisation/entity and:
///   FREE: see basic entity resolution result + identity context
///   PRO : create a full investigation and navigate to its dossier
class ImpactDiscoverScreen extends ConsumerStatefulWidget {
  const ImpactDiscoverScreen({super.key});

  @override
  ConsumerState<ImpactDiscoverScreen> createState() => _ImpactDiscoverScreenState();
}

class _ImpactDiscoverScreenState extends ConsumerState<ImpactDiscoverScreen> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();

  bool   _loading  = false;
  String? _error;

  /// Non-null after a successful search. null while idle or loading.
  _DiscoverResult? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _ctrl.text.trim();
    if (query.isEmpty) return;
    _focus.unfocus();

    setState(() { _loading = true; _error = null; _result = null; });

    try {
      final api = ref.read(impactLabApiProvider);
      // create_investigation is the entry point — even for "discover" the server
      // performs entity resolution as the first step and returns an initial dossier.
      // Fix 4: send correct subject object (ref = slug, type = NONPROFIT default,
      // identity.legalName = original query). Server returns investigationId not id.
      final ref_ = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
      final inv = await api.createInvestigation(
        subjectRef: ref_.isEmpty ? 'query-${DateTime.now().millisecondsSinceEpoch}' : ref_,
        subjectType: 'NONPROFIT',
        legalName: query,
      );
      if (mounted) {
        setState(() { _loading = false; _result = _DiscoverResult.fromSummary(inv, query); });
      }
    } on ImpactApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t      = AppLocalizations.of(context)!;
    final isPro  = ref.watch(currentProfileProvider).valueOrNull?.isPro ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(t.impactDiscoverTitle)),
      body: ImpactPage(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImpactLine(t.impactDiscoverSubtitle, icon: Icons.travel_explore_rounded, muted: true),
            const SizedBox(height: 16),
            _SearchBar(ctrl: _ctrl, focus: _focus, onSearch: _search, loading: _loading),
            const SizedBox(height: 24),
            if (_loading)          _Pending(t.impactDiscoverPending)
            else if (_error != null) _ErrorBanner(message: _error!, onRetry: _search)
            else if (_result == null) ImpactLine(t.impactDiscoverEmpty, icon: Icons.inbox_outlined, muted: true)
            else                    _ResultCard(result: _result!, isPro: isPro, t: t),
          ],
        ),
      ),
    );
  }
}

// ── Supporting sub-widgets ───────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.ctrl, required this.focus, required this.onSearch, required this.loading});
  final TextEditingController ctrl;
  final FocusNode             focus;
  final VoidCallback          onSearch;
  final bool                  loading;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Row(children: [
      Expanded(
        child: TextField(
          controller: ctrl,
          focusNode:  focus,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
          decoration: InputDecoration(
            hintText:    t.impactDiscoverHint,
            prefixIcon:  const Icon(Icons.search),
            border:      const OutlineInputBorder(),
          ),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton(
        onPressed: loading ? null : onSearch,
        child: Text(t.impactDiscoverSearch),
      ),
    ]);
  }
}

class _Pending extends StatelessWidget {
  const _Pending(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 12),
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
    ]),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String   message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) =>
      ImpactErrorView(error: message, onRetry: onRetry);
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.isPro, required this.t});
  final _DiscoverResult    result;
  final bool               isPro;
  final AppLocalizations   t;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.impactDiscoverResultTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _Row(label: t.impactDiscoverEntityLabel, value: result.orgRef),
          if (result.identityStatus != null)
            _Row(label: t.impactDiscoverConfidence, value: result.identityStatus!),
          const SizedBox(height: 8),
          ImpactLine(t.impactDiscoverAbsenceNote, icon: Icons.info_outline, muted: true),
          const Divider(height: 24),
          if (!isPro) ...[
            ImpactLine(t.impactDiscoverProGate, icon: Icons.lock_outline),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.push(AppConstants.routeUpgrade),
              child: Text(t.impactEntitlementUpgradeCta),
            ),
          ] else ...[
            FilledButton.icon(
              icon:  const Icon(Icons.folder_open_outlined),
              label: Text(t.impactDiscoverStartInvestigation),
              onPressed: () => context.push('/impact/${Uri.encodeComponent(result.investigationId)}'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 160, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
      Expanded(child: Text(value)),
    ]),
  );
}

// ── Result model ─────────────────────────────────────────────────────────────

class _DiscoverResult {
  const _DiscoverResult({required this.investigationId, required this.orgRef, this.identityStatus});
  final String  investigationId;
  final String  orgRef;
  final String? identityStatus;

  factory _DiscoverResult.fromSummary(InvestigationSummary s, String query) =>
      _DiscoverResult(
        investigationId: s.id,
        orgRef:          s.subjectOrgRef.isNotEmpty ? s.subjectOrgRef : query,
        identityStatus:  s.status,
      );
}
