import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../domain/dossier_models.dart';
import '../providers/impact_providers.dart';
import '../widgets/impact_widgets.dart';

/// IV-IMPACT-I5 — Impact Lab entry: the caller's own investigations.
class ImpactHomeScreen extends ConsumerWidget {
  const ImpactHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    return ImpactAdminGate(
      title: t.impactTitle,
      child: Scaffold(
        appBar: AppBar(title: Text(t.impactTitle)),
        drawer: const AppDrawer(),
        body: _Body(),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final list = ref.watch(impactInvestigationsProvider);
    return list.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ImpactErrorView(error: e, onRetry: () => ref.invalidate(impactInvestigationsProvider)),
      data: (items) => ImpactPage(
        maxWidth: 840,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImpactLine(t.impactNoScoreNote, icon: Icons.info_outline, muted: true),
            const SizedBox(height: 8),
            Semantics(header: true, child: Text(t.impactInvestigations, style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 8),
            if (items.isEmpty) ImpactLine(t.impactInvestigationsEmpty, icon: Icons.inbox_outlined),
            for (final inv in items)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: Text('«${displaySafe(inv.subjectOrgRef)}»'),
                  subtitle: Text('${inv.status} · ${inv.id}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right),
                  // push (not go): the dossier keeps a back arrow and system Back returns
                  // here instead of leaving the app (physical finding PF-03).
                  onTap: () => context.push('/impact/${Uri.encodeComponent(inv.id)}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
