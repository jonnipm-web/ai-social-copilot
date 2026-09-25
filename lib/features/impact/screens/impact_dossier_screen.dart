import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/breakpoints.dart';
import '../../../l10n/app_localizations.dart';
import '../data/impact_lab_api.dart';
import '../domain/dossier_models.dart';
import '../providers/impact_providers.dart';
import '../widgets/impact_export_panel.dart';
import '../widgets/impact_widgets.dart';
import 'impact_claim_screen.dart';

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// IV-IMPACT-I5 — the verification dossier of one investigation.
///
/// Order is deliberate: what the dossier IS (live vs snapshot, as-of), its
/// summary, then what it does NOT establish and its limitations — before any
/// individual claim — so no reader meets a claim without its caveats.
class ImpactDossierScreen extends ConsumerWidget {
  const ImpactDossierScreen({super.key, required this.investigationId});

  final String investigationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    return ImpactAdminGate(
      title: t.impactTitle,
      child: Scaffold(
        appBar: AppBar(title: Text(t.impactTitle)),
        body: _uuid.hasMatch(investigationId) ? _DossierLoader(id: investigationId.toLowerCase()) : const ImpactErrorView(error: ImpactApiException(ImpactErrorKind.notAvailable)),
      ),
    );
  }
}

class _DossierLoader extends ConsumerWidget {
  const _DossierLoader({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (id: id, lang: impactLang(context));
    return ref.watch(impactDossierProvider(key)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ImpactErrorView(error: e, onRetry: () => ref.invalidate(impactDossierProvider(key))),
          data: (d) => ImpactDossierBody(dossier: d, dossierKey: key),
        );
  }
}

class ImpactDossierBody extends StatelessWidget {
  const ImpactDossierBody({super.key, required this.dossier, required this.dossierKey});

  final DossierView dossier;
  final DossierKey dossierKey;

  @override
  Widget build(BuildContext context) {
    final header = _Header(d: dossier);
    final summary = _SummarySection(d: dossier);
    final notEstablished = _NotEstablishedSection(d: dossier);
    final limitations = _LimitationsSection(d: dossier);
    // Codex I5G1-01 — on desktop the caveats span the full width ABOVE the
    // two columns, so no claim is ever laid out beside or before them.
    final left = <Widget>[
      _IdentitySection(d: dossier),
      _SourcesSection(d: dossier),
      _DisputesSection(d: dossier),
    ];
    final right = <Widget>[
      _ClaimsSection(d: dossier),
      _IntegritySection(d: dossier),
      ImpactExportPanel(dossierKey: dossierKey, live: dossier),
    ];
    return LayoutBuilder(builder: (context, c) {
      if (!Breakpoints.isDesktop(c.maxWidth)) {
        return ImpactPage(
          maxWidth: 840,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [header, summary, notEstablished, limitations, left.first, ...right.take(1), ...left.skip(1), ...right.skip(1)],
          ),
        );
      }
      return ImpactPage(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              summary,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: notEstablished),
                  const SizedBox(width: 16),
                  Expanded(child: limitations),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: Column(children: left)),
                  const SizedBox(width: 16),
                  Expanded(flex: 7, child: Column(children: right)),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.d});

  final DossierView d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final snapshot = d.envelope.isSnapshot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.labels.section('TITLE'), style: theme.textTheme.labelLarge),
          Semantics(
            header: true,
            child: Text(d.subject.legalName ?? d.subject.ref, style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ImpactChip(
              label: snapshot ? t.impactSnapshot : t.impactLiveView,
              icon: snapshot ? Icons.photo_camera_outlined : Icons.sync,
            ),
            ImpactChip(
              label: d.asOf != null ? t.impactAsOf(d.asOf!) : t.impactAsOfUnknown,
              icon: Icons.event_outlined,
            ),
          ]),
          const SizedBox(height: 8),
          ImpactLine(snapshot ? t.impactSnapshotHint : t.impactLiveViewHint, muted: true),
          ImpactLine(t.impactNoScoreNote, icon: Icons.info_outline, muted: true),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.d});

  final DossierView d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final l = d.labels;
    // Server counts, in server order; zero counts omitted.
    final byStatus = d.byStatus.entries.where((e) => e.value > 0).toList();
    final notVerified = d.summary['notVerified'] ?? 0;
    final pending = d.summary['reverificationPending'] ?? 0;
    return ImpactSection(
      title: l.section('SUMMARY'),
      icon: Icons.summarize_outlined,
      children: [
        ImpactLine(l.dossierStatus(d.dossierStatus), icon: Icons.assignment_outlined),
        ImpactLine('${t.impactClaims}: ${d.summary['claims'] ?? 0} · ${t.impactEvidence}: ${d.summary['evidence'] ?? 0} · ${l.section('SOURCES')}: ${d.summary['sources'] ?? 0}'),
        if (d.claims.isEmpty) ImpactLine(t.impactNoClaims, icon: Icons.inbox_outlined),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in byStatus) ImpactChip(label: '${l.status(e.key)}: ${e.value}', icon: impactStatusIcon(e.key)),
          if (notVerified > 0) ImpactChip(label: '${t.impactNotVerifiedYet} $notVerified', icon: Icons.hourglass_empty),
          if (pending > 0) ImpactChip(label: '${t.impactReverifyPending}: $pending', icon: Icons.update, attention: true),
          if (d.openDisputes > 0) ImpactChip(label: '${t.impactOpenDisputes}: ${d.openDisputes}', icon: Icons.forum_outlined, attention: true),
          if (d.limitations.isNotEmpty) ImpactChip(label: '${t.impactLimitations}: ${d.limitationCount}', icon: Icons.warning_amber_outlined, attention: true),
        ]),
      ],
    );
  }
}

