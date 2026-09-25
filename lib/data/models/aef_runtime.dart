/// IV-IVE-AEF-RUNTIME-INTEGRATION-01 — client side of the LAB `aef-runtime`
/// contract (aef/runtime/presentation.ts).
///
/// The client never decides anything: it shows what the server persisted.
/// Parsing is fail-closed — an unknown phase or a malformed reply is never
/// shown as progress or success. "Done" requires ALL of: phase SUCCEEDED,
/// the server's `completed` flag, and a persisted receipt with outcome SUCCESS.
library;

/// Off by default. The LAB runtime only exists on a local stack.
const bool kAefRuntimeLabEnabled = bool.fromEnvironment('AEF_RUNTIME_LAB');

enum AefPhase {
  proposed, // client-only: IVE suggested it, nothing was sent yet
  awaitingApproval,
  authorized,
  executing,
  succeeded,
  failed,
  unknownOutcome,
  rejected,
  expired,
  cancelled,
  invalidated,
  denied,
}

const Map<String, AefPhase> _serverPhases = {
  'AWAITING_APPROVAL': AefPhase.awaitingApproval,
  'AUTHORIZED': AefPhase.authorized,
  'EXECUTING': AefPhase.executing,
  'SUCCEEDED': AefPhase.succeeded,
  'FAILED': AefPhase.failed,
  'UNKNOWN_OUTCOME': AefPhase.unknownOutcome,
  'REJECTED': AefPhase.rejected,
  'EXPIRED': AefPhase.expired,
  'CANCELLED': AefPhase.cancelled,
  'INVALIDATED': AefPhase.invalidated,
  'DENIED': AefPhase.denied,
};

bool isTerminalPhase(AefPhase p) => const {
      AefPhase.succeeded,
      AefPhase.failed,
      AefPhase.unknownOutcome,
      AefPhase.rejected,
      AefPhase.expired,
      AefPhase.cancelled,
      AefPhase.invalidated,
      AefPhase.denied,
    }.contains(p);

final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

class AefGate {
  const AefGate({required this.gateId, required this.bindingHash, required this.expiresAt});
  final String gateId;
  final String bindingHash;
  final String expiresAt;
}

class AefRuntimeResult {
  const AefRuntimeResult._({
    required this.phase,
    required this.serverCompleted,
    required this.reconciliationRequired,
    required this.operationId,
    required this.denialCode,
    required this.gate,
    required this.receiptId,
    required this.receiptOutcome,
  });

  final AefPhase phase;
  final bool serverCompleted;
  final bool reconciliationRequired;
  final String? operationId;
  final String? denialCode;
  final AefGate? gate;
  final String? receiptId;
  final String? receiptOutcome;

  /// The ONLY condition under which the UI may say the action was done.
  bool get isCompleted =>
      phase == AefPhase.succeeded && serverCompleted && receiptId != null && receiptOutcome == 'SUCCESS';

  /// A malformed or unexpected reply: shown as a failure to get a trustworthy
  /// answer, never as progress.
  static const AefRuntimeResult unreadable = AefRuntimeResult._(
    phase: AefPhase.denied,
    serverCompleted: false,
    reconciliationRequired: false,
    operationId: null,
    denialCode: 'UNREADABLE_REPLY',
    gate: null,
    receiptId: null,
    receiptOutcome: null,
  );

  static AefRuntimeResult denied(String code) => AefRuntimeResult._(
        phase: AefPhase.denied,
        serverCompleted: false,
        reconciliationRequired: false,
        operationId: null,
        denialCode: code,
        gate: null,
        receiptId: null,
        receiptOutcome: null,
      );

  factory AefRuntimeResult.fromMap(Object? raw) {
    if (raw is! Map) return unreadable;
    final phase = _serverPhases[raw['phase']];
    if (phase == null) return unreadable;
    final opId = raw['operationId'];
    if (opId != null && (opId is! String || !_uuid.hasMatch(opId))) return unreadable;
    AefGate? gate;
    final g = raw['gate'];
    if (g is Map) {
      final id = g['gateId'];
      final bh = g['bindingHash'];
      final exp = g['expiresAt'];
      if (id is! String || !_uuid.hasMatch(id) || bh is! String || !_hex64.hasMatch(bh) || exp is! String) return unreadable;
      gate = AefGate(gateId: id, bindingHash: bh, expiresAt: exp);
    } else if (g != null) {
      return unreadable;
    }
    if (phase == AefPhase.awaitingApproval && gate == null) return unreadable;
    String? receiptId;
    String? outcome;
    final r = raw['receipt'];
    if (r is Map && r['receiptId'] is String && r['outcome'] is String) {
      receiptId = r['receiptId'] as String;
      outcome = r['outcome'] as String;
    } else if (r != null) {
      return unreadable;
    }
    return AefRuntimeResult._(
      phase: phase,
      serverCompleted: raw['completed'] == true,
      reconciliationRequired: raw['reconciliationRequired'] == true || phase == AefPhase.unknownOutcome,
      operationId: opId as String?,
      denialCode: raw['denialCode'] is String ? raw['denialCode'] as String : null,
      gate: gate,
      receiptId: receiptId,
      receiptOutcome: outcome,
    );
  }
}

/// The IVE suggestion as received from ive-intelligence (six keys, validated).
class IveActionIntentData {
  const IveActionIntentData({
    required this.capabilityId,
    required this.requestedAction,
    required this.projectId,
    required this.riskClass,
    required this.contextRef,
  });

  final String? capabilityId;
  final String requestedAction;
  final String? projectId;
  final String riskClass;
  final String contextRef;

  static IveActionIntentData? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final action = raw['requestedAction'];
    final ref = raw['contextRef'];
    final risk = raw['riskClass'];
    final cap = raw['capabilityId'];
    final project = raw['projectId'];
    if (action is! String || !RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(action)) return null;
    if (ref is! String || !_uuid.hasMatch(ref)) return null;
    if (risk is! String || !const {'READ_ONLY', 'REVERSIBLE', 'CONSEQUENTIAL'}.contains(risk)) return null;
    if (cap != null && cap is! String) return null;
    if (project != null && (project is! String || !_uuid.hasMatch(project))) return null;
    return IveActionIntentData(
      capabilityId: cap as String?,
      requestedAction: action,
      projectId: project as String?,
      riskClass: risk,
      contextRef: ref,
    );
  }

  /// The proposal sent to aef-runtime: the intent plus the parameters the
  /// user reviewed. It carries no authority — the server re-derives subject,
  /// entitlement, tool, risk and the need for approval.
  Map<String, dynamic> toProposal(Map<String, Object> parameters) => {
        'capabilityId': capabilityId,
        'requestedAction': requestedAction,
        'projectId': projectId,
        'riskClass': riskClass,
        'contextRef': contextRef,
        'parameters': parameters,
      };
}

/// The LAB mock actions the runtime accepts, with the fields the user must
/// fill in (mirrors aef/runtime/lab_tools.ts; the server re-validates).
class AefLabField {
  const AefLabField(this.name, {this.options, required this.maxLength});
  final String name;
  final List<String>? options;
  final int maxLength;
}

const Map<String, List<AefLabField>> kAefLabActions = {
  'publish_content': [
    AefLabField('channel', options: ['instagram', 'linkedin', 'x', 'blog'], maxLength: 16),
    AefLabField('text', maxLength: 280),
  ],
  'send_message': [
    AefLabField('audience', options: ['customers', 'leads', 'team'], maxLength: 16),
    AefLabField('subject', maxLength: 120),
    AefLabField('body', maxLength: 2000),
  ],
};
