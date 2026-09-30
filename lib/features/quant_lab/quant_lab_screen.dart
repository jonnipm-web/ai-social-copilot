// IV-QUANT-DATA-PLANE-AND-API-02 — Quant Lab (INTERNAL, admin-only).
//
// A technical lab surface proving the end-to-end flow:
//   CSV (sample / pasted / imported) → quant-analyze (server) → structured result.
// It shows provenance, freshness, market calendar, formulas and assumptions
// for every metric. It has NO buy/sell/execute/connect-broker action, and it
// never computes a financial number itself (display rounding only).
//
// Access: the route is owned by module 'quant-analytics' (INTERNAL →
// route_policy redirects non-admins), the screen re-checks admin fail-closed,
// and the server enforces entitlement on every request regardless.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../shared/widgets/ive_exclusion_region.dart';
import 'quant_lab_models.dart';
import 'quant_lab_service.dart';
import 'quant_watchlist_panel.dart';

class QuantLabScreen extends ConsumerStatefulWidget {
  const QuantLabScreen({super.key});

  @override
  ConsumerState<QuantLabScreen> createState() => _QuantLabScreenState();
}

class _QuantLabScreenState extends ConsumerState<QuantLabScreen> {
  final _symbol = TextEditingController(text: 'TSTA');
  final _currency = TextEditingController(text: 'USD');
  final _csv = TextEditingController();
  final _periods = TextEditingController(text: '252');
  final _sma = TextEditingController(text: '2, 3');
  String _assetClass = kQuantLabAssetClasses.first;
  String? _mic = kQuantLabMics.first;
  String _adjustment = 'UNKNOWN';
  bool _busy = false;
  QuantAnalyzeOutcome? _outcome;
  String? _localError;