class _NotEstablishedSection extends StatelessWidget {
  const _NotEstablishedSection({required this.d});

  final DossierView d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ImpactSection(
      title: t.impactNotEstablished,
      icon: Icons.do_not_disturb_on_outlined,
      emphasis: true,
      children: [for (final code in d.doesNotEstablish) ImpactLine(d.labels.nonFinding(code), icon: Icons.remove)],
    );
  }
}

class _LimitationsSection extends StatelessWidget {
  const _LimitationsSection({required this.d});

  final DossierView d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final groups = d.groupedLimitations;
    return ImpactSection(
      title: d.labels.section('LIMITATIONS'),
      icon: Icons.warning_amber_outlined,
      emphasis: true,
      children: [
        if (groups.isEmpty) ImpactLine(t.impactNoLimitations),
        for (final g in groups)
          ImpactLine(
            g.value.isEmpty ? d.labels.limitation(g.key) : '${d.labels.limitation(g.key)} (${g.value.join(', ')})',
            icon: Icons.remove,
          ),
      ],
    );
  }
}

class _IdentitySection extends StatelessWidget {
  const _IdentitySection({required this.d});

  final DossierView d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final l = d.labels;
    final s = d.subject;
    return ImpactSection(
      title: l.section('IDENTITY'),
      icon: Icons.badge_outlined,
      children: [
        ImpactChip(
          label: l.identity(s.identityStatus),
          icon: s.identityConfirmed ? Icons.verified_outlined : Icons.help_outline,
          attention: !s.identityConfirmed,
        ),
        const SizedBox(height: 8),
        if (s.legalName != null) ImpactQuote(text: s.legalName, attribution: null, caption: t.impactDeclaredQuote),
        for (final r in s.registrations) ImpactLine(r, icon: Icons.numbers),
        for (final dm in s.domains) ImpactLine(dm, icon: Icons.language),
        const SizedBox(height: 8),
        Semantics(header: true, child: Text(l.section('REGISTRY'), style: Theme.of(context).textTheme.titleSmall)),
        const SizedBox(height: 4),
        if (d.registryFacts.isEmpty) ImpactLine(t.impactNoRegistry, icon: Icons.info_outline),
        for (final f in d.registryFacts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (f.legalName != null) ImpactQuote(text: f.legalName, attribution: null, caption: t.impactRegistryQuote),
              ImpactLine([
                f.sourceRef,
                if (f.registryStatus != null) f.registryStatus!,
                if (f.statusAsOf != null) f.statusAsOf!,
                if (f.official) l.misc('OFFICIAL'),
                if (f.synthetic) l.misc('SYNTHETIC'),
              ].join(' · ')),
              ImpactLine(l.misc(f.freshAtAsOf ? 'FRESH_AT_AS_OF' : 'NOT_FRESH_AT_AS_OF'), muted: true),
            ]),
          ),
        for (final c in d.registryConflicts) ImpactLine('${l.limitation('REGISTRY_CONFLICT')} ${c.kind}: ${c.sourceRef} ↔ ${c.otherSourceRef}', icon: Icons.compare_arrows),
      ],
    );
  }
}

class _ClaimsSection extends StatefulWidget {
  const _ClaimsSection({required this.d});

  final DossierView d;

  @override
  State<_ClaimsSection> createState() => _ClaimsSectionState();
}

