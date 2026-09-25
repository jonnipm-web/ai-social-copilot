import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/dossier_models.dart';
import '../providers/impact_providers.dart';
import 'impact_widgets.dart';

/// IV-IMPACT-I5 — issue a snapshot, verify it, copy it privately.
///
/// - Before issuing, the reader is shown how many limitations travel with
///   the dossier and that the export is private (no public link, no share).
/// - Formats: the server's JSON document and the server's text rendering —
///   copied byte-for-byte as received. No PDF, no URL, no share sheet.
/// - Verification is the server's answer; the UI only renders it.
class ImpactExportPanel extends ConsumerWidget {
  const ImpactExportPanel({super.key, required this.dossierKey, required this.live});

  final DossierKey dossierKey;
  final DossierView live;

  Future<void> _confirmAndExport(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.impactExportConfirmTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ImpactLine(t.impactExportLimitations(live.limitationCount), icon: Icons.warning_amber_outlined),
              ImpactLine(t.impactNotEstablished, icon: Icons.do_not_disturb_on_outlined),
              for (final code in live.doesNotEstablish) ImpactLine(live.labels.nonFinding(code), muted: true),
              ImpactLine(t.impactSnapshotHint, icon: Icons.photo_camera_outlined),
              ImpactLine(t.impactExportPrivacy, icon: Icons.lock_outline),
              ImpactLine(t.impactExportFormats, icon: Icons.description_outlined),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.impactExportConfirm)),
        ],
      ),
    );
    if (ok == true) await ref.read(impactExportProvider(dossierKey).notifier).export();
  }

  Future<void> _copy(BuildContext context, String value) async {
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: value));
    messenger?.showSnackBar(SnackBar(content: Text(t.impactCopied)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final st = ref.watch(impactExportProvider(dossierKey));
    final snap = st.snapshot;
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return ImpactSection(
      title: t.impactExport,
      icon: Icons.ios_share_outlined,
      children: [
        ImpactLine(t.impactExportPrivacy, icon: Icons.lock_outline, muted: true),
        ImpactLine(t.impactExportFormats, muted: true),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: st.busy ? null : () => _confirmAndExport(context, ref),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(t.impactExport),
          ),
          if (snap != null)
            OutlinedButton.icon(
              onPressed: st.busy ? null : () => ref.read(impactExportProvider(dossierKey).notifier).verify(),
              icon: const Icon(Icons.verified_outlined),
              label: Text(t.impactVerifySnapshot),
            ),
        ]),
        if (st.busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        if (st.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(liveRegion: true, child: ImpactLine(impactErrorText(t, st.error!), icon: Icons.info_outline)),
          ),
        if (snap == null && st.error == null && !st.busy) ImpactLine(t.impactNoSnapshot, muted: true),
        if (snap != null) ...[
          const SizedBox(height: 12),
          Semantics(liveRegion: true, child: ImpactChip(label: t.impactExportDone, icon: Icons.photo_camera_outlined)),
          const SizedBox(height: 8),
          ImpactLine('${t.impactSnapshotRef}: ${snap.envelope.snapshotRef ?? '—'}'),
          // I5G1-07 — the confirmation described the live view; the issued
          // snapshot's OWN caveats are shown right here.
          ImpactLine(t.impactSnapshotCaveats, icon: Icons.info_outline),
          ImpactLine(t.impactExportLimitations(snap.limitationCount), icon: Icons.warning_amber_outlined),
          for (final code in snap.doesNotEstablish) ImpactLine(snap.labels.nonFinding(code), muted: true),
          if (snap.envelope.generatedAt != null) ImpactLine(t.impactAsOf(snap.asOf ?? snap.envelope.generatedAt!), muted: true),
          Text(t.impactContentHash, style: Theme.of(context).textTheme.labelMedium),
          SelectableText(snap.integrity.contentHash, style: mono),
          ImpactLine(t.impactHashNotTruth, icon: Icons.info_outline, muted: true),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _copy(context, snap.documentJson),
              icon: const Icon(Icons.data_object),
              label: Text(t.impactCopyJson),
            ),
            OutlinedButton.icon(
              onPressed: () => _copy(context, snap.text),
              icon: const Icon(Icons.notes),
              label: Text(t.impactCopyText),
            ),
          ]),
        ],
        if (st.verify != null) ...[
          const SizedBox(height: 12),
          Semantics(liveRegion: true, child: _VerifyResultView(result: st.verify!)),
        ],
      ],
    );
  }
}

class _VerifyResultView extends StatelessWidget {
  const _VerifyResultView({required this.result});

  final VerifyResult result;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final (text, icon) = switch (result.state) {
      'CURRENT' => (t.impactVerifyCurrent, Icons.check_circle_outline),
      'STALE' => (t.impactVerifyStale, Icons.history),
      _ => (t.impactVerifyNotIssued, Icons.help_outline),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A metadata mismatch is shown FIRST: a "current" hash with a
        // tampered envelope must never read as a clean confirmation.
        if (result.envelopeState == 'MISMATCH') ImpactLine(t.impactEnvelopeMismatch, icon: Icons.warning_amber_outlined),
        ImpactLine(text, icon: icon),
        ImpactLine(t.impactHashNotTruth, muted: true),
      ],
    );
  }
}
