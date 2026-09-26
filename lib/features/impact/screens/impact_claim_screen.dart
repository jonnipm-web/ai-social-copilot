import 'package:flutter/material.dart';

import '../../../core/ui/breakpoints.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/dossier_models.dart';
import '../../../shared/widgets/ive_exclusion_region.dart';
import '../widgets/impact_widgets.dart';

/// IV-IMPACT-I5 — one claim, as the server verified it: the evidence the
/// engine counted (for / partial / against / context / excluded), every
/// disagreement side by side with no winner, gaps, the rules applied and
/// the full provenance of each evidence item.
///
/// Reached from the dossier screen already behind its admin gate; it only
/// renders data that screen received from the server.
class ImpactClaimScreen extends StatelessWidget {
  const ImpactClaimScreen({super.key, required this.dossier, required this.claim});

  final DossierView dossier;
  final ClaimView claim;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final l = dossier.labels;
    final v = claim.verification;
    final disputes = dossier.disputes.where((d) => d.claimRef == claim.ref).toList();
    final claimLimitations = dossier.limitationsForClaim(claim);
    return Scaffold(
      appBar: AppBar(title: Text(t.impactClaimDetail)),
      body: ImpactPage(
        maxWidth: 960,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Codex I5G1-04 — the dossier's caveats come before the claim.
            // PF-02: never under the floating IVE avatar.
            IveExclusionRegion(child: ImpactSection(
              title: t.impactClaimCaveats,
              icon: Icons.do_not_disturb_on_outlined,
              emphasis: true,
              children: [
                Text(t.impactNotEstablished, style: Theme.of(context).textTheme.labelLarge),
                for (final code in dossier.doesNotEstablish) ImpactLine(l.nonFinding(code), icon: Icons.remove, muted: true),
                const SizedBox(height: 8),
                Text(t.impactClaimLimitations, style: Theme.of(context).textTheme.labelLarge),
                if (claimLimitations.isEmpty) ImpactLine(t.impactNoLimitations, muted: true),
                for (final lim in claimLimitations)
                  ImpactLine(lim.ref == null ? l.limitation(lim.code) : '${l.limitation(lim.code)} (${lim.ref})', icon: Icons.warning_amber_outlined),
                ImpactLine(t.impactExportLimitations(dossier.limitationCount), muted: true),
              ],
            )),
            ImpactQuote(
              text: claim.text,
              attribution: claim.textAttribution,
              redacted: claim.textRedacted,
              withheld: claim.textWithheld != null,
            ),
            ImpactLine('${claim.ref} · ${claim.kind ?? '—'} · ${claim.sourceRef ?? '—'}', muted: true),
            ImpactLine(t.impactClaimScopeNote, icon: Icons.info_outline),
            const SizedBox(height: 8),
            if (v == null)
              ImpactSection(
                title: l.section('CLAIMS'),
                icon: Icons.hourglass_empty,
                children: [ImpactLine(t.impactNotVerifiedYet)],
              )
            else ...[
              ImpactSection(
                title: l.section('CLAIMS'),
                icon: Icons.fact_check_outlined,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ImpactChip(label: l.status(v.status), icon: impactStatusIcon(v.status)),
                    ImpactChip(label: l.displayClass(v.displayClass), icon: Icons.label_outline),
                    ImpactChip(label: l.sufficiency(v.sufficiency), icon: Icons.stacked_bar_chart_outlined),
                  ]),
                  const SizedBox(height: 8),
                  ImpactLine(t.impactVoices(v.independentVoices, v.documents), icon: Icons.record_voice_over_outlined),
                  ImpactLine(t.impactVoicesNote, muted: true),
                ],
              ),
              _EvidenceGroups(dossier: dossier, v: v),
              ImpactSection(
                title: t.impactConflicts,
                icon: Icons.compare_arrows,
                children: [
                  if (v.conflicts.isEmpty) ImpactLine(t.impactNoConflicts),
                  if (v.conflicts.isNotEmpty) ImpactLine(t.impactPositionsNoWinner, icon: Icons.info_outline),
                  for (final c in v.conflicts) _ConflictBlock(labels: l, conflict: c),
                ],
              ),
              ImpactSection(
                title: t.impactGaps,
                icon: Icons.help_center_outlined,
                children: [
                  if (v.gaps.isEmpty) ImpactLine('—', muted: true),
                  for (final g in v.gaps) ImpactLine(l.gap(g), icon: Icons.remove),
                  const SizedBox(height: 8),
                  Text(t.impactRules, style: Theme.of(context).textTheme.labelMedium),
                  for (final r in v.rulesApplied) ImpactLine(r, muted: true),
                  ImpactLine('${v.policyVersion ?? '—'} · ${v.evaluatedAt ?? '—'}', muted: true),
                ],
              ),
            ],
            if (claim.reverificationPending)
              ImpactSection(
                title: t.impactReverifyPending,
                icon: Icons.update,
                emphasis: true,
                children: [for (final r in claim.reverificationReasons) ImpactLine(l.reverifyReason(r), icon: Icons.remove)],
              ),
            ImpactSection(
              title: l.section('DISPUTES'),
              icon: Icons.forum_outlined,
              children: [
                if (disputes.isEmpty) ImpactLine(t.impactNoDisputes),
                for (final d in disputes)
                  ImpactLine(
                    [d.ref, d.kind ?? '—', d.open ? t.impactOpenDisputes : (d.resolution ?? '—'), d.openedAt ?? ''].join(' · '),
                    icon: Icons.forum_outlined,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceGroups extends StatelessWidget {
  const _EvidenceGroups({required this.dossier, required this.v});

  final DossierView dossier;
  final VerificationView v;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final l = dossier.labels;
    final groups = <(String, List<AssessedEvidence>)>[
      (l.section('EVIDENCE_FOR'), v.supporting),
      (l.section('EVIDENCE_PARTIAL'), v.partiallySupporting),
      (l.section('EVIDENCE_AGAINST'), v.contradicting),
      (l.section('EVIDENCE_CONTEXT'), v.contextual),
      (t.impactEvidenceExcluded, v.excluded),
    ].where((g) => g.$2.isNotEmpty).toList();
    return ImpactSection(
      title: t.impactEvidence,
      icon: Icons.inventory_2_outlined,
      children: [
        if (groups.isEmpty) ImpactLine(t.impactNoEvidence),
        for (final g in groups) ...[
          Semantics(header: true, child: Text(g.$1, style: Theme.of(context).textTheme.titleSmall)),
          const SizedBox(height: 6),
          for (final a in g.$2) _EvidenceCard(dossier: dossier, assessed: a),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.dossier, required this.assessed});

  final DossierView dossier;
  final AssessedEvidence assessed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final l = dossier.labels;
    final e = dossier.evidenceById(assessed.evidenceRef);
    final s = dossier.source(assessed.sourceRef);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImpactLine(
              '${assessed.evidenceRef} · ${assessed.relationship ?? '—'} · ${assessed.authority ?? '—'}',
              icon: Icons.link,
            ),
            if (e != null && (e.excerpt != null || e.excerptWithheld != null))
              ImpactQuote(
                text: e.excerpt,
                attribution: e.excerptAttribution,
                redacted: e.excerptRedacted,
                withheld: e.excerptWithheld != null,
              ),
            if (s != null) ...[
              ImpactLine('${t.impactPublisher}: «${s.publisher ?? '—'}» (${s.type ?? '—'})'),
              if (s.hostProvider != null) ImpactLine(t.impactHostedOn(s.hostProvider!), icon: Icons.cloud_outlined, muted: true),
              if (s.userSubmitted) ImpactLine(t.impactUserSubmitted, icon: Icons.upload_file_outlined, muted: true),
            ],
            if (e != null)
              ImpactLine(
                [
                  t.impactLocator,
                  if (e.locatorArtifactRef != null) e.locatorArtifactRef!,
                  if (e.locatorLines != null) 'L${e.locatorLines}',
                  l.locatorState(e.locatorState),
                ].join(' · '),
                icon: Icons.place_outlined,
                muted: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _ConflictBlock extends StatelessWidget {
  const _ConflictBlock({required this.labels, required this.conflict});

  final DossierLabels labels;
  final ConflictView conflict;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final total = conflict.positions.length;
    final cards = [
      for (final (i, p) in conflict.positions.indexed)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.impactPosition(i + 1, total), style: Theme.of(context).textTheme.labelSmall),
                Text('«${p.publisher}»', style: Theme.of(context).textTheme.titleSmall),
                ImpactLine('${p.evidenceId} · ${p.sourceId}', muted: true),
                ImpactLine(p.relationship ?? '—'),
                if (p.reportedValue != null) ImpactLine('${p.reportedValue}', icon: Icons.numbers),
              ],
            ),
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImpactLine(
            '${labels.conflictKind(conflict.kind)} · ${labels.conflictBasis(conflict.basis)} · ${labels.misc('UNRESOLVED')}',
            icon: Icons.compare_arrows,
          ),
          LayoutBuilder(builder: (context, c) {
            // Side by side when there is room; stacked on phones. Order is
            // the server's — no position is promoted.
            // I5G3-05 — more than three positions are stacked (each labelled
            // "position i of n") instead of squeezed into narrow columns.
            if (!Breakpoints.isTablet(c.maxWidth) || cards.length < 2 || cards.length > 3) return Column(children: cards);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final card in cards) Expanded(child: card)],
            );
          }),
        ],
      ),
    );
  }
}