class _ClaimsSectionState extends State<_ClaimsSection> {
  /// Large dossiers are shown in pages; nothing is dropped or truncated —
  /// every claim is one "show more" away, and the summary counts them all.
  static const pageSize = 20;
  int _shown = pageSize;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final d = widget.d;
    final visible = d.claims.take(_shown).toList();
    final remaining = d.claims.length - visible.length;
    return ImpactSection(
      title: d.labels.section('CLAIMS'),
      icon: Icons.format_quote_outlined,
      children: [
        if (d.claims.isEmpty) ImpactLine(t.impactNoClaims),
        for (final c in visible) ImpactClaimTile(dossier: d, claim: c),
        if (remaining > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _shown += pageSize),
              child: Text(t.impactShowMore(remaining)),
            ),
          ),
        const SizedBox(height: 4),
        ImpactLine(d.labels.section('QUOTE_NOTE'), muted: true),
      ],
    );
  }
}

class ImpactClaimTile extends StatelessWidget {
  const ImpactClaimTile({super.key, required this.dossier, required this.claim});

  final DossierView dossier;
  final ClaimView claim;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final l = dossier.labels;
    final v = claim.verification;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // The whole tile is one button whose label starts with what it opens.
      child: Semantics(
        button: true,
        label: '${t.impactClaimDetail} ${claim.ref}',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ImpactClaimScreen(dossier: dossier, claim: claim),
          )),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImpactQuote(
                  text: claim.text,
                  attribution: claim.textAttribution,
                  redacted: claim.textRedacted,
                  withheld: claim.textWithheld != null,
                ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (v == null)
                    ImpactChip(label: t.impactNotVerifiedYet, icon: Icons.hourglass_empty)
                  else ...[
                    ImpactChip(label: l.status(v.status), icon: impactStatusIcon(v.status)),
                    ImpactChip(label: l.displayClass(v.displayClass), icon: Icons.label_outline),
                  ],
                  if (claim.reverificationPending) ImpactChip(label: t.impactReverifyPending, icon: Icons.update, attention: true),
                  if (claim.disputeRefs.isNotEmpty) ImpactChip(label: t.impactDisputes, icon: Icons.forum_outlined, attention: true),
                ]),
                const Align(
                  alignment: Alignment.centerRight,
                  child: ExcludeSemantics(child: Icon(Icons.chevron_right)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisputesSection extends StatelessWidget {
  const _DisputesSection({required this.d});

  final DossierView d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ImpactSection(
      title: d.labels.section('DISPUTES'),
      icon: Icons.forum_outlined,
      children: [
        if (d.disputes.isEmpty) ImpactLine(t.impactNoDisputes),
        for (final x in d.disputes)
          ImpactLine(
            [x.ref, x.claimRef ?? '—', x.kind ?? '—', x.open ? t.impactOpenDisputes : (x.resolution ?? '—'), x.openedAt ?? ''].join(' · '),
            icon: x.open ? Icons.forum_outlined : Icons.check,
          ),
      ],
    );
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({required this.d});

  final DossierView d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ImpactSection(
      title: t.impactSources,
      icon: Icons.account_tree_outlined,
      children: [
        ImpactLine(t.impactProvenanceChain, muted: true),
        for (final s in d.sources) ImpactSourceTile(source: s),
      ],
    );
  }
}

class ImpactSourceTile extends StatelessWidget {
  const ImpactSourceTile({super.key, required this.source});

  final SourceView source;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final s = source;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImpactLine('${s.ref} · ${s.type ?? '—'} · ${s.status ?? '—'}', icon: Icons.description_outlined),
          ImpactLine('${t.impactPublisher}: «${s.publisher ?? '—'}»'),
          if (s.hostProvider != null) ImpactLine(t.impactHostedOn(s.hostProvider!), icon: Icons.cloud_outlined, muted: true),
          if (s.userSubmitted) ImpactLine(t.impactUserSubmitted, icon: Icons.upload_file_outlined, muted: true),
        ],
      ),
    );
  }
}

class _IntegritySection extends StatelessWidget {
  const _IntegritySection({required this.d});

  final DossierView d;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final mono = Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return ImpactSection(
      title: d.labels.section('INTEGRITY'),
      icon: Icons.fingerprint,
      children: [
        ImpactLine(t.impactHashNotTruth, icon: Icons.info_outline),
        Text('${t.impactContentHash} (${d.integrity.algorithm}, ${d.integrity.canonicalization})', style: Theme.of(context).textTheme.labelMedium),
        SelectableText(d.integrity.contentHash, style: mono),
        const SizedBox(height: 8),
        ImpactLine(d.envelope.isSnapshot ? d.labels.section('SNAPSHOT') : d.labels.section('LIVE'), muted: true),
        if (d.envelope.snapshotRef != null) ImpactLine('${t.impactSnapshotRef}: ${d.envelope.snapshotRef}', muted: true),
      ],
    );
  }
}
