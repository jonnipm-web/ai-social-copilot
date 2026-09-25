import 'package:flutter/material.dart';

import '../../data/models/aef_runtime.dart';
import '../../data/services/aef_runtime_service.dart';
import '../../l10n/app_localizations.dart';

/// IV-IVE-AEF-RUNTIME-INTEGRATION-01 — LAB Human Gate card.
///
/// IVE proposes → the user fills in / reviews the parameters → requests
/// approval (the server registers the operation; nothing runs) → Approve or
/// Reject (two distinct, explicit buttons; no default, no timer) → after an
/// approval, an explicit "Run now" → the persisted result.
///
/// The card shows ONLY what the server returned. It says "done" only when
/// [AefRuntimeResult.isCompleted]; UNKNOWN_OUTCOME is visually distinct from
/// FAILED and offers no retry.
class AefActionCard extends StatefulWidget {
  const AefActionCard({super.key, required this.intent, required this.api});

  final IveActionIntentData intent;
  final AefRuntimeApi api;

  @override
  State<AefActionCard> createState() => _AefActionCardState();
}

class _AefActionCardState extends State<AefActionCard> {
  final Map<String, TextEditingController> _text = {};
  final Map<String, String?> _choice = {};
  AefRuntimeResult? _result;
  Map<String, Object>? _submitted; // frozen once proposed: approval binds this exact payload
  bool _busy = false;

  List<AefLabField> get _fields => kAefLabActions[widget.intent.requestedAction] ?? const [];

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      if (f.options == null) _text[f.name] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  AefPhase get _phase => _result?.phase ?? AefPhase.proposed;

  Map<String, Object>? _values() {
    final out = <String, Object>{};
    for (final f in _fields) {
      final v = f.options != null ? _choice[f.name] : _text[f.name]!.text.trim();
      if (v == null || v.isEmpty || v.length > f.maxLength) return null;
      out[f.name] = v;
    }
    return out;
  }

  Future<void> _run(Future<AefRuntimeResult> Function() call) async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return;
    setState(() {
      _result = r;
      _busy = false;
    });
  }

  void _requestApproval() {
    final v = _values();
    if (v == null) return;
    _submitted = Map.unmodifiable(v);
    _run(() => widget.api.propose(widget.intent.toProposal(_submitted!)));
  }

  void _decide(bool approve) {
    final gate = _result?.gate;
    if (gate == null) return;
    _run(() => widget.api.decide(gate, approve: approve));
  }

  void _execute() {
    final v = _submitted;
    if (v == null) return;
    _run(() => widget.api.execute(widget.intent.toProposal(v)));
  }

  String _fieldLabel(AppLocalizations l, String name) => switch (name) {
        'channel' => l.aefLabFieldChannel,
        'text' => l.aefLabFieldText,
        'audience' => l.aefLabFieldAudience,
        'subject' => l.aefLabFieldSubject,
        _ => l.aefLabFieldBody,
      };

  String _phaseText(AppLocalizations l) {
    final r = _result;
    return switch (_phase) {
      AefPhase.proposed => l.aefLabIntro,
      AefPhase.awaitingApproval => l.aefLabPhaseAwaiting,
      AefPhase.authorized => l.aefLabPhaseAuthorized,
      AefPhase.executing => l.aefLabPhaseExecuting,
      AefPhase.succeeded => (r != null && r.isCompleted) ? l.aefLabPhaseSucceeded : l.aefLabPhaseUnconfirmed,
      AefPhase.failed => l.aefLabPhaseFailed,
      AefPhase.unknownOutcome => l.aefLabPhaseUnknown,
      AefPhase.rejected => l.aefLabPhaseRejected,
      AefPhase.expired => l.aefLabPhaseExpired,
      AefPhase.cancelled => l.aefLabPhaseCancelled,
      AefPhase.invalidated => l.aefLabPhaseInvalidated,
      AefPhase.denied => (r?.denialCode == 'NETWORK_INTERRUPTED') ? l.aefLabPhaseNetwork : l.aefLabPhaseDenied,
    };
  }

  (IconData, Color) _phaseStyle() {
    final r = _result;
    return switch (_phase) {
      AefPhase.succeeded when r != null && r.isCompleted => (Icons.check_circle, Colors.greenAccent),
      AefPhase.unknownOutcome => (Icons.help, Colors.amberAccent),
      AefPhase.failed => (Icons.error, Colors.redAccent),
      AefPhase.denied || AefPhase.rejected || AefPhase.expired || AefPhase.cancelled || AefPhase.invalidated =>
        (Icons.block, Colors.white70),
      _ => (Icons.hourglass_top, Colors.lightBlueAccent),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locked = _submitted != null;
    final (icon, color) = _phaseStyle();
    final consequence = widget.intent.requestedAction == 'send_message' ? l.aefLabConsequenceSend : l.aefLabConsequencePublish;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E1C2E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.aefLabTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('${l.aefLabActionLabel}: ${widget.intent.requestedAction}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(l.aefLabRisk, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          Text(consequence, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          for (final f in _fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: f.options != null
                  ? DropdownButtonFormField<String>(
                      key: Key('aef-field-${f.name}'),
                      initialValue: _choice[f.name],
                      decoration: InputDecoration(labelText: _fieldLabel(l, f.name)),
                      items: [for (final o in f.options!) DropdownMenuItem(value: o, child: Text(o))],
                      onChanged: locked ? null : (v) => setState(() => _choice[f.name] = v),
                    )
                  : TextField(
                      key: Key('aef-field-${f.name}'),
                      controller: _text[f.name],
                      enabled: !locked,
                      maxLength: f.maxLength,
                      maxLines: f.maxLength > 200 ? 3 : 1,
                      decoration: InputDecoration(labelText: _fieldLabel(l, f.name)),
                      onChanged: (_) => setState(() {}),
                    ),
            ),
          Row(
            key: const Key('aef-status'),
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_phaseText(l), style: TextStyle(color: color, fontSize: 12))),
            ],
          ),
          if (_result?.receiptId != null && _result!.isCompleted)
            Text(l.aefLabReceipt(_result!.receiptId!), style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 8),
          if (_phase == AefPhase.proposed)
            ElevatedButton(
              key: const Key('aef-request'),
              onPressed: _busy || _values() == null ? null : _requestApproval,
              child: Text(l.aefLabRequestApproval),
            ),
          if (_phase == AefPhase.awaitingApproval)
            Wrap(spacing: 12, children: [
              ElevatedButton.icon(
                key: const Key('aef-approve'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                icon: const Icon(Icons.check),
                onPressed: _busy ? null : () => _decide(true),
                label: Text(l.aefLabApprove),
              ),
              OutlinedButton.icon(
                key: const Key('aef-reject'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                icon: const Icon(Icons.close),
                onPressed: _busy ? null : () => _decide(false),
                label: Text(l.aefLabReject),
              ),
            ]),
          if (_phase == AefPhase.authorized)
            ElevatedButton(key: const Key('aef-execute'), onPressed: _busy ? null : _execute, child: Text(l.aefLabExecute)),
        ],
      ),
    );
  }
}
