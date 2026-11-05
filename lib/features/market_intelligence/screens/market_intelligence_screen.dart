import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/language_utils.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/market_analysis.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/ai_execution_confirmation.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/canonical_back_button.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

// IVE-COMMERCIAL-EXPERIENCE-14 (Phase B, Section 07) — "Idea Analysis"
// entry point. No dedicated IdeaAnalysis engine exists anywhere in this
// codebase (confirmed by source search before writing this) — the closest,
// and only, existing capability is this screen's own 'project' input mode
// ("Descreva seu projeto ou ideia"), backed by a market-analysis service
// that already accepts an optional projectId (market_analysis_service.
// dart's analyze()) but that this screen never threaded through. Rather
// than build a second engine, this screen now accepts an optional
// [projectId] (and [initialInput], the project's own description) via
// route `extra` from Project Command Center, defaults the input mode to
// 'project', pre-fills the text field, and forwards projectId into the
// existing service call — the analysis this produces is then correctly
// attributable to that project (market_analyses.project_id), and (see
// _analyze below) the project's own market_analysis_id is updated to
// point at it, exactly like a project created directly from this flow
// already does.
class MarketIntelligenceScreen extends ConsumerStatefulWidget {
  const MarketIntelligenceScreen({super.key});

  @override
  ConsumerState<MarketIntelligenceScreen> createState() =>
      _MarketIntelligenceScreenState();
}

