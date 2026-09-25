import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/impact_lab_api.dart';
import '../domain/dossier_models.dart';

/// IV-IMPACT-I5 — overridable in tests with a fixture-backed transport.
final impactTransportProvider = Provider<ImpactTransport>(
  (ref) => SupabaseImpactTransport(Supabase.instance.client),
);

final impactLabApiProvider = Provider<ImpactLabApi>(
  (ref) => ImpactLabApi(ref.watch(impactTransportProvider)),
);

final impactInvestigationsProvider = FutureProvider.autoDispose<List<InvestigationSummary>>(
  (ref) => ref.watch(impactLabApiProvider).listInvestigations(),
);

/// (investigationId, lang). The live view is always refetched from the
/// server; the UI keeps no copy that could drift from the source of truth.
typedef DossierKey = ({String id, String lang});

final impactDossierProvider = FutureProvider.autoDispose.family<DossierView, DossierKey>(
  (ref, key) => ref.watch(impactLabApiProvider).getDossier(key.id, key.lang),
);

/// Export + verify for one investigation. The snapshot held here is what the
/// server issued; verification is always the server's answer.
class ImpactExportState {
  const ImpactExportState({this.snapshot, this.verify, this.busy = false, this.error});

  final DossierView? snapshot;
  final VerifyResult? verify;
  final bool busy;
  final ImpactApiException? error;
}

class ImpactExportController extends AutoDisposeFamilyNotifier<ImpactExportState, DossierKey> {
  @override
  ImpactExportState build(DossierKey arg) => const ImpactExportState();

  Future<void> export() async {
    if (state.busy) return; // no double submission
    state = ImpactExportState(snapshot: state.snapshot, busy: true);
    try {
      final snap = await ref.read(impactLabApiProvider).exportDossier(arg.id, arg.lang);
      state = ImpactExportState(snapshot: snap);
    } on ImpactApiException catch (e) {
      state = ImpactExportState(snapshot: state.snapshot, error: e);
    }
  }

  Future<void> verify() async {
    final snap = state.snapshot;
    if (snap == null || state.busy) return;
    state = ImpactExportState(snapshot: snap, verify: state.verify, busy: true);
    try {
      final v = await ref.read(impactLabApiProvider).verifyDossier(arg.id, snap);
      state = ImpactExportState(snapshot: snap, verify: v);
    } on ImpactApiException catch (e) {
      state = ImpactExportState(snapshot: snap, error: e);
    }
  }
}

final impactExportProvider =
    NotifierProvider.autoDispose.family<ImpactExportController, ImpactExportState, DossierKey>(
  ImpactExportController.new,
);