  @override
  void dispose() {
    for (final c in [_symbol, _currency, _csv, _periods, _sma]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(AppLocalizations l) async {
    try {
      final text = await ref.read(quantLabApiProvider).pickCsv();
      // A successful import clears any previous file error (physical finding S25).
      if (text != null && mounted) {
        setState(() {
          _csv.text = text;
          _localError = null;
        });
      }
    } on QuantLabFileException catch (e) {
      if (mounted) {
        setState(() => _localError = switch (e.code) {
              'FILE_TOO_LARGE' => l.quantLabFileTooLarge,
              'FILE_TYPE_NOT_SUPPORTED' => l.quantLabFileTypeNotSupported,
              'FILE_TYPE_NOT_IMPLEMENTED' => l.quantLabFileTypeNotImplemented,
              _ => l.quantLabFileUnreadable,
            });
      }
    }
  }

  /// True only on an EXPLICIT signed-out state (no emission yet ≠ signed out).
  bool _signedOut() {
    final a = ref.read(authStateProvider);
    return a.hasValue && a.value!.session == null;
  }

  String? _sessionUserId() => ref.read(authStateProvider).valueOrNull?.session?.user.id;

  Future<void> _analyze(AppLocalizations l) async {
    final sma = parseSmaWindows(_sma.text);
    final periodsText = _periods.text.trim();
    final periods = periodsText.isEmpty ? null : int.tryParse(periodsText);
    if (_symbol.text.trim().isEmpty ||
        _currency.text.trim().isEmpty ||
        _csv.text.trim().isEmpty ||
        sma == null ||
        (periodsText.isNotEmpty && (periods == null || periods < 1))) {
      setState(() => _localError = l.quantLabInvalidInput);
      return;
    }
    setState(() {
      _busy = true;
      _localError = null;
    });
    final sessionBefore = _sessionUserId();
    final outcome = await ref.read(quantLabApiProvider).analyze(QuantAnalyzeInput(
          assetClass: _assetClass,
          symbol: _symbol.text,
          mic: _mic,
          currency: _currency.text,
          adjustment: _adjustment,
          csv: _csv.text,
          periodsPerYear: periods,
          smaWindows: sma,
        ));
    // A result that arrives after sign-out / a user switch is discarded (Codex Gate 3).
    if (mounted) {
      final sameUser = _sessionUserId() == sessionBefore && !_signedOut();
      setState(() {
        _busy = false;
        if (sameUser) _outcome = outcome;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Fail closed: render nothing sensitive until the profile positively says admin.
    final profileAsync = ref.watch(currentProfileProvider);
    // Spinner only before the FIRST profile value. The app re-fetches the
    // profile on every resume (profile_resume_policy) — e.g. returning from
    // the Android file picker — and treating that refresh as "no data"
    // unmounted the whole lab (form scroll, watchlist state) and flashed a
    // blank screen (physical finding S25). During a refresh the previous
    // value is kept; a refresh that says "not admin" still denies below.
    if (!profileAsync.hasValue && !profileAsync.hasError) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isAdmin = profileAsync.hasValue && !profileAsync.hasError && (profileAsync.value?.isAdmin ?? false);
    // Fail closed on an explicit sign-out even before the profile refresh
    // completes (Codex Gate 3); the server stays authoritative regardless.
    ref.listen(authStateProvider, (_, next) {
      if (next.hasValue && next.value!.session == null && (_outcome != null || _csv.text.isNotEmpty)) {
        setState(() {
          _outcome = null;
          _csv.clear();
        });
      }
    });
    if (!isAdmin || _signedOut()) {
      return Scaffold(
        appBar: AppBar(title: Text(l.quantLabTitle)),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.quantLabAccessDenied, textAlign: TextAlign.center))),
      );
    }

    final form = _buildForm(context, l);
    final result = _buildResult(context, l);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.quantLabTitle),
          bottom: TabBar(tabs: [
            Tab(key: const Key('quantLabTabSingle'), text: l.quantLabTabSingle),
            Tab(key: const Key('quantLabTabWatchlist'), text: l.quantLabTabWatchlist),
          ]),
        ),
        body: SafeArea(
          child: TabBarView(children: [
            _singleTab(l, form, result),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Banner(text: l.quantLabInternalBanner),
                const SizedBox(height: 12),
                const QuantWatchlistPanel(),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _singleTab(AppLocalizations l, Widget form, Widget result) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      final banner = _Banner(text: l.quantLabInternalBanner);
      if (wide) {
        return Column(children: [
          banner,
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 380, child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: form)),
              const VerticalDivider(width: 1),
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: result)),
            ]),
          ),
        ]);
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [banner, const SizedBox(height: 12), form, const SizedBox(height: 16), result]),
      );
    });
  }

  Widget _buildForm(BuildContext context, AppLocalizations l) {
    const gap = SizedBox(height: 12);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.quantLabInstrument, style: Theme.of(context).textTheme.titleMedium),
      gap,
      DropdownButtonFormField<String>(
        initialValue: _assetClass,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.quantLabAssetClass),
        items: [for (final c in kQuantLabAssetClasses) DropdownMenuItem(value: c, child: Text(c))],
        onChanged: (v) => setState(() => _assetClass = v ?? _assetClass),
      ),
      gap,
      TextField(key: const Key('quantLabSymbol'), controller: _symbol, decoration: InputDecoration(labelText: l.quantLabSymbol)),
      gap,
      DropdownButtonFormField<String?>(
        initialValue: _mic,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.quantLabVenue),
        items: [
          for (final m in kQuantLabMics) DropdownMenuItem(value: m, child: Text(m)),
          DropdownMenuItem(value: null, child: Text(l.quantLabVenueOther, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => _mic = v),
      ),
      gap,
      TextField(controller: _currency, decoration: InputDecoration(labelText: l.quantLabCurrency)),
      gap,
      DropdownButtonFormField<String>(
        initialValue: _adjustment,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.quantLabAdjustment),
        items: [for (final a in kQuantLabAdjustments) DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis))],
        onChanged: (v) => setState(() => _adjustment = v ?? _adjustment),
      ),
      const SizedBox(height: 20),
      Text(l.quantLabDataset, style: Theme.of(context).textTheme.titleMedium),
      gap,
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          key: const Key('quantLabSample'),
          onPressed: _busy
              ? null
              : () => setState(() {
                    _csv.text = kQuantLabSampleCsv;
                    _localError = null;
                  }),
          icon: const Icon(Icons.dataset_outlined),
          label: Text(l.quantLabLoadSample),
        ),
        OutlinedButton.icon(
          key: const Key('quantLabPick'),
          onPressed: _busy ? null : () => _pick(l),
          icon: const Icon(Icons.upload_file),
          label: Text(l.quantLabPickCsv),
        ),
      ]),
      gap,
      TextField(
        key: const Key('quantLabCsv'),
        controller: _csv,
        minLines: 4,
        maxLines: 8,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: InputDecoration(hintText: l.quantLabCsvHint, border: const OutlineInputBorder()),
      ),
      gap,
      TextField(controller: _periods, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.quantLabPeriodsPerYear)),
      gap,
      TextField(controller: _sma, decoration: InputDecoration(labelText: l.quantLabSmaWindows)),
      const SizedBox(height: 16),
      if (_localError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_localError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      // The floating IVE avatar must never rest on the primary action (S25 finding).
      IveExclusionRegion(
        child: SizedBox(
          height: 48,
          child: FilledButton.icon(
            key: const Key('quantLabAnalyze'),
            onPressed: _busy ? null : () => _analyze(l),
            icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.analytics_outlined),
            label: Text(_busy ? l.quantLabAnalyzing : l.quantLabAnalyze),
          ),
        ),
      ),
    ]);
  }

  Widget _buildResult(BuildContext context, AppLocalizations l) {
    final o = _outcome;
    if (o == null) return const SizedBox.shrink();
    if (o.analysis == null) {
      final msg = o.errorField != null ? l.quantLabErrorField(o.errorCode!, o.errorField!) : l.quantLabError(o.errorCode!);
      return Card(
        child: ListTile(
          leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, semanticLabel: 'error'),
          title: Text(msg),
        ),
      );
    }
    final a = o.analysis!;
    final t = Theme.of(context).textTheme;
    Widget section(String title, List<Widget> children) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(title, style: t.titleSmall)),
              const SizedBox(height: 8),
              ...children,
            ]),
          ),
        );
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(TextSpan(children: [TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w600)), TextSpan(text: v)])),
        );

    return Column(key: const Key('quantLabResult'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(a.instrumentLabel, style: t.titleMedium),
      const SizedBox(height: 8),
      section(l.quantLabFreshness, [
        // State is always spelled out in text; the icon is supplementary, never the only signal.
        Row(children: [
          Icon(_freshIcon(a.freshnessState), semanticLabel: a.freshnessState),
          const SizedBox(width: 8),
          Expanded(child: Text(a.freshnessState, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        if (a.freshnessAsOf != null) kv(l.quantLabAsOf, a.freshnessAsOf!),
        kv(
            l.quantLabCalendar,
            '${a.calendarBasis}${a.calendarId != null ? ' · ${a.calendarId}' : ''}'
            '${a.marketState != null ? ' · ${a.marketState}' : ''}${a.sessionsBehind != null ? ' · ${l.quantLabSessionsBehind(a.sessionsBehind!)}' : ''}'),
      ]),
      section(l.quantLabPeriod, [kv(l.quantLabPeriod, '${a.periodStart} → ${a.periodEnd} · ${a.bars} · ${a.frequency}')]),
      section(l.quantLabProvenance, [
        kv(l.quantLabProviderLabel, a.providerId),
        kv(l.quantLabTrustLabel, a.trust),
        kv(l.quantLabAdjustment, a.adjustment),
        kv(l.quantLabRetrievedAt, a.retrievedAt),
        kv(l.quantLabEvidence, a.evidenceStrength),
        kv(l.quantLabContentHash, a.contentHash.substring(0, 16)), // parser guarantees ≥ 16 hex chars
        kv(l.quantLabEngine, a.engineVersion),
      ]),
      section(l.quantLabMetrics, [
        // Key metrics: the IVE avatar covered a metric value on the S25.
        for (final m in a.metrics)
          IveExclusionRegion(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('${m.id}${m.window != null ? ' (${m.window})' : ''}'),
              trailing: Text(m.display(a.currency), style: const TextStyle(fontWeight: FontWeight.w700)),
              children: [kv(l.quantLabFormula, m.formulaId), kv(l.quantLabObservations, '${m.observations}')],
            ),
          ),
      ]),
      section(l.quantLabAssumptions, [for (final s in a.assumptions) Text('• $s')]),
      if (a.warnings.isNotEmpty) section(l.quantLabWarnings, [for (final w in a.warnings) Text('• ${w.code} — ${w.message}')]),
      if (a.riskNotImplemented.isNotEmpty) section(l.quantLabRiskNotImplemented, [Text(a.riskNotImplemented.join(', '))]),
      section(l.quantLabSignals, [
        if (a.signals.isEmpty) Text(l.quantLabNoSignals) else ...[for (final s in a.signals) Text('• $s')],
      ]),
    ]);
  }

  IconData _freshIcon(String s) => switch (s) {
        'FRESH' => Icons.check_circle_outline,
        'DELAYED' => Icons.schedule,
        'STALE' => Icons.warning_amber_outlined,
        _ => Icons.help_outline,
      };
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: cs.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Icon(Icons.science_outlined, color: cs.onSecondaryContainer),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: cs.onSecondaryContainer))),
      ]),
    );
  }
}
