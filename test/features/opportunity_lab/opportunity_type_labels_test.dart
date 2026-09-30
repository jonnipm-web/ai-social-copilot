import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/features/opportunity_lab/opportunity_type_labels.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';

// COMMERCIAL-EXPERIENCE-CLOSURE-16R (mission Section 15/20) — proves every
// canonical OpportunityLabItem.types value maps to the EXACT expected
// PT-BR and EN display label. An earlier version of this test used a
// heuristic ("label != canonical value" => real mapping happened) instead
// of an explicit expected-value table; that heuristic produced a false
// positive for 'SaaS', whose CORRECT translation in both languages is
// deliberately the same string ("SaaS") -- indistinguishable, under that
// heuristic, from silently falling through to the raw-value fallback.
// Explicit expected values side-step that ambiguity entirely.
void main() {
  const expectedPt = {
    'expansão':     'Expansão',
    'novo produto': 'Novo Produto',
    'novo nicho':   'Novo Nicho',
    'afiliado':     'Afiliado',
    'SaaS':         'SaaS',
    'ebook':        'Ebook',
    'curso':        'Curso',
    'assinatura':   'Assinatura',
  };

  const expectedEn = {
    'expansão':     'Expansion',
    'novo produto': 'New Product',
    'novo nicho':   'New Niche',
    'afiliado':     'Affiliate',
    'SaaS':         'SaaS',
    'ebook':        'Ebook',
    'curso':        'Course',
    'assinatura':   'Subscription',
  };

  test('OpportunityLabItem.types is exactly the set this test covers (catches a future untranslated addition)', () {
    expect(OpportunityLabItem.types.toSet(), expectedPt.keys.toSet());
    expect(OpportunityLabItem.types.toSet(), expectedEn.keys.toSet());
  });

  test('every canonical type maps to the exact expected PT-BR label', () async {
    final pt = await AppLocalizations.delegate.load(const Locale('pt'));
    for (final canonical in OpportunityLabItem.types) {
      expect(opportunityTypeLabel(canonical, pt), expectedPt[canonical],
          reason: 'unexpected PT label for "$canonical"');
    }
  });

  test('every canonical type maps to the exact expected EN label (never the PT word)', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    for (final canonical in OpportunityLabItem.types) {
      expect(opportunityTypeLabel(canonical, en), expectedEn[canonical],
          reason: 'unexpected EN label for "$canonical" -- if this shows a PT-BR word, '
              'the untranslated string is leaking into the English UI');
    }
  });

  test('unmapped/legacy value falls back to itself rather than throwing', () async {
    final pt = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(opportunityTypeLabel('valor-legado-desconhecido', pt), 'valor-legado-desconhecido');
  });

  const expectedStatusPt = {
    'pending':   'Pendente',
    'analyzing': 'Analisando',
    'approved':  'Aprovada',
    'rejected':  'Rejeitada',
    'executing': 'Em execução',
  };

  const expectedStatusEn = {
    'pending':   'Pending',
    'analyzing': 'Analyzing',
    'approved':  'Approved',
    'rejected':  'Rejected',
    'executing': 'Executing',
  };

  test('OpportunityLabItem.statusValues is exactly the set this test covers (catches a future untranslated addition)', () {
    expect(OpportunityLabItem.statusValues.toSet(), expectedStatusPt.keys.toSet());
    expect(OpportunityLabItem.statusValues.toSet(), expectedStatusEn.keys.toSet());
  });

  test('every canonical status maps to the exact expected PT-BR label', () async {
    final pt = await AppLocalizations.delegate.load(const Locale('pt'));
    for (final canonical in OpportunityLabItem.statusValues) {
      expect(opportunityStatusLabel(canonical, pt), expectedStatusPt[canonical],
          reason: 'unexpected PT label for status "$canonical"');
    }
  });

  test('every canonical status maps to the exact expected EN label (never the raw enum value)', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    for (final canonical in OpportunityLabItem.statusValues) {
      expect(opportunityStatusLabel(canonical, en), expectedStatusEn[canonical],
          reason: 'unexpected EN label for status "$canonical" -- if this shows the raw '
              'value, the untranslated status is leaking into the UI');
    }
  });

  test('unmapped/legacy status falls back to itself rather than throwing', () async {
    final pt = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(opportunityStatusLabel('status-legado-desconhecido', pt), 'status-legado-desconhecido');
  });
}
