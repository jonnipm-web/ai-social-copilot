import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/utils/ai_enum_labels.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';

// R16 — AI fixed-value codes (persisted as-is) must be DISPLAYED in the
// presentation language: no Portuguese code may leak into an English UI and
// vice versa. Unknown values fall back to the raw value, never crash.
void main() {
  final pt = lookupAppLocalizations(const Locale('pt'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('normalizeAiEnum', () {
    test('is case-, accent- and whitespace-insensitive', () {
      expect(normalizeAiEnum('  MÉDIO '), 'medio');
      expect(normalizeAiEnum('Não'), 'nao');
      expect(normalizeAiEnum('Landing Page'), 'landing_page');
      expect(normalizeAiEnum('landing-page'), 'landing_page');
      expect(normalizeAiEnum(null), '');
    });
  });

  group('aiInvestmentRecommendationLabel', () {
    const cases = {
      'SIM': ('SIM', 'YES'),
      'CONDICIONAL': ('CONDICIONAL', 'CONDITIONAL'),
      'NÃO': ('NÃO', 'NO'),
      'nao': ('NÃO', 'NO'),
      'Yes': ('SIM', 'YES'),
    };
    cases.forEach((code, expected) {
      test('$code → PT/EN', () {
        expect(aiInvestmentRecommendationLabel(code, pt), expected.$1);
        expect(aiInvestmentRecommendationLabel(code, en), expected.$2);
      });
    });
    test('verdict classification drives colour/icon, not raw text', () {
      expect(aiInvestmentVerdict('SIM'), AiInvestmentVerdict.yes);
      expect(aiInvestmentVerdict('NÃO'), AiInvestmentVerdict.no);
      expect(aiInvestmentVerdict('CONDICIONAL'), AiInvestmentVerdict.conditional);
      expect(aiInvestmentVerdict('talvez'), AiInvestmentVerdict.unknown);
    });
    test('unknown → raw value', () {
      expect(aiInvestmentRecommendationLabel('TALVEZ', en), 'TALVEZ');
    });
  });

  group('aiLevelLabel (impact/effort/potential/risk)', () {
    const cases = {
      'Alto': ('Alto', 'High'),
      'alta': ('Alto', 'High'),
      'Médio': ('Médio', 'Medium'),
      'medio': ('Médio', 'Medium'),
      'média': ('Médio', 'Medium'),
      'Baixo': ('Baixo', 'Low'),
      'baixa': ('Baixo', 'Low'),
      'crítico': ('Crítico', 'Critical'),
      'CRITICO': ('Crítico', 'Critical'),
      'high': ('Alto', 'High'),
      'low': ('Baixo', 'Low'),
    };
    cases.forEach((code, expected) {
      test('$code → PT/EN', () {
        expect(aiLevelLabel(code, pt), expected.$1);
        expect(aiLevelLabel(code, en), expected.$2);
      });
    });
    test('decision-simulator risk_level uses the same scale', () {
      for (final c in ['baixo', 'médio', 'alto', 'crítico']) {
        expect(aiRiskLevelLabel(c, en), aiLevelLabel(c, en));
      }
      expect(aiRiskLevelLabel('crítico', en), 'Critical');
    });
    test('unknown → raw value', () {
      expect(aiLevelLabel('Enorme', en), 'Enorme');
      expect(aiLevelLabel('', en), '');
    });
  });

  group('aiPriorityLabel (generate-strategy)', () {
    const cases = {
      'alta': ('Alta', 'High'),
      'média': ('Média', 'Medium'),
      'media': ('Média', 'Medium'),
      'baixa': ('Baixa', 'Low'),
    };
    cases.forEach((code, expected) {
      test('$code → PT/EN', () {
        expect(aiPriorityLabel(code, pt), expected.$1);
        expect(aiPriorityLabel(code, en), expected.$2);
      });
    });
    test('unknown → raw value', () {
      expect(aiPriorityLabel('urgentíssima', en), 'urgentíssima');
    });
  });

  group('aiSearchIntentLabel (content-cluster)', () {
    const cases = {
      'informacional': ('Informacional', 'Informational'),
      'navegacional': ('Navegacional', 'Navigational'),
      'transacional': ('Transacional', 'Transactional'),
      'comercial': ('Comercial', 'Commercial'),
      'Informational': ('Informacional', 'Informational'),
    };
    cases.forEach((code, expected) {
      test('$code → PT/EN', () {
        expect(aiSearchIntentLabel(code, pt), expected.$1);
        expect(aiSearchIntentLabel(code, en), expected.$2);
      });
    });
    test('unknown → raw value', () {
      expect(aiSearchIntentLabel('local', en), 'local');
    });
  });

  group('aiArticleTypeLabel (content-cluster)', () {
    const cases = {
      'pillar': ('Página pilar', 'Pillar page'),
      'supporting': ('Conteúdo de apoio', 'Supporting content'),
      'landing_page': ('Landing page', 'Landing page'),
      'comparison': ('Comparativo', 'Comparison'),
    };
    cases.forEach((code, expected) {
      test('$code → PT/EN', () {
        expect(aiArticleTypeLabel(code, pt), expected.$1);
        expect(aiArticleTypeLabel(code, en), expected.$2);
      });
    });
    test('unknown → raw value', () {
      expect(aiArticleTypeLabel('faq', en), 'faq');
    });
  });

  group('aiOpportunityTypeLabel (opportunity-discovery)', () {
    const cases = {
      'content': ('Conteúdo', 'Content'),
      'seo': ('SEO', 'SEO'),
      'product': ('Produto', 'Product'),
      'monetization': ('Monetização', 'Monetization'),
      'partnership': ('Parceria', 'Partnership'),
      'platform': ('Plataforma', 'Platform'),
      'audience': ('Audiência', 'Audience'),
    };
    cases.forEach((code, expected) {
      test('$code → PT/EN', () {
        expect(aiOpportunityTypeLabel(code, pt), expected.$1);
        expect(aiOpportunityTypeLabel(code, en), expected.$2);
      });
    });
    test('unknown → raw value', () {
      expect(aiOpportunityTypeLabel('other', en), 'other');
    });
  });

  group('aiTimeframeLabel (opportunity-discovery)', () {
    test('keeps the range, localizes the unit', () {
      expect(aiTimeframeLabel('3-6 meses', en), '3-6 months');
      expect(aiTimeframeLabel('3-6 meses', pt), '3-6 meses');
      expect(aiTimeframeLabel('3 a 6 meses', en), '3-6 months');
      expect(aiTimeframeLabel('2 semanas', en), '2 weeks');
      expect(aiTimeframeLabel('30 dias', en), '30 days');
      expect(aiTimeframeLabel('3-6 months', pt), '3-6 meses');
    });
    test('singular units', () {
      expect(aiTimeframeLabel('1 mês', en), '1 month');
      expect(aiTimeframeLabel('1 month', pt), '1 mês');
      expect(aiTimeframeLabel('1 semana', en), '1 week');
      expect(aiTimeframeLabel('1 dia', en), '1 day');
    });
    test('unrecognised shape → raw value', () {
      expect(aiTimeframeLabel('curto prazo', en), 'curto prazo');
      expect(aiTimeframeLabel(null, en), '');
    });
  });

  group('campaignObjectiveLabel', () {
    test('every canonical objective has a PT and EN label', () {
      for (final code in kCampaignObjectives) {
        final ptLabel = campaignObjectiveLabel(code, pt);
        final enLabel = campaignObjectiveLabel(code, en);
        expect(ptLabel, isNotEmpty, reason: code);
        expect(enLabel, isNotEmpty, reason: code);
        // PT label equals the canonical PT value (display parity).
        expect(ptLabel, code, reason: code);
      }
    });
    test('EN labels contain no Portuguese words', () {
      final en0 = kCampaignObjectives.map((c) => campaignObjectiveLabel(c, en)).toList();
      expect(en0, [
        'Sales', 'Authority', 'Leads', 'Engagement', 'Launch', 'Traffic',
        'Hotmart sales', 'Shopify sales', 'Amazon sales', 'Subscription',
      ]);
    });
    test('stored canonical values are unchanged', () {
      expect(kCampaignObjectives, [
        'Venda', 'Autoridade', 'Leads', 'Engajamento',
        'Lançamento', 'Tráfego', 'Venda Hotmart',
        'Venda Shopify', 'Venda Amazon', 'Assinatura',
      ]);
    });
    test('unknown → raw value', () {
      expect(campaignObjectiveLabel('Outro', en), 'Outro');
    });
  });
}
