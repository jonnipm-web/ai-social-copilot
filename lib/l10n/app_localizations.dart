import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('pt'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In pt, this message translates to:
  /// **'InsightValues'**
  String get appName;

  /// No description provided for @commonCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get commonClose;

  /// No description provided for @commonSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get commonSave;

  /// No description provided for @commonBack.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get commonBack;

  /// No description provided for @commonOr.
  ///
  /// In pt, this message translates to:
  /// **'ou'**
  String get commonOr;

  /// No description provided for @commonLoading.
  ///
  /// In pt, this message translates to:
  /// **'Carregando...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In pt, this message translates to:
  /// **'Algo deu errado. Tente novamente.'**
  String get commonError;

  /// No description provided for @commonRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get commonRetry;

  /// No description provided for @commonComingSoon.
  ///
  /// In pt, this message translates to:
  /// **'Em breve'**
  String get commonComingSoon;

  /// No description provided for @authWelcomeBack.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo de volta'**
  String get authWelcomeBack;

  /// No description provided for @authCreateAccount.
  ///
  /// In pt, this message translates to:
  /// **'Crie sua conta'**
  String get authCreateAccount;

  /// No description provided for @authEmail.
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In pt, this message translates to:
  /// **'Senha'**
  String get authPassword;

  /// No description provided for @authEmailRequired.
  ///
  /// In pt, this message translates to:
  /// **'Informe seu e-mail'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In pt, this message translates to:
  /// **'E-mail inválido'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordRequired.
  ///
  /// In pt, this message translates to:
  /// **'Informe sua senha'**
  String get authPasswordRequired;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In pt, this message translates to:
  /// **'Mínimo de 6 caracteres'**
  String get authPasswordMinLength;

  /// No description provided for @authSignIn.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In pt, this message translates to:
  /// **'Criar conta'**
  String get authSignUp;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In pt, this message translates to:
  /// **'Continuar com Google'**
  String get authContinueWithGoogle;

  /// No description provided for @checkoutOpening.
  ///
  /// In pt, this message translates to:
  /// **'Abrindo checkout...'**
  String get checkoutOpening;

  /// No description provided for @authNoAccount.
  ///
  /// In pt, this message translates to:
  /// **'Não tem conta? Cadastre-se'**
  String get authNoAccount;

  /// No description provided for @authHasAccount.
  ///
  /// In pt, this message translates to:
  /// **'Já tem conta? Faça login'**
  String get authHasAccount;

  /// No description provided for @authSignOut.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get authSignOut;

  /// No description provided for @navCommandCenter.
  ///
  /// In pt, this message translates to:
  /// **'OS Command Center'**
  String get navCommandCenter;

  /// No description provided for @navBusinessDashboard.
  ///
  /// In pt, this message translates to:
  /// **'Business Dashboard'**
  String get navBusinessDashboard;

  /// No description provided for @navKnowledgeVault.
  ///
  /// In pt, this message translates to:
  /// **'Cofre de Conhecimento'**
  String get navKnowledgeVault;

  /// No description provided for @navWebsiteAnalyzer.
  ///
  /// In pt, this message translates to:
  /// **'Website Analyzer'**
  String get navWebsiteAnalyzer;

  /// No description provided for @navMarketIntelligence.
  ///
  /// In pt, this message translates to:
  /// **'Market Intelligence'**
  String get navMarketIntelligence;

  /// No description provided for @navProjects.
  ///
  /// In pt, this message translates to:
  /// **'Projetos'**
  String get navProjects;

  /// No description provided for @navOpportunityLab.
  ///
  /// In pt, this message translates to:
  /// **'Opportunity Lab'**
  String get navOpportunityLab;

  /// No description provided for @navActionEngine.
  ///
  /// In pt, this message translates to:
  /// **'Action Engine'**
  String get navActionEngine;

  /// No description provided for @navUpgrade.
  ///
  /// In pt, this message translates to:
  /// **'Plano / Upgrade'**
  String get navUpgrade;

  /// No description provided for @navAccount.
  ///
  /// In pt, this message translates to:
  /// **'Conta e Configurações'**
  String get navAccount;

  /// No description provided for @navAdminPanel.
  ///
  /// In pt, this message translates to:
  /// **'Painel Admin'**
  String get navAdminPanel;

  /// No description provided for @navAdminModules.
  ///
  /// In pt, this message translates to:
  /// **'Módulos (Admin)'**
  String get navAdminModules;

  /// No description provided for @navHelpSupport.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda e Suporte'**
  String get navHelpSupport;

  /// No description provided for @navAbout.
  ///
  /// In pt, this message translates to:
  /// **'Sobre'**
  String get navAbout;

  /// No description provided for @accountTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conta e Configurações'**
  String get accountTitle;

  /// No description provided for @accountProfile.
  ///
  /// In pt, this message translates to:
  /// **'Perfil'**
  String get accountProfile;

  /// No description provided for @accountLanguage.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get accountLanguage;

  /// No description provided for @accountLanguagePortuguese.
  ///
  /// In pt, this message translates to:
  /// **'Português'**
  String get accountLanguagePortuguese;

  /// No description provided for @accountLanguageEnglish.
  ///
  /// In pt, this message translates to:
  /// **'English'**
  String get accountLanguageEnglish;

  /// No description provided for @accountCurrentPlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano atual'**
  String get accountCurrentPlan;

  /// No description provided for @accountUsage.
  ///
  /// In pt, this message translates to:
  /// **'Uso / Cota'**
  String get accountUsage;

  /// No description provided for @accountUpgradeManage.
  ///
  /// In pt, this message translates to:
  /// **'Fazer upgrade / gerenciar assinatura'**
  String get accountUpgradeManage;

  /// No description provided for @accountGoogleLinked.
  ///
  /// In pt, this message translates to:
  /// **'Conectado com Google'**
  String get accountGoogleLinked;

  /// No description provided for @accountHelpSupport.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda e Suporte'**
  String get accountHelpSupport;

  /// No description provided for @accountAbout.
  ///
  /// In pt, this message translates to:
  /// **'Sobre o InsightValues'**
  String get accountAbout;

  /// No description provided for @accountPrivacy.
  ///
  /// In pt, this message translates to:
  /// **'Política de Privacidade'**
  String get accountPrivacy;

  /// No description provided for @accountTerms.
  ///
  /// In pt, this message translates to:
  /// **'Termos de Uso'**
  String get accountTerms;

  /// No description provided for @accountSignOut.
  ///
  /// In pt, this message translates to:
  /// **'Sair da conta'**
  String get accountSignOut;

  /// No description provided for @aboutTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sobre o InsightValues'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In pt, this message translates to:
  /// **'Copiloto de IA para estratégia de marketing e conteúdo.'**
  String get aboutTagline;

  /// No description provided for @aboutVersion.
  ///
  /// In pt, this message translates to:
  /// **'Versão do aplicativo'**
  String get aboutVersion;

  /// No description provided for @aboutCopyright.
  ///
  /// In pt, this message translates to:
  /// **'© {year} InsightValues. Todos os direitos reservados.'**
  String aboutCopyright(int year);

  /// No description provided for @aboutWebsite.
  ///
  /// In pt, this message translates to:
  /// **'Site oficial'**
  String get aboutWebsite;

  /// No description provided for @aboutSupportContact.
  ///
  /// In pt, this message translates to:
  /// **'Suporte'**
  String get aboutSupportContact;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In pt, this message translates to:
  /// **'Política de Privacidade'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutTermsOfUse.
  ///
  /// In pt, this message translates to:
  /// **'Termos de Uso'**
  String get aboutTermsOfUse;

  /// No description provided for @aboutPlanInfo.
  ///
  /// In pt, this message translates to:
  /// **'Plano e assinatura'**
  String get aboutPlanInfo;

  /// No description provided for @aboutOwnerConfigRequired.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não configurado pelo administrador do produto.'**
  String get aboutOwnerConfigRequired;

  /// No description provided for @supportTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda e Suporte'**
  String get supportTitle;

  /// No description provided for @supportContact.
  ///
  /// In pt, this message translates to:
  /// **'Contato'**
  String get supportContact;

  /// No description provided for @supportReportProblem.
  ///
  /// In pt, this message translates to:
  /// **'Relatar um problema'**
  String get supportReportProblem;

  /// No description provided for @supportSendFeedback.
  ///
  /// In pt, this message translates to:
  /// **'Enviar feedback'**
  String get supportSendFeedback;

  /// No description provided for @supportContactEmail.
  ///
  /// In pt, this message translates to:
  /// **'Fale conosco por e-mail: {email}'**
  String supportContactEmail(String email);

  /// No description provided for @supportOwnerConfigRequired.
  ///
  /// In pt, this message translates to:
  /// **'Canal de suporte ainda não configurado pelo administrador do produto.'**
  String get supportOwnerConfigRequired;

  /// No description provided for @planFree.
  ///
  /// In pt, this message translates to:
  /// **'Gratuito'**
  String get planFree;

  /// No description provided for @planFreePrice.
  ///
  /// In pt, this message translates to:
  /// **'R\$ 0'**
  String get planFreePrice;

  /// No description provided for @planFreeAnalyses.
  ///
  /// In pt, this message translates to:
  /// **'{count} análises de IA por mês'**
  String planFreeAnalyses(int count);

  /// No description provided for @planPro.
  ///
  /// In pt, this message translates to:
  /// **'Pro Founder'**
  String get planPro;

  /// No description provided for @planProPrice.
  ///
  /// In pt, this message translates to:
  /// **'R\$ 29/mês'**
  String get planProPrice;

  /// No description provided for @planProPriceAmount.
  ///
  /// In pt, this message translates to:
  /// **'R\$ 29'**
  String get planProPriceAmount;

  /// No description provided for @planProPricePeriod.
  ///
  /// In pt, this message translates to:
  /// **'/mês'**
  String get planProPricePeriod;

  /// No description provided for @planProAnalyses.
  ///
  /// In pt, this message translates to:
  /// **'{count} análises de IA por mês'**
  String planProAnalyses(int count);

  /// No description provided for @planFounderNote.
  ///
  /// In pt, this message translates to:
  /// **'Preço de lançamento (fundador) -- não é um valor permanente.'**
  String get planFounderNote;

  /// No description provided for @planCurrentPlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano atual'**
  String get planCurrentPlan;

  /// No description provided for @planUpgradeCta.
  ///
  /// In pt, this message translates to:
  /// **'Assinar Pro'**
  String get planUpgradeCta;

  /// No description provided for @billingTestMode.
  ///
  /// In pt, this message translates to:
  /// **'Modo de teste (nenhuma cobrança real)'**
  String get billingTestMode;

  /// No description provided for @billingWaitingSecrets.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando configuração final do provedor de pagamento'**
  String get billingWaitingSecrets;

  /// No description provided for @checkoutOpeningError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível abrir a página de pagamento.'**
  String get checkoutOpeningError;

  /// No description provided for @upgradePlansTitle.
  ///
  /// In pt, this message translates to:
  /// **'Planos'**
  String get upgradePlansTitle;

  /// No description provided for @upgradeLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar seu plano agora. Tente novamente em instantes.'**
  String get upgradeLoadError;

  /// No description provided for @upgradeUsageThisMonth.
  ///
  /// In pt, this message translates to:
  /// **'Análises de IA este mês'**
  String get upgradeUsageThisMonth;

  /// No description provided for @upgradeUsedAllAnalyses.
  ///
  /// In pt, this message translates to:
  /// **'Você usou todas as análises de IA deste mês.'**
  String get upgradeUsedAllAnalyses;

  /// No description provided for @upgradeAnalysesRemaining.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 análise restante} other{{count} análises restantes}} no plano {plan}.'**
  String upgradeAnalysesRemaining(int count, String plan);

  /// No description provided for @upgradeFreeSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Plano atual'**
  String get upgradeFreeSubtitle;

  /// No description provided for @upgradeProSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Para quem já está executando a estratégia'**
  String get upgradeProSubtitle;

  /// No description provided for @upgradeFeatureWebsiteAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Análise de site, mercado e concorrência'**
  String get upgradeFeatureWebsiteAnalysis;

  /// No description provided for @upgradeFeatureStrategyActions.
  ///
  /// In pt, this message translates to:
  /// **'Estratégia e ações priorizadas'**
  String get upgradeFeatureStrategyActions;

  /// No description provided for @upgradeFeatureUnlimited.
  ///
  /// In pt, this message translates to:
  /// **'Análises ilimitadas'**
  String get upgradeFeatureUnlimited;

  /// No description provided for @upgradeFeaturePriority.
  ///
  /// In pt, this message translates to:
  /// **'Prioridade no processamento'**
  String get upgradeFeaturePriority;

  /// No description provided for @upgradeFeatureSupport.
  ///
  /// In pt, this message translates to:
  /// **'Suporte prioritário'**
  String get upgradeFeatureSupport;

  /// No description provided for @upgradeFeatureSupportEmail.
  ///
  /// In pt, this message translates to:
  /// **'Suporte prioritário por e-mail'**
  String get upgradeFeatureSupportEmail;

  /// No description provided for @upgradeFeatureEarlyAccess.
  ///
  /// In pt, this message translates to:
  /// **'Acesso a novos recursos primeiro'**
  String get upgradeFeatureEarlyAccess;

  /// No description provided for @upgradePreviousPlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano anterior'**
  String get upgradePreviousPlan;

  /// No description provided for @upgradeCurrentPlanBadge.
  ///
  /// In pt, this message translates to:
  /// **'Seu plano'**
  String get upgradeCurrentPlanBadge;

  /// No description provided for @upgradeMostPopular.
  ///
  /// In pt, this message translates to:
  /// **'Mais popular'**
  String get upgradeMostPopular;

  /// No description provided for @upgradeSubscribeCta.
  ///
  /// In pt, this message translates to:
  /// **'🚀  Assinar Pro — R\$ 29/mês'**
  String get upgradeSubscribeCta;

  /// No description provided for @adminModulesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Inventário de Módulos'**
  String get adminModulesTitle;

  /// No description provided for @adminModulesStatus.
  ///
  /// In pt, this message translates to:
  /// **'Status'**
  String get adminModulesStatus;

  /// No description provided for @adminModulesCommercial.
  ///
  /// In pt, this message translates to:
  /// **'Comercial'**
  String get adminModulesCommercial;

  /// No description provided for @adminModulesPlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano mínimo'**
  String get adminModulesPlan;

  /// No description provided for @adminModulesRoute.
  ///
  /// In pt, this message translates to:
  /// **'Rota'**
  String get adminModulesRoute;

  /// No description provided for @adminModulesAi.
  ///
  /// In pt, this message translates to:
  /// **'Usa IA'**
  String get adminModulesAi;

  /// No description provided for @adminModulesReadiness.
  ///
  /// In pt, this message translates to:
  /// **'Prontidão'**
  String get adminModulesReadiness;

  /// No description provided for @adminModulesNotes.
  ///
  /// In pt, this message translates to:
  /// **'Notas'**
  String get adminModulesNotes;

  /// No description provided for @adminModulesOpen.
  ///
  /// In pt, this message translates to:
  /// **'Abrir módulo'**
  String get adminModulesOpen;

  /// No description provided for @adminModulesNoRoute.
  ///
  /// In pt, this message translates to:
  /// **'Sem rota própria'**
  String get adminModulesNoRoute;

  /// No description provided for @adminModulesYes.
  ///
  /// In pt, this message translates to:
  /// **'Sim'**
  String get adminModulesYes;

  /// No description provided for @adminModulesNo.
  ///
  /// In pt, this message translates to:
  /// **'Não'**
  String get adminModulesNo;

  /// No description provided for @projectBriefingSectionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Briefing Executivo'**
  String get projectBriefingSectionTitle;

  /// No description provided for @projectBriefingNoKnowledge.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum conhecimento cadastrado ainda'**
  String get projectBriefingNoKnowledge;

  /// No description provided for @projectBriefingKnowledgeCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Nenhum item de conhecimento} =1{1 item de conhecimento disponível} other{{count} itens de conhecimento disponíveis}}'**
  String projectBriefingKnowledgeCount(int count);

  /// No description provided for @projectBriefingRecentChanges.
  ///
  /// In pt, this message translates to:
  /// **'O que mudou recentemente'**
  String get projectBriefingRecentChanges;

  /// No description provided for @projectAnalyzeIdea.
  ///
  /// In pt, this message translates to:
  /// **'Analisar Ideia'**
  String get projectAnalyzeIdea;

  /// No description provided for @projectOpenConfig.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get projectOpenConfig;

  /// No description provided for @projectConfigTitle.
  ///
  /// In pt, this message translates to:
  /// **'Configurações do Projeto'**
  String get projectConfigTitle;

  /// No description provided for @projectConfigNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get projectConfigNameLabel;

  /// No description provided for @projectConfigDescriptionLabel.
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get projectConfigDescriptionLabel;

  /// No description provided for @projectConfigUrlLabel.
  ///
  /// In pt, this message translates to:
  /// **'URL'**
  String get projectConfigUrlLabel;

  /// No description provided for @projectConfigTypeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get projectConfigTypeLabel;

  /// No description provided for @projectConfigStatusLabel.
  ///
  /// In pt, this message translates to:
  /// **'Status'**
  String get projectConfigStatusLabel;

  /// No description provided for @projectConfigEdit.
  ///
  /// In pt, this message translates to:
  /// **'Editar'**
  String get projectConfigEdit;

  /// No description provided for @projectConfigNameRequired.
  ///
  /// In pt, this message translates to:
  /// **'O nome do projeto não pode ficar vazio.'**
  String get projectConfigNameRequired;

  /// No description provided for @projectConfigSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Falha ao salvar: {error}'**
  String projectConfigSaveError(String error);

  /// No description provided for @ideaAnalysisProjectBannerText.
  ///
  /// In pt, this message translates to:
  /// **'Esta análise será vinculada ao projeto selecionado'**
  String get ideaAnalysisProjectBannerText;

  /// No description provided for @ivIntroTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conheça a IVE'**
  String get ivIntroTitle;

  /// No description provided for @ivIntroWhoBody.
  ///
  /// In pt, this message translates to:
  /// **'Eu sou a IVE, sua copiloto estratégica dentro do InsightValues.'**
  String get ivIntroWhoBody;

  /// No description provided for @ivIntroWhatBody.
  ///
  /// In pt, this message translates to:
  /// **'Posso explicar seus resultados, apontar riscos e oportunidades, e sugerir o que fazer a seguir — sempre com base nos dados reais do seu projeto.'**
  String get ivIntroWhatBody;

  /// No description provided for @ivIntroWhereBody.
  ///
  /// In pt, this message translates to:
  /// **'Você me encontra de dois jeitos: o ícone flutuante aparece em qualquer tela, e alguns módulos têm um botão direto para me perguntar sobre o que você está vendo ali.'**
  String get ivIntroWhereBody;

  /// No description provided for @ivIntroControlBody.
  ///
  /// In pt, this message translates to:
  /// **'Eu só respondo quando você pede — você decide quando e sobre o que perguntar.'**
  String get ivIntroControlBody;

  /// No description provided for @ivIntroContinueButton.
  ///
  /// In pt, this message translates to:
  /// **'Entendi'**
  String get ivIntroContinueButton;

  /// No description provided for @ivIntroSkipButton.
  ///
  /// In pt, this message translates to:
  /// **'Pular'**
  String get ivIntroSkipButton;

  /// No description provided for @ivIntroSemanticLabel.
  ///
  /// In pt, this message translates to:
  /// **'Introdução à IVE, sua copiloto estratégica'**
  String get ivIntroSemanticLabel;

  /// No description provided for @ivIntroReplayLabel.
  ///
  /// In pt, this message translates to:
  /// **'Conhecer a IVE'**
  String get ivIntroReplayLabel;

  /// No description provided for @iveSemanticsLabel.
  ///
  /// In pt, this message translates to:
  /// **'IVE, assistente executiva'**
  String get iveSemanticsLabel;

  /// No description provided for @iveBubbleChatCta.
  ///
  /// In pt, this message translates to:
  /// **'Conversar com a IVE'**
  String get iveBubbleChatCta;

  /// No description provided for @iveChatAskCta.
  ///
  /// In pt, this message translates to:
  /// **'Pergunte à IVE'**
  String get iveChatAskCta;

  /// No description provided for @iveChatHint.
  ///
  /// In pt, this message translates to:
  /// **'Pergunte à IVE…'**
  String get iveChatHint;

  /// No description provided for @iveChatClearHistory.
  ///
  /// In pt, this message translates to:
  /// **'Limpar histórico'**
  String get iveChatClearHistory;

  /// No description provided for @iveChatErrorPrefix.
  ///
  /// In pt, this message translates to:
  /// **'Erro: {error}'**
  String iveChatErrorPrefix(String error);

  /// No description provided for @iveScreenActions.
  ///
  /// In pt, this message translates to:
  /// **'Ações'**
  String get iveScreenActions;

  /// No description provided for @iveScreenWebsiteAnalyzer.
  ///
  /// In pt, this message translates to:
  /// **'Website Analyzer'**
  String get iveScreenWebsiteAnalyzer;

  /// No description provided for @iveScreenProjects.
  ///
  /// In pt, this message translates to:
  /// **'Projetos'**
  String get iveScreenProjects;

  /// No description provided for @iveScreenDecisions.
  ///
  /// In pt, this message translates to:
  /// **'Decisões'**
  String get iveScreenDecisions;

  /// No description provided for @iveScreenKnowledge.
  ///
  /// In pt, this message translates to:
  /// **'Conhecimento'**
  String get iveScreenKnowledge;

  /// No description provided for @iveScreenMarketIntelligence.
  ///
  /// In pt, this message translates to:
  /// **'Market Intelligence'**
  String get iveScreenMarketIntelligence;

  /// No description provided for @iveScreenBusinessOs.
  ///
  /// In pt, this message translates to:
  /// **'Business OS'**
  String get iveScreenBusinessOs;

  /// No description provided for @iveScreenOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades'**
  String get iveScreenOpportunities;

  /// No description provided for @iveScreenBriefing.
  ///
  /// In pt, this message translates to:
  /// **'Briefing'**
  String get iveScreenBriefing;

  /// No description provided for @iveScreenResources.
  ///
  /// In pt, this message translates to:
  /// **'Recursos'**
  String get iveScreenResources;

  /// No description provided for @iveScreenPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Personas'**
  String get iveScreenPersonas;

  /// No description provided for @iveScreenDebugHub.
  ///
  /// In pt, this message translates to:
  /// **'Debug Hub'**
  String get iveScreenDebugHub;

  /// No description provided for @iveScreenRoiTracker.
  ///
  /// In pt, this message translates to:
  /// **'ROI Tracker'**
  String get iveScreenRoiTracker;

  /// No description provided for @iveScreenScores.
  ///
  /// In pt, this message translates to:
  /// **'Scores'**
  String get iveScreenScores;

  /// No description provided for @iveSuggestionProjects1.
  ///
  /// In pt, this message translates to:
  /// **'Qual projeto devo focar?'**
  String get iveSuggestionProjects1;

  /// No description provided for @iveSuggestionProjects2.
  ///
  /// In pt, this message translates to:
  /// **'Quais projetos têm mais risco?'**
  String get iveSuggestionProjects2;

  /// No description provided for @iveSuggestionOpportunities1.
  ///
  /// In pt, this message translates to:
  /// **'Qual oportunidade tem maior ROI?'**
  String get iveSuggestionOpportunities1;

  /// No description provided for @iveSuggestionOpportunities2.
  ///
  /// In pt, this message translates to:
  /// **'O que devo aprovar agora?'**
  String get iveSuggestionOpportunities2;

  /// No description provided for @iveSuggestionScores1.
  ///
  /// In pt, this message translates to:
  /// **'Por que meu score está baixo?'**
  String get iveSuggestionScores1;

  /// No description provided for @iveSuggestionScores2.
  ///
  /// In pt, this message translates to:
  /// **'Como melhorar o Ecosystem Score?'**
  String get iveSuggestionScores2;

  /// No description provided for @iveSuggestionDecisions1.
  ///
  /// In pt, this message translates to:
  /// **'O que devo escalar?'**
  String get iveSuggestionDecisions1;

  /// No description provided for @iveSuggestionDecisions2.
  ///
  /// In pt, this message translates to:
  /// **'Simule o impacto de aprovar a top oportunidade'**
  String get iveSuggestionDecisions2;

  /// No description provided for @iveSuggestionBriefing1.
  ///
  /// In pt, this message translates to:
  /// **'Resuma minha semana'**
  String get iveSuggestionBriefing1;

  /// No description provided for @iveSuggestionBriefing2.
  ///
  /// In pt, this message translates to:
  /// **'Quais ações críticas estão atrasadas?'**
  String get iveSuggestionBriefing2;

  /// No description provided for @iveSuggestionKnowledge1.
  ///
  /// In pt, this message translates to:
  /// **'O que aprendi esta semana?'**
  String get iveSuggestionKnowledge1;

  /// No description provided for @iveSuggestionKnowledge2.
  ///
  /// In pt, this message translates to:
  /// **'Qual documento mais impacta meu projeto?'**
  String get iveSuggestionKnowledge2;

  /// No description provided for @iveSuggestionPersonas1.
  ///
  /// In pt, this message translates to:
  /// **'Qual persona mais avançou?'**
  String get iveSuggestionPersonas1;

  /// No description provided for @iveSuggestionPersonas2.
  ///
  /// In pt, this message translates to:
  /// **'Qual nicho tem mais potencial?'**
  String get iveSuggestionPersonas2;

  /// No description provided for @iveSuggestionDefault1.
  ///
  /// In pt, this message translates to:
  /// **'Me explique os dados desta tela'**
  String get iveSuggestionDefault1;

  /// No description provided for @iveSuggestionDefault2.
  ///
  /// In pt, this message translates to:
  /// **'O que devo fazer agora?'**
  String get iveSuggestionDefault2;

  /// No description provided for @iveActionSuggestionHint.
  ///
  /// In pt, this message translates to:
  /// **'Sugestão da IVE: {label}. Complete os detalhes na tela que abriu.'**
  String iveActionSuggestionHint(String label);

  /// No description provided for @iveActionNoDestination.
  ///
  /// In pt, this message translates to:
  /// **'Este tipo de ação ainda não tem um destino direto. Pergunte à IVE para mais detalhes.'**
  String get iveActionNoDestination;

  /// No description provided for @oppNewTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nova Oportunidade'**
  String get oppNewTitle;

  /// No description provided for @oppTypeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get oppTypeLabel;

  /// No description provided for @oppTitleLabel.
  ///
  /// In pt, this message translates to:
  /// **'Título'**
  String get oppTitleLabel;

  /// No description provided for @oppDescriptionLabel.
  ///
  /// In pt, this message translates to:
  /// **'Descrição (opcional)'**
  String get oppDescriptionLabel;

  /// No description provided for @oppCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get oppCancel;

  /// No description provided for @oppAdd.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar'**
  String get oppAdd;

  /// No description provided for @oppKnowledgeSectionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conhecimento do projeto'**
  String get oppKnowledgeSectionTitle;

  /// No description provided for @oppKnowledgeSectionHint.
  ///
  /// In pt, this message translates to:
  /// **'Selecione itens do Cofre de Conhecimento deste projeto para dar contexto real à oportunidade.'**
  String get oppKnowledgeSectionHint;

  /// No description provided for @oppKnowledgeSelectProjectFirst.
  ///
  /// In pt, this message translates to:
  /// **'Selecione um projeto no filtro acima para usar conhecimento do projeto (opcional).'**
  String get oppKnowledgeSelectProjectFirst;

  /// No description provided for @oppKnowledgeEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Este projeto ainda não tem itens no Cofre de Conhecimento.'**
  String get oppKnowledgeEmpty;

  /// No description provided for @oppKnowledgeCountSelected.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Nenhum item selecionado} =1{1 item selecionado} other{{count} itens selecionados}}'**
  String oppKnowledgeCountSelected(int count);

  /// No description provided for @oppLinkedKnowledgeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conhecimento vinculado'**
  String get oppLinkedKnowledgeTitle;

  /// No description provided for @oppTypeExpansao.
  ///
  /// In pt, this message translates to:
  /// **'Expansão'**
  String get oppTypeExpansao;

  /// No description provided for @oppTypeNovoProduto.
  ///
  /// In pt, this message translates to:
  /// **'Novo Produto'**
  String get oppTypeNovoProduto;

  /// No description provided for @oppTypeNovoNicho.
  ///
  /// In pt, this message translates to:
  /// **'Novo Nicho'**
  String get oppTypeNovoNicho;

  /// No description provided for @oppTypeAfiliado.
  ///
  /// In pt, this message translates to:
  /// **'Afiliado'**
  String get oppTypeAfiliado;

  /// No description provided for @oppTypeSaas.
  ///
  /// In pt, this message translates to:
  /// **'SaaS'**
  String get oppTypeSaas;

  /// No description provided for @oppTypeEbook.
  ///
  /// In pt, this message translates to:
  /// **'Ebook'**
  String get oppTypeEbook;

  /// No description provided for @oppTypeCurso.
  ///
  /// In pt, this message translates to:
  /// **'Curso'**
  String get oppTypeCurso;

  /// No description provided for @oppTypeAssinatura.
  ///
  /// In pt, this message translates to:
  /// **'Assinatura'**
  String get oppTypeAssinatura;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'Esta ação tem consequências fora do app (publicar, enviar, pagar, negociar ou apagar). A IVE não executa ações desse tipo: elas exigem aprovação pelo fluxo de execução governada.'**
  String get iveCoreRequiresAef;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'Este projeto não está disponível para a sua conta.'**
  String get iveCoreProjectForbidden;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'A IVE está temporariamente indisponível. Nenhuma análise foi descontada. Tente novamente.'**
  String get iveCoreModelUnavailable;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar o contexto do projeto agora. Tente novamente.'**
  String get iveCoreContextUnavailable;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível enviar esta pergunta. Revise o texto e tente novamente.'**
  String get iveCoreInvalidRequest;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'A IVE ainda não está disponível nesta plataforma.'**
  String get iveCoreSurfaceNotSupported;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão expirou. Faça login novamente.'**
  String get iveCoreSessionExpired;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'Este recurso não está disponível para a sua conta.'**
  String get iveCoreAccessDenied;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'Você atingiu o limite de análises de IA do seu plano.'**
  String get iveCoreQuotaExceeded;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'Algo deu errado ao falar com a IVE. Tente novamente.'**
  String get iveCoreGenericError;

  /// IVE-INTELLIGENCE-CORE-01 chat state
  ///
  /// In pt, this message translates to:
  /// **'Resposta com contexto parcial: parte dos seus dados não pôde ser carregada.'**
  String get iveCoreDegradedContext;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Ação proposta pela IVE (LAB)'**
  String get aefLabTitle;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Nada foi executado. Revise os detalhes: a ação só roda depois da sua aprovação explícita.'**
  String get aefLabIntro;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Ação'**
  String get aefLabActionLabel;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Risco: consequencial — exige a sua aprovação.'**
  String get aefLabRisk;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Consequência: publica este texto no canal escolhido (simulado no LAB, nada sai do app).'**
  String get aefLabConsequencePublish;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Consequência: envia esta mensagem ao público escolhido (simulado no LAB, nada sai do app).'**
  String get aefLabConsequenceSend;

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 Action Engine governed completion
  ///
  /// In pt, this message translates to:
  /// **'Consequência: marca esta ação como concluída, com recibo governado e trilha de auditoria. Você mesmo executou isso -- o app registra, não faz por você.'**
  String get aefLabConsequenceCompleteAction;

  /// Macro-08 continuation §5-8 Strategy Simulation governed approval
  ///
  /// In pt, this message translates to:
  /// **'Consequência: registra a sua aprovação formal deste resultado de simulação, com recibo governado e trilha de auditoria. A simulação em si já rodou de forma segura e determinística -- isto é só a aprovação humana formal, nunca dinheiro real, nunca uma ordem.'**
  String get aefLabConsequenceApproveSimulation;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Canal'**
  String get aefLabFieldChannel;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Texto'**
  String get aefLabFieldText;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Público'**
  String get aefLabFieldAudience;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Assunto'**
  String get aefLabFieldSubject;

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 Action Engine governed completion
  ///
  /// In pt, this message translates to:
  /// **'Ação'**
  String get aefLabFieldActionId;

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 Action Engine governed completion
  ///
  /// In pt, this message translates to:
  /// **'Resumo'**
  String get aefLabFieldSummary;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Mensagem'**
  String get aefLabFieldBody;

  /// Macro-08 continuation §5-8 Strategy Simulation governed approval
  ///
  /// In pt, this message translates to:
  /// **'ID do experimento'**
  String get aefLabFieldExperimentId;

  /// Macro-08 continuation §5-8 Strategy Simulation governed approval
  ///
  /// In pt, this message translates to:
  /// **'Nota da aprovação'**
  String get aefLabFieldNote;

  /// Macro-08 continuation §5-8 Strategy Simulation governed approval
  ///
  /// In pt, this message translates to:
  /// **'Aprovação formal da simulação (AEF)'**
  String get aefLabTitleStrategySimulation;

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 UX review (§18): AefActionCard's title, when opened from Action Engine rather than IVE chat -- the default 'Ação proposta pela IVE (LAB)' is both wrong (not proposed by IVE) and exposes internal LAB jargon.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar conclusão'**
  String get aefLabTitleActionEngine;

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 UX review (§18): was a hardcoded, PT-only string naming 'AEF' directly -- neither localized nor jargon-free. Governance stays technically explicit internally; this user-facing line does not need the acronym to say the same thing.
  ///
  /// In pt, this message translates to:
  /// **'Isso exige a sua aprovação explícita e gera um recibo auditável. Nada é enviado a nenhum sistema externo.'**
  String get actionEngineExecuteSheetIntro;

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 UX review (§18): human label for the raw internal action id, replacing a literal string like 'publish_content'.
  ///
  /// In pt, this message translates to:
  /// **'Publicar conteúdo'**
  String get aefLabActionPublishContent;

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 UX review (§18): human label for the raw internal action id.
  ///
  /// In pt, this message translates to:
  /// **'Enviar mensagem'**
  String get aefLabActionSendMessage;

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 UX review (§18): human label for the raw internal action id.
  ///
  /// In pt, this message translates to:
  /// **'Concluir ação'**
  String get aefLabActionCompleteAction;

  /// Macro-08 continuation §5-8: human label for the raw internal action id 'approve_simulation_result'.
  ///
  /// In pt, this message translates to:
  /// **'Aprovar resultado de simulação'**
  String get aefLabActionApproveSimulation;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Solicitar aprovação'**
  String get aefLabRequestApproval;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Aprovar'**
  String get aefLabApprove;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Rejeitar'**
  String get aefLabReject;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Executar agora'**
  String get aefLabExecute;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Aguardando a sua aprovação. Nada foi executado.'**
  String get aefLabPhaseAwaiting;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Aprovada — ainda não executada.'**
  String get aefLabPhaseAuthorized;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Em execução…'**
  String get aefLabPhaseExecuting;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Concluída. Recibo registrado.'**
  String get aefLabPhaseSucceeded;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Conclusão não confirmada pelo servidor.'**
  String get aefLabPhaseUnconfirmed;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Falhou. Nada foi concluído.'**
  String get aefLabPhaseFailed;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Resultado desconhecido: a ação pode ter ocorrido. É necessária reconciliação — não tente de novo.'**
  String get aefLabPhaseUnknown;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Rejeitada. Nada foi executado.'**
  String get aefLabPhaseRejected;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Expirada. Nada foi executado.'**
  String get aefLabPhaseExpired;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Cancelada. Nada foi executado.'**
  String get aefLabPhaseCancelled;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Invalidada (as regras mudaram). Nada foi executado.'**
  String get aefLabPhaseInvalidated;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Ação não permitida.'**
  String get aefLabPhaseDenied;

  /// IV-IVE-AEF-RUNTIME-INTEGRATION-01 LAB Human Gate card
  ///
  /// In pt, this message translates to:
  /// **'Sem resposta confiável do servidor: o estado não foi confirmado.'**
  String get aefLabPhaseNetwork;

  /// Persisted receipt id
  ///
  /// In pt, this message translates to:
  /// **'Recibo: {receiptId}'**
  String aefLabReceipt(String receiptId);

  /// No description provided for @impactTitle.
  ///
  /// In pt, this message translates to:
  /// **'Impact Lab'**
  String get impactTitle;

  /// No description provided for @impactInvestigations.
  ///
  /// In pt, this message translates to:
  /// **'Investigações'**
  String get impactInvestigations;

  /// No description provided for @impactInvestigationsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma investigação ainda.'**
  String get impactInvestigationsEmpty;

  /// No description provided for @impactAdminOnly.
  ///
  /// In pt, this message translates to:
  /// **'O Impact Lab é restrito a administradores.'**
  String get impactAdminOnly;

  /// No description provided for @impactNoScoreNote.
  ///
  /// In pt, this message translates to:
  /// **'Este dossiê organiza evidências. Não atribui nota, ranking nem veredito à organização.'**
  String get impactNoScoreNote;

  /// No description provided for @impactLiveView.
  ///
  /// In pt, this message translates to:
  /// **'Visão ao vivo'**
  String get impactLiveView;

  /// No description provided for @impactLiveViewHint.
  ///
  /// In pt, this message translates to:
  /// **'Reflete o estado atual e muda quando a evidência muda.'**
  String get impactLiveViewHint;

  /// No description provided for @impactSnapshot.
  ///
  /// In pt, this message translates to:
  /// **'Snapshot emitido'**
  String get impactSnapshot;

  /// No description provided for @impactSnapshotHint.
  ///
  /// In pt, this message translates to:
  /// **'Retrato histórico: não é reescrito quando a evidência muda.'**
  String get impactSnapshotHint;

  /// No description provided for @impactAsOf.
  ///
  /// In pt, this message translates to:
  /// **'Situação em {date}'**
  String impactAsOf(String date);

  /// No description provided for @impactAsOfUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Sem data de referência ainda'**
  String get impactAsOfUnknown;

  /// No description provided for @impactSummary.
  ///
  /// In pt, this message translates to:
  /// **'Resumo'**
  String get impactSummary;

  /// No description provided for @impactIdentity.
  ///
  /// In pt, this message translates to:
  /// **'Identidade'**
  String get impactIdentity;

  /// No description provided for @impactClaims.
  ///
  /// In pt, this message translates to:
  /// **'Afirmações'**
  String get impactClaims;

  /// No description provided for @impactEvidence.
  ///
  /// In pt, this message translates to:
  /// **'Evidências'**
  String get impactEvidence;

  /// No description provided for @impactConflicts.
  ///
  /// In pt, this message translates to:
  /// **'Divergências'**
  String get impactConflicts;

  /// No description provided for @impactLimitations.
  ///
  /// In pt, this message translates to:
  /// **'Limitações'**
  String get impactLimitations;

  /// No description provided for @impactNotEstablished.
  ///
  /// In pt, this message translates to:
  /// **'O que este dossiê NÃO estabelece'**
  String get impactNotEstablished;

  /// No description provided for @impactDisputes.
  ///
  /// In pt, this message translates to:
  /// **'Contestações'**
  String get impactDisputes;

  /// No description provided for @impactSources.
  ///
  /// In pt, this message translates to:
  /// **'Fontes e proveniência'**
  String get impactSources;

  /// No description provided for @impactIntegrity.
  ///
  /// In pt, this message translates to:
  /// **'Integridade'**
  String get impactIntegrity;

  /// No description provided for @impactOpenDisputes.
  ///
  /// In pt, this message translates to:
  /// **'Contestações abertas'**
  String get impactOpenDisputes;

  /// No description provided for @impactReverifyPending.
  ///
  /// In pt, this message translates to:
  /// **'Reverificação pendente'**
  String get impactReverifyPending;

  /// No description provided for @impactNotVerifiedYet.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não verificada.'**
  String get impactNotVerifiedYet;

  /// No description provided for @impactNoClaims.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma afirmação registrada ainda.'**
  String get impactNoClaims;

  /// No description provided for @impactNoEvidence.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma evidência vinculada a esta afirmação.'**
  String get impactNoEvidence;

  /// No description provided for @impactNoConflicts.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma divergência registrada.'**
  String get impactNoConflicts;

  /// No description provided for @impactNoDisputes.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma contestação registrada.'**
  String get impactNoDisputes;

  /// No description provided for @impactNoLimitations.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma limitação registrada.'**
  String get impactNoLimitations;

  /// No description provided for @impactNoRegistry.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum registro oficial anexado. Isso não significa que a organização não seja registrada.'**
  String get impactNoRegistry;

  /// No description provided for @impactNoSnapshot.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum snapshot emitido ainda.'**
  String get impactNoSnapshot;

  /// No description provided for @impactQuotedFromSource.
  ///
  /// In pt, this message translates to:
  /// **'Citação da fonte'**
  String get impactQuotedFromSource;

  /// No description provided for @impactQuotedFromUpload.
  ///
  /// In pt, this message translates to:
  /// **'Citação de documento enviado — contexto, nunca autoridade'**
  String get impactQuotedFromUpload;

  /// No description provided for @impactWithheld.
  ///
  /// In pt, this message translates to:
  /// **'Trecho omitido por privacidade'**
  String get impactWithheld;

  /// No description provided for @impactRedactedNote.
  ///
  /// In pt, this message translates to:
  /// **'Dados pessoais foram removidos deste texto.'**
  String get impactRedactedNote;

  /// No description provided for @impactPublisher.
  ///
  /// In pt, this message translates to:
  /// **'Publicador'**
  String get impactPublisher;

  /// No description provided for @impactHostedOn.
  ///
  /// In pt, this message translates to:
  /// **'Hospedado em {host} (não é o publicador)'**
  String impactHostedOn(String host);

  /// No description provided for @impactUserSubmitted.
  ///
  /// In pt, this message translates to:
  /// **'Enviado por usuário — contexto, nunca autoridade'**
  String get impactUserSubmitted;

  /// No description provided for @impactVoices.
  ///
  /// In pt, this message translates to:
  /// **'Vozes independentes: {voices} · fontes avaliadas: {documents}'**
  String impactVoices(int voices, int documents);

  /// No description provided for @impactVoicesNote.
  ///
  /// In pt, this message translates to:
  /// **'Vários documentos não significam várias fontes independentes.'**
  String get impactVoicesNote;

  /// No description provided for @impactRules.
  ///
  /// In pt, this message translates to:
  /// **'Regras aplicadas'**
  String get impactRules;

  /// No description provided for @impactGaps.
  ///
  /// In pt, this message translates to:
  /// **'Lacunas'**
  String get impactGaps;

  /// No description provided for @impactLocator.
  ///
  /// In pt, this message translates to:
  /// **'Localização no documento'**
  String get impactLocator;

  /// No description provided for @impactProvenanceChain.
  ///
  /// In pt, this message translates to:
  /// **'Fonte → documento → localização → evidência → afirmação'**
  String get impactProvenanceChain;

  /// No description provided for @impactPositionsNoWinner.
  ///
  /// In pt, this message translates to:
  /// **'Todas as posições lado a lado — nenhuma é escolhida.'**
  String get impactPositionsNoWinner;

  /// No description provided for @impactContentHash.
  ///
  /// In pt, this message translates to:
  /// **'Hash do conteúdo'**
  String get impactContentHash;

  /// No description provided for @impactHashNotTruth.
  ///
  /// In pt, this message translates to:
  /// **'O hash prova que o conteúdo não foi alterado — não prova que ele é verdadeiro.'**
  String get impactHashNotTruth;

  /// No description provided for @impactSnapshotRef.
  ///
  /// In pt, this message translates to:
  /// **'Referência do snapshot'**
  String get impactSnapshotRef;

  /// No description provided for @impactVerifyCurrent.
  ///
  /// In pt, this message translates to:
  /// **'Snapshot atual: o conteúdo não mudou desde a emissão.'**
  String get impactVerifyCurrent;

  /// No description provided for @impactVerifyStale.
  ///
  /// In pt, this message translates to:
  /// **'Snapshot desatualizado: o conteúdo do dossiê mudou depois da emissão (evidência ou política de apresentação). O snapshot continua válido como registro histórico.'**
  String get impactVerifyStale;

  /// No description provided for @impactVerifyNotIssued.
  ///
  /// In pt, this message translates to:
  /// **'Este hash não foi emitido para esta investigação.'**
  String get impactVerifyNotIssued;

  /// No description provided for @impactEnvelopeMismatch.
  ///
  /// In pt, this message translates to:
  /// **'Os metadados do snapshot não conferem com o registro.'**
  String get impactEnvelopeMismatch;

  /// No description provided for @impactVerifySnapshot.
  ///
  /// In pt, this message translates to:
  /// **'Verificar snapshot'**
  String get impactVerifySnapshot;

  /// No description provided for @impactExport.
  ///
  /// In pt, this message translates to:
  /// **'Emitir snapshot'**
  String get impactExport;

  /// No description provided for @impactExportConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Antes de emitir o snapshot'**
  String get impactExportConfirmTitle;

  /// No description provided for @impactExportLimitations.
  ///
  /// In pt, this message translates to:
  /// **'Limitações que acompanham este dossiê: {count}'**
  String impactExportLimitations(int count);

  /// No description provided for @impactExportPrivacy.
  ///
  /// In pt, this message translates to:
  /// **'O export é privado e autenticado: não há link público nem compartilhamento.'**
  String get impactExportPrivacy;

  /// No description provided for @impactExportFormats.
  ///
  /// In pt, this message translates to:
  /// **'Formatos disponíveis: JSON e texto. PDF não disponível.'**
  String get impactExportFormats;

  /// No description provided for @impactExportConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Emitir'**
  String get impactExportConfirm;

  /// No description provided for @impactExportDone.
  ///
  /// In pt, this message translates to:
  /// **'Snapshot emitido'**
  String get impactExportDone;

  /// No description provided for @impactCopyJson.
  ///
  /// In pt, this message translates to:
  /// **'Copiar JSON'**
  String get impactCopyJson;

  /// No description provided for @impactCopyText.
  ///
  /// In pt, this message translates to:
  /// **'Copiar texto'**
  String get impactCopyText;

  /// No description provided for @impactCopied.
  ///
  /// In pt, this message translates to:
  /// **'Copiado'**
  String get impactCopied;

  /// No description provided for @impactErrorAuth.
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão expirou. Entre novamente.'**
  String get impactErrorAuth;

  /// No description provided for @impactErrorNotAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Investigação não encontrada ou indisponível.'**
  String get impactErrorNotAvailable;

  /// No description provided for @impactErrorTooLarge.
  ///
  /// In pt, this message translates to:
  /// **'Este dossiê excede o limite e não foi truncado. Nada parcial é exibido.'**
  String get impactErrorTooLarge;

  /// No description provided for @impactErrorRateLimited.
  ///
  /// In pt, this message translates to:
  /// **'Muitas solicitações. Tente novamente em {seconds} s.'**
  String impactErrorRateLimited(int seconds);

  /// No description provided for @impactErrorNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão. Verifique a rede e tente novamente.'**
  String get impactErrorNetwork;

  /// No description provided for @impactErrorServer.
  ///
  /// In pt, this message translates to:
  /// **'O serviço não respondeu. Tente novamente.'**
  String get impactErrorServer;

  /// No description provided for @impactShowMore.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar mais ({count})'**
  String impactShowMore(int count);

  /// No description provided for @impactExpand.
  ///
  /// In pt, this message translates to:
  /// **'Expandir'**
  String get impactExpand;

  /// No description provided for @impactCollapse.
  ///
  /// In pt, this message translates to:
  /// **'Recolher'**
  String get impactCollapse;

  /// No description provided for @impactClaimDetail.
  ///
  /// In pt, this message translates to:
  /// **'Detalhe da afirmação'**
  String get impactClaimDetail;

  /// No description provided for @impactErrorContract.
  ///
  /// In pt, this message translates to:
  /// **'Resposta do servidor em formato não suportado. Nada foi exibido para não mostrar um dossiê incompleto.'**
  String get impactErrorContract;

  /// No description provided for @impactRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get impactRetry;

  /// No description provided for @impactEvidenceExcluded.
  ///
  /// In pt, this message translates to:
  /// **'Excluídas da avaliação (com o motivo nas regras)'**
  String get impactEvidenceExcluded;

  /// No description provided for @impactDeclaredQuote.
  ///
  /// In pt, this message translates to:
  /// **'Identidade declarada para esta investigação — citada, não verificada'**
  String get impactDeclaredQuote;

  /// No description provided for @impactRegistryQuote.
  ///
  /// In pt, this message translates to:
  /// **'Como consta no registro — citado'**
  String get impactRegistryQuote;

  /// No description provided for @impactClaimCaveats.
  ///
  /// In pt, this message translates to:
  /// **'Antes de ler esta afirmação'**
  String get impactClaimCaveats;

  /// No description provided for @impactClaimLimitations.
  ///
  /// In pt, this message translates to:
  /// **'Limitações que se aplicam a esta afirmação'**
  String get impactClaimLimitations;

  /// No description provided for @impactSnapshotCaveats.
  ///
  /// In pt, this message translates to:
  /// **'A confirmação descreveu a visão ao vivo naquele momento. As ressalvas do snapshot emitido são estas:'**
  String get impactSnapshotCaveats;

  /// No description provided for @impactClaimScopeNote.
  ///
  /// In pt, this message translates to:
  /// **'Situação desta afirmação apenas — não é um veredito sobre a organização.'**
  String get impactClaimScopeNote;

  /// No description provided for @impactIdentityScopeNote.
  ///
  /// In pt, this message translates to:
  /// **'Identidade apenas — não avalia a conduta da organização.'**
  String get impactIdentityScopeNote;

  /// No description provided for @impactPosition.
  ///
  /// In pt, this message translates to:
  /// **'Posição {index} de {total}'**
  String impactPosition(int index, int total);

  /// No description provided for @impactVerifyInconclusive.
  ///
  /// In pt, this message translates to:
  /// **'Verificação inconclusiva: não confie nos metadados deste snapshot. Obtenha um novo export antes de usá-lo.'**
  String get impactVerifyInconclusive;

  /// No description provided for @quantLabTitle.
  ///
  /// In pt, this message translates to:
  /// **'Quant Lab (interno)'**
  String get quantLabTitle;

  /// No description provided for @quantLabInternalBanner.
  ///
  /// In pt, this message translates to:
  /// **'Laboratório interno de análise. Somente leitura: nenhuma ordem, compra, venda ou conexão com corretora. Números calculados pelo motor determinístico no servidor.'**
  String get quantLabInternalBanner;

  /// No description provided for @quantLabAccessDenied.
  ///
  /// In pt, this message translates to:
  /// **'Você não tem permissão para acessar o Quant Lab.'**
  String get quantLabAccessDenied;

  /// No description provided for @quantLabInstrument.
  ///
  /// In pt, this message translates to:
  /// **'Instrumento'**
  String get quantLabInstrument;

  /// No description provided for @quantLabAssetClass.
  ///
  /// In pt, this message translates to:
  /// **'Classe de ativo'**
  String get quantLabAssetClass;

  /// No description provided for @quantLabSymbol.
  ///
  /// In pt, this message translates to:
  /// **'Símbolo'**
  String get quantLabSymbol;

  /// No description provided for @quantLabVenue.
  ///
  /// In pt, this message translates to:
  /// **'Bolsa (MIC)'**
  String get quantLabVenue;

  /// No description provided for @quantLabVenueOther.
  ///
  /// In pt, this message translates to:
  /// **'Outra / não informada'**
  String get quantLabVenueOther;

  /// No description provided for @quantLabCurrency.
  ///
  /// In pt, this message translates to:
  /// **'Moeda (ISO 4217)'**
  String get quantLabCurrency;

  /// No description provided for @quantLabAdjustment.
  ///
  /// In pt, this message translates to:
  /// **'Ajuste de preços'**
  String get quantLabAdjustment;

  /// No description provided for @quantLabDataset.
  ///
  /// In pt, this message translates to:
  /// **'Dados (CSV OHLCV)'**
  String get quantLabDataset;

  /// No description provided for @quantLabCsvHint.
  ///
  /// In pt, this message translates to:
  /// **'date,open,high,low,close,volume'**
  String get quantLabCsvHint;

  /// No description provided for @quantLabLoadSample.
  ///
  /// In pt, this message translates to:
  /// **'Carregar exemplo sintético'**
  String get quantLabLoadSample;

  /// No description provided for @quantLabPickCsv.
  ///
  /// In pt, this message translates to:
  /// **'Importar arquivo CSV'**
  String get quantLabPickCsv;

  /// No description provided for @quantLabPeriodsPerYear.
  ///
  /// In pt, this message translates to:
  /// **'Períodos por ano (vazio = sem anualização)'**
  String get quantLabPeriodsPerYear;

  /// No description provided for @quantLabSmaWindows.
  ///
  /// In pt, this message translates to:
  /// **'Janelas de média móvel (ex.: 20, 50)'**
  String get quantLabSmaWindows;

  /// No description provided for @quantLabAnalyze.
  ///
  /// In pt, this message translates to:
  /// **'Analisar'**
  String get quantLabAnalyze;

  /// No description provided for @quantLabAnalyzing.
  ///
  /// In pt, this message translates to:
  /// **'Analisando…'**
  String get quantLabAnalyzing;

  /// No description provided for @quantLabPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Período'**
  String get quantLabPeriod;

  /// No description provided for @quantLabProvenance.
  ///
  /// In pt, this message translates to:
  /// **'Proveniência'**
  String get quantLabProvenance;

  /// No description provided for @quantLabFreshness.
  ///
  /// In pt, this message translates to:
  /// **'Atualidade dos dados'**
  String get quantLabFreshness;

  /// No description provided for @quantLabCalendar.
  ///
  /// In pt, this message translates to:
  /// **'Calendário de mercado'**
  String get quantLabCalendar;

  /// No description provided for @quantLabMetrics.
  ///
  /// In pt, this message translates to:
  /// **'Métricas'**
  String get quantLabMetrics;

  /// No description provided for @quantLabAssumptions.
  ///
  /// In pt, this message translates to:
  /// **'Premissas'**
  String get quantLabAssumptions;

  /// No description provided for @quantLabWarnings.
  ///
  /// In pt, this message translates to:
  /// **'Avisos'**
  String get quantLabWarnings;

  /// No description provided for @quantLabRiskNotImplemented.
  ///
  /// In pt, this message translates to:
  /// **'Risco ainda não coberto'**
  String get quantLabRiskNotImplemented;

  /// No description provided for @quantLabSignals.
  ///
  /// In pt, this message translates to:
  /// **'Sinais (descritivos, não são recomendações)'**
  String get quantLabSignals;

  /// No description provided for @quantLabNoSignals.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum sinal no período.'**
  String get quantLabNoSignals;

  /// No description provided for @quantLabFormula.
  ///
  /// In pt, this message translates to:
  /// **'Fórmula'**
  String get quantLabFormula;

  /// No description provided for @quantLabObservations.
  ///
  /// In pt, this message translates to:
  /// **'Observações'**
  String get quantLabObservations;

  /// No description provided for @quantLabEvidence.
  ///
  /// In pt, this message translates to:
  /// **'Força da evidência'**
  String get quantLabEvidence;

  /// No description provided for @quantLabError.
  ///
  /// In pt, this message translates to:
  /// **'O servidor recusou a análise: {code}'**
  String quantLabError(String code);

  /// No description provided for @quantLabErrorField.
  ///
  /// In pt, this message translates to:
  /// **'O servidor recusou a análise: {code} ({field})'**
  String quantLabErrorField(String code, String field);

  /// No description provided for @quantLabInvalidInput.
  ///
  /// In pt, this message translates to:
  /// **'Preencha símbolo, moeda, CSV e números válidos.'**
  String get quantLabInvalidInput;

  /// No description provided for @quantLabFileTooLarge.
  ///
  /// In pt, this message translates to:
  /// **'Arquivo acima de 5 MB.'**
  String get quantLabFileTooLarge;

  /// No description provided for @quantLabFileUnreadable.
  ///
  /// In pt, this message translates to:
  /// **'Arquivo CSV ilegível (use UTF-8).'**
  String get quantLabFileUnreadable;

  /// No description provided for @quantLabTabSingle.
  ///
  /// In pt, this message translates to:
  /// **'Série única'**
  String get quantLabTabSingle;

  /// No description provided for @quantLabTabWatchlist.
  ///
  /// In pt, this message translates to:
  /// **'Watchlist'**
  String get quantLabTabWatchlist;

  /// No description provided for @quantLabWatchlists.
  ///
  /// In pt, this message translates to:
  /// **'Watchlists'**
  String get quantLabWatchlists;

  /// No description provided for @quantLabWatchlistName.
  ///
  /// In pt, this message translates to:
  /// **'Nome da nova watchlist'**
  String get quantLabWatchlistName;

  /// No description provided for @quantLabCreate.
  ///
  /// In pt, this message translates to:
  /// **'Criar'**
  String get quantLabCreate;

  /// No description provided for @quantLabDeleteWatchlist.
  ///
  /// In pt, this message translates to:
  /// **'Excluir watchlist'**
  String get quantLabDeleteWatchlist;

  /// No description provided for @quantLabAddItem.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar instrumento'**
  String get quantLabAddItem;

  /// No description provided for @quantLabRemoveItem.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get quantLabRemoveItem;

  /// No description provided for @quantLabNoWatchlists.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma watchlist ainda.'**
  String get quantLabNoWatchlists;

  /// No description provided for @quantLabNoItems.
  ///
  /// In pt, this message translates to:
  /// **'Esta watchlist está vazia.'**
  String get quantLabNoItems;

  /// No description provided for @quantLabSelectUpTo.
  ///
  /// In pt, this message translates to:
  /// **'Selecione até {max} instrumentos para analisar.'**
  String quantLabSelectUpTo(int max);

  /// No description provided for @quantLabAnalyzeWatchlist.
  ///
  /// In pt, this message translates to:
  /// **'Analisar watchlist'**
  String get quantLabAnalyzeWatchlist;

  /// No description provided for @quantLabSyntheticNotice.
  ///
  /// In pt, this message translates to:
  /// **'A análise de watchlist usa dados SINTÉTICOS gerados pelo servidor (sem dados reais de mercado, sem fornecedor). Serve apenas para testar o fluxo.'**
  String get quantLabSyntheticNotice;

  /// No description provided for @quantLabSeries.
  ///
  /// In pt, this message translates to:
  /// **'Séries'**
  String get quantLabSeries;

  /// No description provided for @quantLabAlignment.
  ///
  /// In pt, this message translates to:
  /// **'Alinhamento'**
  String get quantLabAlignment;

  /// No description provided for @quantLabCorrelation.
  ///
  /// In pt, this message translates to:
  /// **'Correlação dos retornos'**
  String get quantLabCorrelation;

  /// No description provided for @quantLabDataSource.
  ///
  /// In pt, this message translates to:
  /// **'Fonte de dados'**
  String get quantLabDataSource;

  /// No description provided for @quantLabAlignedReturn.
  ///
  /// In pt, this message translates to:
  /// **'Retorno na janela comum'**
  String get quantLabAlignedReturn;

  /// No description provided for @quantLabOperationError.
  ///
  /// In pt, this message translates to:
  /// **'O servidor recusou a operação: {code}'**
  String quantLabOperationError(String code);

  /// No description provided for @quantLabFileTypeNotSupported.
  ///
  /// In pt, this message translates to:
  /// **'Tipo de arquivo não suportado. Use um arquivo CSV (ou TXT com conteúdo CSV).'**
  String get quantLabFileTypeNotSupported;

  /// No description provided for @quantLabFileTypeNotImplemented.
  ///
  /// In pt, this message translates to:
  /// **'Planilhas (XLS, XLSX, ODS) e JSON ainda não são suportados. Exporte os dados como CSV.'**
  String get quantLabFileTypeNotImplemented;

  /// No description provided for @quantLabRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get quantLabRetry;

  /// No description provided for @quantLabAsOf.
  ///
  /// In pt, this message translates to:
  /// **'Referente a'**
  String get quantLabAsOf;

  /// No description provided for @quantLabProviderLabel.
  ///
  /// In pt, this message translates to:
  /// **'Fornecedor'**
  String get quantLabProviderLabel;

  /// No description provided for @quantLabTrustLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nível de confiança'**
  String get quantLabTrustLabel;

  /// No description provided for @quantLabRetrievedAt.
  ///
  /// In pt, this message translates to:
  /// **'Obtido em'**
  String get quantLabRetrievedAt;

  /// No description provided for @quantLabContentHash.
  ///
  /// In pt, this message translates to:
  /// **'Hash do conteúdo'**
  String get quantLabContentHash;

  /// No description provided for @quantLabEngine.
  ///
  /// In pt, this message translates to:
  /// **'Motor'**
  String get quantLabEngine;

  /// No description provided for @quantLabSessionsBehind.
  ///
  /// In pt, this message translates to:
  /// **'sessões de atraso: {count}'**
  String quantLabSessionsBehind(int count);

  /// No description provided for @quantLabKind.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get quantLabKind;

  /// No description provided for @quantLabCacheLabel.
  ///
  /// In pt, this message translates to:
  /// **'Cache'**
  String get quantLabCacheLabel;

  /// No description provided for @quantLabCacheValue.
  ///
  /// In pt, this message translates to:
  /// **'acertos {hits} · falhas {misses}'**
  String quantLabCacheValue(int hits, int misses);

  /// No description provided for @quantLabIdLabel.
  ///
  /// In pt, this message translates to:
  /// **'ID'**
  String get quantLabIdLabel;

  /// No description provided for @quantLabPolicy.
  ///
  /// In pt, this message translates to:
  /// **'Política'**
  String get quantLabPolicy;

  /// No description provided for @quantLabBars.
  ///
  /// In pt, this message translates to:
  /// **'Barras'**
  String get quantLabBars;

  /// No description provided for @strategyLabTitle.
  ///
  /// In pt, this message translates to:
  /// **'Strategy Lab (Robot Builder)'**
  String get strategyLabTitle;

  /// No description provided for @strategyLabAccessDenied.
  ///
  /// In pt, this message translates to:
  /// **'Você não tem permissão para acessar o Strategy Lab.'**
  String get strategyLabAccessDenied;

  /// No description provided for @strategyLabBanner.
  ///
  /// In pt, this message translates to:
  /// **'Fase de MVP. Crie, configure, faça backtest e compare suas próprias estratégias abaixo. Sem conexão com corretora, sem dinheiro real, sem ordem ao vivo.'**
  String get strategyLabBanner;

  /// No description provided for @strategyLabDisclaimer.
  ///
  /// In pt, this message translates to:
  /// **'Apenas referência de pesquisa. NÃO é uma estratégia com lucro comprovado. NÃO aprovada para paper trading ou negociação real. Não é recomendação de investimento.'**
  String get strategyLabDisclaimer;

  /// No description provided for @strategyLabStatusLabel.
  ///
  /// In pt, this message translates to:
  /// **'Status'**
  String get strategyLabStatusLabel;

  /// No description provided for @strategyLabRulesSection.
  ///
  /// In pt, this message translates to:
  /// **'Regras'**
  String get strategyLabRulesSection;

  /// No description provided for @strategyLabEntry.
  ///
  /// In pt, this message translates to:
  /// **'Entrada'**
  String get strategyLabEntry;

  /// No description provided for @strategyLabStop.
  ///
  /// In pt, this message translates to:
  /// **'Stop'**
  String get strategyLabStop;

  /// No description provided for @strategyLabTarget.
  ///
  /// In pt, this message translates to:
  /// **'Alvo'**
  String get strategyLabTarget;

  /// No description provided for @strategyLabBreakEven.
  ///
  /// In pt, this message translates to:
  /// **'Break-even'**
  String get strategyLabBreakEven;

  /// No description provided for @strategyLabSession.
  ///
  /// In pt, this message translates to:
  /// **'Sessão'**
  String get strategyLabSession;

  /// No description provided for @strategyLabForcedExit.
  ///
  /// In pt, this message translates to:
  /// **'Fechamento forçado'**
  String get strategyLabForcedExit;

  /// No description provided for @strategyLabPositionSize.
  ///
  /// In pt, this message translates to:
  /// **'Tamanho da posição'**
  String get strategyLabPositionSize;

  /// No description provided for @strategyLabHistoricalReference.
  ///
  /// In pt, this message translates to:
  /// **'Referência histórica (dataset real WIN1!)'**
  String get strategyLabHistoricalReference;

  /// No description provided for @strategyLabZeroCost.
  ///
  /// In pt, this message translates to:
  /// **'Sem custo'**
  String get strategyLabZeroCost;

  /// No description provided for @strategyLabWithCost.
  ///
  /// In pt, this message translates to:
  /// **'Com custos'**
  String get strategyLabWithCost;

  /// No description provided for @strategyBuilderMyStrategies.
  ///
  /// In pt, this message translates to:
  /// **'Minhas Estratégias'**
  String get strategyBuilderMyStrategies;

  /// No description provided for @strategyBuilderNewButton.
  ///
  /// In pt, this message translates to:
  /// **'Nova estratégia'**
  String get strategyBuilderNewButton;

  /// No description provided for @strategyBuilderCloneV10.
  ///
  /// In pt, this message translates to:
  /// **'Clonar Estratégia #001 (V10)'**
  String get strategyBuilderCloneV10;

  /// No description provided for @strategyBuilderCloneGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Clonar referência genérica'**
  String get strategyBuilderCloneGeneric;

  /// No description provided for @strategyBuilderEmptyList.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma estratégia ainda.'**
  String get strategyBuilderEmptyList;

  /// No description provided for @strategyBuilderNewTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nova estratégia'**
  String get strategyBuilderNewTitle;

  /// No description provided for @strategyBuilderEditTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar estratégia (cria uma nova versão)'**
  String get strategyBuilderEditTitle;

  /// No description provided for @strategyBuilderName.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get strategyBuilderName;

  /// No description provided for @strategyBuilderDescription.
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get strategyBuilderDescription;

  /// No description provided for @strategyBuilderEntryMode.
  ///
  /// In pt, this message translates to:
  /// **'Estilo de entrada'**
  String get strategyBuilderEntryMode;

  /// No description provided for @strategyBuilderEntryModeGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Abertura de sessão genérica (demo seguro, dados sintéticos)'**
  String get strategyBuilderEntryModeGeneric;

  /// No description provided for @strategyBuilderEntryModeV10.
  ///
  /// In pt, this message translates to:
  /// **'Pullback na tendência (estilo Estratégia #001, dados reais WIN1!)'**
  String get strategyBuilderEntryModeV10;

  /// No description provided for @strategyBuilderDirection.
  ///
  /// In pt, this message translates to:
  /// **'Direção'**
  String get strategyBuilderDirection;

  /// No description provided for @strategyBuilderDirectionLong.
  ///
  /// In pt, this message translates to:
  /// **'Compra (long)'**
  String get strategyBuilderDirectionLong;

  /// No description provided for @strategyBuilderDirectionShort.
  ///
  /// In pt, this message translates to:
  /// **'Venda (short)'**
  String get strategyBuilderDirectionShort;

  /// No description provided for @strategyBuilderStopDistance.
  ///
  /// In pt, this message translates to:
  /// **'Distância do stop'**
  String get strategyBuilderStopDistance;

  /// No description provided for @strategyBuilderTargetDistance.
  ///
  /// In pt, this message translates to:
  /// **'Distância do alvo'**
  String get strategyBuilderTargetDistance;

  /// No description provided for @strategyBuilderBreakEven.
  ///
  /// In pt, this message translates to:
  /// **'Break-even'**
  String get strategyBuilderBreakEven;

  /// No description provided for @strategyBuilderBreakEvenTrigger.
  ///
  /// In pt, this message translates to:
  /// **'Gatilho'**
  String get strategyBuilderBreakEvenTrigger;

  /// No description provided for @strategyBuilderBreakEvenInitial.
  ///
  /// In pt, this message translates to:
  /// **'Proteção inicial'**
  String get strategyBuilderBreakEvenInitial;

  /// No description provided for @strategyBuilderBreakEvenStep.
  ///
  /// In pt, this message translates to:
  /// **'Passo'**
  String get strategyBuilderBreakEvenStep;

  /// No description provided for @strategyBuilderSessionStart.
  ///
  /// In pt, this message translates to:
  /// **'Início da sessão (HH:MM)'**
  String get strategyBuilderSessionStart;

  /// No description provided for @strategyBuilderSessionEnd.
  ///
  /// In pt, this message translates to:
  /// **'Fim da sessão (HH:MM)'**
  String get strategyBuilderSessionEnd;

  /// No description provided for @strategyBuilderForcedExit.
  ///
  /// In pt, this message translates to:
  /// **'Fechamento forçado (HH:MM)'**
  String get strategyBuilderForcedExit;

  /// No description provided for @strategyBuilderQuantity.
  ///
  /// In pt, this message translates to:
  /// **'Contratos'**
  String get strategyBuilderQuantity;

  /// No description provided for @strategyBuilderValidate.
  ///
  /// In pt, this message translates to:
  /// **'Validar'**
  String get strategyBuilderValidate;

  /// No description provided for @strategyBuilderSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get strategyBuilderSave;

  /// No description provided for @strategyBuilderValidationOk.
  ///
  /// In pt, this message translates to:
  /// **'Configuração válida.'**
  String get strategyBuilderValidationOk;

  /// No description provided for @strategyBuilderValidationError.
  ///
  /// In pt, this message translates to:
  /// **'Configuração inválida: {code}'**
  String strategyBuilderValidationError(String code);

  /// No description provided for @strategyBuilderSaved.
  ///
  /// In pt, this message translates to:
  /// **'Salvo.'**
  String get strategyBuilderSaved;

  /// No description provided for @strategyBuilderSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar: {code}'**
  String strategyBuilderSaveError(String code);

  /// No description provided for @strategyBuilderSummaryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Resumo'**
  String get strategyBuilderSummaryTitle;

  /// No description provided for @strategyBuilderSummaryInstrument.
  ///
  /// In pt, this message translates to:
  /// **'Instrumento'**
  String get strategyBuilderSummaryInstrument;

  /// No description provided for @strategyBuilderSummarySignal.
  ///
  /// In pt, this message translates to:
  /// **'Sinal'**
  String get strategyBuilderSummarySignal;

  /// No description provided for @strategyBuilderSummaryPosition.
  ///
  /// In pt, this message translates to:
  /// **'Posição'**
  String get strategyBuilderSummaryPosition;

  /// No description provided for @strategyBuilderBack.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get strategyBuilderBack;

  /// No description provided for @strategyBuilderVersion.
  ///
  /// In pt, this message translates to:
  /// **'Versão {n}'**
  String strategyBuilderVersion(int n);

  /// No description provided for @strategyBuilderRunBacktest.
  ///
  /// In pt, this message translates to:
  /// **'Rodar backtest'**
  String get strategyBuilderRunBacktest;

  /// No description provided for @strategyBuilderBacktestRunning.
  ///
  /// In pt, this message translates to:
  /// **'Executando…'**
  String get strategyBuilderBacktestRunning;

  /// No description provided for @strategyBuilderBacktestSucceeded.
  ///
  /// In pt, this message translates to:
  /// **'Backtest concluído.'**
  String get strategyBuilderBacktestSucceeded;

  /// No description provided for @strategyBuilderBacktestFailed.
  ///
  /// In pt, this message translates to:
  /// **'Backtest falhou: {reason}'**
  String strategyBuilderBacktestFailed(String reason);

  /// No description provided for @strategyBuilderNetPnl.
  ///
  /// In pt, this message translates to:
  /// **'Resultado líquido'**
  String get strategyBuilderNetPnl;

  /// No description provided for @strategyBuilderTradeCount.
  ///
  /// In pt, this message translates to:
  /// **'Operações'**
  String get strategyBuilderTradeCount;

  /// No description provided for @strategyBuilderResultHash.
  ///
  /// In pt, this message translates to:
  /// **'Hash'**
  String get strategyBuilderResultHash;

  /// No description provided for @strategyBuilderCompare.
  ///
  /// In pt, this message translates to:
  /// **'Comparar com a versão anterior'**
  String get strategyBuilderCompare;

  /// No description provided for @strategyBuilderNotComparable.
  ///
  /// In pt, this message translates to:
  /// **'Não diretamente comparável: {reasons}'**
  String strategyBuilderNotComparable(String reasons);

  /// No description provided for @strategyBuilderNewVersionButton.
  ///
  /// In pt, this message translates to:
  /// **'Nova versão a partir desta'**
  String get strategyBuilderNewVersionButton;

  /// No description provided for @strategyDetailIntelligenceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Inteligência de Estratégia'**
  String get strategyDetailIntelligenceTitle;

  /// No description provided for @strategyDetailUnavailableForV10.
  ///
  /// In pt, this message translates to:
  /// **'Essas ferramentas de pesquisa só funcionam com o motor genérico in-process por enquanto.'**
  String get strategyDetailUnavailableForV10;

  /// No description provided for @strategyDetailAnalyzeFit.
  ///
  /// In pt, this message translates to:
  /// **'Analisar ajuste com o mercado'**
  String get strategyDetailAnalyzeFit;

  /// No description provided for @strategyDetailFitEvidenceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Evidência de ajuste com o mercado'**
  String get strategyDetailFitEvidenceTitle;

  /// No description provided for @strategyDetailFitFlagged.
  ///
  /// In pt, this message translates to:
  /// **'sinalizado'**
  String get strategyDetailFitFlagged;

  /// No description provided for @strategyDetailProposalsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Propostas limitadas'**
  String get strategyDetailProposalsTitle;

  /// No description provided for @strategyDetailNoProposals.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma proposta baseada em evidência no momento.'**
  String get strategyDetailNoProposals;

  /// No description provided for @strategyDetailRunSimulation.
  ///
  /// In pt, this message translates to:
  /// **'Rodar simulação'**
  String get strategyDetailRunSimulation;

  /// No description provided for @strategyDetailSimulationResult.
  ///
  /// In pt, this message translates to:
  /// **'Simulação: {trades} trades, líquido {netPnl}'**
  String strategyDetailSimulationResult(String trades, String netPnl);

  /// No description provided for @strategyDetailRunResearchLoop.
  ///
  /// In pt, this message translates to:
  /// **'Rodar loop de pesquisa automatizado'**
  String get strategyDetailRunResearchLoop;

  /// No description provided for @strategyDetailResearchLoopSummary.
  ///
  /// In pt, this message translates to:
  /// **'{count} candidato(s) gerado(s)'**
  String strategyDetailResearchLoopSummary(String count);

  /// No description provided for @strategyDetailNoCandidates.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum candidato foi gerado (nenhuma proposta baseada em evidência).'**
  String get strategyDetailNoCandidates;

  /// No description provided for @strategyDetailRequiresMoreEvidence.
  ///
  /// In pt, this message translates to:
  /// **'REQUER MAIS EVIDÊNCIA'**
  String get strategyDetailRequiresMoreEvidence;

  /// No description provided for @strategyDetailMoreRobust.
  ///
  /// In pt, this message translates to:
  /// **'MAIS ROBUSTO SOB AS PREMISSAS TESTADAS'**
  String get strategyDetailMoreRobust;

  /// No description provided for @planUpgradeBannerTitle.
  ///
  /// In pt, this message translates to:
  /// **'Recurso do plano {requiredPlan}'**
  String planUpgradeBannerTitle(String requiredPlan);

  /// No description provided for @planUpgradeBannerBody.
  ///
  /// In pt, this message translates to:
  /// **'Você está no plano {currentPlan}. Faça upgrade para {requiredPlan} para usar este recurso.'**
  String planUpgradeBannerBody(String currentPlan, String requiredPlan);

  /// No description provided for @planUpgradeBannerCta.
  ///
  /// In pt, this message translates to:
  /// **'Ver planos'**
  String get planUpgradeBannerCta;

  /// No description provided for @planNameFree.
  ///
  /// In pt, this message translates to:
  /// **'Free'**
  String get planNameFree;

  /// No description provided for @planNamePro.
  ///
  /// In pt, this message translates to:
  /// **'Pro'**
  String get planNamePro;

  /// No description provided for @planNamePremium.
  ///
  /// In pt, this message translates to:
  /// **'Premium'**
  String get planNamePremium;

  /// No description provided for @strategyDetailRecordExperiment.
  ///
  /// In pt, this message translates to:
  /// **'Registrar como experimento'**
  String get strategyDetailRecordExperiment;

  /// No description provided for @strategyDetailExperimentRecorded.
  ///
  /// In pt, this message translates to:
  /// **'Registrado como experimento #{id}.'**
  String strategyDetailExperimentRecorded(String id);

  /// No description provided for @strategyDetailRecordExperimentError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível registrar o experimento ({code}).'**
  String strategyDetailRecordExperimentError(String code);

  /// No description provided for @strategyDetailSimulationGovernanceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Aprovação formal (governança AEF)'**
  String get strategyDetailSimulationGovernanceTitle;

  /// No description provided for @strategyDetailSimulationRuntimeUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Indisponível neste ambiente: o runtime de governança AEF só existe em stack Supabase local (LAB) -- nunca em produção. Sua simulação foi registrada normalmente; a etapa de aprovação formal fica pendente até um ambiente compatível estar disponível.'**
  String get strategyDetailSimulationRuntimeUnavailable;

  /// No description provided for @strategyDetailSimulationRuntimePlanRequired.
  ///
  /// In pt, this message translates to:
  /// **'Esta etapa de aprovação formal exige participação no programa beta (papel beta_tester) além de um plano com acesso. Fale com o suporte se quiser participar.'**
  String get strategyDetailSimulationRuntimePlanRequired;

  /// No description provided for @strategyDetailSimulationRuntimePolicyBlocked.
  ///
  /// In pt, this message translates to:
  /// **'O servidor recusou esta solicitação de aprovação ({code}).'**
  String strategyDetailSimulationRuntimePolicyBlocked(Object code);

  /// No description provided for @strategyDetailExperimentHistoryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Histórico de experimentos'**
  String get strategyDetailExperimentHistoryTitle;

  /// No description provided for @strategyDetailExperimentHistoryEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum experimento registrado ainda. Rode um backtest ou uma simulação e registre-o para começar o histórico.'**
  String get strategyDetailExperimentHistoryEmpty;

  /// No description provided for @strategyDetailExperimentCategoryBacktest.
  ///
  /// In pt, this message translates to:
  /// **'Backtest'**
  String get strategyDetailExperimentCategoryBacktest;

  /// No description provided for @strategyDetailExperimentCategoryRobustness.
  ///
  /// In pt, this message translates to:
  /// **'Experimento de robustez'**
  String get strategyDetailExperimentCategoryRobustness;

  /// No description provided for @strategyDetailExperimentCategorySimulation.
  ///
  /// In pt, this message translates to:
  /// **'Simulação'**
  String get strategyDetailExperimentCategorySimulation;

  /// No description provided for @strategyDetailExperimentCategoryUserDecision.
  ///
  /// In pt, this message translates to:
  /// **'Decisão do usuário'**
  String get strategyDetailExperimentCategoryUserDecision;

  /// No description provided for @strategyDetailExperimentCategoryIveRecommendation.
  ///
  /// In pt, this message translates to:
  /// **'Recomendação da IVE'**
  String get strategyDetailExperimentCategoryIveRecommendation;

  /// No description provided for @strategyDetailExperimentContaminated.
  ///
  /// In pt, this message translates to:
  /// **'contaminado (visto após o início do holdout)'**
  String get strategyDetailExperimentContaminated;

  /// No description provided for @strategyDetailExperimentSegment.
  ///
  /// In pt, this message translates to:
  /// **'segmento: {segment}'**
  String strategyDetailExperimentSegment(String segment);

  /// No description provided for @strategyDetailUserDecisionTitle.
  ///
  /// In pt, this message translates to:
  /// **'O que você decide sobre este candidato?'**
  String get strategyDetailUserDecisionTitle;

  /// No description provided for @strategyDetailUserDecisionKeepCurrent.
  ///
  /// In pt, this message translates to:
  /// **'Manter versão atual'**
  String get strategyDetailUserDecisionKeepCurrent;

  /// No description provided for @strategyDetailUserDecisionPreferCandidate.
  ///
  /// In pt, this message translates to:
  /// **'Preferir candidato'**
  String get strategyDetailUserDecisionPreferCandidate;

  /// No description provided for @strategyDetailUserDecisionRejectCandidate.
  ///
  /// In pt, this message translates to:
  /// **'Rejeitar candidato'**
  String get strategyDetailUserDecisionRejectCandidate;

  /// No description provided for @strategyDetailUserDecisionNeedsMoreEvidence.
  ///
  /// In pt, this message translates to:
  /// **'Precisa de mais evidência'**
  String get strategyDetailUserDecisionNeedsMoreEvidence;

  /// No description provided for @strategyDetailUserDecisionRecorded.
  ///
  /// In pt, this message translates to:
  /// **'Decisão registrada: {decision}.'**
  String strategyDetailUserDecisionRecorded(String decision);

  /// No description provided for @strategyDetailAnalyzeRobustness.
  ///
  /// In pt, this message translates to:
  /// **'Ver evidência e robustez'**
  String get strategyDetailAnalyzeRobustness;

  /// No description provided for @strategyDetailRobustnessEvidenceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Evidência (afirmações rastreáveis, não opinião de modelo genérico)'**
  String get strategyDetailRobustnessEvidenceTitle;

  /// No description provided for @strategyDetailNoRobustnessClaims.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma afirmação disponível para este resultado.'**
  String get strategyDetailNoRobustnessClaims;

  /// No description provided for @strategyDetailScoreComponentsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Componentes do score (transparente, nunca um número único opaco)'**
  String get strategyDetailScoreComponentsTitle;

  /// No description provided for @strategyDetailScoreOverall.
  ///
  /// In pt, this message translates to:
  /// **'Score geral: {overall}/100 ({language})'**
  String strategyDetailScoreOverall(String overall, String language);

  /// No description provided for @strategyDetailScoreLanguageMoreRobust.
  ///
  /// In pt, this message translates to:
  /// **'mais robusto sob as premissas testadas'**
  String get strategyDetailScoreLanguageMoreRobust;

  /// No description provided for @strategyDetailScoreLanguageRequiresEvidence.
  ///
  /// In pt, this message translates to:
  /// **'requer mais evidência'**
  String get strategyDetailScoreLanguageRequiresEvidence;

  /// No description provided for @strategyDetailSampleSizeInsufficient.
  ///
  /// In pt, this message translates to:
  /// **'Amostra pequena: {count} trades (abaixo do limite de {threshold}) -- resultado não deve ser tratado como conclusivo.'**
  String strategyDetailSampleSizeInsufficient(String count, String threshold);

  /// No description provided for @strategyDetailDirectionalUntested.
  ///
  /// In pt, this message translates to:
  /// **'Direção {direction} nunca foi testada neste resultado -- nenhuma evidência sobre esse lado.'**
  String strategyDetailDirectionalUntested(String direction);

  /// No description provided for @strategyDetailUnsupportedParameter.
  ///
  /// In pt, this message translates to:
  /// **'Exploração limitada de {parameter} ainda não é suportada por este motor -- nenhuma sugestão foi inventada.'**
  String strategyDetailUnsupportedParameter(String parameter);

  /// No description provided for @dashWelcome.
  ///
  /// In pt, this message translates to:
  /// **'Olá! Bem-vindo de volta 👋'**
  String get dashWelcome;

  /// No description provided for @dashPlanLabel.
  ///
  /// In pt, this message translates to:
  /// **'Plano: {plan}'**
  String dashPlanLabel(String plan);

  /// No description provided for @dashUsageRemaining.
  ///
  /// In pt, this message translates to:
  /// **'{remaining} de {limit} gerações restantes'**
  String dashUsageRemaining(String remaining, String limit);

  /// No description provided for @dashUsageLimitReached.
  ///
  /// In pt, this message translates to:
  /// **'Limite atingido'**
  String get dashUsageLimitReached;

  /// No description provided for @dashUsageThisMonth.
  ///
  /// In pt, this message translates to:
  /// **'este mês'**
  String get dashUsageThisMonth;

  /// No description provided for @dashImproveWithAi.
  ///
  /// In pt, this message translates to:
  /// **'Melhorar Post com IA'**
  String get dashImproveWithAi;

  /// No description provided for @dashImproveWithAiSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Transforme seu texto agora'**
  String get dashImproveWithAiSubtitle;

  /// No description provided for @dashShortcutPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Personas'**
  String get dashShortcutPersonas;

  /// No description provided for @dashShortcutLibrary.
  ///
  /// In pt, this message translates to:
  /// **'Biblioteca'**
  String get dashShortcutLibrary;

  /// No description provided for @dashShortcutCalendar.
  ///
  /// In pt, this message translates to:
  /// **'Calendário'**
  String get dashShortcutCalendar;

  /// No description provided for @dashShortcutHistory.
  ///
  /// In pt, this message translates to:
  /// **'Histórico'**
  String get dashShortcutHistory;

  /// No description provided for @dashShortcutVault.
  ///
  /// In pt, this message translates to:
  /// **'Cofre'**
  String get dashShortcutVault;

  /// No description provided for @dashShortcutCampaigns.
  ///
  /// In pt, this message translates to:
  /// **'Campanhas'**
  String get dashShortcutCampaigns;

  /// No description provided for @dashShortcutWebsiteAnalyzer.
  ///
  /// In pt, this message translates to:
  /// **'Website\nAnalyzer'**
  String get dashShortcutWebsiteAnalyzer;

  /// No description provided for @dashShortcutPerformance.
  ///
  /// In pt, this message translates to:
  /// **'Performance'**
  String get dashShortcutPerformance;

  /// No description provided for @dashFeatureUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Este recurso ainda não está disponível.'**
  String get dashFeatureUnavailable;

  /// No description provided for @dashAdminSectionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Admin'**
  String get dashAdminSectionTitle;

  /// No description provided for @dashAdminStatUsers.
  ///
  /// In pt, this message translates to:
  /// **'Usuários'**
  String get dashAdminStatUsers;

  /// No description provided for @dashAdminStatPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Personas'**
  String get dashAdminStatPersonas;

  /// No description provided for @dashAdminStatContent.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdos'**
  String get dashAdminStatContent;

  /// No description provided for @dashAdminStatSites.
  ///
  /// In pt, this message translates to:
  /// **'Sites'**
  String get dashAdminStatSites;

  /// No description provided for @dashAdminStatVault.
  ///
  /// In pt, this message translates to:
  /// **'Cofre'**
  String get dashAdminStatVault;

  /// No description provided for @dashAdminStatCampaigns.
  ///
  /// In pt, this message translates to:
  /// **'Campanhas'**
  String get dashAdminStatCampaigns;

  /// No description provided for @dashAdminStatAnalyzed.
  ///
  /// In pt, this message translates to:
  /// **'Analisados'**
  String get dashAdminStatAnalyzed;

  /// No description provided for @dashAdminPanelButton.
  ///
  /// In pt, this message translates to:
  /// **'Painel Administrativo'**
  String get dashAdminPanelButton;

  /// No description provided for @dashAdminPanelSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Usuários, personas e planos'**
  String get dashAdminPanelSubtitle;

  /// No description provided for @dashProBadge.
  ///
  /// In pt, this message translates to:
  /// **'PRO'**
  String get dashProBadge;

  /// No description provided for @dashProIncluded.
  ///
  /// In pt, this message translates to:
  /// **'Incluso no seu plano'**
  String get dashProIncluded;

  /// No description provided for @dashProUpgradeCta.
  ///
  /// In pt, this message translates to:
  /// **'Toque para desbloquear'**
  String get dashProUpgradeCta;

  /// No description provided for @dashProBenefitPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Crie personas de marca com IA'**
  String get dashProBenefitPersonas;

  /// No description provided for @dashProBenefitLibrary.
  ///
  /// In pt, this message translates to:
  /// **'Organize todo seu conteúdo gerado'**
  String get dashProBenefitLibrary;

  /// No description provided for @dashProBenefitCalendar.
  ///
  /// In pt, this message translates to:
  /// **'Planeje sua produção de conteúdo'**
  String get dashProBenefitCalendar;

  /// No description provided for @dashProBenefitCampaigns.
  ///
  /// In pt, this message translates to:
  /// **'Gere campanhas completas com IA'**
  String get dashProBenefitCampaigns;

  /// No description provided for @dashProBenefitPerformance.
  ///
  /// In pt, this message translates to:
  /// **'Acompanhe métricas de desempenho'**
  String get dashProBenefitPerformance;

  /// No description provided for @dashPortfolioTitle.
  ///
  /// In pt, this message translates to:
  /// **'PORTFÓLIO'**
  String get dashPortfolioTitle;

  /// No description provided for @dashPortfolioActiveProjects.
  ///
  /// In pt, this message translates to:
  /// **'Projetos ativos'**
  String get dashPortfolioActiveProjects;

  /// No description provided for @dashPortfolioAnalyses.
  ///
  /// In pt, this message translates to:
  /// **'Análises de mercado'**
  String get dashPortfolioAnalyses;

  /// No description provided for @dashPortfolioAvgScore.
  ///
  /// In pt, this message translates to:
  /// **'Score médio'**
  String get dashPortfolioAvgScore;

  /// No description provided for @dashRecommendationsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Recomendações Executivas'**
  String get dashRecommendationsTitle;

  /// No description provided for @dashRecEmptyProjectTitle.
  ///
  /// In pt, this message translates to:
  /// **'Cadastre seu primeiro projeto'**
  String get dashRecEmptyProjectTitle;

  /// No description provided for @dashRecEmptyProjectBody.
  ///
  /// In pt, this message translates to:
  /// **'Acesse Projetos e cadastre pelo menos um para desbloquear análises e oportunidades.'**
  String get dashRecEmptyProjectBody;

  /// No description provided for @dashRecEmptyAnalysisTitle.
  ///
  /// In pt, this message translates to:
  /// **'Execute sua primeira análise de mercado'**
  String get dashRecEmptyAnalysisTitle;

  /// No description provided for @dashRecEmptyAnalysisBody.
  ///
  /// In pt, this message translates to:
  /// **'Vá a Market Intelligence e analise o nicho de {projectName}.'**
  String dashRecEmptyAnalysisBody(String projectName);

  /// No description provided for @dashRecPendingActionsTitle.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 ação aguardando aprovação} other{{count} ações aguardando aprovação}}'**
  String dashRecPendingActionsTitle(int count);

  /// No description provided for @dashRecPendingActionsBody.
  ///
  /// In pt, this message translates to:
  /// **'Revise e aprove as ações pendentes no Action Engine para começar a execução.'**
  String get dashRecPendingActionsBody;

  /// No description provided for @dashRecTopOpportunityTitle.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidade de alta pontuação: {niche}'**
  String dashRecTopOpportunityTitle(String niche);

  /// No description provided for @dashRecTopOpportunityBody.
  ///
  /// In pt, this message translates to:
  /// **'Score {score}/100. Acione o Opportunity Lab para converter em tarefas.'**
  String dashRecTopOpportunityBody(int score);

  /// No description provided for @dashRecNoRevenueTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma receita registrada ainda'**
  String get dashRecNoRevenueTitle;

  /// No description provided for @dashRecNoRevenueBody.
  ///
  /// In pt, this message translates to:
  /// **'Adicione entradas no ROI Tracker para acompanhar o retorno real dos seus projetos.'**
  String get dashRecNoRevenueBody;

  /// No description provided for @dashPendingActionsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Prioridades da Semana'**
  String get dashPendingActionsTitle;

  /// No description provided for @dashPendingActionsViewAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver todas'**
  String get dashPendingActionsViewAll;

  /// No description provided for @dashPendingActionsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma ação pendente. O Action Engine preencherá automaticamente com base nas suas análises.'**
  String get dashPendingActionsEmpty;

  /// No description provided for @commonAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get commonAll;

  /// No description provided for @commonDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get commonDelete;

  /// No description provided for @actionEngineComingSoonBody.
  ///
  /// In pt, this message translates to:
  /// **'O motor de ações está sendo calibrado.\nEm breve você terá um sistema inteligente que transforma análises em tarefas executáveis com priorização automática.'**
  String get actionEngineComingSoonBody;

  /// No description provided for @actionEngineComingSoonPro.
  ///
  /// In pt, this message translates to:
  /// **'Disponível em breve — Plano Pro'**
  String get actionEngineComingSoonPro;

  /// No description provided for @actionEngineSectionPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendentes'**
  String get actionEngineSectionPending;

  /// No description provided for @actionEngineSectionActive.
  ///
  /// In pt, this message translates to:
  /// **'Em Execução'**
  String get actionEngineSectionActive;

  /// No description provided for @actionEngineSectionCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Concluídas'**
  String get actionEngineSectionCompleted;

  /// No description provided for @actionEngineSummaryPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendentes'**
  String get actionEngineSummaryPending;

  /// No description provided for @actionEngineSummaryActive.
  ///
  /// In pt, this message translates to:
  /// **'Ativas'**
  String get actionEngineSummaryActive;

  /// No description provided for @actionEngineSummaryCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Concluídas'**
  String get actionEngineSummaryCompleted;

  /// No description provided for @actionEngineDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir ação?'**
  String get actionEngineDeleteTitle;

  /// No description provided for @actionEngineDeleteBody.
  ///
  /// In pt, this message translates to:
  /// **'A ação \"{title}\" será removida permanentemente.'**
  String actionEngineDeleteBody(String title);

  /// No description provided for @actionEngineDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get actionEngineDelete;

  /// No description provided for @actionEngineApprove.
  ///
  /// In pt, this message translates to:
  /// **'Aprovar'**
  String get actionEngineApprove;

  /// No description provided for @actionEngineExecute.
  ///
  /// In pt, this message translates to:
  /// **'Executar'**
  String get actionEngineExecute;

  /// No description provided for @actionEngineVerify.
  ///
  /// In pt, this message translates to:
  /// **'Verificar'**
  String get actionEngineVerify;

  /// No description provided for @actionEnginePause.
  ///
  /// In pt, this message translates to:
  /// **'Pausar'**
  String get actionEnginePause;

  /// No description provided for @actionEngineScoreRoi.
  ///
  /// In pt, this message translates to:
  /// **'ROI'**
  String get actionEngineScoreRoi;

  /// No description provided for @actionEngineScoreImpact.
  ///
  /// In pt, this message translates to:
  /// **'Impacto'**
  String get actionEngineScoreImpact;

  /// No description provided for @actionEngineScoreEffort.
  ///
  /// In pt, this message translates to:
  /// **'Esforço'**
  String get actionEngineScoreEffort;

  /// No description provided for @actionEngineScorePriority.
  ///
  /// In pt, this message translates to:
  /// **'Prio.'**
  String get actionEngineScorePriority;

  /// No description provided for @actionEngineFilterAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get actionEngineFilterAll;

  /// No description provided for @actionEngineEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Fila de ações vazia'**
  String get actionEngineEmptyTitle;

  /// No description provided for @actionEngineEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Ações serão geradas automaticamente a partir de análises de mercado e oportunidades.'**
  String get actionEngineEmptyBody;

  /// No description provided for @actionEngineStatusPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendente'**
  String get actionEngineStatusPending;

  /// No description provided for @actionEngineStatusApproved.
  ///
  /// In pt, this message translates to:
  /// **'Aprovada'**
  String get actionEngineStatusApproved;

  /// No description provided for @actionEngineStatusExecuting.
  ///
  /// In pt, this message translates to:
  /// **'Em execução'**
  String get actionEngineStatusExecuting;

  /// No description provided for @actionEngineStatusCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Concluída'**
  String get actionEngineStatusCompleted;

  /// No description provided for @actionEngineStatusCancelled.
  ///
  /// In pt, this message translates to:
  /// **'Cancelada'**
  String get actionEngineStatusCancelled;

  /// No description provided for @actionDetailTitle.
  ///
  /// In pt, this message translates to:
  /// **'Detalhe da Ação'**
  String get actionDetailTitle;

  /// No description provided for @actionDetailNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Ação não encontrada.'**
  String get actionDetailNotFound;

  /// No description provided for @actionDetailExecuteWithApproval.
  ///
  /// In pt, this message translates to:
  /// **'Executar (com aprovação AEF)'**
  String get actionDetailExecuteWithApproval;

  /// No description provided for @actionDetailRecheck.
  ///
  /// In pt, this message translates to:
  /// **'Verificar novamente'**
  String get actionDetailRecheck;

  /// No description provided for @actionDetailDeleteBody.
  ///
  /// In pt, this message translates to:
  /// **'\"{title}\" será removida.'**
  String actionDetailDeleteBody(String title);

  /// No description provided for @actionDetailSectionScoreBreakdown.
  ///
  /// In pt, this message translates to:
  /// **'Score Breakdown'**
  String get actionDetailSectionScoreBreakdown;

  /// No description provided for @actionDetailSectionOrigin.
  ///
  /// In pt, this message translates to:
  /// **'Origem'**
  String get actionDetailSectionOrigin;

  /// No description provided for @actionDetailSectionSources.
  ///
  /// In pt, this message translates to:
  /// **'Fontes'**
  String get actionDetailSectionSources;

  /// No description provided for @actionDetailSectionDescription.
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get actionDetailSectionDescription;

  /// No description provided for @actionDetailSectionRationale.
  ///
  /// In pt, this message translates to:
  /// **'Justificativa da IA'**
  String get actionDetailSectionRationale;

  /// No description provided for @actionDetailSectionPlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano de Execução'**
  String get actionDetailSectionPlan;

  /// No description provided for @actionDetailSectionRisks.
  ///
  /// In pt, this message translates to:
  /// **'Riscos'**
  String get actionDetailSectionRisks;

  /// No description provided for @actionDetailScoreMarket.
  ///
  /// In pt, this message translates to:
  /// **'Mercado'**
  String get actionDetailScoreMarket;

  /// No description provided for @actionDetailScoreRevenue.
  ///
  /// In pt, this message translates to:
  /// **'Receita'**
  String get actionDetailScoreRevenue;

  /// No description provided for @actionDetailScoreRoiFinal.
  ///
  /// In pt, this message translates to:
  /// **'ROI / Final'**
  String get actionDetailScoreRoiFinal;

  /// No description provided for @actionDetailScorePriority.
  ///
  /// In pt, this message translates to:
  /// **'Prioridade'**
  String get actionDetailScorePriority;

  /// No description provided for @actionDetailScoreConfidence.
  ///
  /// In pt, this message translates to:
  /// **'Confiança'**
  String get actionDetailScoreConfidence;

  /// No description provided for @actionDetailOriginGeneratedBy.
  ///
  /// In pt, this message translates to:
  /// **'Gerada por'**
  String get actionDetailOriginGeneratedBy;

  /// No description provided for @actionDetailOriginProject.
  ///
  /// In pt, this message translates to:
  /// **'Projeto'**
  String get actionDetailOriginProject;

  /// No description provided for @actionDetailOriginOpportunity.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidade'**
  String get actionDetailOriginOpportunity;

  /// No description provided for @actionDetailOriginOpportunityValue.
  ///
  /// In pt, this message translates to:
  /// **'Lab #{id}…'**
  String actionDetailOriginOpportunityValue(String id);

  /// No description provided for @actionDetailOriginMarketAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Análise de mercado'**
  String get actionDetailOriginMarketAnalysis;

  /// No description provided for @actionDetailOriginMarketAnalysisValue.
  ///
  /// In pt, this message translates to:
  /// **'Market #{id}…'**
  String actionDetailOriginMarketAnalysisValue(String id);

  /// No description provided for @actionDetailOriginCreatedAt.
  ///
  /// In pt, this message translates to:
  /// **'Criada em'**
  String get actionDetailOriginCreatedAt;

  /// No description provided for @actionDetailOriginUpdatedAt.
  ///
  /// In pt, this message translates to:
  /// **'Atualizada em'**
  String get actionDetailOriginUpdatedAt;

  /// No description provided for @actionDetailApproveAction.
  ///
  /// In pt, this message translates to:
  /// **'Aprovar Ação'**
  String get actionDetailApproveAction;

  /// No description provided for @actionDetailReconciliationNeeded.
  ///
  /// In pt, this message translates to:
  /// **'O AEF não confirmou o resultado (reconciliação necessária). Verifique novamente — o mesmo pedido é seguro de repetir.'**
  String get actionDetailReconciliationNeeded;

  /// No description provided for @actionDetailCompletedVerified.
  ///
  /// In pt, this message translates to:
  /// **'Concluída (recibo AEF verificado)'**
  String get actionDetailCompletedVerified;

  /// No description provided for @actionDetailCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Concluída'**
  String get actionDetailCompleted;

  /// No description provided for @actionDetailAskIve.
  ///
  /// In pt, this message translates to:
  /// **'Perguntar à IVE sobre esta ação'**
  String get actionDetailAskIve;

  /// No description provided for @actionDetailAskIveMessage.
  ///
  /// In pt, this message translates to:
  /// **'Analise a ação \"{title}\" e me dê orientação sobre como conduzi-la.'**
  String actionDetailAskIveMessage(String title);

  /// No description provided for @improvePostTitle.
  ///
  /// In pt, this message translates to:
  /// **'Melhorar Post'**
  String get improvePostTitle;

  /// No description provided for @improvePostMinLength.
  ///
  /// In pt, this message translates to:
  /// **'Escreva pelo menos {min} caracteres.'**
  String improvePostMinLength(int min);

  /// No description provided for @improvePostLimitReached.
  ///
  /// In pt, this message translates to:
  /// **'Você atingiu o limite de {limit} gerações este mês.'**
  String improvePostLimitReached(int limit);

  /// No description provided for @improvePostAnalysisLabel.
  ///
  /// In pt, this message translates to:
  /// **'Melhorar Conteúdo'**
  String get improvePostAnalysisLabel;

  /// No description provided for @improvePostSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Resultado gerado com sucesso!'**
  String get improvePostSuccess;

  /// No description provided for @improvePostClearTitle.
  ///
  /// In pt, this message translates to:
  /// **'Limpar texto'**
  String get improvePostClearTitle;

  /// No description provided for @improvePostClearBody.
  ///
  /// In pt, this message translates to:
  /// **'Deseja apagar todo o conteúdo digitado?'**
  String get improvePostClearBody;

  /// No description provided for @improvePostClearConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get improvePostClearConfirm;

  /// No description provided for @improvePostLimitBanner.
  ///
  /// In pt, this message translates to:
  /// **'Limite atingido ({limit}/{limit} gerações este mês).'**
  String improvePostLimitBanner(int limit);

  /// No description provided for @improvePostRemainingBanner.
  ///
  /// In pt, this message translates to:
  /// **'{remaining} de {limit} gerações restantes este mês.'**
  String improvePostRemainingBanner(int remaining, int limit);

  /// No description provided for @improvePostUpgradeCta.
  ///
  /// In pt, this message translates to:
  /// **'Upgrade'**
  String get improvePostUpgradeCta;

  /// No description provided for @improvePostSeePlans.
  ///
  /// In pt, this message translates to:
  /// **'Ver planos'**
  String get improvePostSeePlans;

  /// No description provided for @improvePostHeading.
  ///
  /// In pt, this message translates to:
  /// **'Cole ou escreva seu post'**
  String get improvePostHeading;

  /// No description provided for @improvePostHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Hoje aprendi algo incrível sobre produtividade...'**
  String get improvePostHint;

  /// No description provided for @improvePostCharCount.
  ///
  /// In pt, this message translates to:
  /// **'{count} / {max} caracteres'**
  String improvePostCharCount(int count, int max);

  /// No description provided for @improvePostButtonLabel.
  ///
  /// In pt, this message translates to:
  /// **'✨  Melhorar post'**
  String get improvePostButtonLabel;

  /// No description provided for @improvePostButtonLoading.
  ///
  /// In pt, this message translates to:
  /// **'Analisando seu conteúdo...'**
  String get improvePostButtonLoading;

  /// No description provided for @miSubErrorPrefix.
  ///
  /// In pt, this message translates to:
  /// **'Erro: {error}'**
  String miSubErrorPrefix(String error);

  /// No description provided for @miCompetitorTitle.
  ///
  /// In pt, this message translates to:
  /// **'Concorrentes'**
  String get miCompetitorTitle;

  /// No description provided for @miCompetitorSearching.
  ///
  /// In pt, this message translates to:
  /// **'Buscando...'**
  String get miCompetitorSearching;

  /// No description provided for @miCompetitorDiscoverButton.
  ///
  /// In pt, this message translates to:
  /// **'Descobrir'**
  String get miCompetitorDiscoverButton;

  /// No description provided for @miCompetitorEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum concorrente ainda'**
  String get miCompetitorEmptyTitle;

  /// No description provided for @miCompetitorEmptyButton.
  ///
  /// In pt, this message translates to:
  /// **'Descobrir Concorrentes'**
  String get miCompetitorEmptyButton;

  /// No description provided for @miCompetitorStrengthsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Pontos fortes:'**
  String get miCompetitorStrengthsLabel;

  /// No description provided for @miCompetitorWeaknessesLabel.
  ///
  /// In pt, this message translates to:
  /// **'Pontos fracos:'**
  String get miCompetitorWeaknessesLabel;

  /// No description provided for @miCompetitorScoreSimilarity.
  ///
  /// In pt, this message translates to:
  /// **'Simil.'**
  String get miCompetitorScoreSimilarity;

  /// No description provided for @miCompetitorScoreAuthority.
  ///
  /// In pt, this message translates to:
  /// **'Autor.'**
  String get miCompetitorScoreAuthority;

  /// No description provided for @miCompetitorScoreRelevance.
  ///
  /// In pt, this message translates to:
  /// **'Relev.'**
  String get miCompetitorScoreRelevance;

  /// No description provided for @miCompetitorScoreOverall.
  ///
  /// In pt, this message translates to:
  /// **'Geral'**
  String get miCompetitorScoreOverall;

  /// No description provided for @miGapTitle.
  ///
  /// In pt, this message translates to:
  /// **'Gap Analysis'**
  String get miGapTitle;

  /// No description provided for @miGapAnalyzing.
  ///
  /// In pt, this message translates to:
  /// **'Analisando...'**
  String get miGapAnalyzing;

  /// No description provided for @miGapAnalyzeButton.
  ///
  /// In pt, this message translates to:
  /// **'Analisar'**
  String get miGapAnalyzeButton;

  /// No description provided for @miGapEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma análise de gaps ainda'**
  String get miGapEmptyTitle;

  /// No description provided for @miGapEmptyButton.
  ///
  /// In pt, this message translates to:
  /// **'Analisar Gaps'**
  String get miGapEmptyButton;

  /// No description provided for @miGapSectionContent.
  ///
  /// In pt, this message translates to:
  /// **'Gaps de Conteúdo'**
  String get miGapSectionContent;

  /// No description provided for @miGapSectionSeo.
  ///
  /// In pt, this message translates to:
  /// **'Gaps de SEO'**
  String get miGapSectionSeo;

  /// No description provided for @miGapSectionAuthority.
  ///
  /// In pt, this message translates to:
  /// **'Gaps de Autoridade'**
  String get miGapSectionAuthority;

  /// No description provided for @miGapSectionMonetization.
  ///
  /// In pt, this message translates to:
  /// **'Gaps de Monetização'**
  String get miGapSectionMonetization;

  /// No description provided for @miGapSectionProduct.
  ///
  /// In pt, this message translates to:
  /// **'Gaps de Produto'**
  String get miGapSectionProduct;

  /// No description provided for @miGapTotalIdentified.
  ///
  /// In pt, this message translates to:
  /// **'Total: {count} gaps identificados'**
  String miGapTotalIdentified(int count);

  /// No description provided for @miNicheTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nichos & Sub-nichos'**
  String get miNicheTitle;

  /// No description provided for @miNicheDiscovering.
  ///
  /// In pt, this message translates to:
  /// **'Descobrindo...'**
  String get miNicheDiscovering;

  /// No description provided for @miNicheDiscoverButton.
  ///
  /// In pt, this message translates to:
  /// **'Descobrir'**
  String get miNicheDiscoverButton;

  /// No description provided for @miNicheEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum nicho ainda'**
  String get miNicheEmptyTitle;

  /// No description provided for @miNicheEmptyButton.
  ///
  /// In pt, this message translates to:
  /// **'Descobrir Nichos'**
  String get miNicheEmptyButton;

  /// No description provided for @miNicheLevelNiche.
  ///
  /// In pt, this message translates to:
  /// **'Nicho'**
  String get miNicheLevelNiche;

  /// No description provided for @miNicheLevelSubNiche.
  ///
  /// In pt, this message translates to:
  /// **'Sub-nicho'**
  String get miNicheLevelSubNiche;

  /// No description provided for @miNicheLevelMicroNiche.
  ///
  /// In pt, this message translates to:
  /// **'Micro-nicho'**
  String get miNicheLevelMicroNiche;

  /// No description provided for @miNicheScoreLabel.
  ///
  /// In pt, this message translates to:
  /// **'score'**
  String get miNicheScoreLabel;

  /// No description provided for @miNicheScorePotential.
  ///
  /// In pt, this message translates to:
  /// **'Potencial'**
  String get miNicheScorePotential;

  /// No description provided for @miNicheScoreGrowth.
  ///
  /// In pt, this message translates to:
  /// **'Crescimento'**
  String get miNicheScoreGrowth;

  /// No description provided for @miNicheScoreMonetization.
  ///
  /// In pt, this message translates to:
  /// **'Monetização'**
  String get miNicheScoreMonetization;

  /// No description provided for @miNicheScoreTrend.
  ///
  /// In pt, this message translates to:
  /// **'Tendência'**
  String get miNicheScoreTrend;

  /// No description provided for @miOpportunityTitle.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades'**
  String get miOpportunityTitle;

  /// No description provided for @miOpportunitySearching.
  ///
  /// In pt, this message translates to:
  /// **'Buscando...'**
  String get miOpportunitySearching;

  /// No description provided for @miOpportunityDiscoverButton.
  ///
  /// In pt, this message translates to:
  /// **'Descobrir'**
  String get miOpportunityDiscoverButton;

  /// No description provided for @miOpportunityEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma oportunidade ainda'**
  String get miOpportunityEmptyTitle;

  /// No description provided for @miOpportunityEmptyButton.
  ///
  /// In pt, this message translates to:
  /// **'Descobrir Oportunidades'**
  String get miOpportunityEmptyButton;

  /// No description provided for @miOpportunityScoreMarket.
  ///
  /// In pt, this message translates to:
  /// **'Mercado'**
  String get miOpportunityScoreMarket;

  /// No description provided for @miOpportunityScoreGrowth.
  ///
  /// In pt, this message translates to:
  /// **'Crescimento'**
  String get miOpportunityScoreGrowth;

  /// No description provided for @miOpportunityScoreMonetization.
  ///
  /// In pt, this message translates to:
  /// **'Monetização'**
  String get miOpportunityScoreMonetization;

  /// No description provided for @miOpportunityScoreDifficulty.
  ///
  /// In pt, this message translates to:
  /// **'Dificuldade'**
  String get miOpportunityScoreDifficulty;

  /// No description provided for @miClusterTitle.
  ///
  /// In pt, this message translates to:
  /// **'Content Cluster Engine'**
  String get miClusterTitle;

  /// No description provided for @miClusterKeywordRequired.
  ///
  /// In pt, this message translates to:
  /// **'Digite a palavra-chave principal'**
  String get miClusterKeywordRequired;

  /// No description provided for @miClusterEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum cluster ainda'**
  String get miClusterEmptyTitle;

  /// No description provided for @miClusterKeywordFieldLabel.
  ///
  /// In pt, this message translates to:
  /// **'Palavra-chave principal'**
  String get miClusterKeywordFieldLabel;

  /// No description provided for @miClusterGenerating.
  ///
  /// In pt, this message translates to:
  /// **'Gerando...'**
  String get miClusterGenerating;

  /// No description provided for @miClusterGenerateButton.
  ///
  /// In pt, this message translates to:
  /// **'Gerar Content Cluster'**
  String get miClusterGenerateButton;

  /// No description provided for @miClusterKeywordDisplay.
  ///
  /// In pt, this message translates to:
  /// **'Palavra-chave: {keyword}'**
  String miClusterKeywordDisplay(String keyword);

  /// No description provided for @miClusterSectionClusters.
  ///
  /// In pt, this message translates to:
  /// **'Clusters de Conteúdo'**
  String get miClusterSectionClusters;

  /// No description provided for @miClusterSectionSilos.
  ///
  /// In pt, this message translates to:
  /// **'Silos de SEO'**
  String get miClusterSectionSilos;

  /// No description provided for @miClusterSectionArticles.
  ///
  /// In pt, this message translates to:
  /// **'Artigos Sugeridos'**
  String get miClusterSectionArticles;

  /// No description provided for @miClusterArticleKeyword.
  ///
  /// In pt, this message translates to:
  /// **'Keyword: {keyword}'**
  String miClusterArticleKeyword(String keyword);

  /// No description provided for @miClusterSectionRoadmap.
  ///
  /// In pt, this message translates to:
  /// **'Roadmap Editorial'**
  String get miClusterSectionRoadmap;

  /// No description provided for @miClusterRoadmapMonth.
  ///
  /// In pt, this message translates to:
  /// **'Mês {month}'**
  String miClusterRoadmapMonth(String month);

  /// No description provided for @miRevenueTitle.
  ///
  /// In pt, this message translates to:
  /// **'Revenue Planner'**
  String get miRevenueTitle;

  /// No description provided for @miRevenueProjectNameRequired.
  ///
  /// In pt, this message translates to:
  /// **'Digite o nome do projeto'**
  String get miRevenueProjectNameRequired;

  /// No description provided for @miRevenueEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum plano de receita ainda'**
  String get miRevenueEmptyTitle;

  /// No description provided for @miRevenueProjectFieldLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome do projeto'**
  String get miRevenueProjectFieldLabel;

  /// No description provided for @miRevenueCalculating.
  ///
  /// In pt, this message translates to:
  /// **'Calculando...'**
  String get miRevenueCalculating;

  /// No description provided for @miRevenueGenerateButton.
  ///
  /// In pt, this message translates to:
  /// **'Gerar Revenue Plan'**
  String get miRevenueGenerateButton;

  /// No description provided for @miRevenueScenarioConservative.
  ///
  /// In pt, this message translates to:
  /// **'Conservador'**
  String get miRevenueScenarioConservative;

  /// No description provided for @miRevenueScenarioModerate.
  ///
  /// In pt, this message translates to:
  /// **'Moderado'**
  String get miRevenueScenarioModerate;

  /// No description provided for @miRevenueScenarioAggressive.
  ///
  /// In pt, this message translates to:
  /// **'Agressivo'**
  String get miRevenueScenarioAggressive;

  /// No description provided for @miRevenueMonthlyLabel.
  ///
  /// In pt, this message translates to:
  /// **'Mensal: {amount}'**
  String miRevenueMonthlyLabel(String amount);

  /// No description provided for @miRevenueAnnualLabel.
  ///
  /// In pt, this message translates to:
  /// **'Anual'**
  String get miRevenueAnnualLabel;

  /// No description provided for @miRevenueSectionSources.
  ///
  /// In pt, this message translates to:
  /// **'Fontes de Receita'**
  String get miRevenueSectionSources;

  /// No description provided for @miRevenueSectionMilestones.
  ///
  /// In pt, this message translates to:
  /// **'Marcos de Receita'**
  String get miRevenueSectionMilestones;

  /// No description provided for @miRevenueMilestoneTarget.
  ///
  /// In pt, this message translates to:
  /// **'Meta: {amount}'**
  String miRevenueMilestoneTarget(String amount);

  /// No description provided for @miRevenueSectionAssumptions.
  ///
  /// In pt, this message translates to:
  /// **'Premissas'**
  String get miRevenueSectionAssumptions;

  /// No description provided for @miRootErrorNotFound.
  ///
  /// In pt, this message translates to:
  /// **'A função de análise não foi encontrada no servidor. Verifique se as Edge Functions estão implantadas no Supabase Dashboard.'**
  String get miRootErrorNotFound;

  /// No description provided for @miRootErrorSession.
  ///
  /// In pt, this message translates to:
  /// **'Sessão expirada. Saia e entre novamente no aplicativo.'**
  String get miRootErrorSession;

  /// No description provided for @miRootErrorTimeout.
  ///
  /// In pt, this message translates to:
  /// **'A análise demorou demais. Tente novamente em alguns instantes.'**
  String get miRootErrorTimeout;

  /// No description provided for @miRootErrorNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão com a internet. Verifique sua rede e tente novamente.'**
  String get miRootErrorNetwork;

  /// No description provided for @miRootErrorApiKey.
  ///
  /// In pt, this message translates to:
  /// **'Chave de API não configurada no servidor. Configure GROQ_API_KEY nos secrets do Supabase.'**
  String get miRootErrorApiKey;

  /// No description provided for @miRootErrorGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Tente novamente em alguns instantes. Se o erro persistir, verifique o Supabase Dashboard.'**
  String get miRootErrorGeneric;

  /// No description provided for @miRootEngineTitle.
  ///
  /// In pt, this message translates to:
  /// **'Market Intelligence Engine'**
  String get miRootEngineTitle;

  /// No description provided for @miRootEngineSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Analise qualquer URL, domínio ou projeto para descobrir oportunidades de mercado, concorrentes e potencial de receita.'**
  String get miRootEngineSubtitle;

  /// No description provided for @miRootInputTypeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo de entrada'**
  String get miRootInputTypeLabel;

  /// No description provided for @miRootInputTypeUrl.
  ///
  /// In pt, this message translates to:
  /// **'URL / Domínio'**
  String get miRootInputTypeUrl;

  /// No description provided for @miRootInputTypeNiche.
  ///
  /// In pt, this message translates to:
  /// **'Nicho'**
  String get miRootInputTypeNiche;

  /// No description provided for @miRootInputTypeProject.
  ///
  /// In pt, this message translates to:
  /// **'Projeto'**
  String get miRootInputTypeProject;

  /// No description provided for @miRootHintUrl.
  ///
  /// In pt, this message translates to:
  /// **'https://exemplo.com ou exemplo.com'**
  String get miRootHintUrl;

  /// No description provided for @miRootHintNiche.
  ///
  /// In pt, this message translates to:
  /// **'Ex: marketing digital para pequenas empresas'**
  String get miRootHintNiche;

  /// No description provided for @miRootHintProject.
  ///
  /// In pt, this message translates to:
  /// **'Descreva seu projeto ou ideia'**
  String get miRootHintProject;

  /// No description provided for @miRootAnalyzing.
  ///
  /// In pt, this message translates to:
  /// **'Analisando...'**
  String get miRootAnalyzing;

  /// No description provided for @miRootAnalyzeCta.
  ///
  /// In pt, this message translates to:
  /// **'Analisar Mercado'**
  String get miRootAnalyzeCta;

  /// No description provided for @miRootConnectionErrorTitle.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível conectar ao mecanismo de análise'**
  String get miRootConnectionErrorTitle;

  /// No description provided for @miRootPreviousAnalysesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Análises anteriores'**
  String get miRootPreviousAnalysesTitle;

  /// No description provided for @miRootNoAnalysesYet.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma análise ainda.'**
  String get miRootNoAnalysesYet;

  /// No description provided for @miHubAppBarTitle.
  ///
  /// In pt, this message translates to:
  /// **'Inteligência de Mercado'**
  String get miHubAppBarTitle;

  /// No description provided for @miHubCompareWithIveTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Comparar com IVE'**
  String get miHubCompareWithIveTooltip;

  /// No description provided for @miHubCompareInitialMessage.
  ///
  /// In pt, this message translates to:
  /// **'Compare os resultados desta análise de mercado ({subject}) e identifique a maior oportunidade.'**
  String miHubCompareInitialMessage(String subject);

  /// No description provided for @miHubReloadTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Recarregar dados'**
  String get miHubReloadTooltip;

  /// No description provided for @miHubLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar análise:\n{error}'**
  String miHubLoadError(String error);

  /// No description provided for @miHubDescHigh.
  ///
  /// In pt, this message translates to:
  /// **'Alto potencial de crescimento. Monetização forte. Concorrência administrável.'**
  String get miHubDescHigh;

  /// No description provided for @miHubDescMedium.
  ///
  /// In pt, this message translates to:
  /// **'Potencial moderado. Mercado em crescimento. Avalie seus diferenciais.'**
  String get miHubDescMedium;

  /// No description provided for @miHubDescLow.
  ///
  /// In pt, this message translates to:
  /// **'Potencial limitado. Mercado saturado ou monetização fraca. Considere pivotar.'**
  String get miHubDescLow;

  /// No description provided for @miHubPriorityHigh.
  ///
  /// In pt, this message translates to:
  /// **'🚀  Prioridade Alta'**
  String get miHubPriorityHigh;

  /// No description provided for @miHubPriorityMedium.
  ///
  /// In pt, this message translates to:
  /// **'⚡  Prioridade Média'**
  String get miHubPriorityMedium;

  /// No description provided for @miHubPriorityLow.
  ///
  /// In pt, this message translates to:
  /// **'⚠️  Baixa Prioridade'**
  String get miHubPriorityLow;

  /// No description provided for @miHubOpportunityScoreLabel.
  ///
  /// In pt, this message translates to:
  /// **'OPPORTUNITY SCORE'**
  String get miHubOpportunityScoreLabel;

  /// No description provided for @miHubScoreSeo.
  ///
  /// In pt, this message translates to:
  /// **'SEO'**
  String get miHubScoreSeo;

  /// No description provided for @miHubScoreMonetization.
  ///
  /// In pt, this message translates to:
  /// **'Monetização'**
  String get miHubScoreMonetization;

  /// No description provided for @miHubScoreCompetition.
  ///
  /// In pt, this message translates to:
  /// **'Concorrência'**
  String get miHubScoreCompetition;

  /// No description provided for @miHubScoreGrowth.
  ///
  /// In pt, this message translates to:
  /// **'Crescimento'**
  String get miHubScoreGrowth;

  /// No description provided for @miHubRevenuePotentialTitle.
  ///
  /// In pt, this message translates to:
  /// **'Revenue Potential'**
  String get miHubRevenuePotentialTitle;

  /// No description provided for @miHubRevenueNoDataHint.
  ///
  /// In pt, this message translates to:
  /// **'Execute o Revenue Planner para estimativas detalhadas.'**
  String get miHubRevenueNoDataHint;

  /// No description provided for @miHubRevenueRangeMonthly.
  ///
  /// In pt, this message translates to:
  /// **'{min} – {max}/mês'**
  String miHubRevenueRangeMonthly(String min, String max);

  /// No description provided for @miHubRevenueSingleMonthly.
  ///
  /// In pt, this message translates to:
  /// **'{max}/mês'**
  String miHubRevenueSingleMonthly(String max);

  /// No description provided for @miHubRevenueAnnual.
  ///
  /// In pt, this message translates to:
  /// **'Anual: {value}'**
  String miHubRevenueAnnual(String value);

  /// No description provided for @miHubLabelDeadline.
  ///
  /// In pt, this message translates to:
  /// **'Prazo'**
  String get miHubLabelDeadline;

  /// No description provided for @miHubLabelConfidence.
  ///
  /// In pt, this message translates to:
  /// **'Confiança'**
  String get miHubLabelConfidence;

  /// No description provided for @miHubMonthsValue.
  ///
  /// In pt, this message translates to:
  /// **'{months, plural, one{1 mês} other{{months} meses}}'**
  String miHubMonthsValue(int months);

  /// No description provided for @miHubInvestmentTitle.
  ///
  /// In pt, this message translates to:
  /// **'Vale a Pena Investir?'**
  String get miHubInvestmentTitle;

  /// No description provided for @miHubInvestmentScoreLabel.
  ///
  /// In pt, this message translates to:
  /// **'Score: {score}/100'**
  String miHubInvestmentScoreLabel(int score);

  /// No description provided for @miHubNextActionsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Próximas Ações Recomendadas'**
  String get miHubNextActionsTitle;

  /// No description provided for @miHubBadgeImpact.
  ///
  /// In pt, this message translates to:
  /// **'Impacto: {value}'**
  String miHubBadgeImpact(String value);

  /// No description provided for @miHubBadgeEffort.
  ///
  /// In pt, this message translates to:
  /// **'Esforço: {value}'**
  String miHubBadgeEffort(String value);

  /// No description provided for @miHubBadgeRoi.
  ///
  /// In pt, this message translates to:
  /// **'ROI: {value}'**
  String miHubBadgeRoi(String value);

  /// No description provided for @miHubCompetitorsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Principais Concorrentes'**
  String get miHubCompetitorsTitle;

  /// No description provided for @miHubCompetitorsViewAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver todos'**
  String get miHubCompetitorsViewAll;

  /// No description provided for @miHubCompetitorsEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Concorrentes ainda não descobertos.'**
  String get miHubCompetitorsEmptyMessage;

  /// No description provided for @miHubCompetitorsEmptyCta.
  ///
  /// In pt, this message translates to:
  /// **'Descobrir Concorrentes'**
  String get miHubCompetitorsEmptyCta;

  /// No description provided for @miHubThCompetitor.
  ///
  /// In pt, this message translates to:
  /// **'Concorrente'**
  String get miHubThCompetitor;

  /// No description provided for @miHubThSimilarity.
  ///
  /// In pt, this message translates to:
  /// **'Similar.'**
  String get miHubThSimilarity;

  /// No description provided for @miHubThAuthority.
  ///
  /// In pt, this message translates to:
  /// **'Autoridade'**
  String get miHubThAuthority;

  /// No description provided for @miHubThScore.
  ///
  /// In pt, this message translates to:
  /// **'Score'**
  String get miHubThScore;

  /// No description provided for @miHubAnalyzeCompetitorCta.
  ///
  /// In pt, this message translates to:
  /// **'Analisar Concorrente'**
  String get miHubAnalyzeCompetitorCta;

  /// No description provided for @miHubGapSummaryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Resumo dos Gaps'**
  String get miHubGapSummaryTitle;

  /// No description provided for @miHubGapDetailCta.
  ///
  /// In pt, this message translates to:
  /// **'Detalhar'**
  String get miHubGapDetailCta;

  /// No description provided for @miHubGapEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Gap Analysis ainda não executada.'**
  String get miHubGapEmptyMessage;

  /// No description provided for @miHubGapEmptyCta.
  ///
  /// In pt, this message translates to:
  /// **'Executar Gap Analysis'**
  String get miHubGapEmptyCta;

  /// No description provided for @miHubGapSeo.
  ///
  /// In pt, this message translates to:
  /// **'SEO Gap'**
  String get miHubGapSeo;

  /// No description provided for @miHubGapContent.
  ///
  /// In pt, this message translates to:
  /// **'Content Gap'**
  String get miHubGapContent;

  /// No description provided for @miHubGapAuthority.
  ///
  /// In pt, this message translates to:
  /// **'Authority Gap'**
  String get miHubGapAuthority;

  /// No description provided for @miHubGapMonetization.
  ///
  /// In pt, this message translates to:
  /// **'Monetization Gap'**
  String get miHubGapMonetization;

  /// No description provided for @miHubGapProduct.
  ///
  /// In pt, this message translates to:
  /// **'Product Gap'**
  String get miHubGapProduct;

  /// No description provided for @miHubGapTotal.
  ///
  /// In pt, this message translates to:
  /// **'Total: {count, plural, one{1 gap identificado} other{{count} gaps identificados}}'**
  String miHubGapTotal(int count);

  /// No description provided for @miHubOpportunitiesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades Detectadas'**
  String get miHubOpportunitiesTitle;

  /// No description provided for @miHubOpportunitiesViewAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver todas'**
  String get miHubOpportunitiesViewAll;

  /// No description provided for @miHubOpportunitiesEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades ainda não mapeadas.'**
  String get miHubOpportunitiesEmptyMessage;

  /// No description provided for @miHubOpportunitiesEmptyCta.
  ///
  /// In pt, this message translates to:
  /// **'Descobrir Oportunidades'**
  String get miHubOpportunitiesEmptyCta;

  /// No description provided for @miHubOppEffortBadge.
  ///
  /// In pt, this message translates to:
  /// **'Esforço: {value}'**
  String miHubOppEffortBadge(String value);

  /// No description provided for @miHubOppRevenueBadge.
  ///
  /// In pt, this message translates to:
  /// **'Receita: {value}'**
  String miHubOppRevenueBadge(String value);

  /// No description provided for @miHubOppDifficultyBadge.
  ///
  /// In pt, this message translates to:
  /// **'Dificuldade: {value}'**
  String miHubOppDifficultyBadge(String value);

  /// No description provided for @miHubScoreLevelHigh.
  ///
  /// In pt, this message translates to:
  /// **'Alto'**
  String get miHubScoreLevelHigh;

  /// No description provided for @miHubScoreLevelMedium.
  ///
  /// In pt, this message translates to:
  /// **'Médio'**
  String get miHubScoreLevelMedium;

  /// No description provided for @miHubScoreLevelLow.
  ///
  /// In pt, this message translates to:
  /// **'Baixo'**
  String get miHubScoreLevelLow;

  /// No description provided for @miHubModulesGridTitle.
  ///
  /// In pt, this message translates to:
  /// **'MÓDULOS DE ANÁLISE'**
  String get miHubModulesGridTitle;

  /// No description provided for @miHubModCompetitors.
  ///
  /// In pt, this message translates to:
  /// **'Concorrentes'**
  String get miHubModCompetitors;

  /// No description provided for @miHubModGapAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Gap Analysis'**
  String get miHubModGapAnalysis;

  /// No description provided for @miHubModOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades'**
  String get miHubModOpportunities;

  /// No description provided for @miHubModNiches.
  ///
  /// In pt, this message translates to:
  /// **'Nichos'**
  String get miHubModNiches;

  /// No description provided for @miHubModContentCluster.
  ///
  /// In pt, this message translates to:
  /// **'Content Cluster'**
  String get miHubModContentCluster;

  /// No description provided for @miHubModRevenuePlanner.
  ///
  /// In pt, this message translates to:
  /// **'Revenue Planner'**
  String get miHubModRevenuePlanner;

  /// No description provided for @miHubRoiTrackerTitle.
  ///
  /// In pt, this message translates to:
  /// **'ROI Tracker'**
  String get miHubRoiTrackerTitle;

  /// No description provided for @miHubRoiOpportunityScoreLabel.
  ///
  /// In pt, this message translates to:
  /// **'Opportunity Score'**
  String get miHubRoiOpportunityScoreLabel;

  /// No description provided for @miHubRoiOpportunitiesLabel.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades'**
  String get miHubRoiOpportunitiesLabel;

  /// No description provided for @miHubRoiAvgScoreLabel.
  ///
  /// In pt, this message translates to:
  /// **'Score Médio'**
  String get miHubRoiAvgScoreLabel;

  /// No description provided for @miHubRoiRevenueLabel.
  ///
  /// In pt, this message translates to:
  /// **'Revenue/mês'**
  String get miHubRoiRevenueLabel;

  /// No description provided for @miHubRoiSavedMessage.
  ///
  /// In pt, this message translates to:
  /// **'Dados registrados no ROI Tracker!'**
  String get miHubRoiSavedMessage;

  /// No description provided for @miHubRoiSavingCta.
  ///
  /// In pt, this message translates to:
  /// **'Registrando...'**
  String get miHubRoiSavingCta;

  /// No description provided for @miHubRoiSaveCta.
  ///
  /// In pt, this message translates to:
  /// **'Registrar no ROI Tracker'**
  String get miHubRoiSaveCta;

  /// No description provided for @miHubRoiSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao registrar: {error}'**
  String miHubRoiSaveError(String error);

  /// No description provided for @calendarTitle.
  ///
  /// In pt, this message translates to:
  /// **'Calendário Editorial'**
  String get calendarTitle;

  /// No description provided for @calendarNewPost.
  ///
  /// In pt, this message translates to:
  /// **'Novo Post'**
  String get calendarNewPost;

  /// No description provided for @calendarEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum post agendado.'**
  String get calendarEmpty;

  /// No description provided for @calendarEmptyHint.
  ///
  /// In pt, this message translates to:
  /// **'Crie seu primeiro post usando o botão abaixo.'**
  String get calendarEmptyHint;

  /// No description provided for @calendarNoTheme.
  ///
  /// In pt, this message translates to:
  /// **'(sem tema)'**
  String get calendarNoTheme;

  /// No description provided for @calendarNewPostSheetTitle.
  ///
  /// In pt, this message translates to:
  /// **'Novo Post no Calendário'**
  String get calendarNewPostSheetTitle;

  /// No description provided for @calendarThemeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tema / Assunto do post *'**
  String get calendarThemeLabel;

  /// No description provided for @calendarThemeHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Dica de segunda sobre produtividade'**
  String get calendarThemeHint;

  /// No description provided for @calendarObjectiveLabel.
  ///
  /// In pt, this message translates to:
  /// **'Objetivo (opcional)'**
  String get calendarObjectiveLabel;

  /// No description provided for @calendarObjectiveHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Gerar engajamento, Vender produto X'**
  String get calendarObjectiveHint;

  /// No description provided for @calendarPlatformLabel.
  ///
  /// In pt, this message translates to:
  /// **'Plataforma'**
  String get calendarPlatformLabel;

  /// No description provided for @calendarFormatLabel.
  ///
  /// In pt, this message translates to:
  /// **'Formato'**
  String get calendarFormatLabel;

  /// No description provided for @calendarSetSuggestedDate.
  ///
  /// In pt, this message translates to:
  /// **'Definir data sugerida'**
  String get calendarSetSuggestedDate;

  /// No description provided for @calendarSuggestedDateValue.
  ///
  /// In pt, this message translates to:
  /// **'Data: {day}/{month}/{year}'**
  String calendarSuggestedDateValue(int day, int month, int year);

  /// No description provided for @calendarAddButton.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar ao Calendário'**
  String get calendarAddButton;

  /// No description provided for @performanceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Performance'**
  String get performanceTitle;

  /// No description provided for @performanceLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar métricas:\n{error}'**
  String performanceLoadError(String error);

  /// No description provided for @performanceEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma métrica registrada ainda.'**
  String get performanceEmpty;

  /// No description provided for @performanceEmptyHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque no + para adicionar uma entrada.'**
  String get performanceEmptyHint;

  /// No description provided for @performanceDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir métrica'**
  String get performanceDeleteTitle;

  /// No description provided for @performanceDeleteConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Deseja excluir a métrica de {platform}?'**
  String performanceDeleteConfirm(String platform);

  /// No description provided for @performanceDeleteSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Métrica excluída com sucesso.'**
  String get performanceDeleteSuccess;

  /// No description provided for @performanceDeleteError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao excluir: {error}'**
  String performanceDeleteError(String error);

  /// No description provided for @performanceAddSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Métrica adicionada com sucesso!'**
  String get performanceAddSuccess;

  /// No description provided for @performanceMetricImpressions.
  ///
  /// In pt, this message translates to:
  /// **'Impressões'**
  String get performanceMetricImpressions;

  /// No description provided for @performanceMetricClicks.
  ///
  /// In pt, this message translates to:
  /// **'Cliques'**
  String get performanceMetricClicks;

  /// No description provided for @performanceMetricEngagement.
  ///
  /// In pt, this message translates to:
  /// **'Eng%'**
  String get performanceMetricEngagement;

  /// No description provided for @performanceMetricConversion.
  ///
  /// In pt, this message translates to:
  /// **'Conv%'**
  String get performanceMetricConversion;

  /// No description provided for @performanceScoreLabel.
  ///
  /// In pt, this message translates to:
  /// **'Score'**
  String get performanceScoreLabel;

  /// No description provided for @performanceSelectPlatform.
  ///
  /// In pt, this message translates to:
  /// **'Selecione uma plataforma.'**
  String get performanceSelectPlatform;

  /// No description provided for @performanceSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao salvar: {error}'**
  String performanceSaveError(String error);

  /// No description provided for @performanceNewMetricTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nova Métrica'**
  String get performanceNewMetricTitle;

  /// No description provided for @performanceFieldPlatform.
  ///
  /// In pt, this message translates to:
  /// **'Plataforma'**
  String get performanceFieldPlatform;

  /// No description provided for @performanceFieldLikes.
  ///
  /// In pt, this message translates to:
  /// **'Curtidas'**
  String get performanceFieldLikes;

  /// No description provided for @performanceFieldComments.
  ///
  /// In pt, this message translates to:
  /// **'Comentários'**
  String get performanceFieldComments;

  /// No description provided for @performanceFieldShares.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhamentos'**
  String get performanceFieldShares;

  /// No description provided for @performanceFieldSaves.
  ///
  /// In pt, this message translates to:
  /// **'Salvamentos'**
  String get performanceFieldSaves;

  /// No description provided for @performanceFieldLeads.
  ///
  /// In pt, this message translates to:
  /// **'Leads'**
  String get performanceFieldLeads;

  /// No description provided for @performanceFieldSales.
  ///
  /// In pt, this message translates to:
  /// **'Vendas'**
  String get performanceFieldSales;

  /// No description provided for @performanceFieldRevenue.
  ///
  /// In pt, this message translates to:
  /// **'Receita (R\$)'**
  String get performanceFieldRevenue;

  /// No description provided for @performanceFieldNotes.
  ///
  /// In pt, this message translates to:
  /// **'Notas (opcional)'**
  String get performanceFieldNotes;

  /// No description provided for @contentLibraryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Biblioteca de Conteúdo'**
  String get contentLibraryTitle;

  /// No description provided for @contentLibraryNewItem.
  ///
  /// In pt, this message translates to:
  /// **'Novo Item'**
  String get contentLibraryNewItem;

  /// No description provided for @contentLibraryEmptyType.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum item deste tipo.'**
  String get contentLibraryEmptyType;

  /// No description provided for @contentLibraryEmptyProject.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum item neste projeto.'**
  String get contentLibraryEmptyProject;

  /// No description provided for @contentLibraryEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Biblioteca vazia.'**
  String get contentLibraryEmpty;

  /// No description provided for @contentLibraryEmptyHint.
  ///
  /// In pt, this message translates to:
  /// **'Adicione itens usando o botão abaixo.'**
  String get contentLibraryEmptyHint;

  /// No description provided for @contentLibraryDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir item'**
  String get contentLibraryDeleteTitle;

  /// No description provided for @contentLibraryDeleteConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Deseja excluir \"{title}\"?'**
  String contentLibraryDeleteConfirm(String title);

  /// No description provided for @contentLibraryDeleteError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao excluir: {error}'**
  String contentLibraryDeleteError(String error);

  /// No description provided for @personasTitle.
  ///
  /// In pt, this message translates to:
  /// **'Personas / Marcas'**
  String get personasTitle;

  /// No description provided for @personasNewPersona.
  ///
  /// In pt, this message translates to:
  /// **'Nova Persona'**
  String get personasNewPersona;

  /// No description provided for @personasEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma persona ainda.'**
  String get personasEmpty;

  /// No description provided for @personasEmptyHint.
  ///
  /// In pt, this message translates to:
  /// **'Crie a primeira usando o botão abaixo.'**
  String get personasEmptyHint;

  /// No description provided for @personasGlobalSection.
  ///
  /// In pt, this message translates to:
  /// **'Personas Globais'**
  String get personasGlobalSection;

  /// No description provided for @personasMineSection.
  ///
  /// In pt, this message translates to:
  /// **'Minhas Personas'**
  String get personasMineSection;

  /// No description provided for @personasToneLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tom: {tone}'**
  String personasToneLabel(String tone);

  /// No description provided for @personasDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir persona'**
  String get personasDeleteTitle;

  /// No description provided for @personasDeleteConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Deseja excluir \"{name}\"?'**
  String personasDeleteConfirm(String name);

  /// No description provided for @personaTrainingTitle.
  ///
  /// In pt, this message translates to:
  /// **'Treinamento: {name}'**
  String personaTrainingTitle(String name);

  /// No description provided for @personaTrainingLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar treinamentos: {error}'**
  String personaTrainingLoadError(String error);

  /// No description provided for @personaTrainingHistoryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Histórico de Treinamentos'**
  String get personaTrainingHistoryTitle;

  /// No description provided for @personaTrainingSummaryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Resumo do Treinamento'**
  String get personaTrainingSummaryTitle;

  /// No description provided for @personaTrainingItemsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Itens treinados'**
  String get personaTrainingItemsLabel;

  /// No description provided for @personaTrainingItemsCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 item} other{{count} itens}}'**
  String personaTrainingItemsCount(int count);

  /// No description provided for @personaTrainingToneProfileLabel.
  ///
  /// In pt, this message translates to:
  /// **'Perfil de Tom (mais recente)'**
  String get personaTrainingToneProfileLabel;

  /// No description provided for @personaTrainingVocabularyLabel.
  ///
  /// In pt, this message translates to:
  /// **'Vocabulário Combinado'**
  String get personaTrainingVocabularyLabel;

  /// No description provided for @personaTrainingValuesLabel.
  ///
  /// In pt, this message translates to:
  /// **'Valores Combinados'**
  String get personaTrainingValuesLabel;

  /// No description provided for @personaTrainingDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Remover treinamento?'**
  String get personaTrainingDeleteTitle;

  /// No description provided for @personaTrainingDeleteBody.
  ///
  /// In pt, this message translates to:
  /// **'Este item de treinamento será removido permanentemente da persona.'**
  String get personaTrainingDeleteBody;

  /// No description provided for @personaTrainingRemove.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get personaTrainingRemove;

  /// No description provided for @personaTrainingNoTitle.
  ///
  /// In pt, this message translates to:
  /// **'Item sem título'**
  String get personaTrainingNoTitle;

  /// No description provided for @personaTrainingToneLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tom: '**
  String get personaTrainingToneLabel;

  /// No description provided for @personaTrainingItemVocabularyLabel.
  ///
  /// In pt, this message translates to:
  /// **'Vocabulário:'**
  String get personaTrainingItemVocabularyLabel;

  /// No description provided for @personaTrainingMoreWords.
  ///
  /// In pt, this message translates to:
  /// **'+{count} palavras'**
  String personaTrainingMoreWords(int count);

  /// No description provided for @personaTrainingEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum treinamento ainda.'**
  String get personaTrainingEmptyTitle;

  /// No description provided for @personaTrainingEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Analise um item no Cofre de Conhecimento e clique em Treinar Persona.'**
  String get personaTrainingEmptyBody;

  /// No description provided for @personaFormEditTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar Persona'**
  String get personaFormEditTitle;

  /// No description provided for @personaFormNewTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nova Persona'**
  String get personaFormNewTitle;

  /// No description provided for @personaFormNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome da Persona / Marca *'**
  String get personaFormNameLabel;

  /// No description provided for @personaFormNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Marca Pessoal do João'**
  String get personaFormNameHint;

  /// No description provided for @personaFormRequired.
  ///
  /// In pt, this message translates to:
  /// **'Obrigatório'**
  String get personaFormRequired;

  /// No description provided for @personaFormNicheLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nicho / Segmento'**
  String get personaFormNicheLabel;

  /// No description provided for @personaFormNicheHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Marketing Digital, Fitness, Gastronomia'**
  String get personaFormNicheHint;

  /// No description provided for @personaFormToneLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tom de Voz'**
  String get personaFormToneLabel;

  /// No description provided for @personaFormToneHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Descontraído e inspirador, Profissional e direto'**
  String get personaFormToneHint;

  /// No description provided for @personaFormAudienceLabel.
  ///
  /// In pt, this message translates to:
  /// **'Público-alvo'**
  String get personaFormAudienceLabel;

  /// No description provided for @personaFormAudienceHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Empreendedores iniciantes de 25–40 anos'**
  String get personaFormAudienceHint;

  /// No description provided for @personaFormDescLabel.
  ///
  /// In pt, this message translates to:
  /// **'Descrição / Posicionamento'**
  String get personaFormDescLabel;

  /// No description provided for @personaFormDescHint.
  ///
  /// In pt, this message translates to:
  /// **'Descreva a essência desta persona ou marca...'**
  String get personaFormDescHint;

  /// No description provided for @personaFormWordsUseLabel.
  ///
  /// In pt, this message translates to:
  /// **'Palavras que DEVE usar (separadas por vírgula)'**
  String get personaFormWordsUseLabel;

  /// No description provided for @personaFormWordsUseHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: inovação, transformação, resultado'**
  String get personaFormWordsUseHint;

  /// No description provided for @personaFormWordsAvoidLabel.
  ///
  /// In pt, this message translates to:
  /// **'Palavras que DEVE EVITAR (separadas por vírgula)'**
  String get personaFormWordsAvoidLabel;

  /// No description provided for @personaFormWordsAvoidHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: barato, simples, fácil'**
  String get personaFormWordsAvoidHint;

  /// No description provided for @personaFormGlobalTitle.
  ///
  /// In pt, this message translates to:
  /// **'Persona Global'**
  String get personaFormGlobalTitle;

  /// No description provided for @personaFormGlobalSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Visível para todos os usuários (apenas admin)'**
  String get personaFormGlobalSubtitle;

  /// No description provided for @personaFormSaveChanges.
  ///
  /// In pt, this message translates to:
  /// **'Salvar Alterações'**
  String get personaFormSaveChanges;

  /// No description provided for @personaFormCreate.
  ///
  /// In pt, this message translates to:
  /// **'Criar Persona'**
  String get personaFormCreate;

  /// No description provided for @campaignsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Campanhas'**
  String get campaignsTitle;

  /// No description provided for @campaignsRefreshTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get campaignsRefreshTooltip;

  /// No description provided for @campaignsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma campanha'**
  String get campaignsEmpty;

  /// No description provided for @campaignsEmptyHint.
  ///
  /// In pt, this message translates to:
  /// **'Acesse o Cofre de Conhecimento, analise um item e crie sua primeira campanha com IA.'**
  String get campaignsEmptyHint;

  /// No description provided for @campaignsGoToVault.
  ///
  /// In pt, this message translates to:
  /// **'Ir ao Cofre'**
  String get campaignsGoToVault;

  /// No description provided for @campaignsDurationDays.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{1 dia} other{{count} dias}}'**
  String campaignsDurationDays(int count);

  /// No description provided for @campaignsDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir campanha?'**
  String get campaignsDeleteTitle;

  /// No description provided for @campaignsDeleteConfirm.
  ///
  /// In pt, this message translates to:
  /// **'A campanha \"{title}\" será removida.'**
  String campaignsDeleteConfirm(String title);

  /// No description provided for @campaignBuilderTitle.
  ///
  /// In pt, this message translates to:
  /// **'Criar Campanha'**
  String get campaignBuilderTitle;

  /// No description provided for @campaignBuilderItemNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Item não encontrado.'**
  String get campaignBuilderItemNotFound;

  /// No description provided for @campaignBuilderNoAnalysisBody.
  ///
  /// In pt, this message translates to:
  /// **'Analise o item primeiro para criar uma campanha.'**
  String get campaignBuilderNoAnalysisBody;

  /// No description provided for @campaignBuilderObjectiveLabel.
  ///
  /// In pt, this message translates to:
  /// **'Objetivo da Campanha'**
  String get campaignBuilderObjectiveLabel;

  /// No description provided for @campaignBuilderDurationLabel.
  ///
  /// In pt, this message translates to:
  /// **'Duração'**
  String get campaignBuilderDurationLabel;

  /// No description provided for @campaignBuilderChannelsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Canais (selecione pelo menos 1)'**
  String get campaignBuilderChannelsLabel;

  /// No description provided for @campaignBuilderGenerating.
  ///
  /// In pt, this message translates to:
  /// **'Gerando campanha…'**
  String get campaignBuilderGenerating;

  /// No description provided for @campaignBuilderGenerateCta.
  ///
  /// In pt, this message translates to:
  /// **'Gerar Campanha com IA'**
  String get campaignBuilderGenerateCta;

  /// No description provided for @campaignBuilderGenerateLabel.
  ///
  /// In pt, this message translates to:
  /// **'Gerar Campanha'**
  String get campaignBuilderGenerateLabel;

  /// No description provided for @campaignBuilderSelectChannelWarning.
  ///
  /// In pt, this message translates to:
  /// **'Selecione pelo menos um canal.'**
  String get campaignBuilderSelectChannelWarning;

  /// No description provided for @campaignBuilderGenerateError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao gerar campanha. Tente novamente.'**
  String get campaignBuilderGenerateError;

  /// No description provided for @campaignDetailTitle.
  ///
  /// In pt, this message translates to:
  /// **'Campanha'**
  String get campaignDetailTitle;

  /// No description provided for @campaignDetailNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Campanha não encontrada.'**
  String get campaignDetailNotFound;

  /// No description provided for @campaignDetailOverviewTitle.
  ///
  /// In pt, this message translates to:
  /// **'Visão Geral'**
  String get campaignDetailOverviewTitle;

  /// No description provided for @campaignDetailKeyMessagesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Mensagens-chave'**
  String get campaignDetailKeyMessagesTitle;

  /// No description provided for @campaignDetailExpectedResultsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Resultados Esperados'**
  String get campaignDetailExpectedResultsTitle;

  /// No description provided for @campaignDetailCalendarTitle.
  ///
  /// In pt, this message translates to:
  /// **'Calendário de Conteúdo'**
  String get campaignDetailCalendarTitle;

  /// No description provided for @campaignDetailEmailSequenceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sequência de Emails'**
  String get campaignDetailEmailSequenceTitle;

  /// No description provided for @campaignDetailMetricsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Métricas de Sucesso'**
  String get campaignDetailMetricsTitle;

  /// No description provided for @campaignDetailCopied.
  ///
  /// In pt, this message translates to:
  /// **'Copiado!'**
  String get campaignDetailCopied;

  /// No description provided for @campaignDetailHookLabel.
  ///
  /// In pt, this message translates to:
  /// **'Hook'**
  String get campaignDetailHookLabel;

  /// No description provided for @campaignDetailCtaLabel.
  ///
  /// In pt, this message translates to:
  /// **'CTA'**
  String get campaignDetailCtaLabel;

  /// No description provided for @campaignDetailBriefLabel.
  ///
  /// In pt, this message translates to:
  /// **'Brief'**
  String get campaignDetailBriefLabel;

  /// No description provided for @campaignDetailTopicLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tópico'**
  String get campaignDetailTopicLabel;

  /// No description provided for @roiTrackerTitle.
  ///
  /// In pt, this message translates to:
  /// **'ROI Tracker'**
  String get roiTrackerTitle;

  /// No description provided for @roiTrackerTypeRevenue.
  ///
  /// In pt, this message translates to:
  /// **'Receita'**
  String get roiTrackerTypeRevenue;

  /// No description provided for @roiTrackerTypeInvestment.
  ///
  /// In pt, this message translates to:
  /// **'Investimento'**
  String get roiTrackerTypeInvestment;

  /// No description provided for @roiTrackerTypeTraffic.
  ///
  /// In pt, this message translates to:
  /// **'Tráfego'**
  String get roiTrackerTypeTraffic;

  /// No description provided for @roiTrackerTypeLeads.
  ///
  /// In pt, this message translates to:
  /// **'Leads'**
  String get roiTrackerTypeLeads;

  /// No description provided for @roiTrackerTypeConversions.
  ///
  /// In pt, this message translates to:
  /// **'Conversões'**
  String get roiTrackerTypeConversions;

  /// No description provided for @roiTrackerTypeOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades'**
  String get roiTrackerTypeOpportunities;

  /// No description provided for @roiTrackerTypeRevenuePotential.
  ///
  /// In pt, this message translates to:
  /// **'Receita Potencial'**
  String get roiTrackerTypeRevenuePotential;

  /// No description provided for @roiTrackerTypeRevenueEstimated.
  ///
  /// In pt, this message translates to:
  /// **'Receita Estimada'**
  String get roiTrackerTypeRevenueEstimated;

  /// No description provided for @roiTrackerTypeHoursSaved.
  ///
  /// In pt, this message translates to:
  /// **'Horas Economizadas'**
  String get roiTrackerTypeHoursSaved;

  /// No description provided for @roiTrackerTypeStrategiesExecuted.
  ///
  /// In pt, this message translates to:
  /// **'Estratégias Executadas'**
  String get roiTrackerTypeStrategiesExecuted;

  /// No description provided for @roiTrackerTypeCampaignsExecuted.
  ///
  /// In pt, this message translates to:
  /// **'Campanhas Executadas'**
  String get roiTrackerTypeCampaignsExecuted;

  /// No description provided for @roiTrackerTypeDecisionsMade.
  ///
  /// In pt, this message translates to:
  /// **'Decisões Tomadas'**
  String get roiTrackerTypeDecisionsMade;

  /// No description provided for @roiTrackerTypeOpportunityScore.
  ///
  /// In pt, this message translates to:
  /// **'Score de Oportunidade'**
  String get roiTrackerTypeOpportunityScore;

  /// No description provided for @roiTrackerTypeAvgOpportunityScore.
  ///
  /// In pt, this message translates to:
  /// **'Score Médio de Oportunidade'**
  String get roiTrackerTypeAvgOpportunityScore;

  /// No description provided for @roiTrackerTypeOther.
  ///
  /// In pt, this message translates to:
  /// **'Outro'**
  String get roiTrackerTypeOther;

  /// No description provided for @roiTrackerInvalidValue.
  ///
  /// In pt, this message translates to:
  /// **'Valor inválido'**
  String get roiTrackerInvalidValue;

  /// No description provided for @roiTrackerRecordsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Registros'**
  String get roiTrackerRecordsTitle;

  /// No description provided for @roiTrackerEmptyRecords.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum registro ainda'**
  String get roiTrackerEmptyRecords;

  /// No description provided for @roiTrackerSummaryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Resumo ROI'**
  String get roiTrackerSummaryTitle;

  /// No description provided for @roiTrackerRoiPercent.
  ///
  /// In pt, this message translates to:
  /// **'ROI: {value}%'**
  String roiTrackerRoiPercent(String value);

  /// No description provided for @roiTrackerExecutiveDashboardTitle.
  ///
  /// In pt, this message translates to:
  /// **'Dashboard Executivo'**
  String get roiTrackerExecutiveDashboardTitle;

  /// No description provided for @roiTrackerRevenueSectionTitle.
  ///
  /// In pt, this message translates to:
  /// **'RECEITA'**
  String get roiTrackerRevenueSectionTitle;

  /// No description provided for @roiTrackerRevenueRegistered.
  ///
  /// In pt, this message translates to:
  /// **'Registrada'**
  String get roiTrackerRevenueRegistered;

  /// No description provided for @roiTrackerRevenuePotentialLabel.
  ///
  /// In pt, this message translates to:
  /// **'Potencial'**
  String get roiTrackerRevenuePotentialLabel;

  /// No description provided for @roiTrackerRevenueEstimatedLabel.
  ///
  /// In pt, this message translates to:
  /// **'Estimada'**
  String get roiTrackerRevenueEstimatedLabel;

  /// No description provided for @roiTrackerActivitySectionTitle.
  ///
  /// In pt, this message translates to:
  /// **'ATIVIDADE'**
  String get roiTrackerActivitySectionTitle;

  /// No description provided for @roiTrackerHoursSavedShort.
  ///
  /// In pt, this message translates to:
  /// **'Horas Econ.'**
  String get roiTrackerHoursSavedShort;

  /// No description provided for @roiTrackerNewRecordTitle.
  ///
  /// In pt, this message translates to:
  /// **'Novo Registro'**
  String get roiTrackerNewRecordTitle;

  /// No description provided for @roiTrackerTypeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get roiTrackerTypeLabel;

  /// No description provided for @roiTrackerProjectOptionalLabel.
  ///
  /// In pt, this message translates to:
  /// **'Projeto (opcional)'**
  String get roiTrackerProjectOptionalLabel;

  /// No description provided for @roiTrackerNoneOption.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum'**
  String get roiTrackerNoneOption;

  /// No description provided for @roiTrackerValueLabel.
  ///
  /// In pt, this message translates to:
  /// **'Valor *'**
  String get roiTrackerValueLabel;

  /// No description provided for @roiTrackerNotesOptionalLabel.
  ///
  /// In pt, this message translates to:
  /// **'Observações (opcional)'**
  String get roiTrackerNotesOptionalLabel;

  /// No description provided for @roiTrackerNewRecord.
  ///
  /// In pt, this message translates to:
  /// **'Novo Registro'**
  String get roiTrackerNewRecord;

  /// No description provided for @roiTrackerProjectOptional.
  ///
  /// In pt, this message translates to:
  /// **'Projeto (opcional)'**
  String get roiTrackerProjectOptional;

  /// No description provided for @roiTrackerProjectNone.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum'**
  String get roiTrackerProjectNone;

  /// No description provided for @roiTrackerNotesLabel.
  ///
  /// In pt, this message translates to:
  /// **'Observações (opcional)'**
  String get roiTrackerNotesLabel;

  /// No description provided for @knowledgeVaultTitle.
  ///
  /// In pt, this message translates to:
  /// **'Cofre de Conhecimento'**
  String get knowledgeVaultTitle;

  /// No description provided for @knowledgeVaultFilterAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get knowledgeVaultFilterAll;

  /// No description provided for @knowledgeVaultEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum item ainda'**
  String get knowledgeVaultEmptyTitle;

  /// No description provided for @knowledgeVaultEmptyProjectTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum item em {project}'**
  String knowledgeVaultEmptyProjectTitle(String project);

  /// No description provided for @knowledgeVaultThisProject.
  ///
  /// In pt, this message translates to:
  /// **'este projeto'**
  String get knowledgeVaultThisProject;

  /// No description provided for @knowledgeVaultLinkToProject.
  ///
  /// In pt, this message translates to:
  /// **'Vincular \"{title}\" a projeto'**
  String knowledgeVaultLinkToProject(String title);

  /// No description provided for @knowledgeVaultCurrentProject.
  ///
  /// In pt, this message translates to:
  /// **'Projeto atual: {name}'**
  String knowledgeVaultCurrentProject(String name);

  /// No description provided for @knowledgeVaultNoProject.
  ///
  /// In pt, this message translates to:
  /// **'Sem projeto'**
  String get knowledgeVaultNoProject;

  /// No description provided for @knowledgeVaultUnlinkedSnack.
  ///
  /// In pt, this message translates to:
  /// **'Item desvinculado do projeto'**
  String get knowledgeVaultUnlinkedSnack;

  /// No description provided for @knowledgeVaultLinkedSnack.
  ///
  /// In pt, this message translates to:
  /// **'Item vinculado a {name}'**
  String knowledgeVaultLinkedSnack(String name);

  /// No description provided for @knowledgeVaultNicheLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nicho: {niche}'**
  String knowledgeVaultNicheLabel(String niche);

  /// No description provided for @knowledgeVaultAnalyzeWithAi.
  ///
  /// In pt, this message translates to:
  /// **'Analisar com IA'**
  String get knowledgeVaultAnalyzeWithAi;

  /// No description provided for @knowledgeVaultAnalyzeError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao analisar: {error}'**
  String knowledgeVaultAnalyzeError(String error);

  /// No description provided for @knowledgeVaultEdit.
  ///
  /// In pt, this message translates to:
  /// **'Editar'**
  String get knowledgeVaultEdit;

  /// No description provided for @knowledgeVaultExplainWithIve.
  ///
  /// In pt, this message translates to:
  /// **'Explicar com IVE'**
  String get knowledgeVaultExplainWithIve;

  /// No description provided for @knowledgeVaultExplainPrompt.
  ///
  /// In pt, this message translates to:
  /// **'Resuma e explique o documento \"{title}\".'**
  String knowledgeVaultExplainPrompt(String title);

  /// No description provided for @knowledgeVaultDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get knowledgeVaultDelete;

  /// No description provided for @knowledgeVaultDeleteError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao excluir: {error}'**
  String knowledgeVaultDeleteError(String error);

  /// No description provided for @knowledgeVaultStatusAnalyzed.
  ///
  /// In pt, this message translates to:
  /// **'Analisado'**
  String get knowledgeVaultStatusAnalyzed;

  /// No description provided for @knowledgeVaultStatusProcessing.
  ///
  /// In pt, this message translates to:
  /// **'Processando'**
  String get knowledgeVaultStatusProcessing;

  /// No description provided for @knowledgeVaultStatusError.
  ///
  /// In pt, this message translates to:
  /// **'Erro'**
  String get knowledgeVaultStatusError;

  /// No description provided for @knowledgeVaultStatusPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendente'**
  String get knowledgeVaultStatusPending;

  /// No description provided for @knowledgeFormContentEmptyError.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdo não pode estar vazio'**
  String get knowledgeFormContentEmptyError;

  /// No description provided for @knowledgeFormSavedWithProject.
  ///
  /// In pt, this message translates to:
  /// **'Item salvo em {project}'**
  String knowledgeFormSavedWithProject(String project);

  /// No description provided for @knowledgeFormSavedNoProject.
  ///
  /// In pt, this message translates to:
  /// **'Item salvo'**
  String get knowledgeFormSavedNoProject;

  /// No description provided for @knowledgeFormExtracting.
  ///
  /// In pt, this message translates to:
  /// **'Extraindo texto...'**
  String get knowledgeFormExtracting;

  /// No description provided for @knowledgeFormCharsExtracted.
  ///
  /// In pt, this message translates to:
  /// **'{count} caracteres extraídos'**
  String knowledgeFormCharsExtracted(int count);

  /// No description provided for @knowledgeFormChangeFile.
  ///
  /// In pt, this message translates to:
  /// **'Trocar'**
  String get knowledgeFormChangeFile;

  /// No description provided for @knowledgeFormSelectFilePrompt.
  ///
  /// In pt, this message translates to:
  /// **'Clique para selecionar arquivo'**
  String get knowledgeFormSelectFilePrompt;

  /// No description provided for @knowledgeFormFileTypesHint.
  ///
  /// In pt, this message translates to:
  /// **'PDF, DOCX, TXT ou CSV'**
  String get knowledgeFormFileTypesHint;

  /// No description provided for @knowledgeFormImportError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao importar: {error}'**
  String knowledgeFormImportError(String error);

  /// No description provided for @knowledgeFormDriveDefaultName.
  ///
  /// In pt, this message translates to:
  /// **'arquivo do Drive'**
  String get knowledgeFormDriveDefaultName;

  /// No description provided for @knowledgeFormSelectDriveFile.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar arquivo do Drive'**
  String get knowledgeFormSelectDriveFile;

  /// No description provided for @knowledgeFormDriveFileTypesHint.
  ///
  /// In pt, this message translates to:
  /// **'Google Docs, PDF, DOCX, TXT ou CSV'**
  String get knowledgeFormDriveFileTypesHint;

  /// No description provided for @knowledgeFormProjectLabel.
  ///
  /// In pt, this message translates to:
  /// **'Projeto (opcional)'**
  String get knowledgeFormProjectLabel;

  /// No description provided for @knowledgeFormNoProject.
  ///
  /// In pt, this message translates to:
  /// **'Sem projeto'**
  String get knowledgeFormNoProject;

  /// No description provided for @knowledgeFormEditTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar Conhecimento'**
  String get knowledgeFormEditTitle;

  /// No description provided for @knowledgeFormNewTitle.
  ///
  /// In pt, this message translates to:
  /// **'Novo Conhecimento'**
  String get knowledgeFormNewTitle;

  /// No description provided for @knowledgeFormSourceTypeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo de fonte'**
  String get knowledgeFormSourceTypeLabel;

  /// No description provided for @knowledgeFormSourceManual.
  ///
  /// In pt, this message translates to:
  /// **'Texto Manual'**
  String get knowledgeFormSourceManual;

  /// No description provided for @knowledgeFormSourceUrl.
  ///
  /// In pt, this message translates to:
  /// **'URL'**
  String get knowledgeFormSourceUrl;

  /// No description provided for @knowledgeFormSourceFile.
  ///
  /// In pt, this message translates to:
  /// **'Arquivo'**
  String get knowledgeFormSourceFile;

  /// No description provided for @knowledgeFormSourceDrive.
  ///
  /// In pt, this message translates to:
  /// **'Google Drive'**
  String get knowledgeFormSourceDrive;

  /// No description provided for @knowledgeFormTitleLabel.
  ///
  /// In pt, this message translates to:
  /// **'Título *'**
  String get knowledgeFormTitleLabel;

  /// No description provided for @knowledgeFormTitleHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Livro sobre Marketing Digital'**
  String get knowledgeFormTitleHint;

  /// No description provided for @knowledgeFormTitleRequired.
  ///
  /// In pt, this message translates to:
  /// **'Informe o título.'**
  String get knowledgeFormTitleRequired;

  /// No description provided for @knowledgeFormImportFromDrive.
  ///
  /// In pt, this message translates to:
  /// **'Importar do Google Drive'**
  String get knowledgeFormImportFromDrive;

  /// No description provided for @knowledgeFormImportFile.
  ///
  /// In pt, this message translates to:
  /// **'Importar Arquivo (PDF, DOCX, TXT, CSV)'**
  String get knowledgeFormImportFile;

  /// No description provided for @knowledgeFormUrlLabel.
  ///
  /// In pt, this message translates to:
  /// **'URL do conteúdo *'**
  String get knowledgeFormUrlLabel;

  /// No description provided for @knowledgeFormUrlHint.
  ///
  /// In pt, this message translates to:
  /// **'https://docs.google.com/document/d/...'**
  String get knowledgeFormUrlHint;

  /// No description provided for @knowledgeFormUrlRequired.
  ///
  /// In pt, this message translates to:
  /// **'Informe a URL.'**
  String get knowledgeFormUrlRequired;

  /// No description provided for @knowledgeFormUrlInvalid.
  ///
  /// In pt, this message translates to:
  /// **'URL deve começar com http ou https.'**
  String get knowledgeFormUrlInvalid;

  /// No description provided for @knowledgeFormGoogleDocsHintTitle.
  ///
  /// In pt, this message translates to:
  /// **'📄 Para Google Docs / Livros:'**
  String get knowledgeFormGoogleDocsHintTitle;

  /// No description provided for @knowledgeFormGoogleDocsHintBody.
  ///
  /// In pt, this message translates to:
  /// **'1. Abra o documento no Google Docs\n2. Clique em Compartilhar\n3. Mude para \"Qualquer pessoa com o link pode visualizar\"\n4. Copie o link e cole aqui'**
  String get knowledgeFormGoogleDocsHintBody;

  /// No description provided for @knowledgeFormContentLabel.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdo *'**
  String get knowledgeFormContentLabel;

  /// No description provided for @knowledgeFormContentHint.
  ///
  /// In pt, this message translates to:
  /// **'Cole aqui o texto do livro, artigo, post, roteiro ou qualquer conteúdo que deseja analisar…'**
  String get knowledgeFormContentHint;

  /// No description provided for @knowledgeFormContentTooShort.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdo muito curto (mínimo 20 caracteres).'**
  String get knowledgeFormContentTooShort;

  /// No description provided for @knowledgeFormNicheLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nicho (opcional)'**
  String get knowledgeFormNicheLabel;

  /// No description provided for @knowledgeFormNicheHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Marketing Digital, Saúde, Finanças'**
  String get knowledgeFormNicheHint;

  /// No description provided for @knowledgeFormAudienceLabel.
  ///
  /// In pt, this message translates to:
  /// **'Audiência-alvo (opcional)'**
  String get knowledgeFormAudienceLabel;

  /// No description provided for @knowledgeFormAudienceHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Empreendedores iniciantes, Mães de primeira viagem'**
  String get knowledgeFormAudienceHint;

  /// No description provided for @knowledgeFormLanguageLabel.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get knowledgeFormLanguageLabel;

  /// No description provided for @knowledgeFormLanguagePtBr.
  ///
  /// In pt, this message translates to:
  /// **'Português (BR)'**
  String get knowledgeFormLanguagePtBr;

  /// No description provided for @knowledgeFormLanguageEnUs.
  ///
  /// In pt, this message translates to:
  /// **'English (US)'**
  String get knowledgeFormLanguageEnUs;

  /// No description provided for @knowledgeFormLanguageEs.
  ///
  /// In pt, this message translates to:
  /// **'Español'**
  String get knowledgeFormLanguageEs;

  /// No description provided for @knowledgeFormSaving.
  ///
  /// In pt, this message translates to:
  /// **'Salvando…'**
  String get knowledgeFormSaving;

  /// No description provided for @knowledgeFormAddToVault.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar ao Cofre'**
  String get knowledgeFormAddToVault;

  /// No description provided for @knowledgeFormClickToSelectFile.
  ///
  /// In pt, this message translates to:
  /// **'Clique para selecionar arquivo'**
  String get knowledgeFormClickToSelectFile;

  /// No description provided for @knowledgeFormFileTypes.
  ///
  /// In pt, this message translates to:
  /// **'PDF, DOCX, TXT ou CSV'**
  String get knowledgeFormFileTypes;

  /// No description provided for @knowledgeFormPdfWarning.
  ///
  /// In pt, this message translates to:
  /// **'PDF deve ter texto selecionável (não imagem escaneada). Para melhores resultados, use TXT ou DOCX.'**
  String get knowledgeFormPdfWarning;

  /// No description provided for @knowledgeFormDriveFileTypes.
  ///
  /// In pt, this message translates to:
  /// **'Google Docs, PDF, DOCX, TXT ou CSV'**
  String get knowledgeFormDriveFileTypes;

  /// No description provided for @knowledgeVaultRefreshTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get knowledgeVaultRefreshTooltip;

  /// No description provided for @knowledgeVaultNewItem.
  ///
  /// In pt, this message translates to:
  /// **'Novo Item'**
  String get knowledgeVaultNewItem;

  /// No description provided for @knowledgeVaultEmptyProjectBody.
  ///
  /// In pt, this message translates to:
  /// **'Adicione conhecimento a este projeto para que a IA extraia insights personalizados.'**
  String get knowledgeVaultEmptyProjectBody;

  /// No description provided for @knowledgeVaultEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Adicione textos, URLs ou arquivos para que a IA extraia insights de marketing, SEO e monetização.'**
  String get knowledgeVaultEmptyBody;

  /// No description provided for @knowledgeVaultAddKnowledge.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Conhecimento'**
  String get knowledgeVaultAddKnowledge;

  /// No description provided for @knowledgeVaultViewAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Ver Análise'**
  String get knowledgeVaultViewAnalysis;

  /// No description provided for @knowledgeVaultProcessing.
  ///
  /// In pt, this message translates to:
  /// **'Processando…'**
  String get knowledgeVaultProcessing;

  /// No description provided for @knowledgeVaultAddToProject.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar a Projeto'**
  String get knowledgeVaultAddToProject;

  /// No description provided for @knowledgeVaultChangeProject.
  ///
  /// In pt, this message translates to:
  /// **'Trocar Projeto'**
  String get knowledgeVaultChangeProject;

  /// No description provided for @knowledgeVaultDeleteItemTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir item?'**
  String get knowledgeVaultDeleteItemTitle;

  /// No description provided for @knowledgeVaultDeleteItemBody.
  ///
  /// In pt, this message translates to:
  /// **'O item \"{title}\" e sua análise serão removidos.'**
  String knowledgeVaultDeleteItemBody(String title);

  /// No description provided for @websiteAnalyzerAnalyzeButton.
  ///
  /// In pt, this message translates to:
  /// **'Analisar Site'**
  String get websiteAnalyzerAnalyzeButton;

  /// No description provided for @websiteAnalyzerAnalyzeError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao analisar: {error}'**
  String websiteAnalyzerAnalyzeError(String error);

  /// No description provided for @websiteAnalyzerLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar: {error}'**
  String websiteAnalyzerLoadError(String error);

  /// No description provided for @websiteAnalyzerScoreSite.
  ///
  /// In pt, this message translates to:
  /// **'Site'**
  String get websiteAnalyzerScoreSite;

  /// No description provided for @websiteAnalyzerScoreAdsense.
  ///
  /// In pt, this message translates to:
  /// **'AdSense'**
  String get websiteAnalyzerScoreAdsense;

  /// No description provided for @websiteAnalyzerHeaderTitle.
  ///
  /// In pt, this message translates to:
  /// **'Analisar Website'**
  String get websiteAnalyzerHeaderTitle;

  /// No description provided for @websiteAnalyzerHeaderBody.
  ///
  /// In pt, this message translates to:
  /// **'Analise seu site e receba um diagnóstico completo com SEO, AdSense e oportunidades de monetização.'**
  String get websiteAnalyzerHeaderBody;

  /// No description provided for @websiteAnalyzerUrlLabel.
  ///
  /// In pt, this message translates to:
  /// **'URL do site (ex: https://meusite.com)'**
  String get websiteAnalyzerUrlLabel;

  /// No description provided for @websiteAnalyzerUrlHint.
  ///
  /// In pt, this message translates to:
  /// **'https://meusite.com'**
  String get websiteAnalyzerUrlHint;

  /// No description provided for @websiteAnalyzerUrlRequired.
  ///
  /// In pt, this message translates to:
  /// **'Por favor, insira a URL do site'**
  String get websiteAnalyzerUrlRequired;

  /// No description provided for @websiteAnalyzerUrlInvalid.
  ///
  /// In pt, this message translates to:
  /// **'URL inválida. Use o formato https://meusite.com'**
  String get websiteAnalyzerUrlInvalid;

  /// No description provided for @websiteAnalyzerAnalyzing.
  ///
  /// In pt, this message translates to:
  /// **'Analisando...'**
  String get websiteAnalyzerAnalyzing;

  /// No description provided for @websiteAnalyzerPreviousTitle.
  ///
  /// In pt, this message translates to:
  /// **'Análises Anteriores'**
  String get websiteAnalyzerPreviousTitle;

  /// No description provided for @websiteAnalyzerEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma análise ainda'**
  String get websiteAnalyzerEmptyTitle;

  /// No description provided for @websiteAnalyzerEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Insira uma URL acima para começar'**
  String get websiteAnalyzerEmptyBody;

  /// No description provided for @websiteResultTitle.
  ///
  /// In pt, this message translates to:
  /// **'Análise do Site'**
  String get websiteResultTitle;

  /// No description provided for @websiteResultSavedSnack.
  ///
  /// In pt, this message translates to:
  /// **'Análise já salva no banco de dados!'**
  String get websiteResultSavedSnack;

  /// No description provided for @websiteResultSaveToVault.
  ///
  /// In pt, this message translates to:
  /// **'Salvar no Cofre'**
  String get websiteResultSaveToVault;

  /// No description provided for @websiteResultCreateStrategy.
  ///
  /// In pt, this message translates to:
  /// **'Criar Estratégia'**
  String get websiteResultCreateStrategy;

  /// No description provided for @websiteResultExplainPrompt.
  ///
  /// In pt, this message translates to:
  /// **'Explique os resultados da análise do site {url} (score geral {scoreWebsite}, SEO {scoreSeo}, AdSense {scoreAdsense}, monetização {scoreMonetization}).'**
  String websiteResultExplainPrompt(String url, String scoreWebsite,
      String scoreSeo, String scoreAdsense, String scoreMonetization);

  /// No description provided for @websiteResultLoadingAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Carregando análise...'**
  String get websiteResultLoadingAnalysis;

  /// No description provided for @websiteResultLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar análise'**
  String get websiteResultLoadError;

  /// No description provided for @websiteResultScoreWebsite.
  ///
  /// In pt, this message translates to:
  /// **'Website'**
  String get websiteResultScoreWebsite;

  /// No description provided for @websiteResultScoreSeo.
  ///
  /// In pt, this message translates to:
  /// **'SEO'**
  String get websiteResultScoreSeo;

  /// No description provided for @websiteResultScoreMonetization.
  ///
  /// In pt, this message translates to:
  /// **'Monetização'**
  String get websiteResultScoreMonetization;

  /// No description provided for @websiteResultSectionDiagnostic.
  ///
  /// In pt, this message translates to:
  /// **'Diagnóstico'**
  String get websiteResultSectionDiagnostic;

  /// No description provided for @websiteResultSectionStrengths.
  ///
  /// In pt, this message translates to:
  /// **'Pontos Fortes'**
  String get websiteResultSectionStrengths;

  /// No description provided for @websiteResultSectionWeaknesses.
  ///
  /// In pt, this message translates to:
  /// **'Pontos Fracos'**
  String get websiteResultSectionWeaknesses;

  /// No description provided for @websiteResultSectionCriticalIssues.
  ///
  /// In pt, this message translates to:
  /// **'Problemas Críticos'**
  String get websiteResultSectionCriticalIssues;

  /// No description provided for @websiteResultSectionSeoAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Análise SEO'**
  String get websiteResultSectionSeoAnalysis;

  /// No description provided for @websiteResultSectionAdsenseAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Análise AdSense'**
  String get websiteResultSectionAdsenseAnalysis;

  /// No description provided for @websiteResultSectionQuickWins.
  ///
  /// In pt, this message translates to:
  /// **'Vitórias Rápidas'**
  String get websiteResultSectionQuickWins;

  /// No description provided for @websiteResultSectionPlan7Days.
  ///
  /// In pt, this message translates to:
  /// **'Plano 7 Dias'**
  String get websiteResultSectionPlan7Days;

  /// No description provided for @websiteResultSectionPlan30Days.
  ///
  /// In pt, this message translates to:
  /// **'Plano 30 Dias'**
  String get websiteResultSectionPlan30Days;

  /// No description provided for @websiteResultSectionArticleIdeas.
  ///
  /// In pt, this message translates to:
  /// **'Ideias de Artigos'**
  String get websiteResultSectionArticleIdeas;

  /// No description provided for @websiteResultSectionMonetizationOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades de Monetização'**
  String get websiteResultSectionMonetizationOpportunities;

  /// No description provided for @websiteResultSectionCommercialOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades Comerciais'**
  String get websiteResultSectionCommercialOpportunities;

  /// No description provided for @websiteResultMainTopicsLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tópicos Principais:'**
  String get websiteResultMainTopicsLabel;

  /// No description provided for @websiteResultPolicyPrivacy.
  ///
  /// In pt, this message translates to:
  /// **'Política de Privacidade'**
  String get websiteResultPolicyPrivacy;

  /// No description provided for @websiteResultPolicyAbout.
  ///
  /// In pt, this message translates to:
  /// **'Sobre'**
  String get websiteResultPolicyAbout;

  /// No description provided for @websiteResultPolicyContact.
  ///
  /// In pt, this message translates to:
  /// **'Contato'**
  String get websiteResultPolicyContact;

  /// No description provided for @websiteResultCreateCampaign.
  ///
  /// In pt, this message translates to:
  /// **'Criar Campanha'**
  String get websiteResultCreateCampaign;

  /// No description provided for @websiteResultSeoPlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano SEO'**
  String get websiteResultSeoPlan;

  /// No description provided for @websiteResultAdsensePlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano AdSense'**
  String get websiteResultAdsensePlan;

  /// No description provided for @websiteResultSeoPlanComingSoon.
  ///
  /// In pt, this message translates to:
  /// **'Plano SEO — disponível na Fase 9'**
  String get websiteResultSeoPlanComingSoon;

  /// No description provided for @websiteResultAdsensePlanComingSoon.
  ///
  /// In pt, this message translates to:
  /// **'Plano AdSense — disponível na Fase 9'**
  String get websiteResultAdsensePlanComingSoon;

  /// No description provided for @projectCommandTitle.
  ///
  /// In pt, this message translates to:
  /// **'Project Command Center'**
  String get projectCommandTitle;

  /// No description provided for @projectCommandRefreshTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get projectCommandRefreshTooltip;

  /// No description provided for @projectCommandLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Erro: {error}'**
  String projectCommandLoadError(String error);

  /// No description provided for @projectCommandEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum projeto ainda'**
  String get projectCommandEmptyTitle;

  /// No description provided for @projectCommandEmptySubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Adicione seu primeiro projeto'**
  String get projectCommandEmptySubtitle;

  /// No description provided for @projectCommandNewProject.
  ///
  /// In pt, this message translates to:
  /// **'Novo Projeto'**
  String get projectCommandNewProject;

  /// No description provided for @projectCommandFieldNameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome do projeto *'**
  String get projectCommandFieldNameLabel;

  /// No description provided for @projectCommandFieldNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Blog de Finanças Pessoais'**
  String get projectCommandFieldNameHint;

  /// No description provided for @projectCommandFieldDescLabel.
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get projectCommandFieldDescLabel;

  /// No description provided for @projectCommandFieldDescHint.
  ///
  /// In pt, this message translates to:
  /// **'Descreva o projeto brevemente'**
  String get projectCommandFieldDescHint;

  /// No description provided for @projectCommandFieldUrlLabel.
  ///
  /// In pt, this message translates to:
  /// **'URL (opcional)'**
  String get projectCommandFieldUrlLabel;

  /// No description provided for @projectCommandFieldUrlHint.
  ///
  /// In pt, this message translates to:
  /// **'https://...'**
  String get projectCommandFieldUrlHint;

  /// No description provided for @projectCommandFieldTypeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get projectCommandFieldTypeLabel;

  /// No description provided for @projectCommandDeleteConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar exclusão'**
  String get projectCommandDeleteConfirmTitle;

  /// No description provided for @projectCommandDeleteConfirmBody.
  ///
  /// In pt, this message translates to:
  /// **'Excluir \"{name}\"?\nEsta ação não pode ser desfeita.'**
  String projectCommandDeleteConfirmBody(String name);

  /// No description provided for @projectCommandDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get projectCommandDelete;

  /// No description provided for @projectCommandDeleteError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao excluir: {error}'**
  String projectCommandDeleteError(String error);

  /// No description provided for @projectCommandNoKnowledgeWarning.
  ///
  /// In pt, this message translates to:
  /// **'Adicione conhecimentos ao projeto antes de analisar.'**
  String get projectCommandNoKnowledgeWarning;

  /// No description provided for @projectCommandAnalyzeWithKnowledgeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Analisar com Conhecimento'**
  String get projectCommandAnalyzeWithKnowledgeLabel;

  /// No description provided for @projectCommandAnalyzingSnackbar.
  ///
  /// In pt, this message translates to:
  /// **'Analisando projeto \"{name}\" com {count} conhecimento(s)…'**
  String projectCommandAnalyzingSnackbar(String name, int count);

  /// No description provided for @projectCommandOpportunitiesGenerated.
  ///
  /// In pt, this message translates to:
  /// **'{count} oportunidade(s) gerada(s) para \"{name}\"!'**
  String projectCommandOpportunitiesGenerated(int count, String name);

  /// No description provided for @projectCommandView.
  ///
  /// In pt, this message translates to:
  /// **'Ver'**
  String get projectCommandView;

  /// No description provided for @projectCommandAnalyzeError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao analisar: {error}'**
  String projectCommandAnalyzeError(String error);

  /// No description provided for @projectCommandAutoBootstrapLabel.
  ///
  /// In pt, this message translates to:
  /// **'Gerar oportunidades, ações e plano de receita automaticamente'**
  String get projectCommandAutoBootstrapLabel;

  /// No description provided for @projectCommandStatusActive.
  ///
  /// In pt, this message translates to:
  /// **'Ativo'**
  String get projectCommandStatusActive;

  /// No description provided for @projectCommandStatusCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Concluído'**
  String get projectCommandStatusCompleted;

  /// No description provided for @projectCommandStatusPaused.
  ///
  /// In pt, this message translates to:
  /// **'Pausado'**
  String get projectCommandStatusPaused;

  /// No description provided for @projectCommandStatusIdea.
  ///
  /// In pt, this message translates to:
  /// **'Ideia'**
  String get projectCommandStatusIdea;

  /// No description provided for @projectCommandRevenueNotEstimated.
  ///
  /// In pt, this message translates to:
  /// **'Não estimado'**
  String get projectCommandRevenueNotEstimated;

  /// No description provided for @projectCommandRevenueNotEstimatedYet.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não estimado'**
  String get projectCommandRevenueNotEstimatedYet;

  /// No description provided for @projectCommandStatOpportunity.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidade'**
  String get projectCommandStatOpportunity;

  /// No description provided for @projectCommandStatPotential.
  ///
  /// In pt, this message translates to:
  /// **'Potencial'**
  String get projectCommandStatPotential;

  /// No description provided for @projectCommandStatDeadline.
  ///
  /// In pt, this message translates to:
  /// **'Prazo'**
  String get projectCommandStatDeadline;

  /// No description provided for @projectCommandActionDetail.
  ///
  /// In pt, this message translates to:
  /// **'Detalhe'**
  String get projectCommandActionDetail;

  /// No description provided for @projectCommandActionAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Análise'**
  String get projectCommandActionAnalysis;

  /// No description provided for @projectCommandActionActivate.
  ///
  /// In pt, this message translates to:
  /// **'Ativar'**
  String get projectCommandActionActivate;

  /// No description provided for @projectCommandEcoScoreLabel.
  ///
  /// In pt, this message translates to:
  /// **'eco score'**
  String get projectCommandEcoScoreLabel;

  /// No description provided for @projectCommandSectionRecommendation.
  ///
  /// In pt, this message translates to:
  /// **'Recomendação IA'**
  String get projectCommandSectionRecommendation;

  /// No description provided for @projectCommandSectionEcosystemScores.
  ///
  /// In pt, this message translates to:
  /// **'Scores do Ecossistema'**
  String get projectCommandSectionEcosystemScores;

  /// No description provided for @projectCommandScoreStrategicFit.
  ///
  /// In pt, this message translates to:
  /// **'Fit Estratégico'**
  String get projectCommandScoreStrategicFit;

  /// No description provided for @projectCommandScoreSynergy.
  ///
  /// In pt, this message translates to:
  /// **'Sinergia'**
  String get projectCommandScoreSynergy;

  /// No description provided for @projectCommandScoreRoi.
  ///
  /// In pt, this message translates to:
  /// **'ROI'**
  String get projectCommandScoreRoi;

  /// No description provided for @projectCommandScoreMomentum.
  ///
  /// In pt, this message translates to:
  /// **'Momentum'**
  String get projectCommandScoreMomentum;

  /// No description provided for @projectCommandScoreExecution.
  ///
  /// In pt, this message translates to:
  /// **'Execução'**
  String get projectCommandScoreExecution;

  /// No description provided for @projectCommandActionsStats.
  ///
  /// In pt, this message translates to:
  /// **'Ações: {completed}/{total} ({rate}%)'**
  String projectCommandActionsStats(int completed, int total, int rate);

  /// No description provided for @projectCommandTotalRoi.
  ///
  /// In pt, this message translates to:
  /// **'ROI total: {value}'**
  String projectCommandTotalRoi(String value);

  /// No description provided for @projectCommandSectionProjectMetrics.
  ///
  /// In pt, this message translates to:
  /// **'Métricas do Projeto'**
  String get projectCommandSectionProjectMetrics;

  /// No description provided for @projectCommandMetricComplexity.
  ///
  /// In pt, this message translates to:
  /// **'Complexidade'**
  String get projectCommandMetricComplexity;

  /// No description provided for @projectCommandSectionStrengths.
  ///
  /// In pt, this message translates to:
  /// **'Pontos Fortes'**
  String get projectCommandSectionStrengths;

  /// No description provided for @projectCommandSectionQuickWins.
  ///
  /// In pt, this message translates to:
  /// **'Quick Wins'**
  String get projectCommandSectionQuickWins;

  /// No description provided for @projectCommandSectionNextActions.
  ///
  /// In pt, this message translates to:
  /// **'Próximas Ações'**
  String get projectCommandSectionNextActions;

  /// No description provided for @projectCommandSectionIntelligenceProfile.
  ///
  /// In pt, this message translates to:
  /// **'Perfil de Inteligência'**
  String get projectCommandSectionIntelligenceProfile;

  /// No description provided for @projectCommandSectionResourceAllocation.
  ///
  /// In pt, this message translates to:
  /// **'Alocação de Recursos'**
  String get projectCommandSectionResourceAllocation;

  /// No description provided for @projectCommandViewMarketAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Ver Análise de Mercado'**
  String get projectCommandViewMarketAnalysis;

  /// No description provided for @projectCommandViewKnowledge.
  ///
  /// In pt, this message translates to:
  /// **'Ver Conhecimentos'**
  String get projectCommandViewKnowledge;

  /// No description provided for @projectCommandAnalyzeWithAi.
  ///
  /// In pt, this message translates to:
  /// **'Analisar com IA'**
  String get projectCommandAnalyzeWithAi;

  /// No description provided for @projectCommandActionPause.
  ///
  /// In pt, this message translates to:
  /// **'Pausar'**
  String get projectCommandActionPause;

  /// No description provided for @projectCommandActionComplete.
  ///
  /// In pt, this message translates to:
  /// **'Concluir'**
  String get projectCommandActionComplete;

  /// No description provided for @projectCommandDeleteProject.
  ///
  /// In pt, this message translates to:
  /// **'Excluir Projeto'**
  String get projectCommandDeleteProject;

  /// No description provided for @projectCommandMaturityLabel.
  ///
  /// In pt, this message translates to:
  /// **'Maturidade: {label}'**
  String projectCommandMaturityLabel(String label);

  /// No description provided for @projectCommandNiche.
  ///
  /// In pt, this message translates to:
  /// **'Nicho'**
  String get projectCommandNiche;

  /// No description provided for @projectCommandAudience.
  ///
  /// In pt, this message translates to:
  /// **'Público'**
  String get projectCommandAudience;

  /// No description provided for @projectCommandMonetization.
  ///
  /// In pt, this message translates to:
  /// **'Monetização'**
  String get projectCommandMonetization;

  /// No description provided for @projectCommandValueProposition.
  ///
  /// In pt, this message translates to:
  /// **'Proposta'**
  String get projectCommandValueProposition;

  /// No description provided for @projectCommandIdentifiedTopics.
  ///
  /// In pt, this message translates to:
  /// **'Tópicos identificados'**
  String get projectCommandIdentifiedTopics;

  /// No description provided for @projectCommandKnowledgeGaps.
  ///
  /// In pt, this message translates to:
  /// **'Lacunas de conhecimento'**
  String get projectCommandKnowledgeGaps;

  /// No description provided for @projectCommandRelatedProjects.
  ///
  /// In pt, this message translates to:
  /// **'Relacionados'**
  String get projectCommandRelatedProjects;

  /// No description provided for @projectCommandAskIveAboutProfile.
  ///
  /// In pt, this message translates to:
  /// **'Perguntar à IVE sobre este perfil'**
  String get projectCommandAskIveAboutProfile;

  /// No description provided for @projectCommandResourceLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar a alocação de recursos deste projeto.'**
  String get projectCommandResourceLoadError;

  /// No description provided for @projectCommandInvalidBudgetValue.
  ///
  /// In pt, this message translates to:
  /// **'Valor inválido. Use apenas números, ex: 1500.00'**
  String get projectCommandInvalidBudgetValue;

  /// No description provided for @projectCommandSavedAllocation.
  ///
  /// In pt, this message translates to:
  /// **'Salvo: {hours}h · {amount} ({currency})'**
  String projectCommandSavedAllocation(
      int hours, String amount, String currency);

  /// No description provided for @projectCommandEditingBadge.
  ///
  /// In pt, this message translates to:
  /// **'EDITANDO'**
  String get projectCommandEditingBadge;

  /// No description provided for @projectCommandHoursLabel.
  ///
  /// In pt, this message translates to:
  /// **'Horas'**
  String get projectCommandHoursLabel;

  /// No description provided for @projectCommandBudgetLabel.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento ({currency})'**
  String projectCommandBudgetLabel(String currency);

  /// No description provided for @projectCommandSaveAllocationError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao salvar: {error}'**
  String projectCommandSaveAllocationError(String error);

  /// No description provided for @projectCommandAnalyzeResourcesWithIve.
  ///
  /// In pt, this message translates to:
  /// **'Analisar recursos com a IVE'**
  String get projectCommandAnalyzeResourcesWithIve;

  /// No description provided for @opportunityDetailTitle.
  ///
  /// In pt, this message translates to:
  /// **'Detalhe da Oportunidade'**
  String get opportunityDetailTitle;

  /// No description provided for @opportunityDetailLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Erro: {error}'**
  String opportunityDetailLoadError(String error);

  /// No description provided for @opportunityDetailNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidade não encontrada.'**
  String get opportunityDetailNotFound;

  /// No description provided for @opportunityDetailApprovedSentTitle.
  ///
  /// In pt, this message translates to:
  /// **'Aprovada e enviada ao Action Engine!'**
  String get opportunityDetailApprovedSentTitle;

  /// No description provided for @opportunityDetailViewAction.
  ///
  /// In pt, this message translates to:
  /// **'Ver Ação'**
  String get opportunityDetailViewAction;

  /// No description provided for @opportunityDetailApprovedTitle.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidade aprovada!'**
  String get opportunityDetailApprovedTitle;

  /// No description provided for @opportunityDetailDeleteConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir oportunidade?'**
  String get opportunityDetailDeleteConfirmTitle;

  /// No description provided for @opportunityDetailDeleteConfirmBody.
  ///
  /// In pt, this message translates to:
  /// **'\"{title}\" será removida permanentemente.'**
  String opportunityDetailDeleteConfirmBody(String title);

  /// No description provided for @opportunityDetailDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get opportunityDetailDelete;

  /// No description provided for @opportunityDetailApproveAndCreateMenu.
  ///
  /// In pt, this message translates to:
  /// **'Aprovar e criar ação'**
  String get opportunityDetailApproveAndCreateMenu;

  /// No description provided for @opportunityDetailScoreBreakdownTitle.
  ///
  /// In pt, this message translates to:
  /// **'Score Breakdown'**
  String get opportunityDetailScoreBreakdownTitle;

  /// No description provided for @opportunityDetailOriginTitle.
  ///
  /// In pt, this message translates to:
  /// **'Origem'**
  String get opportunityDetailOriginTitle;

  /// No description provided for @opportunityDetailSourcesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Fontes'**
  String get opportunityDetailSourcesTitle;

  /// No description provided for @opportunityDetailAiRationaleTitle.
  ///
  /// In pt, this message translates to:
  /// **'Justificativa da IA'**
  String get opportunityDetailAiRationaleTitle;

  /// No description provided for @opportunityDetailConfidenceTitle.
  ///
  /// In pt, this message translates to:
  /// **'Confiança'**
  String get opportunityDetailConfidenceTitle;

  /// No description provided for @opportunityDetailRisksTitle.
  ///
  /// In pt, this message translates to:
  /// **'Riscos'**
  String get opportunityDetailRisksTitle;

  /// No description provided for @opportunityDetailNextStepsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Próximos Passos'**
  String get opportunityDetailNextStepsTitle;

  /// No description provided for @opportunityDetailScoreMarket.
  ///
  /// In pt, this message translates to:
  /// **'Mercado'**
  String get opportunityDetailScoreMarket;

  /// No description provided for @opportunityDetailScoreRevenue.
  ///
  /// In pt, this message translates to:
  /// **'Receita'**
  String get opportunityDetailScoreRevenue;

  /// No description provided for @opportunityDetailScoreCompetition.
  ///
  /// In pt, this message translates to:
  /// **'Competição'**
  String get opportunityDetailScoreCompetition;

  /// No description provided for @opportunityDetailScoreSynergy.
  ///
  /// In pt, this message translates to:
  /// **'Sinergia'**
  String get opportunityDetailScoreSynergy;

  /// No description provided for @opportunityDetailScoreStrategicFit.
  ///
  /// In pt, this message translates to:
  /// **'Fit Estratégico'**
  String get opportunityDetailScoreStrategicFit;

  /// No description provided for @opportunityDetailOriginGeneratedBy.
  ///
  /// In pt, this message translates to:
  /// **'Gerada por'**
  String get opportunityDetailOriginGeneratedBy;

  /// No description provided for @opportunityDetailOriginProject.
  ///
  /// In pt, this message translates to:
  /// **'Projeto'**
  String get opportunityDetailOriginProject;

  /// No description provided for @opportunityDetailOriginMarketAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Análise de mercado'**
  String get opportunityDetailOriginMarketAnalysis;

  /// No description provided for @opportunityDetailOriginCreatedAt.
  ///
  /// In pt, this message translates to:
  /// **'Criada em'**
  String get opportunityDetailOriginCreatedAt;

  /// No description provided for @opportunityDetailConfidenceHigh.
  ///
  /// In pt, this message translates to:
  /// **'Alta'**
  String get opportunityDetailConfidenceHigh;

  /// No description provided for @opportunityDetailConfidenceMedium.
  ///
  /// In pt, this message translates to:
  /// **'Média'**
  String get opportunityDetailConfidenceMedium;

  /// No description provided for @opportunityDetailConfidenceLow.
  ///
  /// In pt, this message translates to:
  /// **'Baixa'**
  String get opportunityDetailConfidenceLow;

  /// No description provided for @opportunityDetailApproveCreateActionButton.
  ///
  /// In pt, this message translates to:
  /// **'Aprovar e Criar Ação'**
  String get opportunityDetailApproveCreateActionButton;

  /// No description provided for @opportunityDetailApprovedCreateActionError.
  ///
  /// In pt, this message translates to:
  /// **'Aprovada! Erro ao criar ação: {error}'**
  String opportunityDetailApprovedCreateActionError(String error);

  /// No description provided for @opportunityDetailSendToActionEngine.
  ///
  /// In pt, this message translates to:
  /// **'Enviar para Action Engine'**
  String get opportunityDetailSendToActionEngine;

  /// No description provided for @opportunityDetailActionCreatedTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ação criada no Action Engine!'**
  String get opportunityDetailActionCreatedTitle;

  /// No description provided for @opportunityDetailGenericError.
  ///
  /// In pt, this message translates to:
  /// **'Erro: {error}'**
  String opportunityDetailGenericError(String error);

  /// No description provided for @opportunityDetailAskIveButton.
  ///
  /// In pt, this message translates to:
  /// **'Perguntar à IVE sobre esta oportunidade'**
  String get opportunityDetailAskIveButton;

  /// No description provided for @upgradeFaqTitle.
  ///
  /// In pt, this message translates to:
  /// **'Perguntas frequentes'**
  String get upgradeFaqTitle;

  /// No description provided for @upgradeFaqFreeLimitQ.
  ///
  /// In pt, this message translates to:
  /// **'Como funciona o limite gratuito?'**
  String get upgradeFaqFreeLimitQ;

  /// No description provided for @upgradeFaqFreeLimitA.
  ///
  /// In pt, this message translates to:
  /// **'Você pode fazer até {limit} análises de IA por mês no plano gratuito (análise de site, estratégia, mercado, etc). O contador reinicia todo dia 1º.'**
  String upgradeFaqFreeLimitA(int limit);

  /// No description provided for @upgradeFaqCancelQ.
  ///
  /// In pt, this message translates to:
  /// **'Posso cancelar a qualquer momento?'**
  String get upgradeFaqCancelQ;

  /// No description provided for @upgradeFaqCancelA.
  ///
  /// In pt, this message translates to:
  /// **'Sim. O plano Pro é mensal e você pode cancelar a qualquer momento sem taxa.'**
  String get upgradeFaqCancelA;

  /// No description provided for @upgradeFaqDataQ.
  ///
  /// In pt, this message translates to:
  /// **'Meus dados ficam salvos se eu cancelar?'**
  String get upgradeFaqDataQ;

  /// No description provided for @upgradeFaqDataA.
  ///
  /// In pt, this message translates to:
  /// **'Sim. Seu histórico e projetos ficam salvos, mas o limite de análises volta para o do plano gratuito.'**
  String get upgradeFaqDataA;

  /// No description provided for @aiConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar análise'**
  String get aiConfirmTitle;

  /// No description provided for @aiConfirmCostSingle.
  ///
  /// In pt, this message translates to:
  /// **'\"{label}\" vai consumir 1 das suas análises mensais.'**
  String aiConfirmCostSingle(String label);

  /// No description provided for @aiConfirmCostMultiple.
  ///
  /// In pt, this message translates to:
  /// **'\"{label}\" pode consumir até {units} das suas análises mensais.'**
  String aiConfirmCostMultiple(String label, int units);

  /// No description provided for @aiConfirmRemaining.
  ///
  /// In pt, this message translates to:
  /// **'Restam {remaining} de {limit} análises este mês.'**
  String aiConfirmRemaining(int remaining, int limit);

  /// No description provided for @aiConfirmCancel.
  ///
  /// In pt, this message translates to:
  /// **'CANCELAR'**
  String get aiConfirmCancel;

  /// No description provided for @aiConfirmConfirm.
  ///
  /// In pt, this message translates to:
  /// **'CONFIRMAR'**
  String get aiConfirmConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
