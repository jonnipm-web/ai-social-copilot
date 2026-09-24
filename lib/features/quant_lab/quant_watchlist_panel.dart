// IV-QUANT-REAL-DATA-READINESS-03 — Quant Lab watchlist panel (INTERNAL, admin-only).
//
// Watchlist CRUD through `quant-watchlists` and the watchlist → analysis
// flow through `quant.analyze.watchlist.v1`. Only ids travel to the analysis:
// the server reads the instruments from the caller's own watchlist (RLS) and
// the prices from its own SYNTHETIC provider. The client computes nothing
// (display rounding only) and offers no order/buy/sell/broker action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'quant_lab_models.dart';
import 'quant_lab_service.dart';

class QuantWatchlistPanel extends ConsumerStatefulWidget {
  const QuantWatchlistPanel({super.key});

  @override
  ConsumerState<QuantWatchlistPanel> createState() => _QuantWatchlistPanelState();
}

class _QuantWatchlistPanelState extends ConsumerState<QuantWatchlistPanel> {
  final _name = TextEditingController();
  final _symbol = TextEditingController();
  final _currency = TextEditingController(text: 'USD');
  String _assetClass = kQuantLabAssetClasses.first;
  String? _mic = kQuantLabMics.first;

  List<QuantWatchlistView>? _lists;
  String? _selectedId;
  final Set<String> _checked = {};
  bool _busy = false;
  String? _error;
  QuantMultiOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    for (final c in [_name, _symbol, _currency]) {
      c.dispose();
    }
    super.dispose();
  }

  QuantWatchlistView? get _selected {
    final lists = _lists;
    if (lists == null) return null;
    for (final w in lists) {
      if (w.id == _selectedId) return w;
    }
    return null;
  }

  Future<void> _reload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final o = await ref.read(quantLabApiProvider).listWatchlists();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (o.watchlists == null) {
        _error = o.errorCode;
        return;
      }
      _lists = o.watchlists;
      if (_selected == null) _selectedId = _lists!.isEmpty ? null : _lists!.first.id;
      final ids = _selected?.items.map((i) => i.id).toSet() ?? <String>{};
      _checked.removeWhere((id) => !ids.contains(id));
    });
  }

  Future<void> _act(Map<String, dynamic> action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final o = await ref.read(quantLabApiProvider).watchlistAction(action);
    if (!mounted) return;
    if (!o.ok) {
      setState(() {
        _busy = false;
        _error = o.reason != null ? '${o.errorCode} (${o.reason})' : o.errorCode;
      });
      return;
    }
    await _reload();
  }

  Future<void> _create() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    await _act({'action': 'create', 'name': n});
    if (mounted && _error == null) {
      _name.clear();
      final lists = _lists;
      if (lists != null && lists.isNotEmpty) setState(() => _selectedId = lists.last.id);
    }
  }

  Future<void> _addItem() async {
    final w = _selected;
    if (w == null || _symbol.text.trim().isEmpty || _currency.text.trim().isEmpty) return;
    await _act({
      'action': 'add_item',
      'watchlist_id': w.id,
      'instrument': {
        'asset_class': _assetClass,
        'symbol': _symbol.text.trim(),
        if (_mic != null) 'exchange_mic': _mic,
        'currency': _currency.text.trim(),
      },
    });
    if (mounted && _error == null) _symbol.clear();
  }

  Future<void> _analyze() async {
    final w = _selected;
    if (w == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ids = [
      for (final i in w.items)
        if (_checked.contains(i.id)) i.id
    ];
    final o = await ref.read(quantLabApiProvider).analyzeWatchlist(w.id, ids);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = o;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final t = Theme.of(context).textTheme;
    const gap = SizedBox(height: 12);
    final lists = _lists;
    final w = _selected;
    final itemCount = w?.items.length ?? 0;
    final selectedCount = _checked.length;
    final canAnalyze =
        w != null && itemCount > 0 && !_busy && (selectedCount > 0 ? selectedCount <= kQuantMaxSeriesPerAnalysis : itemCount <= kQuantMaxSeriesPerAnalysis);

    return Column(key: const Key('quantWatchlistPanel'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(padding: const EdgeInsets.all(12), child: Text(l.quantLabSyntheticNotice)),
      ),
      gap,
      Semantics(header: true, child: Text(l.quantLabWatchlists, style: t.titleMedium)),
      gap,
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Expanded(child: Text(l.quantLabOperationError(_error!), style: TextStyle(color: Theme.of(context).colorScheme.error))),
            TextButton(onPressed: _busy ? null : _reload, child: Text(l.quantLabRetry)),
          ]),
        ),
      if (lists == null && _busy) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      if (lists != null && lists.isEmpty) Text(l.quantLabNoWatchlists),
      if (lists != null && lists.isNotEmpty)
        Row(children: [
          Expanded(
            // Re-created when the selection is changed programmatically (create/delete).
            child: KeyedSubtree(
              key: ValueKey('$_selectedId/${lists.length}'),
              child: DropdownButtonFormField<String>(
                key: const Key('quantWatchlistSelect'),
                initialValue: _selectedId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.quantLabWatchlists),
                items: [for (final x in lists) DropdownMenuItem(value: x.id, child: Text('${x.name} (${x.items.length})', overflow: TextOverflow.ellipsis))],
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _selectedId = v;
                          _checked.clear();
                          _outcome = null;
                        }),
              ),
            ),
          ),
          IconButton(
            tooltip: l.quantLabDeleteWatchlist,
            onPressed: _busy || w == null ? null : () => _act({'action': 'delete', 'watchlist_id': w.id}),
            icon: const Icon(Icons.delete_outline),
          ),
        ]),
      gap,
      Row(children: [
        Expanded(
          child: TextField(
            key: const Key('quantWatchlistName'),
            controller: _name,
            maxLength: 80,
            decoration: InputDecoration(labelText: l.quantLabWatchlistName, counterText: ''),
            onSubmitted: (_) => _create(),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(key: const Key('quantWatchlistCreate'), onPressed: _busy ? null : _create, child: Text(l.quantLabCreate)),
      ]),
      if (w != null) ...[
        const SizedBox(height: 20),
        Text(w.name, style: t.titleSmall),
        const SizedBox(height: 4),
        if (w.items.isEmpty) Text(l.quantLabNoItems) else Text(l.quantLabSelectUpTo(kQuantMaxSeriesPerAnalysis)),
        for (final it in w.items)
          CheckboxListTile(
            key: Key('quantWatchlistItem_${it.id}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _checked.contains(it.id),
            onChanged: _busy
                ? null
                : (v) => setState(() {
                      if (v == true) {
                        _checked.add(it.id);
                      } else {
                        _checked.remove(it.id);
                      }
                    }),
            title: Text(it.label),
            secondary: IconButton(
              tooltip: l.quantLabRemoveItem,
              onPressed: _busy ? null : () => _act({'action': 'remove_item', 'watchlist_id': w.id, 'item_id': it.id}),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ),
        gap,
        Text(l.quantLabAddItem, style: t.titleSmall),
        gap,
        DropdownButtonFormField<String>(
          initialValue: _assetClass,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.quantLabAssetClass),
          items: [for (final c in kQuantLabAssetClasses) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _assetClass = v ?? _assetClass),
        ),
        gap,
        TextField(key: const Key('quantWatchlistSymbol'), controller: _symbol, decoration: InputDecoration(labelText: l.quantLabSymbol)),
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
        OutlinedButton.icon(
          key: const Key('quantWatchlistAdd'),
          onPressed: _busy ? null : _addItem,
          icon: const Icon(Icons.add),
          label: Text(l.quantLabAddItem),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            key: const Key('quantWatchlistAnalyze'),
            onPressed: canAnalyze ? _analyze : null,
            icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.analytics_outlined),
            label: Text(_busy ? l.quantLabAnalyzing : l.quantLabAnalyzeWatchlist),
          ),
        ),
      ],
      const SizedBox(height: 16),
      _MultiResult(outcome: _outcome),
    ]);
  }
}