class _MarketIntelligenceScreenState
    extends ConsumerState<MarketIntelligenceScreen> {
  final _inputCtrl = TextEditingController();
  String _inputType = 'url';

  /// Set from GoRouter `extra` (same convention as
  /// knowledge_item_form_screen.dart's own projectId-via-extra handling)
  /// — never inferred, only ever the explicit id Project Command Center
  /// passed when it opened this screen for one specific project.
  String? _projectId;

  /// Codex Gate P2 mitigation: tracks the specific `extra` instance already
  /// processed (identity, not just "have we ever processed any extra"), so
  /// that if go_router ever reuses this State for a route re-entry carrying
  /// a DIFFERENT extra (e.g. a second push before the first was disposed),
  /// the new extra is picked up instead of silently keeping a stale
  /// `_projectId` from the previous entry.
  Object? _lastProcessedExtra;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (identical(extra, _lastProcessedExtra)) return;
    _lastProcessedExtra = extra;
    final projectId = extra is Map &&
            extra['projectId'] is String &&
            (extra['projectId'] as String).isNotEmpty
        ? extra['projectId'] as String
        : null;
    setState(() {
      // Always reset, never leave a previous entry's binding in place —
      // a reused State with no projectId in its new extra must NOT keep
      // pointing at the old project (Codex Gate P2 follow-up: also reset
      // _inputType/_inputCtrl so a reused State doesn't keep showing
      // stale "project mode" UI/text from the previous entry).
      _projectId = projectId;
      if (projectId != null) {
        _inputType = 'project';
        final prefill = (extra as Map)['initialInput'];
        _inputCtrl.text = prefill is String ? prefill : '';
      } else {
        _inputType = 'url';
        _inputCtrl.clear();
      }
    });
  }

  // IVE-COMMERCIAL-QUOTA-HARDENING-13 — this screen fired market-analysis
  // (a quota-consuming Edge Function) directly from the notifier with no
  // confirmation and no idempotency key. Codex Gate 2 finding: only
  // gap_analysis_screen.dart's representative call site was migrated by
  // Foundation-11; every other market-intelligence sub-flow (this one
  // included) was still silent. Same pattern as gap_analysis_screen.dart.
  final _exec = AiExecutionController();

  @override
  void dispose() {
    _inputCtrl.dispose();
    _exec.dispose();
    super.dispose();
  }

  // IVE-COMMERCIAL-EXPERIENCE-14 — Codex Gate P0: `_projectId` originates
  // from a GoRouter `extra`, which is client-supplied and MUST NOT be
  // trusted as authority to bind a new market_analyses/opportunity_lab row
  // to an arbitrary project (mission threat model: "Client projectId is
  // context, never authority"). market_analysis_service.dart's INSERT path
  // (pre-existing, unmodified this mission) accepts project_id without
  // server-side ownership validation — Supabase RLS on market_analyses only
  // checks the row's own user_id, not that project_id belongs to that same
  // user (baseline migration, projects table only). A real server-side fix
  // needs a new RLS policy / RPC — a migration, which this implementation-
  // only mission cannot make (see final report, architectural escalation).
  // This client-side check is defense-in-depth for the NEW path this
  // mission adds: only accept `_projectId` if it appears in the current
  // user's own (RLS-scoped) project list; otherwise treat the analysis as
  // project-less rather than silently trusting the caller-supplied id.
  String? get _verifiedProjectId {
    final id = _projectId;
    if (id == null) return null;
    final owned = ref.read(projectsNotifierProvider).valueOrNull;
    if (owned == null) return null; // not loaded — fail closed, not open
    return owned.any((p) => p.id == id) ? id : null;
  }

  Future<void> _analyze() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final verifiedProjectId = _verifiedProjectId;
    final notifier = ref.read(marketAnalysisNotifierProvider.notifier);
    final result = await _exec.run<MarketAnalysis?>(
      context: context,
      ref: ref,
      analysisLabel: l10n.miRootAnalyzeCta,
      request: IveInteractionRequest(
        sourceModule: 'market_intelligence',
        sourceEntityType: 'market_analysis',
        operationType: IveOperationType.analyze,
      ),
      action: (idempotencyKey) => notifier.analyze(
        input,
        inputType: _inputType,
        projectId: verifiedProjectId,
        language: backendLanguageCode(context),
        idempotencyKey: idempotencyKey,
      ),
    );
    if (result != null && mounted) {
      if (verifiedProjectId != null) {
        // Link this project to its newest analysis — mirrors what already
        // happens when a project is first CREATED via this same 'project'
        // input mode (see market_analysis_provider.dart's own project-
        // creation path); without this, "Ver Análise de Mercado" on Project
        // Command Center would keep pointing at a stale/absent analysis
        // after a project-scoped re-analysis. Reuses the existing, already-
        // safe updateFields() — no new update semantics introduced.
        // Reuses the SAME verifiedProjectId gate as the analyze() call above
        // — this update is itself RLS-protected by the projects table's own
        // "auth.uid() = user_id" policy, but only ever reached with an id
        // the user already legitimately owns.
        await ref.read(projectsNotifierProvider.notifier).updateFields(
          verifiedProjectId,
          {'market_analysis_id': result.id},
        );
        if (!mounted) return;
      }
      // Navigation must not depend on whether a project was linked: a
      // URL/Domínio or Nicho analysis (no project) completes and persists
      // successfully either way (confirmed live: status 'completed' with a
      // real opportunity_score in market_analyses) but was previously never
      // shown to the user when verifiedProjectId was null -- the result
      // existed only in the database, invisible in the UI.
      context.go(
        AppConstants.routeMarketIntelligenceHub.replaceFirst(':id', result.id),
      );
    }
  }

  static String _friendlyError(AppLocalizations t, String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('404') ||
        lower.contains('not_found') ||
        lower.contains('not found')) {
      return t.miRootErrorNotFound;
    }
    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('jwt')) {
      return t.miRootErrorSession;
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return t.miRootErrorTimeout;
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection')) {
      return t.miRootErrorNetwork;
    }
    if (lower.contains('groq') ||
        lower.contains('api key') ||
        lower.contains('apikey')) {
      return t.miRootErrorApiKey;
    }
    return t.miRootErrorGeneric;
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder over `_exec` so the button also reacts to the
    // confirmation-dialog phase (AiExecutionState.awaitingConfirmation),
    // not just the notifier's own AsyncLoading (which only starts once
    // the user has already confirmed) — same reasoning as
    // gap_analysis_screen.dart.
    return AnimatedBuilder(
      animation: _exec,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final state = ref.watch(marketAnalysisNotifierProvider);
    final analyses = ref.watch(marketAnalysesProvider);
    final busy = state is AsyncLoading || _exec.isBusy;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // IVE-COMMERCIAL-EXPERIENCE-14 (Phase B, Section 13) — replaces
        // this screen's own hand-rolled canPop()/go() with the shared
        // CanonicalBackButton (Architecture-10), same fallback target
        // (routeHome) this inline version already used.
        leading:
            const CanonicalBackButton(fallbackRoute: AppConstants.routeHome),
        backgroundColor: Colors.transparent,
        title: Text(t.navMarketIntelligence,
            style: const TextStyle(color: AppColors.ink)),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.surface, AppColors.surface],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: AppColors.info.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_rounded,
                            color: AppColors.info, size: 28),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            t.miRootEngineTitle,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.miRootEngineSubtitle,
                      style:
                          const TextStyle(color: AppColors.inkMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // COMMERCIAL-V1-UX-RECONCILIATION (R14) — before this, the
              // ONLY way to bind an analysis to a project was arriving via
              // Project Command Center's `extra` (didChangeDependencies
              // above); a user starting directly from this screen had no
              // way to link the analysis to a real project at all, so
              // every analysis they created stayed project-less even when
              // they meant it for a specific project. This dropdown is a
              // second, user-driven way to set the SAME `_projectId` state
              // field — it goes through the exact same `_verifiedProjectId`
              // ownership check and the same analyze()/updateFields() path
              // below, no new authorization surface. Hidden once a project
              // was already supplied via `extra` (that binding takes
              // precedence and is shown by the banner below instead).
              if (_projectId == null) ...[
                const SizedBox(height: 16),
                Text(t.miRootProjectSelectorLabel,
                    style:
                        const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final projectsAsync = ref.watch(projectsNotifierProvider);
                    final projects = projectsAsync.valueOrNull ?? const [];
                    return DropdownButtonFormField<String?>(
                      initialValue: null,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.ink),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide:
                              const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          borderSide:
                              const BorderSide(color: AppColors.line),
                        ),
                        prefixIcon: const Icon(Icons.folder_outlined,
                            color: AppColors.inkSubtle),
                      ),
                      hint: Text(t.miRootProjectSelectorNone,
                          style: const TextStyle(color: AppColors.inkSubtle)),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(t.miRootProjectSelectorNone,
                              style: const TextStyle(color: AppColors.inkMuted)),
                        ),
                        ...projects.map((p) => DropdownMenuItem<String?>(
                              value: p.id,
                              child:
                                  Text(p.name, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (value) => setState(() {
                        _projectId = value;
                        if (value != null) _inputType = 'project';
                      }),
                    );
                  },
                ),
              ],
              // Same ownership check as _verifiedProjectId (Codex Gate P0
              // mitigation) — keeps the banner honest: never claims a link
              // will be made if the write path would actually reject it.
              if (_projectId != null &&
                  (ref
                          .watch(projectsNotifierProvider)
                          .valueOrNull
                          ?.any((p) => p.id == _projectId) ??
                      false)) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin_rounded,
                          size: 13, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          t.ideaAnalysisProjectBannerText,
                          style: const TextStyle(
                              color: AppColors.accent, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Input type selector
              Text(t.miRootInputTypeLabel,
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
              const SizedBox(height: 8),
              // Wrap, not Row: the "Projeto" chip goes bold when selected,
              // which widens it enough to overflow a Row at narrow (~390px)
              // widths -- Wrap lets chips flow to a second line instead of
              // clipping or shrinking the label text.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TypeChip(
                      label: t.miRootInputTypeUrl,
                      value: 'url',
                      selected: _inputType,
                      onTap: (v) => setState(() => _inputType = v)),
                  _TypeChip(
                      label: t.miRootInputTypeNiche,
                      value: 'niche',
                      selected: _inputType,
                      onTap: (v) => setState(() => _inputType = v)),
                  _TypeChip(
                      label: t.miRootInputTypeProject,
                      value: 'project',
                      selected: _inputType,
                      onTap: (v) => setState(() => _inputType = v)),
                ],
              ),
              const SizedBox(height: 16),

              // Input field
              TextField(
                controller: _inputCtrl,
                style: const TextStyle(color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: _inputType == 'url'
                      ? t.miRootHintUrl
                      : _inputType == 'niche'
                          ? t.miRootHintNiche
                          : t.miRootHintProject,
                  hintStyle: const TextStyle(color: AppColors.inkSubtle),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: const BorderSide(color: AppColors.info),
                  ),
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: AppColors.inkSubtle),
                ),
              ),
              const SizedBox(height: 16),

              // Analyze button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: busy ? null : _analyze,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: AppColors.ink, strokeWidth: 2),
                        )
                      : const Icon(Icons.rocket_launch_rounded),
                  label: Text(
                    busy ? t.miRootAnalyzing : t.miRootAnalyzeCta,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg)),
                  ),
                ),
              ),

              if (state is AsyncError) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.negative.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.negative.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.negative, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(t.miRootConnectionErrorTitle,
                                style: const TextStyle(
                                    color: AppColors.negative,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _friendlyError(t, state.error.toString()),
                        style: const TextStyle(
                            color: AppColors.inkMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // History
              Text(t.miRootPreviousAnalysesTitle,
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              analyses.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.info)),
                error: (e, _) => Text(t.commonError,
                    style: const TextStyle(color: AppColors.negative)),
                data: (list) => list.isEmpty
                    ? Text(t.miRootNoAnalysesYet,
                        style: const TextStyle(color: AppColors.inkSubtle))
                    : Column(
                        children: list
                            .map((a) => _AnalysisCard(analysis: a))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.info : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color:
                isSelected ? AppColors.info : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppColors.inkMuted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.analysis});
  final MarketAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(
        AppConstants.routeMarketIntelligenceHub
            .replaceFirst(':id', analysis.id),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface, gradient: kIvSurfaceGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Text(
                  '${analysis.opportunityScore}',
                  style: const TextStyle(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.input,
                    style: const TextStyle(
                        color: AppColors.ink, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    analysis.niche ?? analysis.inputType,
                    style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
          ],
        ),
      ),
    );
  }
}
