// INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 §5-9 — Structured Strategy Builder.
//
// A REAL create/edit form (no longer read-only, per the mission's own
// complaint about Macro-05). Live validation calls the server's
// validate op before save (§7: "Fail closed. Do not silently reinterpret
// invalid configuration."). The summary card (§8) and the save payload
// are both built from the SAME buildStrategySpecInput call -- one source
// of truth, per the form's current field values.
//
// Editing an existing strategy always calls create_version (§9/§29): the
// prior version's spec is never sent back for mutation, only ever read
// once to seed the form's initial values.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ive_exclusion_region.dart';
import 'data/strategy_builder_api.dart';

class StrategyBuilderFormScreen extends ConsumerStatefulWidget {
  const StrategyBuilderFormScreen({super.key, this.existingStrategyId, this.initialSpec});

  /// Null for a brand-new strategy; set when creating a new version of an
  /// existing one.
  final String? existingStrategyId;
  final Map<String, dynamic>? initialSpec;

  @override
  ConsumerState<StrategyBuilderFormScreen> createState() => _StrategyBuilderFormScreenState();
}

class _StrategyBuilderFormScreenState extends ConsumerState<StrategyBuilderFormScreen> {
  late final _name = TextEditingController(text: _seed('name', ''));
  late final _description = TextEditingController(text: _seed('description', ''));
  late final _stop = TextEditingController(text: _seedNum('stop', 'distance', 100));
  late final _target = TextEditingController(text: _seedNum('target', 'distance', 250));
  late final _beTrigger = TextEditingController(text: _seedNum('breakEven', 'triggerDistance', 50));
  late final _beInitial = TextEditingController(text: _seedNum('breakEven', 'initialProtectedDistance', 10));
  late final _beStep = TextEditingController(text: _seedNum('breakEven', 'stepDistance', 10));
  late final _sessionStart = TextEditingController(text: _seedSession('startTime', '10:00'));
  late final _sessionEnd = TextEditingController(text: _seedSession('endTime', '16:00'));
  late final _forcedExit = TextEditingController(text: _seed('forcedExit', null)?['time'] as String? ?? '16:00');
  late final _quantity = TextEditingController(text: '${_seed('positionSize', null)?['quantity'] ?? 1}');

  late bool _useV10Entry = (widget.initialSpec?['entry']?['ruleId']) == 'ENTRY.PULLBACK_IN_TREND';
  late final Set<String> _directions = {
    ...((widget.initialSpec?['allowedDirections'] as List?)?.cast<String>() ?? const ['LONG']),
  };
  late bool _breakEvenEnabled = widget.initialSpec?['breakEven'] != null;

  bool _busy = false;
  String? _statusMessage;
  bool? _statusOk;

  dynamic _seed(String field, dynamic fallback) => widget.initialSpec?[field] ?? fallback;
  String _seedNum(String field, String sub, num fallback) => '${(widget.initialSpec?[field]?[sub] as num?) ?? fallback}';
  String _seedSession(String sub, String fallback) => (widget.initialSpec?['session']?[sub] as String?) ?? fallback;

