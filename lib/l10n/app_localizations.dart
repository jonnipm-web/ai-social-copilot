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