class _MultiResult extends StatelessWidget {
  const _MultiResult({required this.outcome});
  final QuantMultiOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final o = outcome;
    if (o == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    if (o.result == null) {
      final msg = o.errorField != null ? l.quantLabErrorField(o.errorCode!, o.errorField!) : l.quantLabError(o.errorCode!);
      return Card(
        child: ListTile(
          leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, semanticLabel: 'error'),
          title: Text(msg),
        ),
      );
    }
    final r = o.result!;
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
    return Column(key: const Key('quantMultiResult'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      section(l.quantLabDataSource, [
        kv('kind', r.dataSourceKind ?? 'USER_UPLOAD'),
        if (r.cacheHits != null) kv('cache', 'hits=${r.cacheHits} · misses=${r.cacheMisses}'),
        kv('id', r.id.length > 19 ? r.id.substring(0, 19) : r.id),
      ]),
      section(l.quantLabAlignment, [
        kv('policy', r.alignmentPolicy),
        kv(l.quantLabPeriod, '${r.alignmentStart ?? '—'} → ${r.alignmentEnd ?? '—'} · ${r.commonBars}'),
      ]),
      section(l.quantLabSeries, [
        for (final s in r.series)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              kv(l.quantLabAlignedReturn, quantPct(s.alignedReturn)),
              kv(l.quantLabFreshness, s.freshnessState),
              kv('trust', '${s.trust} · ${s.providerId}'),
              kv('bars', '${s.bars} (−${s.dropped})'),
            ]),
          ),
      ]),
      if (r.correlation.isNotEmpty)
        section(l.quantLabCorrelation, [
          for (final c in r.correlation) kv('${c.a} × ${c.b}', '${quantCorr(c.value)}${c.error != null ? ' (${c.error})' : ''} · n=${c.observations}'),
        ]),
      section(l.quantLabAssumptions, [for (final s in r.assumptions) Text('• $s')]),
      if (r.warnings.isNotEmpty) section(l.quantLabWarnings, [for (final w in r.warnings) Text('• ${w.code} — ${w.message}')]),
    ]);
  }
}