  @override
  void dispose() {
    for (final c in [_name, _description, _stop, _target, _beTrigger, _beInitial, _beStep, _sessionStart, _sessionEnd, _forcedExit, _quantity]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _currentSpecInput() => buildStrategySpecInput(
        name: _name.text.trim().isEmpty ? 'Untitled strategy' : _name.text.trim(),
        description: _description.text.trim(),
        useV10Entry: _useV10Entry,
        allowedDirections: _directions.toList(),
        stopDistance: double.tryParse(_stop.text) ?? 0,
        targetDistance: double.tryParse(_target.text) ?? 0,
        breakEvenEnabled: _breakEvenEnabled,
        breakEvenTrigger: double.tryParse(_beTrigger.text) ?? 0,
        breakEvenInitial: double.tryParse(_beInitial.text) ?? 0,
        breakEvenStep: double.tryParse(_beStep.text) ?? 0,
        sessionStart: _sessionStart.text.trim(),
        sessionEnd: _sessionEnd.text.trim(),
        forcedExitTime: _forcedExit.text.trim(),
        quantity: int.tryParse(_quantity.text) ?? 0,
      );

  Future<void> _validate(AppLocalizations l) async {
    setState(() => _busy = true);
    final result = await ref.read(strategyBuilderApiProvider).validate(_currentSpecInput());
    if (!mounted) return;
    final valid = result.data?['valid'] == true;
    setState(() {
      _busy = false;
      _statusOk = valid;
      _statusMessage = valid ? l.strategyBuilderValidationOk : l.strategyBuilderValidationError(result.errorCode ?? 'UNKNOWN');
    });
  }

  Future<void> _save(AppLocalizations l) async {
    setState(() => _busy = true);
    final api = ref.read(strategyBuilderApiProvider);
    final spec = _currentSpecInput();
    final result = widget.existingStrategyId == null ? await api.create(spec) : await api.createVersion(widget.existingStrategyId!, spec);
    if (!mounted) return;
    final saved = result.status == 200 && result.data?['error'] == null;
    setState(() {
      _busy = false;
      _statusOk = saved;
      _statusMessage = saved ? l.strategyBuilderSaved : l.strategyBuilderSaveError(result.errorCode ?? 'UNKNOWN');
    });
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isEdit = widget.existingStrategyId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? l.strategyBuilderEditTitle : l.strategyBuilderNewTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('strategyBuilderFormScroll'),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(key: const Key('strategyBuilderNameField'), controller: _name, decoration: InputDecoration(labelText: l.strategyBuilderName)),
            const SizedBox(height: 12),
            TextField(controller: _description, decoration: InputDecoration(labelText: l.strategyBuilderDescription), maxLines: 2),
            const SizedBox(height: 16),
            Text(l.strategyBuilderEntryMode, style: Theme.of(context).textTheme.titleSmall),
            RadioListTile<bool>(
              key: const Key('strategyBuilderEntryGeneric'),
              value: false, groupValue: _useV10Entry, title: Text(l.strategyBuilderEntryModeGeneric),
              onChanged: (v) => setState(() => _useV10Entry = v ?? false),
            ),
            RadioListTile<bool>(
              key: const Key('strategyBuilderEntryV10'),
              value: true, groupValue: _useV10Entry, title: Text(l.strategyBuilderEntryModeV10),
              onChanged: (v) => setState(() => _useV10Entry = v ?? true),
            ),
            const SizedBox(height: 8),
            Text(l.strategyBuilderDirection, style: Theme.of(context).textTheme.titleSmall),
            Wrap(spacing: 8, children: [
              FilterChip(
                key: const Key('strategyBuilderDirLong'),
                label: Text(l.strategyBuilderDirectionLong), selected: _directions.contains('LONG'),
                onSelected: (sel) => setState(() => sel ? _directions.add('LONG') : _directions.remove('LONG')),
              ),
              FilterChip(
                key: const Key('strategyBuilderDirShort'),
                label: Text(l.strategyBuilderDirectionShort), selected: _directions.contains('SHORT'),
                onSelected: (sel) => setState(() => sel ? _directions.add('SHORT') : _directions.remove('SHORT')),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextField(key: const Key('strategyBuilderStop'), controller: _stop, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.strategyBuilderStopDistance))),
              const SizedBox(width: 12),
              Expanded(child: TextField(key: const Key('strategyBuilderTarget'), controller: _target, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.strategyBuilderTargetDistance))),
            ]),
            const SizedBox(height: 12),
            SwitchListTile(
              key: const Key('strategyBuilderBreakEvenToggle'),
              value: _breakEvenEnabled, title: Text(l.strategyBuilderBreakEven),
              onChanged: (v) => setState(() => _breakEvenEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_breakEvenEnabled)
              Row(children: [
                Expanded(child: TextField(controller: _beTrigger, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.strategyBuilderBreakEvenTrigger))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _beInitial, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.strategyBuilderBreakEvenInitial))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _beStep, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.strategyBuilderBreakEvenStep))),
              ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _sessionStart, decoration: InputDecoration(labelText: l.strategyBuilderSessionStart))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _sessionEnd, decoration: InputDecoration(labelText: l.strategyBuilderSessionEnd))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _forcedExit, decoration: InputDecoration(labelText: l.strategyBuilderForcedExit)),
            const SizedBox(height: 12),
            TextField(key: const Key('strategyBuilderQuantity'), controller: _quantity, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l.strategyBuilderQuantity)),
            const SizedBox(height: 20),
            _SummaryCard(
              l: l, useV10Entry: _useV10Entry, directions: _directions, stop: _stop.text, target: _target.text,
              breakEven: _breakEvenEnabled, breakEvenSummary: '+${_beTrigger.text} → +${_beInitial.text}, step +${_beStep.text}',
              session: '${_sessionStart.text}–${_sessionEnd.text}', quantity: _quantity.text,
            ),
            const SizedBox(height: 16),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_statusMessage!, key: const Key('strategyBuilderStatusText'), style: TextStyle(color: _statusOk == false ? Theme.of(context).colorScheme.error : null)),
              ),
            IveExclusionRegion(
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('strategyBuilderValidateButton'),
                    onPressed: _busy ? null : () => _validate(l),
                    child: Text(l.strategyBuilderValidate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('strategyBuilderSaveButton'),
                    onPressed: _busy ? null : () => _save(l),
                    child: Text(l.strategyBuilderSave),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.l, required this.useV10Entry, required this.directions, required this.stop,
    required this.target, required this.breakEven, required this.breakEvenSummary, required this.session, required this.quantity,
  });
  final AppLocalizations l;
  final bool useV10Entry;
  final Set<String> directions;
  final String stop;
  final String target;
  final bool breakEven;
  final String breakEvenSummary;
  final String session;
  final String quantity;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text.rich(TextSpan(children: [TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w600)), TextSpan(text: v)])),
        );
    return Card(
      key: const Key('strategyBuilderSummaryCard'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(l.strategyBuilderSummaryTitle, style: t.titleSmall)),
          const SizedBox(height: 8),
          kv(l.strategyBuilderSummaryInstrument, useV10Entry ? 'WIN1!' : 'SYNTH1'),
          kv(l.strategyBuilderSummarySignal, '5min'),
          kv(l.strategyBuilderDirection, directions.join(' + ')),
          kv(l.strategyBuilderStopDistance, stop),
          kv(l.strategyBuilderTargetDistance, target),
          if (breakEven) kv(l.strategyBuilderBreakEven, breakEvenSummary),
          kv(l.strategyLabSession, session),
          kv(l.strategyBuilderSummaryPosition, quantity),
        ]),
      ),
    );
  }
}
