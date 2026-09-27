import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/action_queue_item.dart';
import '../models/aef_runtime.dart';
import '../../core/constants/app_constants.dart';

class ActionQueueService {
  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<ActionQueueItem>> fetchAll({String? projectId, String? status}) async {
    var filter = _client
        .from(AppConstants.tableActionQueue)
        .select();

    if (projectId != null) filter = filter.eq('project_id', projectId);
    if (status != null)    filter = filter.eq('status', status);

    final rows = await filter.order('priority', ascending: true);
    return rows.map((r) => ActionQueueItem.fromMap(r)).toList();
  }

  Future<ActionQueueItem> create(ActionQueueItem item) async {
    // Codex re-verification (Macro-03) — create() inserted item.status
    // verbatim, so a caller could construct ActionQueueItem(status:
    // 'completed') and reach a governed-only status through a completely
    // different method than updateStatus(), skipping this same guard.
    // create() only ever legitimately inserts 'pending' (every real caller,
    // action_queue_provider.dart's add()/addFromOpportunity(), hardcodes
    // it) -- there is no reason for it to accept a governed-only status.
    // Checked before touching _client so this is testable without a live
    // Supabase instance, same as updateStatus's own guard.
    _refuseIfAefGovernedOnly(item.status);

    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');

    final map = item.toInsertMap();
    map['user_id'] = uid;

    final row = await _client
        .from(AppConstants.tableActionQueue)
        .insert(map)
        .select()
        .single();
    return ActionQueueItem.fromMap(row);
  }

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 (Codex final audit, P1, then
  /// re-verification) — 'executing' and 'completed' are AEF-governed-only:
  /// before this guard, nothing stopped a caller from reaching them through
  /// this same generic method (or, before the re-verification finding,
  /// through create()) and bypassing applyAefResult -- and therefore the
  /// Human Gate/receipt -- entirely. Only applyAefResult may ever write
  /// them, because only it derives the status from a real AefRuntimeResult
  /// rather than an arbitrary string. Normalized (trim + lowercase, then
  /// invisible Unicode format characters stripped -- INSIGHTVALUES-
  /// INTELLIGENCE-AUTOMATION-MACRO-04 §26, the round-3 Codex P3: a
  /// zero-width space/joiner or BOM inside 'completed' must not survive
  /// trim()/toLowerCase() alone) so no case, whitespace, or invisible-
  /// character variant can slip through a guard that only checked the
  /// exact literal.
  static const _aefGovernedOnlyStatuses = {'executing', 'completed'};

  /// Unicode category Cf ("Format"): zero-width space/joiner/non-joiner,
  /// byte-order mark, bidi control characters, soft hyphen, etc. -- visibly
  /// nothing, but present in the string's code units.
  static final RegExp _invisibleFormatChars = RegExp(r'\p{Cf}', unicode: true);

  void _refuseIfAefGovernedOnly(String status) {
    final normalized = status.trim().toLowerCase().replaceAll(_invisibleFormatChars, '');
    if (_aefGovernedOnlyStatuses.contains(normalized)) {
      throw ArgumentError('"$status" is AEF-governed-only -- use applyAefResult, which requires a real AEF receipt');
    }
  }

  Future<ActionQueueItem> updateStatus(String id, String status) async {
    _refuseIfAefGovernedOnly(status);
    final row = await _client
        .from(AppConstants.tableActionQueue)
        .update({'status': status})
        .eq('id', id)
        .select()
        .single();
    return ActionQueueItem.fromMap(row);
  }

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 — writes the item's status and
  /// AEF provenance together, derived ONLY from a real, already-validated
  /// AefRuntimeResult (never an invented status string). The status
  /// written mirrors the receipt's real outcome, not a client guess:
  ///   SUCCESS            -> 'completed'
  ///   FAILURE/NOT_EXECUTED -> the item reverts to 'approved' (governance
  ///                          says nothing happened; the user may retry)
  ///   PARTIAL/UNKNOWN_OUTCOME -> 'executing' (reconciliation required,
  ///                          never silently shown as done or failed)
  Future<ActionQueueItem> applyAefResult(String id, AefRuntimeResult result) async {
    final status = aefReceiptOutcomeToActionStatus(result);
    final row = await _client
        .from(AppConstants.tableActionQueue)
        .update({
          'status': status,
          'aef_operation_id': result.operationId,
          'aef_receipt_id': result.receiptId,
          'aef_receipt_outcome': result.receiptOutcome,
        })
        .eq('id', id)
        .select()
        .single();
    return ActionQueueItem.fromMap(row);
  }

  Future<ActionQueueItem?> fetchById(String id) async {
    final row = await _client
        .from(AppConstants.tableActionQueue)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ActionQueueItem.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableActionQueue).delete().eq('id', id);
  }

  Future<List<ActionQueueItem>> fetchPending() =>
      fetchAll(status: 'pending');

  Future<Map<String, int>> summary() async {
    final list = await fetchAll();
    return {
      'total':     list.length,
      'pending':   list.where((i) => i.status == 'pending').length,
      'executing': list.where((i) => i.status == 'executing').length,
      'completed': list.where((i) => i.status == 'completed').length,
    };
  }
}
