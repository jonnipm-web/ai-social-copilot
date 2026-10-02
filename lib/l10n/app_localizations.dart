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

  /// No description provided for @iveChatAskLabel.
  ///
  /// In pt, this message translates to:
  /// **'Perguntar à IVE'**
  String get iveChatAskLabel;

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

  /// No description provided for @actionEngineTypeTask.
  ///
  /// In pt, this message translates to:
  /// **'Tarefa'**
  String get actionEngineTypeTask;

  /// No description provided for @actionEngineTypeOpportunity.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidade'**
  String get actionEngineTypeOpportunity;

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

  /// No description provided for @miCompetitorEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Descubra concorrentes diretos, indiretos e aspiracionais e compare posicionamento, autoridade e relevância.'**
  String get miCompetitorEmptyBody;

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

  /// No description provided for @miCompetitorTypeDirect.
  ///
  /// In pt, this message translates to:
  /// **'Direto'**
  String get miCompetitorTypeDirect;

  /// No description provided for @miCompetitorTypeIndirect.
  ///
  /// In pt, this message translates to:
  /// **'Indireto'**
  String get miCompetitorTypeIndirect;

  /// No description provided for @miCompetitorTypeAspirational.
  ///
  /// In pt, this message translates to:
  /// **'Aspiracional'**
  String get miCompetitorTypeAspirational;

  /// No description provided for @miGapTitle.
  ///
  /// In pt, this message translates to:
  /// **'Análise de Lacunas'**
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

  /// No description provided for @miGapEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Identifique lacunas de conteúdo, SEO, autoridade, monetização e produto que seus concorrentes já exploram e você ainda não.'**
  String get miGapEmptyBody;

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

  /// No description provided for @miNicheEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Descubra e ranqueie nichos e sub-nichos com maior potencial dentro do seu mercado.'**
  String get miNicheEmptyBody;

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

  /// No description provided for @miOpportunityEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Encontre oportunidades de negócio priorizadas por score e potencial dentro do seu mercado.'**
  String get miOpportunityEmptyBody;

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
  /// **'Cluster de Conteúdo'**
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

  /// No description provided for @miClusterEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Gere um cluster de conteúdo com silos, artigos e um roteiro editorial a partir de uma palavra-chave principal.'**
  String get miClusterEmptyBody;

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
  /// **'Planejador de Receita'**
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

  /// No description provided for @miRevenueEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Projete cenários de receita conservador, moderado e agressivo com base em dados reais do seu projeto.'**
  String get miRevenueEmptyBody;

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

  /// No description provided for @miHubNichesSummaryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nichos'**
  String get miHubNichesSummaryTitle;

  /// No description provided for @miHubNichesViewAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver todos'**
  String get miHubNichesViewAll;

  /// No description provided for @miHubNichesEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum nicho avaliado ainda. Descubra e avalie nichos para encontrar o melhor candidato para este projeto.'**
  String get miHubNichesEmptyMessage;

  /// No description provided for @miHubNichesEmptyCta.
  ///
  /// In pt, this message translates to:
  /// **'Descobrir Nichos'**
  String get miHubNichesEmptyCta;

  /// No description provided for @miHubNichesBestCandidateLabel.
  ///
  /// In pt, this message translates to:
  /// **'Melhor candidato'**
  String get miHubNichesBestCandidateLabel;

  /// No description provided for @miHubNichesCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{Nenhum nicho avaliado} =1{1 nicho avaliado} other{{count} nichos avaliados}}'**
  String miHubNichesCount(int count);

  /// No description provided for @miHubClusterSummaryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Cluster de Conteúdo'**
  String get miHubClusterSummaryTitle;

  /// No description provided for @miHubClusterViewAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver todos'**
  String get miHubClusterViewAll;

  /// No description provided for @miHubClusterEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum cluster de conteúdo gerado ainda. Gere um cluster para planejar sua estratégia de conteúdo em torno da palavra-chave principal.'**
  String get miHubClusterEmptyMessage;

  /// No description provided for @miHubClusterEmptyCta.
  ///
  /// In pt, this message translates to:
  /// **'Gerar Cluster'**
  String get miHubClusterEmptyCta;

  /// No description provided for @miHubClusterCountBadge.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{0 clusters} =1{1 cluster} other{{count} clusters}}'**
  String miHubClusterCountBadge(int count);

  /// No description provided for @miHubClusterArticlesBadge.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{0 artigos} =1{1 artigo} other{{count} artigos}}'**
  String miHubClusterArticlesBadge(int count);

  /// No description provided for @miHubRevenuePlannerSummaryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Planejamento de Receita'**
  String get miHubRevenuePlannerSummaryTitle;

  /// No description provided for @miHubRevenuePlannerViewAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver todos'**
  String get miHubRevenuePlannerViewAll;

  /// No description provided for @miHubRevenuePlannerEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum plano de receita criado ainda. Crie um plano para projetar cenários de receita com base em dados reais.'**
  String get miHubRevenuePlannerEmptyMessage;

  /// No description provided for @miHubRevenuePlannerEmptyCta.
  ///
  /// In pt, this message translates to:
  /// **'Criar Plano'**
  String get miHubRevenuePlannerEmptyCta;

  /// No description provided for @miHubRevenuePlannerMonthly.
  ///
  /// In pt, this message translates to:
  /// **'{value}/mês (moderado)'**
  String miHubRevenuePlannerMonthly(String value);

  /// No description provided for @miHubRevenueMilestonesBadge.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{0 marcos} =1{1 marco} other{{count} marcos}}'**
  String miHubRevenueMilestonesBadge(int count);

  /// No description provided for @miHubRevenueSourcesBadge.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =0{0 fontes de receita} =1{1 fonte de receita} other{{count} fontes de receita}}'**
  String miHubRevenueSourcesBadge(int count);

  /// No description provided for @miHubRevenueNextMilestoneLabel.
  ///
  /// In pt, this message translates to:
  /// **'Próximo marco'**
  String get miHubRevenueNextMilestoneLabel;

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

  /// No description provided for @knowledgeStrategyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Estratégia'**
  String get knowledgeStrategyTitle;

  /// No description provided for @knowledgeStrategyGenericError.
  ///
  /// In pt, this message translates to:
  /// **'Erro: {error}'**
  String knowledgeStrategyGenericError(String error);

  /// No description provided for @knowledgeStrategyItemNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Item não encontrado.'**
  String get knowledgeStrategyItemNotFound;

  /// No description provided for @knowledgeStrategyAnalysisRequiredTitle.
  ///
  /// In pt, this message translates to:
  /// **'Análise necessária'**
  String get knowledgeStrategyAnalysisRequiredTitle;

  /// No description provided for @knowledgeStrategyAnalysisRequiredBody.
  ///
  /// In pt, this message translates to:
  /// **'Primeiro analise este item com IA para depois gerar a estratégia.'**
  String get knowledgeStrategyAnalysisRequiredBody;

  /// No description provided for @knowledgeStrategyBackAndAnalyze.
  ///
  /// In pt, this message translates to:
  /// **'Voltar e Analisar'**
  String get knowledgeStrategyBackAndAnalyze;

  /// No description provided for @knowledgeStrategyGenerateTitle.
  ///
  /// In pt, this message translates to:
  /// **'Gerar Estratégia Completa'**
  String get knowledgeStrategyGenerateTitle;

  /// No description provided for @knowledgeStrategyGenerateBody.
  ///
  /// In pt, this message translates to:
  /// **'A IA vai criar um plano estratégico completo com público-alvo, posicionamento, canais, funil, oportunidades comerciais e plano de crescimento.'**
  String get knowledgeStrategyGenerateBody;

  /// No description provided for @knowledgeStrategyGenerating.
  ///
  /// In pt, this message translates to:
  /// **'Gerando estratégia…'**
  String get knowledgeStrategyGenerating;

  /// No description provided for @knowledgeStrategyGenerateButton.
  ///
  /// In pt, this message translates to:
  /// **'Gerar Estratégia'**
  String get knowledgeStrategyGenerateButton;

  /// No description provided for @knowledgeStrategyRegenerateButton.
  ///
  /// In pt, this message translates to:
  /// **'Regenerar Estratégia'**
  String get knowledgeStrategyRegenerateButton;

  /// No description provided for @knowledgeStrategyCopied.
  ///
  /// In pt, this message translates to:
  /// **'Copiado!'**
  String get knowledgeStrategyCopied;

  /// No description provided for @knowledgeStrategyCopiedKeyword.
  ///
  /// In pt, this message translates to:
  /// **'Copiado: {keyword}'**
  String knowledgeStrategyCopiedKeyword(String keyword);

  /// No description provided for @knowledgeStrategySectionSummary.
  ///
  /// In pt, this message translates to:
  /// **'Resumo Estratégico'**
  String get knowledgeStrategySectionSummary;

  /// No description provided for @knowledgeStrategySectionValueProp.
  ///
  /// In pt, this message translates to:
  /// **'Proposta de Valor'**
  String get knowledgeStrategySectionValueProp;

  /// No description provided for @knowledgeStrategySectionPositioning.
  ///
  /// In pt, this message translates to:
  /// **'Posicionamento'**
  String get knowledgeStrategySectionPositioning;

  /// No description provided for @knowledgeStrategySectionAudience.
  ///
  /// In pt, this message translates to:
  /// **'Público-alvo'**
  String get knowledgeStrategySectionAudience;

  /// No description provided for @knowledgeStrategySectionChannels.
  ///
  /// In pt, this message translates to:
  /// **'Canais Recomendados'**
  String get knowledgeStrategySectionChannels;

  /// No description provided for @knowledgeStrategySectionFunnel.
  ///
  /// In pt, this message translates to:
  /// **'Funil de Marketing'**
  String get knowledgeStrategySectionFunnel;

  /// No description provided for @knowledgeStrategySectionOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades Comerciais'**
  String get knowledgeStrategySectionOpportunities;

  /// No description provided for @knowledgeStrategySectionKeywords.
  ///
  /// In pt, this message translates to:
  /// **'Keywords Prioritárias'**
  String get knowledgeStrategySectionKeywords;

  /// No description provided for @knowledgeStrategySectionQuickWins.
  ///
  /// In pt, this message translates to:
  /// **'Ações Rápidas'**
  String get knowledgeStrategySectionQuickWins;

  /// No description provided for @knowledgeStrategySectionGrowthPlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano de Crescimento'**
  String get knowledgeStrategySectionGrowthPlan;

  /// No description provided for @knowledgeStrategyFunnelAwareness.
  ///
  /// In pt, this message translates to:
  /// **'Awareness'**
  String get knowledgeStrategyFunnelAwareness;

  /// No description provided for @knowledgeStrategyFunnelConsideration.
  ///
  /// In pt, this message translates to:
  /// **'Consideração'**
  String get knowledgeStrategyFunnelConsideration;

  /// No description provided for @knowledgeStrategyFunnelConversion.
  ///
  /// In pt, this message translates to:
  /// **'Conversão'**
  String get knowledgeStrategyFunnelConversion;

  /// No description provided for @knowledgeStrategyFunnelRetention.
  ///
  /// In pt, this message translates to:
  /// **'Retenção'**
  String get knowledgeStrategyFunnelRetention;

  /// No description provided for @knowledgeStrategyMonth.
  ///
  /// In pt, this message translates to:
  /// **'Mês {n}'**
  String knowledgeStrategyMonth(int n);

  /// No description provided for @knowledgeStrategyKpisLabel.
  ///
  /// In pt, this message translates to:
  /// **'KPIs'**
  String get knowledgeStrategyKpisLabel;

  /// No description provided for @knowledgeStrategyAudiencePrimary.
  ///
  /// In pt, this message translates to:
  /// **'Primário'**
  String get knowledgeStrategyAudiencePrimary;

  /// No description provided for @knowledgeStrategyAudienceSecondary.
  ///
  /// In pt, this message translates to:
  /// **'Secundário'**
  String get knowledgeStrategyAudienceSecondary;

  /// No description provided for @knowledgeStrategyAudienceAgeRange.
  ///
  /// In pt, this message translates to:
  /// **'Faixa etária'**
  String get knowledgeStrategyAudienceAgeRange;

  /// No description provided for @knowledgeAnalysisTitle.
  ///
  /// In pt, this message translates to:
  /// **'Análise de Conhecimento'**
  String get knowledgeAnalysisTitle;

  /// No description provided for @knowledgeAnalysisReanalyzeTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Re-analisar'**
  String get knowledgeAnalysisReanalyzeTooltip;

  /// No description provided for @knowledgeAnalysisLoadingLabel.
  ///
  /// In pt, this message translates to:
  /// **'Analisando com IA…'**
  String get knowledgeAnalysisLoadingLabel;

  /// No description provided for @knowledgeAnalysisNotYetLabel.
  ///
  /// In pt, this message translates to:
  /// **'Este item ainda não foi analisado.'**
  String get knowledgeAnalysisNotYetLabel;

  /// No description provided for @knowledgeAnalysisCopied.
  ///
  /// In pt, this message translates to:
  /// **'Copiado!'**
  String get knowledgeAnalysisCopied;

  /// No description provided for @knowledgeAnalysisCopiedKeyword.
  ///
  /// In pt, this message translates to:
  /// **'Copiado: {keyword}'**
  String knowledgeAnalysisCopiedKeyword(String keyword);

  /// No description provided for @knowledgeAnalysisSectionSummary.
  ///
  /// In pt, this message translates to:
  /// **'Resumo'**
  String get knowledgeAnalysisSectionSummary;

  /// No description provided for @knowledgeAnalysisSectionChannelScores.
  ///
  /// In pt, this message translates to:
  /// **'Pontuações por Canal'**
  String get knowledgeAnalysisSectionChannelScores;

  /// No description provided for @knowledgeAnalysisSectionKeywords.
  ///
  /// In pt, this message translates to:
  /// **'Palavras-chave'**
  String get knowledgeAnalysisSectionKeywords;

  /// No description provided for @knowledgeAnalysisKeywordsPrimary.
  ///
  /// In pt, this message translates to:
  /// **'Primárias'**
  String get knowledgeAnalysisKeywordsPrimary;

  /// No description provided for @knowledgeAnalysisKeywordsSecondary.
  ///
  /// In pt, this message translates to:
  /// **'Secundárias'**
  String get knowledgeAnalysisKeywordsSecondary;

  /// No description provided for @knowledgeAnalysisKeywordsLongtail.
  ///
  /// In pt, this message translates to:
  /// **'Long-tail'**
  String get knowledgeAnalysisKeywordsLongtail;

  /// No description provided for @knowledgeAnalysisSectionAudiencePainPoints.
  ///
  /// In pt, this message translates to:
  /// **'Dores da Audiência'**
  String get knowledgeAnalysisSectionAudiencePainPoints;

  /// No description provided for @knowledgeAnalysisSectionAudienceDesires.
  ///
  /// In pt, this message translates to:
  /// **'Desejos da Audiência'**
  String get knowledgeAnalysisSectionAudienceDesires;

  /// No description provided for @knowledgeAnalysisSectionContentPillars.
  ///
  /// In pt, this message translates to:
  /// **'Pilares de Conteúdo'**
  String get knowledgeAnalysisSectionContentPillars;

  /// No description provided for @knowledgeAnalysisSectionTopics.
  ///
  /// In pt, this message translates to:
  /// **'Tópicos Principais'**
  String get knowledgeAnalysisSectionTopics;

  /// No description provided for @knowledgeAnalysisSectionPostIdeas.
  ///
  /// In pt, this message translates to:
  /// **'Ideias de Posts para Redes Sociais'**
  String get knowledgeAnalysisSectionPostIdeas;

  /// No description provided for @knowledgeAnalysisSectionCampaignIdeas.
  ///
  /// In pt, this message translates to:
  /// **'Ideias de Campanhas'**
  String get knowledgeAnalysisSectionCampaignIdeas;

  /// No description provided for @knowledgeAnalysisSectionArticleIdeas.
  ///
  /// In pt, this message translates to:
  /// **'Ideias de Artigos / Blog'**
  String get knowledgeAnalysisSectionArticleIdeas;

  /// No description provided for @knowledgeAnalysisSectionCommercialAngles.
  ///
  /// In pt, this message translates to:
  /// **'Ângulos Comerciais'**
  String get knowledgeAnalysisSectionCommercialAngles;

  /// No description provided for @knowledgeAnalysisSectionCtas.
  ///
  /// In pt, this message translates to:
  /// **'CTAs Sugeridas'**
  String get knowledgeAnalysisSectionCtas;

  /// No description provided for @knowledgeAnalysisSectionSeoOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades SEO'**
  String get knowledgeAnalysisSectionSeoOpportunities;

  /// No description provided for @knowledgeAnalysisSectionAdsenseOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades AdSense'**
  String get knowledgeAnalysisSectionAdsenseOpportunities;

  /// No description provided for @knowledgeAnalysisSectionAmazonKdpOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades Amazon KDP'**
  String get knowledgeAnalysisSectionAmazonKdpOpportunities;

  /// No description provided for @knowledgeAnalysisSectionHotmartEngine.
  ///
  /// In pt, this message translates to:
  /// **'Hotmart Engine'**
  String get knowledgeAnalysisSectionHotmartEngine;

  /// No description provided for @knowledgeAnalysisSectionShopifyEngine.
  ///
  /// In pt, this message translates to:
  /// **'Shopify Engine'**
  String get knowledgeAnalysisSectionShopifyEngine;

  /// No description provided for @knowledgeAnalysisSectionChannelDetails.
  ///
  /// In pt, this message translates to:
  /// **'Detalhes por Canal'**
  String get knowledgeAnalysisSectionChannelDetails;

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

  /// No description provided for @projectCommandCreatedSuccess.
  ///
  /// In pt, this message translates to:
  /// **'Projeto criado! Adicione fontes de conhecimento para enriquecer a análise.'**
  String get projectCommandCreatedSuccess;

  /// No description provided for @projectCommandAddSources.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Fonte'**
  String get projectCommandAddSources;

  /// No description provided for @knowledgeAnalysisSummaryHint.
  ///
  /// In pt, this message translates to:
  /// **'Use estes insights para criar campanhas, treinar personas ou gerar estratégias de conteúdo.'**
  String get knowledgeAnalysisSummaryHint;

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

  /// No description provided for @projectCommandAskProfilePrompt.
  ///
  /// In pt, this message translates to:
  /// **'Analise o perfil de inteligência do projeto \"{name}\": nicho {niche}, público {audience}, maturidade {maturity}. {gaps}O que devo priorizar agora?'**
  String projectCommandAskProfilePrompt(
      String name, String niche, String audience, String maturity, String gaps);

  /// No description provided for @projectCommandAskProfileGaps.
  ///
  /// In pt, this message translates to:
  /// **'Lacunas: {list}. '**
  String projectCommandAskProfileGaps(String list);

  /// No description provided for @projectCommandAskAllocationPrompt.
  ///
  /// In pt, this message translates to:
  /// **'Com base na alocação de recursos SALVA do projeto \"{name}\" ({hours}h, {budget}), essa alocação está adequada para as prioridades atuais do projeto? O que ajustar?{dirtyNote}'**
  String projectCommandAskAllocationPrompt(
      String name, int hours, String budget, String dirtyNote);

  /// No description provided for @projectCommandAskAllocationDirtyNote.
  ///
  /// In pt, this message translates to:
  /// **' Nota: há edições de alocação ainda não salvas que não estão refletidas nesta análise.'**
  String get projectCommandAskAllocationDirtyNote;

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

  /// No description provided for @oppLabFeatureGatedBody.
  ///
  /// In pt, this message translates to:
  /// **'O Opportunity Lab está sendo preparado para lançamento.\nEm breve você poderá gerar e avaliar oportunidades de negócio de forma massiva e inteligente.'**
  String get oppLabFeatureGatedBody;

  /// No description provided for @oppLabFeatureGatedProBadge.
  ///
  /// In pt, this message translates to:
  /// **'Disponível em breve — Plano Pro'**
  String get oppLabFeatureGatedProBadge;

  /// No description provided for @oppLabApprove.
  ///
  /// In pt, this message translates to:
  /// **'Aprovar'**
  String get oppLabApprove;

  /// No description provided for @oppLabConvertToAction.
  ///
  /// In pt, this message translates to:
  /// **'→ Ação'**
  String get oppLabConvertToAction;

  /// No description provided for @oppLabViewActionShort.
  ///
  /// In pt, this message translates to:
  /// **'Ver'**
  String get oppLabViewActionShort;

  /// No description provided for @oppLabEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Opportunity Lab vazio'**
  String get oppLabEmptyTitle;

  /// No description provided for @oppLabEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Adicione oportunidades para analisar, priorizar e executar.'**
  String get oppLabEmptyBody;

  /// No description provided for @oppLabAddButton.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar Oportunidade'**
  String get oppLabAddButton;

  /// No description provided for @oppStatusPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendente'**
  String get oppStatusPending;

  /// No description provided for @oppStatusAnalyzing.
  ///
  /// In pt, this message translates to:
  /// **'Analisando'**
  String get oppStatusAnalyzing;

  /// No description provided for @oppStatusApproved.
  ///
  /// In pt, this message translates to:
  /// **'Aprovada'**
  String get oppStatusApproved;

  /// No description provided for @oppStatusRejected.
  ///
  /// In pt, this message translates to:
  /// **'Rejeitada'**
  String get oppStatusRejected;

  /// No description provided for @oppStatusExecuting.
  ///
  /// In pt, this message translates to:
  /// **'Em execução'**
  String get oppStatusExecuting;

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

  /// No description provided for @miRootProjectSelectorLabel.
  ///
  /// In pt, this message translates to:
  /// **'Vincular a um projeto (opcional)'**
  String get miRootProjectSelectorLabel;

  /// No description provided for @miRootProjectSelectorNone.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum'**
  String get miRootProjectSelectorNone;

  /// No description provided for @r16LanguageNamePortuguese.
  ///
  /// In pt, this message translates to:
  /// **'português'**
  String get r16LanguageNamePortuguese;

  /// No description provided for @r16LanguageNameEnglish.
  ///
  /// In pt, this message translates to:
  /// **'inglês'**
  String get r16LanguageNameEnglish;

  /// No description provided for @r16LanguageNameSpanish.
  ///
  /// In pt, this message translates to:
  /// **'espanhol'**
  String get r16LanguageNameSpanish;

  /// No description provided for @r16LanguageNameOther.
  ///
  /// In pt, this message translates to:
  /// **'outro idioma'**
  String get r16LanguageNameOther;

  /// No description provided for @ecoVerdictScale.
  ///
  /// In pt, this message translates to:
  /// **'ESCALAR'**
  String get ecoVerdictScale;

  /// No description provided for @ecoVerdictAccelerate.
  ///
  /// In pt, this message translates to:
  /// **'ACELERAR'**
  String get ecoVerdictAccelerate;

  /// No description provided for @ecoVerdictMaintain.
  ///
  /// In pt, this message translates to:
  /// **'MANTER'**
  String get ecoVerdictMaintain;

  /// No description provided for @ecoVerdictValidate.
  ///
  /// In pt, this message translates to:
  /// **'VALIDAR'**
  String get ecoVerdictValidate;

  /// No description provided for @ecoVerdictPause.
  ///
  /// In pt, this message translates to:
  /// **'PAUSAR'**
  String get ecoVerdictPause;

  /// No description provided for @ecoVerdictIncomplete.
  ///
  /// In pt, this message translates to:
  /// **'ANÁLISE INCOMPLETA'**
  String get ecoVerdictIncomplete;

  /// No description provided for @ecoRecTypeInvest.
  ///
  /// In pt, this message translates to:
  /// **'Investir'**
  String get ecoRecTypeInvest;

  /// No description provided for @ecoRecTypeExecute.
  ///
  /// In pt, this message translates to:
  /// **'Executar'**
  String get ecoRecTypeExecute;

  /// No description provided for @ecoRecTypeAction.
  ///
  /// In pt, this message translates to:
  /// **'Ação'**
  String get ecoRecTypeAction;

  /// No description provided for @ecoRecTypePause.
  ///
  /// In pt, this message translates to:
  /// **'Pausar'**
  String get ecoRecTypePause;

  /// No description provided for @ecoRecTypeRisk.
  ///
  /// In pt, this message translates to:
  /// **'Risco'**
  String get ecoRecTypeRisk;

  /// No description provided for @ecoRecTypeQuickWin.
  ///
  /// In pt, this message translates to:
  /// **'Ganho Rápido'**
  String get ecoRecTypeQuickWin;

  /// No description provided for @ecoRecTypeWaste.
  ///
  /// In pt, this message translates to:
  /// **'Desperdício'**
  String get ecoRecTypeWaste;

  /// No description provided for @ecoRecScaleTitle.
  ///
  /// In pt, this message translates to:
  /// **'Escale \"{name}\"'**
  String ecoRecScaleTitle(String name);

  /// No description provided for @ecoRecInvestTitle.
  ///
  /// In pt, this message translates to:
  /// **'Invista mais em \"{name}\"'**
  String ecoRecInvestTitle(String name);

  /// No description provided for @ecoRecTopReason.
  ///
  /// In pt, this message translates to:
  /// **'Ecosystem Score {score}/100 — maior potencial do seu portfólio'**
  String ecoRecTopReason(int score);

  /// No description provided for @ecoRecTopData.
  ///
  /// In pt, this message translates to:
  /// **'Score: oportunidade {opportunity}, fit {fit}, mercado {market}'**
  String ecoRecTopData(int opportunity, int fit, int market);

  /// No description provided for @ecoRecTopImpact.
  ///
  /// In pt, this message translates to:
  /// **'Aceleração de receita e execução de {count} oportunidades mapeadas'**
  String ecoRecTopImpact(int count);

  /// No description provided for @ecoRecValidateTitle.
  ///
  /// In pt, this message translates to:
  /// **'Valide as premissas de \"{name}\"'**
  String ecoRecValidateTitle(String name);

  /// No description provided for @ecoRecValidateReason.
  ///
  /// In pt, this message translates to:
  /// **'Score {score}/100 — potencial presente mas dados ainda insuficientes para decisão'**
  String ecoRecValidateReason(int score);

  /// No description provided for @ecoRecValidateData.
  ///
  /// In pt, this message translates to:
  /// **'Market score {market}, ROI {roi}, execução {execution}'**
  String ecoRecValidateData(int market, int roi, int execution);

  /// No description provided for @ecoRecValidateImpact.
  ///
  /// In pt, this message translates to:
  /// **'Clareza estratégica para escalar ou pivotar'**
  String get ecoRecValidateImpact;

  /// No description provided for @ecoRecOppTitle.
  ///
  /// In pt, this message translates to:
  /// **'Execute a oportunidade \"{title}\"'**
  String ecoRecOppTitle(String title);

  /// No description provided for @ecoRecOppReason.
  ///
  /// In pt, this message translates to:
  /// **'Score final {score}/100 — maior ROI esperado do Lab'**
  String ecoRecOppReason(int score);

  /// No description provided for @ecoRecOppData.
  ///
  /// In pt, this message translates to:
  /// **'Market score {market}, revenue score {revenue}'**
  String ecoRecOppData(int market, int revenue);

  /// No description provided for @ecoRecOppImpactFallback.
  ///
  /// In pt, this message translates to:
  /// **'Alta alavancagem do portfólio'**
  String get ecoRecOppImpactFallback;

  /// No description provided for @ecoRecQuickWinTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ganho rápido: \"{title}\"'**
  String ecoRecQuickWinTitle(String title);

  /// No description provided for @ecoRecQuickWinReason.
  ///
  /// In pt, this message translates to:
  /// **'Impacto {impact} com esforço apenas {effort} — melhor relação do portfólio'**
  String ecoRecQuickWinReason(int impact, int effort);

  /// No description provided for @ecoRecQuickWinData.
  ///
  /// In pt, this message translates to:
  /// **'Impact score {impact}, effort score {effort}'**
  String ecoRecQuickWinData(int impact, int effort);

  /// No description provided for @ecoRecQuickWinImpact.
  ///
  /// In pt, this message translates to:
  /// **'Execução rápida com alto retorno proporcional'**
  String get ecoRecQuickWinImpact;

  /// No description provided for @ecoRecPauseTitle.
  ///
  /// In pt, this message translates to:
  /// **'Pause ou revise \"{name}\"'**
  String ecoRecPauseTitle(String name);

  /// No description provided for @ecoRecPauseReason.
  ///
  /// In pt, this message translates to:
  /// **'Ecosystem Score {score}/100 — recursos consumidos sem retorno visível'**
  String ecoRecPauseReason(int score);

  /// No description provided for @ecoRecPauseData.
  ///
  /// In pt, this message translates to:
  /// **'ROI score {roi}, momentum {momentum}, {count} ações sem conclusão'**
  String ecoRecPauseData(int roi, int momentum, int count);

  /// No description provided for @ecoRecPauseImpact.
  ///
  /// In pt, this message translates to:
  /// **'Liberação de tempo e foco para projetos de maior potencial'**
  String get ecoRecPauseImpact;

  /// No description provided for @ecoRecRiskTitle.
  ///
  /// In pt, this message translates to:
  /// **'Risco em \"{name}\": {risk}'**
  String ecoRecRiskTitle(String name, String risk);

  /// No description provided for @ecoRecRiskReason.
  ///
  /// In pt, this message translates to:
  /// **'Identificado pelo Ecosystem Intelligence com base nos dados do projeto'**
  String get ecoRecRiskReason;

  /// No description provided for @ecoRecRiskData.
  ///
  /// In pt, this message translates to:
  /// **'Ecosystem Score {score}, momentum {momentum}'**
  String ecoRecRiskData(int score, int momentum);

  /// No description provided for @ecoRecRiskImpact.
  ///
  /// In pt, this message translates to:
  /// **'Mitigação preventiva antes do impacto no portfólio'**
  String get ecoRecRiskImpact;

  /// No description provided for @ecoAllocEmptySummary.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum projeto com score suficiente para alocação. Execute o Knowledge → Action Engine para gerar inteligência operacional.'**
  String get ecoAllocEmptySummary;

  /// No description provided for @ecoAllocUnitHours.
  ///
  /// In pt, this message translates to:
  /// **'horas'**
  String get ecoAllocUnitHours;

  /// No description provided for @ecoAllocResourceBudget.
  ///
  /// In pt, this message translates to:
  /// **'budget'**
  String get ecoAllocResourceBudget;

  /// No description provided for @ecoAllocSummary.
  ///
  /// In pt, this message translates to:
  /// **'Priorize \"{name}\" com {amount} {unit} ({percent}% do orçamento). Score: {score}/100.'**
  String ecoAllocSummary(
      String name, String amount, String unit, int percent, int score);

  /// No description provided for @ecoAllocReasonScale.
  ///
  /// In pt, this message translates to:
  /// **'Maior potencial — escale o investimento em {resource}'**
  String ecoAllocReasonScale(String resource);

  /// No description provided for @ecoAllocReasonAccelerate.
  ///
  /// In pt, this message translates to:
  /// **'Alto potencial — maximize o {resource} aqui'**
  String ecoAllocReasonAccelerate(String resource);

  /// No description provided for @ecoAllocReasonMaintain.
  ///
  /// In pt, this message translates to:
  /// **'Projeto saudável — mantenha investimento consistente'**
  String get ecoAllocReasonMaintain;

  /// No description provided for @ecoAllocReasonValidate.
  ///
  /// In pt, this message translates to:
  /// **'Alocação reduzida até validar premissas'**
  String get ecoAllocReasonValidate;

  /// No description provided for @ecoAllocReasonPause.
  ///
  /// In pt, this message translates to:
  /// **'Não recomendado — considere pausar este projeto'**
  String get ecoAllocReasonPause;

  /// No description provided for @ecoResourceAllocationTitle.
  ///
  /// In pt, this message translates to:
  /// **'Alocação de Recursos'**
  String get ecoResourceAllocationTitle;

  /// No description provided for @ecoAllocModeHours.
  ///
  /// In pt, this message translates to:
  /// **'⏱ Tempo (Horas)'**
  String get ecoAllocModeHours;

  /// No description provided for @ecoAllocModeMoney.
  ///
  /// In pt, this message translates to:
  /// **'💰 Dinheiro (R\$)'**
  String get ecoAllocModeMoney;

  /// No description provided for @ecoAllocBudgetQuestion.
  ///
  /// In pt, this message translates to:
  /// **'Quanto tenho disponível?'**
  String get ecoAllocBudgetQuestion;

  /// No description provided for @ecoAllocExecutiveRecommendation.
  ///
  /// In pt, this message translates to:
  /// **'Recomendação Executiva'**
  String get ecoAllocExecutiveRecommendation;

  /// No description provided for @ecoAllocEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Adicione projetos com análises para ver a alocação.'**
  String get ecoAllocEmpty;

  /// No description provided for @ecoAllocDistribution.
  ///
  /// In pt, this message translates to:
  /// **'Distribuição das {total} {unit}'**
  String ecoAllocDistribution(int total, String unit);

  /// No description provided for @ecoBriefNewAnalysesTitle.
  ///
  /// In pt, this message translates to:
  /// **'{count} nova(s) análise(s) de mercado'**
  String ecoBriefNewAnalysesTitle(int count);

  /// No description provided for @ecoBriefNewAnalysesDetail.
  ///
  /// In pt, this message translates to:
  /// **'Novas oportunidades mapeadas pelo Market Intelligence'**
  String get ecoBriefNewAnalysesDetail;

  /// No description provided for @ecoBriefNewActionsTitle.
  ///
  /// In pt, this message translates to:
  /// **'{count} nova(s) ação(ões) criada(s)'**
  String ecoBriefNewActionsTitle(int count);

  /// No description provided for @ecoBriefNewActionsDetail.
  ///
  /// In pt, this message translates to:
  /// **'Action Engine em movimento'**
  String get ecoBriefNewActionsDetail;

  /// No description provided for @ecoBriefNewLabTitle.
  ///
  /// In pt, this message translates to:
  /// **'{count} novo(s) item(ns) no Opportunity Lab'**
  String ecoBriefNewLabTitle(int count);

  /// No description provided for @ecoBriefNewLabDetail.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades sendo avaliadas'**
  String get ecoBriefNewLabDetail;

  /// No description provided for @ecoBriefNewRoiTitle.
  ///
  /// In pt, this message translates to:
  /// **'{count} novo(s) registro(s) de ROI'**
  String ecoBriefNewRoiTitle(int count);

  /// No description provided for @ecoBriefNewRoiDetail.
  ///
  /// In pt, this message translates to:
  /// **'Resultados financeiros atualizados'**
  String get ecoBriefNewRoiDetail;

  /// No description provided for @ecoBriefNoActivityTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma atividade nova esta semana'**
  String get ecoBriefNoActivityTitle;

  /// No description provided for @ecoBriefNoActivityDetail.
  ///
  /// In pt, this message translates to:
  /// **'Adicione análises ou ações para gerar insights'**
  String get ecoBriefNoActivityDetail;

  /// No description provided for @ecoBriefProjectScoreTitle.
  ///
  /// In pt, this message translates to:
  /// **'{name} — Ecosystem Score {score}'**
  String ecoBriefProjectScoreTitle(String name, int score);

  /// No description provided for @ecoBriefRecommendationDetail.
  ///
  /// In pt, this message translates to:
  /// **'Recomendação: {verdict}. {note}'**
  String ecoBriefRecommendationDetail(String verdict, String note);

  /// No description provided for @ecoBriefGrewFallback.
  ///
  /// In pt, this message translates to:
  /// **'Alto potencial identificado.'**
  String get ecoBriefGrewFallback;

  /// No description provided for @ecoBriefDeclinedFallback.
  ///
  /// In pt, this message translates to:
  /// **'Baixo retorno identificado.'**
  String get ecoBriefDeclinedFallback;

  /// No description provided for @ecoBriefToPauseDetail.
  ///
  /// In pt, this message translates to:
  /// **'Score {score}/100 — libere recursos para projetos de maior potencial'**
  String ecoBriefToPauseDetail(int score);

  /// No description provided for @ecoBriefRiskProjectDetail.
  ///
  /// In pt, this message translates to:
  /// **'Projeto: {name}'**
  String ecoBriefRiskProjectDetail(String name);

  /// No description provided for @ecoBriefSummaryEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum projeto registrado. Comece adicionando projetos e executando análises.'**
  String get ecoBriefSummaryEmpty;

  /// No description provided for @ecoBriefSummary.
  ///
  /// In pt, this message translates to:
  /// **'Seu ecossistema tem {count} projeto(s) com saúde geral de {health}/100. {growing} projeto(s) em crescimento, {pausing} requerem revisão.'**
  String ecoBriefSummary(int count, int health, int growing, int pausing);

  /// No description provided for @ecoExecNoActions.
  ///
  /// In pt, this message translates to:
  /// **'Sem ações cadastradas'**
  String get ecoExecNoActions;

  /// No description provided for @ecoExecRoadmapPresent.
  ///
  /// In pt, this message translates to:
  /// **'Roadmap presente → +20pts'**
  String get ecoExecRoadmapPresent;

  /// No description provided for @ecoExecNoRoadmap.
  ///
  /// In pt, this message translates to:
  /// **'Sem roadmap → +0pts'**
  String get ecoExecNoRoadmap;

  /// No description provided for @ecoExecCompleted.
  ///
  /// In pt, this message translates to:
  /// **'{completed}/{total} ações concluídas → {points}pts'**
  String ecoExecCompleted(int completed, int total, int points);

  /// No description provided for @ecoExecApproved.
  ///
  /// In pt, this message translates to:
  /// **'{approved} oportunidades aprovadas × 10 = {points}pts (max 30)'**
  String ecoExecApproved(int approved, int points);

  /// No description provided for @ecoStrengthMarket.
  ///
  /// In pt, this message translates to:
  /// **'Mercado com alto potencial identificado'**
  String get ecoStrengthMarket;

  /// No description provided for @ecoStrengthOpportunity.
  ///
  /// In pt, this message translates to:
  /// **'Alta pontuação de oportunidade de mercado'**
  String get ecoStrengthOpportunity;

  /// No description provided for @ecoStrengthRoi.
  ///
  /// In pt, this message translates to:
  /// **'ROI positivo registrado'**
  String get ecoStrengthRoi;

  /// No description provided for @ecoStrengthSynergy.
  ///
  /// In pt, this message translates to:
  /// **'Alta sinergia com o ecossistema'**
  String get ecoStrengthSynergy;

  /// No description provided for @ecoStrengthMomentum.
  ///
  /// In pt, this message translates to:
  /// **'Atividade recente elevada'**
  String get ecoStrengthMomentum;

  /// No description provided for @ecoStrengthPriority.
  ///
  /// In pt, this message translates to:
  /// **'Alta prioridade estratégica'**
  String get ecoStrengthPriority;

  /// No description provided for @ecoStrengthDefault.
  ///
  /// In pt, this message translates to:
  /// **'Projeto com potencial a desenvolver'**
  String get ecoStrengthDefault;

  /// No description provided for @ecoRiskInsufficientData.
  ///
  /// In pt, this message translates to:
  /// **'Dados insuficientes para análise de valor'**
  String get ecoRiskInsufficientData;

  /// No description provided for @ecoRiskPendingActions.
  ///
  /// In pt, this message translates to:
  /// **'{count} ações pendentes acumuladas sem execução'**
  String ecoRiskPendingActions(int count);

  /// No description provided for @ecoRiskNoRoi.
  ///
  /// In pt, this message translates to:
  /// **'Sem ROI registrado apesar das ações em andamento'**
  String get ecoRiskNoRoi;

  /// No description provided for @ecoRiskLowActivity.
  ///
  /// In pt, this message translates to:
  /// **'Baixa atividade nos últimos 30 dias'**
  String get ecoRiskLowActivity;

  /// No description provided for @ecoRiskIdeaStage.
  ///
  /// In pt, this message translates to:
  /// **'Projeto ainda em fase de ideia — sem execução iniciada'**
  String get ecoRiskIdeaStage;

  /// No description provided for @ecoIveCriticalProjects.
  ///
  /// In pt, this message translates to:
  /// **'Atenção: {count} projeto(s) com score crítico. Posso ajudar a resolver.'**
  String ecoIveCriticalProjects(int count);

  /// No description provided for @ecoDecisionCenterTitle.
  ///
  /// In pt, this message translates to:
  /// **'Central de Decisões'**
  String get ecoDecisionCenterTitle;

  /// No description provided for @ecoTabTop5.
  ///
  /// In pt, this message translates to:
  /// **'TOP 5'**
  String get ecoTabTop5;

  /// No description provided for @ecoTabEcosystem.
  ///
  /// In pt, this message translates to:
  /// **'ECOSSISTEMA'**
  String get ecoTabEcosystem;

  /// No description provided for @ecoTabRecommendations.
  ///
  /// In pt, this message translates to:
  /// **'RECOMENDAÇÕES'**
  String get ecoTabRecommendations;

  /// No description provided for @ecoWeeklyBriefingTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Briefing Semanal'**
  String get ecoWeeklyBriefingTooltip;

  /// No description provided for @ecoBootstrapPending.
  ///
  /// In pt, this message translates to:
  /// **'Projetos sem inteligência operacional: {count}'**
  String ecoBootstrapPending(int count);

  /// No description provided for @ecoHealthTitle.
  ///
  /// In pt, this message translates to:
  /// **'Saúde do Ecossistema'**
  String get ecoHealthTitle;

  /// No description provided for @ecoIveAskHealth.
  ///
  /// In pt, this message translates to:
  /// **'Por que minha saúde do ecossistema está em {health}? O que está limitando e como posso melhorar?'**
  String ecoIveAskHealth(int health);

  /// No description provided for @ecoHealthNarrativeExcellent.
  ///
  /// In pt, this message translates to:
  /// **'Seu ecossistema está operando no máximo potencial. Os projetos estão sincronizados e escalando.'**
  String get ecoHealthNarrativeExcellent;

  /// No description provided for @ecoHealthNarrativeHealthy.
  ///
  /// In pt, this message translates to:
  /// **'Seu ecossistema está saudável e crescendo. Existem alavancas prontas para acelerar.'**
  String get ecoHealthNarrativeHealthy;

  /// No description provided for @ecoHealthNarrativeStable.
  ///
  /// In pt, this message translates to:
  /// **'Seu ecossistema está estável. Algumas áreas precisam de atenção para desbloquear crescimento.'**
  String get ecoHealthNarrativeStable;

  /// No description provided for @ecoHealthNarrativeValidating.
  ///
  /// In pt, this message translates to:
  /// **'Seu ecossistema está em fase de validação. Adicione mais análises para elevar a inteligência.'**
  String get ecoHealthNarrativeValidating;

  /// No description provided for @ecoHealthNarrativeReview.
  ///
  /// In pt, this message translates to:
  /// **'Seu ecossistema precisa de revisão estratégica. A IVE pode ajudar a identificar os bloqueios.'**
  String get ecoHealthNarrativeReview;

  /// No description provided for @ecoErrorGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Erro: {error}'**
  String ecoErrorGeneric(String error);

  /// No description provided for @ecoTop5Empty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum projeto encontrado.\nAdicione textos no Cofre e crie projetos.'**
  String get ecoTop5Empty;

  /// No description provided for @ecoTop5ProjectsTitle.
  ///
  /// In pt, this message translates to:
  /// **'🚀 TOP 5 PROJETOS'**
  String get ecoTop5ProjectsTitle;

  /// No description provided for @ecoTop5ProjectsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Ranqueados por Ecosystem Score'**
  String get ecoTop5ProjectsSubtitle;

  /// No description provided for @ecoTop5OpportunitiesTitle.
  ///
  /// In pt, this message translates to:
  /// **'💡 TOP 5 OPORTUNIDADES'**
  String get ecoTop5OpportunitiesTitle;

  /// No description provided for @ecoTop5OpportunitiesSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Maior potencial do Opportunity Lab'**
  String get ecoTop5OpportunitiesSubtitle;

  /// No description provided for @ecoOppExplanation.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidade do tipo \"{type}\" com score {score}/100. Status atual: {status}.'**
  String ecoOppExplanation(String type, int score, String status);

  /// No description provided for @ecoLabelType.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get ecoLabelType;

  /// No description provided for @ecoLabelFinalScore.
  ///
  /// In pt, this message translates to:
  /// **'Score Final'**
  String get ecoLabelFinalScore;

  /// No description provided for @ecoLabelStatus.
  ///
  /// In pt, this message translates to:
  /// **'Status'**
  String get ecoLabelStatus;

  /// No description provided for @ecoAskIveOpportunity.
  ///
  /// In pt, this message translates to:
  /// **'Perguntar à IVE sobre esta oportunidade'**
  String get ecoAskIveOpportunity;

  /// No description provided for @ecoIveAskOpportunity.
  ///
  /// In pt, this message translates to:
  /// **'Analise a oportunidade \"{title}\" (score {score}) e diga como aproveitá-la.'**
  String ecoIveAskOpportunity(String title, int score);

  /// No description provided for @ecoTop5QuickWinsTitle.
  ///
  /// In pt, this message translates to:
  /// **'⚡ TOP 5 GANHOS RÁPIDOS'**
  String get ecoTop5QuickWinsTitle;

  /// No description provided for @ecoTop5QuickWinsSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Alto impacto, baixo esforço'**
  String get ecoTop5QuickWinsSubtitle;

  /// No description provided for @ecoImpactEffort.
  ///
  /// In pt, this message translates to:
  /// **'Impacto {impact} / Esforço {effort}'**
  String ecoImpactEffort(int impact, int effort);

  /// No description provided for @ecoQuickWinExplanation.
  ///
  /// In pt, this message translates to:
  /// **'Ganho rápido: alto impacto ({impact}/100) e baixo esforço ({effort}/100). Priorize esta ação para resultados imediatos.'**
  String ecoQuickWinExplanation(int impact, int effort);

  /// No description provided for @ecoLabelImpact.
  ///
  /// In pt, this message translates to:
  /// **'Impacto'**
  String get ecoLabelImpact;

  /// No description provided for @ecoLabelEffort.
  ///
  /// In pt, this message translates to:
  /// **'Esforço'**
  String get ecoLabelEffort;

  /// No description provided for @ecoTop5RisksTitle.
  ///
  /// In pt, this message translates to:
  /// **'⚠️ TOP 5 RISCOS'**
  String get ecoTop5RisksTitle;

  /// No description provided for @ecoTop5RisksSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Ações em projetos de baixo score'**
  String get ecoTop5RisksSubtitle;

  /// No description provided for @ecoBadgeRisk.
  ///
  /// In pt, this message translates to:
  /// **'risco'**
  String get ecoBadgeRisk;

  /// No description provided for @ecoRiskActionExplanation.
  ///
  /// In pt, this message translates to:
  /// **'Esta ação está em um projeto com Ecosystem Score crítico (abaixo de 30). Requer atenção urgente para evitar perda de oportunidade.'**
  String get ecoRiskActionExplanation;

  /// No description provided for @ecoTop5WastesTitle.
  ///
  /// In pt, this message translates to:
  /// **'🗑️ TOP 5 DESPERDÍCIOS'**
  String get ecoTop5WastesTitle;

  /// No description provided for @ecoTop5WastesSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Baixo impacto, alto esforço'**
  String get ecoTop5WastesSubtitle;

  /// No description provided for @ecoBadgeReview.
  ///
  /// In pt, this message translates to:
  /// **'rever'**
  String get ecoBadgeReview;

  /// No description provided for @ecoWasteExplanation.
  ///
  /// In pt, this message translates to:
  /// **'Desperdício: baixo impacto ({impact}/100) e alto esforço ({effort}/100). Considere remover ou reformular esta ação para liberar capacidade.'**
  String ecoWasteExplanation(int impact, int effort);

  /// No description provided for @ecoNoItemsYet.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum item ainda'**
  String get ecoNoItemsYet;

  /// No description provided for @ecoProjectExplanation.
  ///
  /// In pt, this message translates to:
  /// **'{name} tem um Ecosystem Score de {score}/100. Isso significa que o projeto está classificado como \"{verdict}\". O score combina oportunidades de mercado, fit estratégico, ROI potencial e capacidade de execução.'**
  String ecoProjectExplanation(String name, int score, String verdict);

  /// No description provided for @ecoLabelOpportunity.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidade'**
  String get ecoLabelOpportunity;

  /// No description provided for @ecoLabelStrategicFit.
  ///
  /// In pt, this message translates to:
  /// **'Strategic Fit'**
  String get ecoLabelStrategicFit;

  /// No description provided for @ecoLabelRoiScore.
  ///
  /// In pt, this message translates to:
  /// **'ROI Score'**
  String get ecoLabelRoiScore;

  /// No description provided for @ecoLabelMarket.
  ///
  /// In pt, this message translates to:
  /// **'Mercado'**
  String get ecoLabelMarket;

  /// No description provided for @ecoLabelExecution.
  ///
  /// In pt, this message translates to:
  /// **'Execução'**
  String get ecoLabelExecution;

  /// No description provided for @ecoLabelMomentum.
  ///
  /// In pt, this message translates to:
  /// **'Momentum'**
  String get ecoLabelMomentum;

  /// No description provided for @ecoLabelSynergy.
  ///
  /// In pt, this message translates to:
  /// **'Sinergia'**
  String get ecoLabelSynergy;

  /// No description provided for @ecoLabelTotalRoi.
  ///
  /// In pt, this message translates to:
  /// **'ROI Total'**
  String get ecoLabelTotalRoi;

  /// No description provided for @ecoLabelEcosystem.
  ///
  /// In pt, this message translates to:
  /// **'Ecosystem'**
  String get ecoLabelEcosystem;

  /// No description provided for @ecoAskIveImproveScore.
  ///
  /// In pt, this message translates to:
  /// **'Perguntar à IVE como melhorar este score'**
  String get ecoAskIveImproveScore;

  /// No description provided for @ecoAskIveImproveScoreDesc.
  ///
  /// In pt, this message translates to:
  /// **'Abrir chat com contexto deste projeto'**
  String get ecoAskIveImproveScoreDesc;

  /// No description provided for @ecoIveAskImproveProject.
  ///
  /// In pt, this message translates to:
  /// **'Como posso melhorar o Ecosystem Score do projeto \"{name}\" que está em {score}/100? Explique cada componente e quais ações têm maior impacto.'**
  String ecoIveAskImproveProject(String name, int score);

  /// No description provided for @ecoShortMarket.
  ///
  /// In pt, this message translates to:
  /// **'Mkt {score}'**
  String ecoShortMarket(int score);

  /// No description provided for @ecoShortFit.
  ///
  /// In pt, this message translates to:
  /// **'Fit {score}'**
  String ecoShortFit(int score);

  /// No description provided for @ecoShortExec.
  ///
  /// In pt, this message translates to:
  /// **'Exec {score}'**
  String ecoShortExec(int score);

  /// No description provided for @ecoIveAskProjectScore.
  ///
  /// In pt, this message translates to:
  /// **'Por que o projeto {name} tem score {score}? Explique cada componente e como melhorar.'**
  String ecoIveAskProjectScore(String name, int score);

  /// No description provided for @ecoEcosystemEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Adicione projetos para ver o Ecosystem Score.'**
  String get ecoEcosystemEmpty;

  /// No description provided for @ecoCardFooter.
  ///
  /// In pt, this message translates to:
  /// **'{count} ações  •  {percent}% concluídas  •  R\${roi} ROI'**
  String ecoCardFooter(int count, int percent, String roi);

  /// No description provided for @ecoStrengthsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Pontos Fortes'**
  String get ecoStrengthsTitle;

  /// No description provided for @ecoRisksTitle.
  ///
  /// In pt, this message translates to:
  /// **'Riscos'**
  String get ecoRisksTitle;

  /// No description provided for @ecoQuickWinsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ganhos Rápidos'**
  String get ecoQuickWinsTitle;

  /// No description provided for @ecoRecsEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Adicione projetos e análises para gerar recomendações.'**
  String get ecoRecsEmpty;

  /// No description provided for @ecoBlockedBadge.
  ///
  /// In pt, this message translates to:
  /// **'🔒 BLOQUEADO'**
  String get ecoBlockedBadge;

  /// No description provided for @ecoGateDocuments.
  ///
  /// In pt, this message translates to:
  /// **'Documentos'**
  String get ecoGateDocuments;

  /// No description provided for @ecoGateIndexing.
  ///
  /// In pt, this message translates to:
  /// **'Indexação'**
  String get ecoGateIndexing;

  /// No description provided for @ecoGateAssets.
  ///
  /// In pt, this message translates to:
  /// **'Ativos'**
  String get ecoGateAssets;

  /// No description provided for @ecoGateOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades'**
  String get ecoGateOpportunities;

  /// No description provided for @ecoGateBlockReasons.
  ///
  /// In pt, this message translates to:
  /// **'Motivos do bloqueio:'**
  String get ecoGateBlockReasons;

  /// No description provided for @ecoExpectedImpact.
  ///
  /// In pt, this message translates to:
  /// **'Impacto esperado: {impact}'**
  String ecoExpectedImpact(String impact);

  /// No description provided for @ecoLabelConfidence.
  ///
  /// In pt, this message translates to:
  /// **'Confiança'**
  String get ecoLabelConfidence;

  /// No description provided for @ecoLabelDataUsed.
  ///
  /// In pt, this message translates to:
  /// **'Dados usados'**
  String get ecoLabelDataUsed;

  /// No description provided for @ecoAskIveRecommendation.
  ///
  /// In pt, this message translates to:
  /// **'Perguntar à IVE sobre esta recomendação'**
  String get ecoAskIveRecommendation;

  /// No description provided for @ecoIveAskRecommendation.
  ///
  /// In pt, this message translates to:
  /// **'Explique a recomendação \"{title}\" e me dê um plano de ação concreto.'**
  String ecoIveAskRecommendation(String title);

  /// No description provided for @ecoConfidencePct.
  ///
  /// In pt, this message translates to:
  /// **'{percent}% confiança'**
  String ecoConfidencePct(int percent);

  /// No description provided for @ecoDataPrefix.
  ///
  /// In pt, this message translates to:
  /// **'Dados: {data}'**
  String ecoDataPrefix(String data);

  /// No description provided for @ecoWeeklyBriefingTitle.
  ///
  /// In pt, this message translates to:
  /// **'Briefing Executivo Semanal'**
  String get ecoWeeklyBriefingTitle;

  /// No description provided for @ecoBriefingError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao gerar briefing: {error}'**
  String ecoBriefingError(String error);

  /// No description provided for @ecoBriefSectionChanged.
  ///
  /// In pt, this message translates to:
  /// **'🔄 O que mudou'**
  String get ecoBriefSectionChanged;

  /// No description provided for @ecoBriefSectionGrew.
  ///
  /// In pt, this message translates to:
  /// **'📈 O que cresceu'**
  String get ecoBriefSectionGrew;

  /// No description provided for @ecoBriefSectionDeclined.
  ///
  /// In pt, this message translates to:
  /// **'📉 O que piorou'**
  String get ecoBriefSectionDeclined;

  /// No description provided for @ecoBriefSectionPriorities.
  ///
  /// In pt, this message translates to:
  /// **'🎯 O que priorizar'**
  String get ecoBriefSectionPriorities;

  /// No description provided for @ecoBriefSectionPause.
  ///
  /// In pt, this message translates to:
  /// **'⏸️ O que pausar'**
  String get ecoBriefSectionPause;

  /// No description provided for @ecoBriefSectionNewOpps.
  ///
  /// In pt, this message translates to:
  /// **'💡 Oportunidades novas'**
  String get ecoBriefSectionNewOpps;

  /// No description provided for @ecoBriefSectionRisks.
  ///
  /// In pt, this message translates to:
  /// **'⚠️ Riscos'**
  String get ecoBriefSectionRisks;

  /// No description provided for @ecoBriefSectionRisksIdentified.
  ///
  /// In pt, this message translates to:
  /// **'⚠️ Riscos identificados'**
  String get ecoBriefSectionRisksIdentified;

  /// No description provided for @ecoBriefOverallHealth.
  ///
  /// In pt, this message translates to:
  /// **'Saúde Geral'**
  String get ecoBriefOverallHealth;

  /// No description provided for @ecoBriefOverallHealthValue.
  ///
  /// In pt, this message translates to:
  /// **'Saúde Geral: {score}/100'**
  String ecoBriefOverallHealthValue(int score);

  /// No description provided for @ecoBriefLowScoreHint.
  ///
  /// In pt, this message translates to:
  /// **'⚠ Score baixo. Veja os riscos identificados e as prioridades abaixo para melhorar.'**
  String get ecoBriefLowScoreHint;

  /// No description provided for @ecoBriefHeaderLabel.
  ///
  /// In pt, this message translates to:
  /// **'BRIEFING EXECUTIVO'**
  String get ecoBriefHeaderLabel;

  /// No description provided for @ecoBriefWeekOf.
  ///
  /// In pt, this message translates to:
  /// **'Semana de {date}'**
  String ecoBriefWeekOf(String date);

  /// No description provided for @ecoBriefExecutiveSummary.
  ///
  /// In pt, this message translates to:
  /// **'Resumo Executivo'**
  String get ecoBriefExecutiveSummary;

  /// No description provided for @ecoBriefNoItemsThisWeek.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum item nesta semana'**
  String get ecoBriefNoItemsThisWeek;

  /// No description provided for @ecoBriefDataAnalyzed.
  ///
  /// In pt, this message translates to:
  /// **'DADOS ANALISADOS'**
  String get ecoBriefDataAnalyzed;

  /// No description provided for @ecoBriefGeneratedAt.
  ///
  /// In pt, this message translates to:
  /// **'Gerado em {date} às {time}'**
  String ecoBriefGeneratedAt(String date, String time);

  /// No description provided for @ecoCountProjects.
  ///
  /// In pt, this message translates to:
  /// **'Projetos'**
  String get ecoCountProjects;

  /// No description provided for @ecoCountAnalyses.
  ///
  /// In pt, this message translates to:
  /// **'Análises'**
  String get ecoCountAnalyses;

  /// No description provided for @ecoCountActions.
  ///
  /// In pt, this message translates to:
  /// **'Ações'**
  String get ecoCountActions;

  /// No description provided for @ecoBriefIncludedProjects.
  ///
  /// In pt, this message translates to:
  /// **'Projetos incluídos'**
  String get ecoBriefIncludedProjects;

  /// No description provided for @ctxIveProjectsMsg1.
  ///
  /// In pt, this message translates to:
  /// **'Olá! Sou a IVE, sua consultora executiva. Posso analisar seu portfólio agora.'**
  String get ctxIveProjectsMsg1;

  /// No description provided for @ctxIveProjectsMsg2.
  ///
  /// In pt, this message translates to:
  /// **'Quer saber qual projeto tem mais potencial de escala neste momento?'**
  String get ctxIveProjectsMsg2;

  /// No description provided for @ctxIveProjectsMsg3.
  ///
  /// In pt, this message translates to:
  /// **'Identifico padrões entre seus projetos. Alguma dúvida estratégica?'**
  String get ctxIveProjectsMsg3;

  /// No description provided for @ctxIveOppLabMsg1.
  ///
  /// In pt, this message translates to:
  /// **'Identifiquei oportunidades com alto ROI nesta lista. Posso priorizar para você.'**
  String get ctxIveOppLabMsg1;

  /// No description provided for @ctxIveOppLabMsg2.
  ///
  /// In pt, this message translates to:
  /// **'Cada oportunidade aqui tem critérios mensuráveis. Posso explicar qualquer uma.'**
  String get ctxIveOppLabMsg2;

  /// No description provided for @ctxIveOppLabMsg3.
  ///
  /// In pt, this message translates to:
  /// **'Quer que eu indique quais oportunidades executar primeiro esta semana?'**
  String get ctxIveOppLabMsg3;

  /// No description provided for @ctxIveEcosystemMsg1.
  ///
  /// In pt, this message translates to:
  /// **'Este é seu centro de decisão. Posso explicar qualquer score em linguagem simples.'**
  String get ctxIveEcosystemMsg1;

  /// No description provided for @ctxIveEcosystemMsg2.
  ///
  /// In pt, this message translates to:
  /// **'Vejo projetos com potencial não explorado. Quer uma análise detalhada?'**
  String get ctxIveEcosystemMsg2;

  /// No description provided for @ctxIveEcosystemMsg3.
  ///
  /// In pt, this message translates to:
  /// **'Posso simular o impacto de aprovar oportunidades ou concluir ações.'**
  String get ctxIveEcosystemMsg3;

  /// No description provided for @ctxIveBriefingMsg1.
  ///
  /// In pt, this message translates to:
  /// **'Seu briefing executivo está pronto. Posso destacar o que é mais urgente.'**
  String get ctxIveBriefingMsg1;

  /// No description provided for @ctxIveBriefingMsg2.
  ///
  /// In pt, this message translates to:
  /// **'Quer que eu traduza este relatório em próximos passos concretos?'**
  String get ctxIveBriefingMsg2;

  /// No description provided for @ctxIveBriefingMsg3.
  ///
  /// In pt, this message translates to:
  /// **'Posso identificar o que mudou esta semana e por quê.'**
  String get ctxIveBriefingMsg3;

  /// No description provided for @ctxIvePersonasMsg1.
  ///
  /// In pt, this message translates to:
  /// **'Suas personas são sua presença no mercado. Posso comparar o desempenho de cada uma.'**
  String get ctxIvePersonasMsg1;

  /// No description provided for @ctxIvePersonasMsg2.
  ///
  /// In pt, this message translates to:
  /// **'Quer saber qual persona tem maior potencial de crescimento agora?'**
  String get ctxIvePersonasMsg2;

  /// No description provided for @ctxIvePersonasMsg3.
  ///
  /// In pt, this message translates to:
  /// **'Posso recomendar estratégias específicas para cada nicho.'**
  String get ctxIvePersonasMsg3;

  /// No description provided for @ctxIveKnowledgeMsg1.
  ///
  /// In pt, this message translates to:
  /// **'Seu cofre de conhecimento alimenta toda a inteligência do sistema.'**
  String get ctxIveKnowledgeMsg1;

  /// No description provided for @ctxIveKnowledgeMsg2.
  ///
  /// In pt, this message translates to:
  /// **'Qual documento quer que eu analise ou conecte com seus projetos?'**
  String get ctxIveKnowledgeMsg2;

  /// No description provided for @ctxIveKnowledgeMsg3.
  ///
  /// In pt, this message translates to:
  /// **'Posso mostrar quais conhecimentos estão gerando mais insights.'**
  String get ctxIveKnowledgeMsg3;

  /// No description provided for @ctxIveActionsMsg1.
  ///
  /// In pt, this message translates to:
  /// **'Sua fila de ações determina sua velocidade de execução.'**
  String get ctxIveActionsMsg1;

  /// No description provided for @ctxIveActionsMsg2.
  ///
  /// In pt, this message translates to:
  /// **'Posso ajudar a priorizar: quais ações têm maior impacto no score?'**
  String get ctxIveActionsMsg2;

  /// No description provided for @ctxIveActionsMsg3.
  ///
  /// In pt, this message translates to:
  /// **'Quer que eu identifique o que está bloqueando seu progresso?'**
  String get ctxIveActionsMsg3;

  /// No description provided for @ctxIveDebugMsg1.
  ///
  /// In pt, this message translates to:
  /// **'Centro de observabilidade completo. Posso auditar qualquer cálculo.'**
  String get ctxIveDebugMsg1;

  /// No description provided for @ctxIveDebugMsg2.
  ///
  /// In pt, this message translates to:
  /// **'Quer entender como um score foi gerado? Basta perguntar.'**
  String get ctxIveDebugMsg2;

  /// No description provided for @ctxIveDebugMsg3.
  ///
  /// In pt, this message translates to:
  /// **'Posso rastrear a origem de qualquer dado ou recomendação.'**
  String get ctxIveDebugMsg3;

  /// No description provided for @ctxIveAnalysisCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Análise de \"{name}\" concluída!'**
  String ctxIveAnalysisCompleted(String name);

  /// No description provided for @ctxIveAnalyzing.
  ///
  /// In pt, this message translates to:
  /// **'Analisando \"{name}\"...'**
  String ctxIveAnalyzing(String name);

  /// No description provided for @ctxIveProjectCreated.
  ///
  /// In pt, this message translates to:
  /// **'Projeto \"{name}\" criado!'**
  String ctxIveProjectCreated(String name);

  /// No description provided for @ctxIveProjectRemoved.
  ///
  /// In pt, this message translates to:
  /// **'Projeto \"{name}\" removido.'**
  String ctxIveProjectRemoved(String name);

  /// No description provided for @ctxIveProjectStatusChanged.
  ///
  /// In pt, this message translates to:
  /// **'\"{name}\" {status}.'**
  String ctxIveProjectStatusChanged(String name, String status);

  /// No description provided for @ctxIveStatusActivated.
  ///
  /// In pt, this message translates to:
  /// **'ativado'**
  String get ctxIveStatusActivated;

  /// No description provided for @ctxIveStatusPaused.
  ///
  /// In pt, this message translates to:
  /// **'pausado'**
  String get ctxIveStatusPaused;

  /// No description provided for @ctxIveStatusCompleted.
  ///
  /// In pt, this message translates to:
  /// **'concluído'**
  String get ctxIveStatusCompleted;

  /// No description provided for @ctxIveCtxEcosystem.
  ///
  /// In pt, this message translates to:
  /// **'Ecossistema em {score}/100. Principal gargalo: {bottleneck}. Posso detalhar como melhorar.'**
  String ctxIveCtxEcosystem(int score, String bottleneck);

  /// No description provided for @ctxIveCtxBottleneckFallback.
  ///
  /// In pt, this message translates to:
  /// **'execução'**
  String get ctxIveCtxBottleneckFallback;

  /// No description provided for @ctxIveCtxProjectLeads.
  ///
  /// In pt, this message translates to:
  /// **'{name} lidera com score {score}.'**
  String ctxIveCtxProjectLeads(String name, int score);

  /// No description provided for @ctxIveCtxPendingDetected.
  ///
  /// In pt, this message translates to:
  /// **'Ações pendentes detectadas: {count}.'**
  String ctxIveCtxPendingDetected(int count);

  /// No description provided for @ctxIveCtxAnalyzeOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Quer analisar oportunidades?'**
  String get ctxIveCtxAnalyzeOpportunities;

  /// No description provided for @ctxIveCtxOppLab.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades aguardando sua avaliação: {count}. Posso priorizar as de maior ROI.'**
  String ctxIveCtxOppLab(int count);

  /// No description provided for @ctxIveCtxBriefing.
  ///
  /// In pt, this message translates to:
  /// **'Briefing gerado com saúde geral em {score}/100. Posso traduzir os dados em ações concretas.'**
  String ctxIveCtxBriefing(int score);

  /// No description provided for @ctxIveCtxActions.
  ///
  /// In pt, this message translates to:
  /// **'Ações pendentes: {count}. Posso identificar as de maior impacto no score de execução.'**
  String ctxIveCtxActions(int count);

  /// No description provided for @ctxIssueAnalysisFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui analisar \"{name}\".\nA falha ocorreu durante o processamento pela IA.\nVocê pode tentar novamente.'**
  String ctxIssueAnalysisFailed(String name);

  /// No description provided for @ctxIssueDownloadFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui importar \"{name}\".\nA falha ocorreu durante o download do arquivo.\nO conteúdo ainda não foi analisado.'**
  String ctxIssueDownloadFailed(String name);

  /// No description provided for @ctxIssueActionMutationFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui atualizar \"{name}\".\nVerifique sua conexão e tente novamente.'**
  String ctxIssueActionMutationFailed(String name);

  /// No description provided for @ctxIssueActionViewDetails.
  ///
  /// In pt, this message translates to:
  /// **'Ver detalhes'**
  String get ctxIssueActionViewDetails;

  /// No description provided for @ctxIssueActionUpdateLink.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar link'**
  String get ctxIssueActionUpdateLink;

  /// No description provided for @ctxIssueActionSendFile.
  ///
  /// In pt, this message translates to:
  /// **'Enviar arquivo'**
  String get ctxIssueActionSendFile;

  /// No description provided for @ctxIssueActionDismiss.
  ///
  /// In pt, this message translates to:
  /// **'Dispensar'**
  String get ctxIssueActionDismiss;

  /// No description provided for @ctxAlertHealthLow.
  ///
  /// In pt, this message translates to:
  /// **'Saúde do ecossistema em {health}/100. Ação imediata recomendada.'**
  String ctxAlertHealthLow(int health);

  /// No description provided for @ctxAlertProjectCritical.
  ///
  /// In pt, this message translates to:
  /// **'{name} com score crítico ({score}/100). Posso identificar o que está limitando.'**
  String ctxAlertProjectCritical(String name, int score);

  /// No description provided for @ctxAlertActionsOverdue.
  ///
  /// In pt, this message translates to:
  /// **'Ações pendentes acumuladas: {count}. Isso está impactando seu score de execução.'**
  String ctxAlertActionsOverdue(int count);

  /// No description provided for @ctxDocCoverageWarning.
  ///
  /// In pt, this message translates to:
  /// **'{total} fontes vinculadas · {used} utilizadas nesta análise · {unused} não utilizadas nesta execução.'**
  String ctxDocCoverageWarning(int total, int used, int unused);

  /// No description provided for @ctxGroundingEmptyContent.
  ///
  /// In pt, this message translates to:
  /// **'\"{title}\": registrado mas sem conteúdo processável.'**
  String ctxGroundingEmptyContent(String title);

  /// No description provided for @ctxGroundingBudgetExceeded.
  ///
  /// In pt, this message translates to:
  /// **'Limite de {maxChars} caracteres atingido. Documentos posteriores omitidos.'**
  String ctxGroundingBudgetExceeded(int maxChars);

  /// No description provided for @ctxDvReasonCoverage.
  ///
  /// In pt, this message translates to:
  /// **'Knowledge Coverage insuficiente ({score}% < {min}%)'**
  String ctxDvReasonCoverage(int score, int min);

  /// No description provided for @ctxDvReasonLearning.
  ///
  /// In pt, this message translates to:
  /// **'Learning Score médio insuficiente ({score}% < {min}%)'**
  String ctxDvReasonLearning(int score, int min);

  /// No description provided for @ctxDvReasonProfile.
  ///
  /// In pt, this message translates to:
  /// **'Perfil de inteligência incompleto — vincule uma análise de mercado'**
  String get ctxDvReasonProfile;

  /// No description provided for @ctxDvReasonStructuring.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma oportunidade ou ação gerada ainda — execute o Knowledge → Action Engine'**
  String get ctxDvReasonStructuring;

  /// No description provided for @ctxDvBlockStructuring.
  ///
  /// In pt, this message translates to:
  /// **'Projeto ainda em fase de estruturação. Conhecimento disponível, mas inteligência operacional insuficiente para recomendação estratégica.'**
  String get ctxDvBlockStructuring;

  /// No description provided for @ctxDvBlockInsufficient.
  ///
  /// In pt, this message translates to:
  /// **'Dados insuficientes para decisão estratégica.'**
  String get ctxDvBlockInsufficient;

  /// No description provided for @ctxDvNoDocuments.
  ///
  /// In pt, this message translates to:
  /// **'Sem documentos'**
  String get ctxDvNoDocuments;

  /// No description provided for @ctxDvIndexedCount.
  ///
  /// In pt, this message translates to:
  /// **'{indexed}/{total} indexados'**
  String ctxDvIndexedCount(int indexed, int total);

  /// No description provided for @ctxDvThresholdLabel.
  ///
  /// In pt, this message translates to:
  /// **'{mark} {score}% (mínimo {min}%)'**
  String ctxDvThresholdLabel(String mark, int score, int min);

  /// No description provided for @ctxDvProfileComplete.
  ///
  /// In pt, this message translates to:
  /// **'✅ Completo'**
  String get ctxDvProfileComplete;

  /// No description provided for @ctxDvProfileIncomplete.
  ///
  /// In pt, this message translates to:
  /// **'❌ Incompleto — vincule uma análise de mercado'**
  String get ctxDvProfileIncomplete;

  /// No description provided for @ctxCoverageExcellent.
  ///
  /// In pt, this message translates to:
  /// **'Excelente'**
  String get ctxCoverageExcellent;

  /// No description provided for @ctxCoverageGood.
  ///
  /// In pt, this message translates to:
  /// **'Bom'**
  String get ctxCoverageGood;

  /// No description provided for @ctxCoverageModerate.
  ///
  /// In pt, this message translates to:
  /// **'Moderado'**
  String get ctxCoverageModerate;

  /// No description provided for @ctxCoverageBasic.
  ///
  /// In pt, this message translates to:
  /// **'Básico'**
  String get ctxCoverageBasic;

  /// No description provided for @ctxCoverageMinimal.
  ///
  /// In pt, this message translates to:
  /// **'Mínimo'**
  String get ctxCoverageMinimal;

  /// No description provided for @ctxGapNoDocuments.
  ///
  /// In pt, this message translates to:
  /// **'Adicione documentos ao Cofre de Conhecimento'**
  String get ctxGapNoDocuments;

  /// No description provided for @ctxGapNoOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Sem oportunidades — execute o Knowledge → Action Engine'**
  String get ctxGapNoOpportunities;

  /// No description provided for @ctxGapNoActions.
  ///
  /// In pt, this message translates to:
  /// **'Sem ações definidas para o projeto'**
  String get ctxGapNoActions;

  /// No description provided for @ctxGapNoRoadmap.
  ///
  /// In pt, this message translates to:
  /// **'Roadmap não gerado — execute o Bootstrap'**
  String get ctxGapNoRoadmap;

  /// No description provided for @ctxGapNoRevenuePlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano de receita não criado'**
  String get ctxGapNoRevenuePlan;

  /// No description provided for @ctxGapUntrainedPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Personas sem treinamento de conhecimento'**
  String get ctxGapUntrainedPersonas;

  /// No description provided for @ctxStrengthKnowledgeBase.
  ///
  /// In pt, this message translates to:
  /// **'Base de conhecimento estabelecida'**
  String get ctxStrengthKnowledgeBase;

  /// No description provided for @ctxStrengthOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades mapeadas'**
  String get ctxStrengthOpportunities;

  /// No description provided for @ctxStrengthActions.
  ///
  /// In pt, this message translates to:
  /// **'Ações planejadas'**
  String get ctxStrengthActions;

  /// No description provided for @ctxStrengthRoadmap.
  ///
  /// In pt, this message translates to:
  /// **'Roadmap estruturado'**
  String get ctxStrengthRoadmap;

  /// No description provided for @ctxStrengthRevenuePlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano de receita projetado'**
  String get ctxStrengthRevenuePlan;

  /// No description provided for @ctxStrengthTrainedPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Personas com conhecimento treinado'**
  String get ctxStrengthTrainedPersonas;

  /// No description provided for @ctxLearningExpert.
  ///
  /// In pt, this message translates to:
  /// **'Especialista'**
  String get ctxLearningExpert;

  /// No description provided for @ctxLearningAdvanced.
  ///
  /// In pt, this message translates to:
  /// **'Avançado'**
  String get ctxLearningAdvanced;

  /// No description provided for @ctxLearningIntermediate.
  ///
  /// In pt, this message translates to:
  /// **'Intermediário'**
  String get ctxLearningIntermediate;

  /// No description provided for @ctxLearningBeginner.
  ///
  /// In pt, this message translates to:
  /// **'Iniciante'**
  String get ctxLearningBeginner;

  /// No description provided for @ctxLearningUntrained.
  ///
  /// In pt, this message translates to:
  /// **'Sem Treinamento'**
  String get ctxLearningUntrained;

  /// No description provided for @ctxMaturityMature.
  ///
  /// In pt, this message translates to:
  /// **'Maduro'**
  String get ctxMaturityMature;

  /// No description provided for @ctxMaturityGrowing.
  ///
  /// In pt, this message translates to:
  /// **'Crescendo'**
  String get ctxMaturityGrowing;

  /// No description provided for @ctxMaturityValidating.
  ///
  /// In pt, this message translates to:
  /// **'Validando'**
  String get ctxMaturityValidating;

  /// No description provided for @ctxMaturityIdea.
  ///
  /// In pt, this message translates to:
  /// **'Ideia'**
  String get ctxMaturityIdea;

  /// No description provided for @ctxProfileWarningNoAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Execute uma análise de mercado para obter inteligência.'**
  String get ctxProfileWarningNoAnalysis;

  /// No description provided for @ctxProfileWarningLowData.
  ///
  /// In pt, this message translates to:
  /// **'Dados insuficientes. Adicione ações e oportunidades.'**
  String get ctxProfileWarningLowData;

  /// No description provided for @ctxProfileNotDefined.
  ///
  /// In pt, this message translates to:
  /// **'Não definido'**
  String get ctxProfileNotDefined;

  /// No description provided for @ctxEmptyServerResponse.
  ///
  /// In pt, this message translates to:
  /// **'Resposta vazia do servidor.'**
  String get ctxEmptyServerResponse;

  /// No description provided for @ctxDurationYears.
  ///
  /// In pt, this message translates to:
  /// **'{count}a'**
  String ctxDurationYears(int count);

  /// No description provided for @ctxDurationMonths.
  ///
  /// In pt, this message translates to:
  /// **'{count}m'**
  String ctxDurationMonths(int count);

  /// No description provided for @ctxDurationDays.
  ///
  /// In pt, this message translates to:
  /// **'{count}d'**
  String ctxDurationDays(int count);

  /// No description provided for @ctxProjectTypeWebsite.
  ///
  /// In pt, this message translates to:
  /// **'Site'**
  String get ctxProjectTypeWebsite;

  /// No description provided for @ctxProjectTypeApp.
  ///
  /// In pt, this message translates to:
  /// **'App'**
  String get ctxProjectTypeApp;

  /// No description provided for @ctxProjectTypeProduct.
  ///
  /// In pt, this message translates to:
  /// **'Produto'**
  String get ctxProjectTypeProduct;

  /// No description provided for @ctxProjectTypeService.
  ///
  /// In pt, this message translates to:
  /// **'Serviço'**
  String get ctxProjectTypeService;

  /// No description provided for @ctxProjectTypeContent.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdo'**
  String get ctxProjectTypeContent;

  /// No description provided for @ctxHomeFeatureUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Este recurso ainda não está disponível.'**
  String get ctxHomeFeatureUnavailable;

  /// No description provided for @ctxHomeCommandCenter.
  ///
  /// In pt, this message translates to:
  /// **'Command Center'**
  String get ctxHomeCommandCenter;

  /// No description provided for @ctxHomeImprovePostTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Melhorar Post'**
  String get ctxHomeImprovePostTooltip;

  /// No description provided for @ctxHomeRefreshTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get ctxHomeRefreshTooltip;

  /// No description provided for @ctxHomeExecCommandCenter.
  ///
  /// In pt, this message translates to:
  /// **'Executive Command Center'**
  String get ctxHomeExecCommandCenter;

  /// No description provided for @ctxHomeMetricProjects.
  ///
  /// In pt, this message translates to:
  /// **'Projetos'**
  String get ctxHomeMetricProjects;

  /// No description provided for @ctxHomeMetricOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades'**
  String get ctxHomeMetricOpportunities;

  /// No description provided for @ctxHomeMetricPendingActions.
  ///
  /// In pt, this message translates to:
  /// **'Ações Pendentes'**
  String get ctxHomeMetricPendingActions;

  /// No description provided for @ctxHomeMetricKnowledge.
  ///
  /// In pt, this message translates to:
  /// **'Conhecimento'**
  String get ctxHomeMetricKnowledge;

  /// No description provided for @ctxHomeMetricLearning.
  ///
  /// In pt, this message translates to:
  /// **'Learning Score'**
  String get ctxHomeMetricLearning;

  /// No description provided for @ctxHomeQuickDecisionCenter.
  ///
  /// In pt, this message translates to:
  /// **'Decision Center'**
  String get ctxHomeQuickDecisionCenter;

  /// No description provided for @ctxHomeQuickBriefing.
  ///
  /// In pt, this message translates to:
  /// **'Briefing'**
  String get ctxHomeQuickBriefing;

  /// No description provided for @ctxHomePriorityProjects.
  ///
  /// In pt, this message translates to:
  /// **'Projetos Prioritários'**
  String get ctxHomePriorityProjects;

  /// No description provided for @ctxHomeNoProjects.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum projeto cadastrado.'**
  String get ctxHomeNoProjects;

  /// No description provided for @ctxHomeAddProject.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar projeto'**
  String get ctxHomeAddProject;

  /// No description provided for @ctxHomeNextBestAction.
  ///
  /// In pt, this message translates to:
  /// **'Próxima Melhor Ação'**
  String get ctxHomeNextBestAction;

  /// No description provided for @ctxHomeNoRecommendations.
  ///
  /// In pt, this message translates to:
  /// **'Sem recomendações disponíveis.'**
  String get ctxHomeNoRecommendations;

  /// No description provided for @ctxHomeViewOpportunityLab.
  ///
  /// In pt, this message translates to:
  /// **'Ver Opportunity Lab'**
  String get ctxHomeViewOpportunityLab;

  /// No description provided for @ctxHomeConfidence.
  ///
  /// In pt, this message translates to:
  /// **'{value}% confiança'**
  String ctxHomeConfidence(int value);

  /// No description provided for @ctxHomeExpectedImpact.
  ///
  /// In pt, this message translates to:
  /// **'Impacto esperado: {impact}'**
  String ctxHomeExpectedImpact(String impact);

  /// No description provided for @ctxHomePersonas.
  ///
  /// In pt, this message translates to:
  /// **'Personas'**
  String get ctxHomePersonas;

  /// No description provided for @ctxHomeNoPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma persona criada.'**
  String get ctxHomeNoPersonas;

  /// No description provided for @ctxHomeCreatePersona.
  ///
  /// In pt, this message translates to:
  /// **'Criar persona'**
  String get ctxHomeCreatePersona;

  /// No description provided for @ctxHomeEcosystemIntelligence.
  ///
  /// In pt, this message translates to:
  /// **'Inteligência do Ecossistema'**
  String get ctxHomeEcosystemIntelligence;

  /// No description provided for @ctxHomeStatProjects.
  ///
  /// In pt, this message translates to:
  /// **'Projetos: {count}'**
  String ctxHomeStatProjects(int count);

  /// No description provided for @ctxHomeStatOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades: {count}'**
  String ctxHomeStatOpportunities(int count);

  /// No description provided for @ctxHomeStatActions.
  ///
  /// In pt, this message translates to:
  /// **'Ações: {count}'**
  String ctxHomeStatActions(int count);

  /// No description provided for @ctxHomeStatConnections.
  ///
  /// In pt, this message translates to:
  /// **'Conexões: {count}'**
  String ctxHomeStatConnections(int count);

  /// No description provided for @ctxHomeConnectionsFound.
  ///
  /// In pt, this message translates to:
  /// **'Conexões identificadas:'**
  String get ctxHomeConnectionsFound;

  /// No description provided for @ctxHomeNoConnections.
  ///
  /// In pt, this message translates to:
  /// **'Execute análises de mercado para descobrir conexões entre seus projetos.'**
  String get ctxHomeNoConnections;

  /// No description provided for @ctxHomeSeeAll.
  ///
  /// In pt, this message translates to:
  /// **'ver todos'**
  String get ctxHomeSeeAll;

  /// No description provided for @ctxHomeHealth.
  ///
  /// In pt, this message translates to:
  /// **'Saúde {score}/100'**
  String ctxHomeHealth(int score);

  /// No description provided for @ctxHomeCoverage.
  ///
  /// In pt, this message translates to:
  /// **'{emoji} {score}% de cobertura'**
  String ctxHomeCoverage(String emoji, int score);

  /// No description provided for @ctxHomePersonaStats.
  ///
  /// In pt, this message translates to:
  /// **'Treinamentos: {trainings} · Palavras: {words}'**
  String ctxHomePersonaStats(int trainings, int words);

  /// No description provided for @ctxHomeError.
  ///
  /// In pt, this message translates to:
  /// **'Erro: {message}'**
  String ctxHomeError(String message);

  /// No description provided for @ctxGraphSharesNiche.
  ///
  /// In pt, this message translates to:
  /// **'compartilha nicho'**
  String get ctxGraphSharesNiche;

  /// No description provided for @ctxGraphUsesKnowledge.
  ///
  /// In pt, this message translates to:
  /// **'usa conhecimento'**
  String get ctxGraphUsesKnowledge;

  /// No description provided for @ctxGraphOpportunityOf.
  ///
  /// In pt, this message translates to:
  /// **'oportunidade de'**
  String get ctxGraphOpportunityOf;

  /// No description provided for @ctxGraphPersonaKnows.
  ///
  /// In pt, this message translates to:
  /// **'persona conhece'**
  String get ctxGraphPersonaKnows;

  /// No description provided for @ctxGraphEdge.
  ///
  /// In pt, this message translates to:
  /// **'{source} → {relation} → {target}'**
  String ctxGraphEdge(String source, String relation, String target);

  /// No description provided for @ctxExecNotEstimated.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não estimado'**
  String get ctxExecNotEstimated;

  /// No description provided for @ctxExecSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'InsightValues · Painel Executivo'**
  String get ctxExecSubtitle;

  /// No description provided for @ctxExecAskIve.
  ///
  /// In pt, this message translates to:
  /// **'Perguntar à IVE'**
  String get ctxExecAskIve;

  /// No description provided for @ctxExecReload.
  ///
  /// In pt, this message translates to:
  /// **'Recarregar'**
  String get ctxExecReload;

  /// No description provided for @ctxExecPortfolioTitle.
  ///
  /// In pt, this message translates to:
  /// **'PORTFÓLIO EXECUTIVO'**
  String get ctxExecPortfolioTitle;

  /// No description provided for @ctxExecActiveProjects.
  ///
  /// In pt, this message translates to:
  /// **'Projetos Ativos'**
  String get ctxExecActiveProjects;

  /// No description provided for @ctxExecTotalProjects.
  ///
  /// In pt, this message translates to:
  /// **'Total de Projetos'**
  String get ctxExecTotalProjects;

  /// No description provided for @ctxExecMiAnalyses.
  ///
  /// In pt, this message translates to:
  /// **'Análises MI'**
  String get ctxExecMiAnalyses;

  /// No description provided for @ctxExecAvgScore.
  ///
  /// In pt, this message translates to:
  /// **'Score Médio'**
  String get ctxExecAvgScore;

  /// No description provided for @ctxExecFinancialTitle.
  ///
  /// In pt, this message translates to:
  /// **'FINANCEIRO'**
  String get ctxExecFinancialTitle;

  /// No description provided for @ctxExecRecordedRevenue.
  ///
  /// In pt, this message translates to:
  /// **'Receita Registrada'**
  String get ctxExecRecordedRevenue;

  /// No description provided for @ctxExecMonthlyPotential.
  ///
  /// In pt, this message translates to:
  /// **'Potencial Mensal'**
  String get ctxExecMonthlyPotential;

  /// No description provided for @ctxExecModProjects.
  ///
  /// In pt, this message translates to:
  /// **'Projetos'**
  String get ctxExecModProjects;

  /// No description provided for @ctxExecTotal.
  ///
  /// In pt, this message translates to:
  /// **'Total'**
  String get ctxExecTotal;

  /// No description provided for @ctxExecActive.
  ///
  /// In pt, this message translates to:
  /// **'Ativos'**
  String get ctxExecActive;

  /// No description provided for @ctxExecInIdea.
  ///
  /// In pt, this message translates to:
  /// **'Em ideia'**
  String get ctxExecInIdea;

  /// No description provided for @ctxExecNoAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Sem análise'**
  String get ctxExecNoAnalysis;

  /// No description provided for @ctxExecEmptyProjects.
  ///
  /// In pt, this message translates to:
  /// **'Cadastre seu primeiro projeto para começar.'**
  String get ctxExecEmptyProjects;

  /// No description provided for @ctxExecViewProjects.
  ///
  /// In pt, this message translates to:
  /// **'Ver Projetos'**
  String get ctxExecViewProjects;

  /// No description provided for @ctxExecAnalyses.
  ///
  /// In pt, this message translates to:
  /// **'Análises'**
  String get ctxExecAnalyses;

  /// No description provided for @ctxExecAvgScoreShort.
  ///
  /// In pt, this message translates to:
  /// **'Score médio'**
  String get ctxExecAvgScoreShort;

  /// No description provided for @ctxExecHighQuality.
  ///
  /// In pt, this message translates to:
  /// **'Alta qualidade'**
  String get ctxExecHighQuality;

  /// No description provided for @ctxExecNoProject.
  ///
  /// In pt, this message translates to:
  /// **'Sem projeto'**
  String get ctxExecNoProject;

  /// No description provided for @ctxExecEmptyMi.
  ///
  /// In pt, this message translates to:
  /// **'Execute uma análise de mercado no Market Intelligence.'**
  String get ctxExecEmptyMi;

  /// No description provided for @ctxExecAnalyzeMarket.
  ///
  /// In pt, this message translates to:
  /// **'Analisar Mercado'**
  String get ctxExecAnalyzeMarket;

  /// No description provided for @ctxExecModOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidades'**
  String get ctxExecModOpportunities;

  /// No description provided for @ctxExecHighPriority.
  ///
  /// In pt, this message translates to:
  /// **'Alta prioridade'**
  String get ctxExecHighPriority;

  /// No description provided for @ctxExecApproved.
  ///
  /// In pt, this message translates to:
  /// **'Aprovadas'**
  String get ctxExecApproved;

  /// No description provided for @ctxExecPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendentes'**
  String get ctxExecPending;

  /// No description provided for @ctxExecEmptyOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Gere oportunidades a partir das análises de mercado.'**
  String get ctxExecEmptyOpportunities;

  /// No description provided for @ctxExecViewOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Ver Oportunidades'**
  String get ctxExecViewOpportunities;

  /// No description provided for @ctxExecInProgress.
  ///
  /// In pt, this message translates to:
  /// **'Em execução'**
  String get ctxExecInProgress;

  /// No description provided for @ctxExecBlocked.
  ///
  /// In pt, this message translates to:
  /// **'Bloqueadas'**
  String get ctxExecBlocked;

  /// No description provided for @ctxExecCompleted.
  ///
  /// In pt, this message translates to:
  /// **'Concluídas'**
  String get ctxExecCompleted;

  /// No description provided for @ctxExecEmptyActions.
  ///
  /// In pt, this message translates to:
  /// **'Aprove oportunidades para gerar ações executáveis.'**
  String get ctxExecEmptyActions;

  /// No description provided for @ctxExecOpenDecisions.
  ///
  /// In pt, this message translates to:
  /// **'Abrir Decisions'**
  String get ctxExecOpenDecisions;

  /// No description provided for @ctxExecWeeklyBriefing.
  ///
  /// In pt, this message translates to:
  /// **'Briefing Semanal'**
  String get ctxExecWeeklyBriefing;

  /// No description provided for @ctxExecAllocation.
  ///
  /// In pt, this message translates to:
  /// **'Alocação'**
  String get ctxExecAllocation;

  /// No description provided for @ctxExecQuickAccess.
  ///
  /// In pt, this message translates to:
  /// **'ACESSO RÁPIDO'**
  String get ctxExecQuickAccess;

  /// No description provided for @ctxExecPendingEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma ação pendente. O Action Engine preencherá automaticamente.'**
  String get ctxExecPendingEmpty;

  /// No description provided for @ctxExecModulesTitle.
  ///
  /// In pt, this message translates to:
  /// **'MÓDULOS DO BUSINESS OS'**
  String get ctxExecModulesTitle;

  /// No description provided for @ctxExecOpenModule.
  ///
  /// In pt, this message translates to:
  /// **'Abrir {label}'**
  String ctxExecOpenModule(String label);

  /// No description provided for @ctxExecModuleUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Módulo não disponível'**
  String get ctxExecModuleUnavailable;

  /// No description provided for @ctxIveDetailExplanation.
  ///
  /// In pt, this message translates to:
  /// **'Explicação IVE'**
  String get ctxIveDetailExplanation;

  /// No description provided for @ctxIveDetailNumbers.
  ///
  /// In pt, this message translates to:
  /// **'Números e fórmulas'**
  String get ctxIveDetailNumbers;

  /// No description provided for @ctxIveDetailSuggestedActions.
  ///
  /// In pt, this message translates to:
  /// **'Ações sugeridas'**
  String get ctxIveDetailSuggestedActions;

  /// No description provided for @ctxIveExplainCompact.
  ///
  /// In pt, this message translates to:
  /// **'Entender'**
  String get ctxIveExplainCompact;

  /// No description provided for @ctxIveExplainFull.
  ///
  /// In pt, this message translates to:
  /// **'Explicar com IVE'**
  String get ctxIveExplainFull;

  /// No description provided for @ctxResultCopied.
  ///
  /// In pt, this message translates to:
  /// **'\"{title}\" copiado!'**
  String ctxResultCopied(String title);

  /// No description provided for @ctxResultCopyTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Copiar'**
  String get ctxResultCopyTooltip;

  /// No description provided for @ctxCopilotConfidenceBadge.
  ///
  /// In pt, this message translates to:
  /// **'{value}% conf.'**
  String ctxCopilotConfidenceBadge(int value);

  /// No description provided for @uxAiInvestmentYes.
  ///
  /// In pt, this message translates to:
  /// **'SIM'**
  String get uxAiInvestmentYes;

  /// No description provided for @uxAiInvestmentConditional.
  ///
  /// In pt, this message translates to:
  /// **'CONDICIONAL'**
  String get uxAiInvestmentConditional;

  /// No description provided for @uxAiInvestmentNo.
  ///
  /// In pt, this message translates to:
  /// **'NÃO'**
  String get uxAiInvestmentNo;

  /// No description provided for @uxAiLevelLow.
  ///
  /// In pt, this message translates to:
  /// **'Baixo'**
  String get uxAiLevelLow;

  /// No description provided for @uxAiLevelMedium.
  ///
  /// In pt, this message translates to:
  /// **'Médio'**
  String get uxAiLevelMedium;

  /// No description provided for @uxAiLevelHigh.
  ///
  /// In pt, this message translates to:
  /// **'Alto'**
  String get uxAiLevelHigh;

  /// No description provided for @uxAiLevelCritical.
  ///
  /// In pt, this message translates to:
  /// **'Crítico'**
  String get uxAiLevelCritical;

  /// No description provided for @uxAiPriorityLow.
  ///
  /// In pt, this message translates to:
  /// **'Baixa'**
  String get uxAiPriorityLow;

  /// No description provided for @uxAiPriorityMedium.
  ///
  /// In pt, this message translates to:
  /// **'Média'**
  String get uxAiPriorityMedium;

  /// No description provided for @uxAiPriorityHigh.
  ///
  /// In pt, this message translates to:
  /// **'Alta'**
  String get uxAiPriorityHigh;

  /// No description provided for @uxAiPriorityCritical.
  ///
  /// In pt, this message translates to:
  /// **'Crítica'**
  String get uxAiPriorityCritical;

  /// No description provided for @uxAiSearchIntentInformational.
  ///
  /// In pt, this message translates to:
  /// **'Informacional'**
  String get uxAiSearchIntentInformational;

  /// No description provided for @uxAiSearchIntentNavigational.
  ///
  /// In pt, this message translates to:
  /// **'Navegacional'**
  String get uxAiSearchIntentNavigational;

  /// No description provided for @uxAiSearchIntentTransactional.
  ///
  /// In pt, this message translates to:
  /// **'Transacional'**
  String get uxAiSearchIntentTransactional;

  /// No description provided for @uxAiSearchIntentCommercial.
  ///
  /// In pt, this message translates to:
  /// **'Comercial'**
  String get uxAiSearchIntentCommercial;

  /// No description provided for @uxAiArticleTypePillar.
  ///
  /// In pt, this message translates to:
  /// **'Página pilar'**
  String get uxAiArticleTypePillar;

  /// No description provided for @uxAiArticleTypeSupporting.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdo de apoio'**
  String get uxAiArticleTypeSupporting;

  /// No description provided for @uxAiArticleTypeLandingPage.
  ///
  /// In pt, this message translates to:
  /// **'Landing page'**
  String get uxAiArticleTypeLandingPage;

  /// No description provided for @uxAiArticleTypeComparison.
  ///
  /// In pt, this message translates to:
  /// **'Comparativo'**
  String get uxAiArticleTypeComparison;

  /// No description provided for @uxAiOpportunityTypeContent.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdo'**
  String get uxAiOpportunityTypeContent;

  /// No description provided for @uxAiOpportunityTypeSeo.
  ///
  /// In pt, this message translates to:
  /// **'SEO'**
  String get uxAiOpportunityTypeSeo;

  /// No description provided for @uxAiOpportunityTypeProduct.
  ///
  /// In pt, this message translates to:
  /// **'Produto'**
  String get uxAiOpportunityTypeProduct;

  /// No description provided for @uxAiOpportunityTypeMonetization.
  ///
  /// In pt, this message translates to:
  /// **'Monetização'**
  String get uxAiOpportunityTypeMonetization;

  /// No description provided for @uxAiOpportunityTypePartnership.
  ///
  /// In pt, this message translates to:
  /// **'Parceria'**
  String get uxAiOpportunityTypePartnership;

  /// No description provided for @uxAiOpportunityTypePlatform.
  ///
  /// In pt, this message translates to:
  /// **'Plataforma'**
  String get uxAiOpportunityTypePlatform;

  /// No description provided for @uxAiOpportunityTypeAudience.
  ///
  /// In pt, this message translates to:
  /// **'Audiência'**
  String get uxAiOpportunityTypeAudience;

  /// No description provided for @uxAiTimeframeMonths.
  ///
  /// In pt, this message translates to:
  /// **'{range} meses'**
  String uxAiTimeframeMonths(String range);

  /// No description provided for @uxAiTimeframeWeeks.
  ///
  /// In pt, this message translates to:
  /// **'{range} semanas'**
  String uxAiTimeframeWeeks(String range);

  /// No description provided for @uxAiTimeframeDays.
  ///
  /// In pt, this message translates to:
  /// **'{range} dias'**
  String uxAiTimeframeDays(String range);

  /// No description provided for @uxCampaignObjectiveSales.
  ///
  /// In pt, this message translates to:
  /// **'Venda'**
  String get uxCampaignObjectiveSales;

  /// No description provided for @uxCampaignObjectiveAuthority.
  ///
  /// In pt, this message translates to:
  /// **'Autoridade'**
  String get uxCampaignObjectiveAuthority;

  /// No description provided for @uxCampaignObjectiveLeads.
  ///
  /// In pt, this message translates to:
  /// **'Leads'**
  String get uxCampaignObjectiveLeads;

  /// No description provided for @uxCampaignObjectiveEngagement.
  ///
  /// In pt, this message translates to:
  /// **'Engajamento'**
  String get uxCampaignObjectiveEngagement;

  /// No description provided for @uxCampaignObjectiveLaunch.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento'**
  String get uxCampaignObjectiveLaunch;

  /// No description provided for @uxCampaignObjectiveTraffic.
  ///
  /// In pt, this message translates to:
  /// **'Tráfego'**
  String get uxCampaignObjectiveTraffic;

  /// No description provided for @uxCampaignObjectiveSalesOn.
  ///
  /// In pt, this message translates to:
  /// **'Venda {platform}'**
  String uxCampaignObjectiveSalesOn(String platform);

  /// No description provided for @uxCampaignObjectiveSubscription.
  ///
  /// In pt, this message translates to:
  /// **'Assinatura'**
  String get uxCampaignObjectiveSubscription;

  /// No description provided for @uxAiTimeframeOneMonth.
  ///
  /// In pt, this message translates to:
  /// **'1 mês'**
  String get uxAiTimeframeOneMonth;

  /// No description provided for @uxAiTimeframeOneWeek.
  ///
  /// In pt, this message translates to:
  /// **'1 semana'**
  String get uxAiTimeframeOneWeek;

  /// No description provided for @uxAiTimeframeOneDay.
  ///
  /// In pt, this message translates to:
  /// **'1 dia'**
  String get uxAiTimeframeOneDay;

  /// No description provided for @uxMiRoiNoteOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'{count} oportunidades — {input}'**
  String uxMiRoiNoteOpportunities(String count, String input);

  /// No description provided for @uxNotAvailableShort.
  ///
  /// In pt, this message translates to:
  /// **'N/D'**
  String get uxNotAvailableShort;

  /// No description provided for @uxOppSeedDescription.
  ///
  /// In pt, this message translates to:
  /// **'Impacto: {impact} · Esforço: {effort}'**
  String uxOppSeedDescription(String impact, String effort);

  /// No description provided for @uxOppSeedRationaleFallback.
  ///
  /// In pt, this message translates to:
  /// **'Identificado pelo Market Intelligence com base na análise de {input}.'**
  String uxOppSeedRationaleFallback(String input);

  /// No description provided for @uxOppSeedRiskEffort.
  ///
  /// In pt, this message translates to:
  /// **'Esforço: {effort}'**
  String uxOppSeedRiskEffort(String effort);

  /// No description provided for @uxOppSeedEstimatedTimeframe.
  ///
  /// In pt, this message translates to:
  /// **'Prazo estimado: {timeframe}'**
  String uxOppSeedEstimatedTimeframe(String timeframe);

  /// No description provided for @uxActionDefaultTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ação'**
  String get uxActionDefaultTitle;

  /// No description provided for @uxErrorNotAuthenticated.
  ///
  /// In pt, this message translates to:
  /// **'Sessão expirada. Entre novamente para continuar.'**
  String get uxErrorNotAuthenticated;

  /// No description provided for @uxMemoryCampaignSucceeded.
  ///
  /// In pt, this message translates to:
  /// **'Campanha bem-sucedida'**
  String get uxMemoryCampaignSucceeded;

  /// No description provided for @uxMemoryCampaignFailed.
  ///
  /// In pt, this message translates to:
  /// **'Campanha mal-sucedida'**
  String get uxMemoryCampaignFailed;

  /// No description provided for @uxMemoryRoiTitle.
  ///
  /// In pt, this message translates to:
  /// **'ROI: R\$ {value}'**
  String uxMemoryRoiTitle(String value);

  /// No description provided for @uxAuthErrorInvalidCredentials.
  ///
  /// In pt, this message translates to:
  /// **'E-mail ou senha incorretos.'**
  String get uxAuthErrorInvalidCredentials;

  /// No description provided for @uxAuthErrorEmailNotConfirmed.
  ///
  /// In pt, this message translates to:
  /// **'Confirme seu e-mail antes de entrar.'**
  String get uxAuthErrorEmailNotConfirmed;

  /// No description provided for @uxAuthErrorAlreadyRegistered.
  ///
  /// In pt, this message translates to:
  /// **'Este e-mail já está cadastrado.'**
  String get uxAuthErrorAlreadyRegistered;

  /// No description provided for @uxAuthErrorRateLimited.
  ///
  /// In pt, this message translates to:
  /// **'Muitas tentativas. Aguarde alguns segundos.'**
  String get uxAuthErrorRateLimited;

  /// No description provided for @uxAuthErrorWeakPassword.
  ///
  /// In pt, this message translates to:
  /// **'Senha muito fraca. Use pelo menos 6 caracteres.'**
  String get uxAuthErrorWeakPassword;

  /// No description provided for @uxAuthErrorGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir a autenticação. Tente novamente.'**
  String get uxAuthErrorGeneric;

  /// No description provided for @uxErrorQuotaExceeded.
  ///
  /// In pt, this message translates to:
  /// **'Você atingiu o limite mensal de análises de IA do seu plano. Faça upgrade para o Pro para continuar.'**
  String get uxErrorQuotaExceeded;

  /// No description provided for @uxErrorPlanRequired.
  ///
  /// In pt, this message translates to:
  /// **'Este recurso faz parte de um plano superior. Faça upgrade para continuar.'**
  String get uxErrorPlanRequired;

  /// No description provided for @uxErrorModuleNotAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Este recurso ainda não está disponível para a sua conta.'**
  String get uxErrorModuleNotAvailable;

  /// No description provided for @uxErrorModuleDisabled.
  ///
  /// In pt, this message translates to:
  /// **'Este recurso foi desativado.'**
  String get uxErrorModuleDisabled;

  /// No description provided for @uxErrorEntitlementUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível verificar o seu acesso agora. Tente novamente.'**
  String get uxErrorEntitlementUnavailable;

  /// No description provided for @uxErrorSessionExpired.
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão expirou. Faça login novamente.'**
  String get uxErrorSessionExpired;

  /// No description provided for @uxErrorNoConnection.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível conectar. Verifique sua internet.'**
  String get uxErrorNoConnection;

  /// No description provided for @uxErrorTimeout.
  ///
  /// In pt, this message translates to:
  /// **'A conexão demorou muito. Tente novamente.'**
  String get uxErrorTimeout;

  /// No description provided for @uxErrorServiceUnavailable.
  ///
  /// In pt, this message translates to:
  /// **'Serviço temporariamente indisponível. Tente novamente.'**
  String get uxErrorServiceUnavailable;

  /// No description provided for @uxOriginManual.
  ///
  /// In pt, this message translates to:
  /// **'Adicionado manualmente'**
  String get uxOriginManual;

  /// No description provided for @uxOriginMarketAnalysis.
  ///
  /// In pt, this message translates to:
  /// **'Análise de Mercado'**
  String get uxOriginMarketAnalysis;

  /// No description provided for @uxOriginAutoBootstrap.
  ///
  /// In pt, this message translates to:
  /// **'Bootstrap Automático'**
  String get uxOriginAutoBootstrap;

  /// No description provided for @uxKnowledgeFormSourceLanguageLabel.
  ///
  /// In pt, this message translates to:
  /// **'Idioma do documento'**
  String get uxKnowledgeFormSourceLanguageLabel;

  /// No description provided for @uxAdminAccessDeniedTitle.
  ///
  /// In pt, this message translates to:
  /// **'Acesso negado'**
  String get uxAdminAccessDeniedTitle;

  /// No description provided for @uxAdminAccessDeniedBody.
  ///
  /// In pt, this message translates to:
  /// **'Você não tem permissão para acessar esta área.'**
  String get uxAdminAccessDeniedBody;

  /// No description provided for @uxAdminPanelTitle.
  ///
  /// In pt, this message translates to:
  /// **'Painel Admin'**
  String get uxAdminPanelTitle;

  /// No description provided for @uxAdminTabUsers.
  ///
  /// In pt, this message translates to:
  /// **'Usuários'**
  String get uxAdminTabUsers;

  /// No description provided for @uxAdminTabPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Personas'**
  String get uxAdminTabPersonas;

  /// No description provided for @uxAdminTabOverview.
  ///
  /// In pt, this message translates to:
  /// **'Visão Geral'**
  String get uxAdminTabOverview;

  /// No description provided for @uxAdminTabModules.
  ///
  /// In pt, this message translates to:
  /// **'Módulos'**
  String get uxAdminTabModules;

  /// No description provided for @uxAdminTabDiagnostics.
  ///
  /// In pt, this message translates to:
  /// **'Diagnóstico'**
  String get uxAdminTabDiagnostics;

  /// No description provided for @uxAdminNoUsers.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum usuário encontrado.'**
  String get uxAdminNoUsers;

  /// No description provided for @uxAdminNoEmail.
  ///
  /// In pt, this message translates to:
  /// **'Sem e-mail'**
  String get uxAdminNoEmail;

  /// No description provided for @uxAdminUserPlanLine.
  ///
  /// In pt, this message translates to:
  /// **'{role} · {limit} gerações/mês'**
  String uxAdminUserPlanLine(String role, String limit);

  /// No description provided for @uxAdminDeactivate.
  ///
  /// In pt, this message translates to:
  /// **'Desativar'**
  String get uxAdminDeactivate;

  /// No description provided for @uxAdminActivate.
  ///
  /// In pt, this message translates to:
  /// **'Ativar'**
  String get uxAdminActivate;

  /// No description provided for @uxAdminManagePersonas.
  ///
  /// In pt, this message translates to:
  /// **'Gerenciar todas as personas'**
  String get uxAdminManagePersonas;

  /// No description provided for @uxAdminNewPersona.
  ///
  /// In pt, this message translates to:
  /// **'Nova Persona'**
  String get uxAdminNewPersona;

  /// No description provided for @uxAdminOpenPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Abrir gestão de Personas'**
  String get uxAdminOpenPersonas;

  /// No description provided for @uxAdminUserDistribution.
  ///
  /// In pt, this message translates to:
  /// **'Distribuição de Usuários'**
  String get uxAdminUserDistribution;

  /// No description provided for @uxAdminTotalUsers.
  ///
  /// In pt, this message translates to:
  /// **'Total de Usuários'**
  String get uxAdminTotalUsers;

  /// No description provided for @uxAdminModuleNotCommercial.
  ///
  /// In pt, this message translates to:
  /// **'Não comercial'**
  String get uxAdminModuleNotCommercial;

  /// No description provided for @uxAdminModuleTables.
  ///
  /// In pt, this message translates to:
  /// **'Tabelas'**
  String get uxAdminModuleTables;

  /// No description provided for @uxDiagActive.
  ///
  /// In pt, this message translates to:
  /// **'DIAGNÓSTICO ATIVO'**
  String get uxDiagActive;

  /// No description provided for @uxDiagInactive.
  ///
  /// In pt, this message translates to:
  /// **'Diagnóstico inativo'**
  String get uxDiagInactive;

  /// No description provided for @uxDiagCopySessionId.
  ///
  /// In pt, this message translates to:
  /// **'Copiar ID da sessão'**
  String get uxDiagCopySessionId;

  /// No description provided for @uxDiagIdCopied.
  ///
  /// In pt, this message translates to:
  /// **'ID copiado.'**
  String get uxDiagIdCopied;

  /// No description provided for @uxDiagLabelValue.
  ///
  /// In pt, this message translates to:
  /// **'Rótulo: {label}'**
  String uxDiagLabelValue(String label);

  /// No description provided for @uxDiagStopSession.
  ///
  /// In pt, this message translates to:
  /// **'ENCERRAR SESSÃO'**
  String get uxDiagStopSession;

  /// No description provided for @uxDiagLabelHint.
  ///
  /// In pt, this message translates to:
  /// **'Rótulo (opcional) — ex: COMMERCIAL-E2E-001'**
  String get uxDiagLabelHint;

  /// No description provided for @uxDiagStartSession.
  ///
  /// In pt, this message translates to:
  /// **'INICIAR SESSÃO DE DIAGNÓSTICO'**
  String get uxDiagStartSession;

  /// No description provided for @uxDiagStartFailed.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível iniciar a sessão.'**
  String get uxDiagStartFailed;

  /// No description provided for @uxDiagSessionsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sessões de Diagnóstico'**
  String get uxDiagSessionsTitle;

  /// No description provided for @uxDiagSessionsLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao carregar sessões: {error}'**
  String uxDiagSessionsLoadError(String error);

  /// No description provided for @uxDiagNoSessions.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma sessão registrada.'**
  String get uxDiagNoSessions;

  /// No description provided for @uxDiagSessionShort.
  ///
  /// In pt, this message translates to:
  /// **'Sessão {id}…'**
  String uxDiagSessionShort(String id);

  /// No description provided for @uxDiagCopyReport.
  ///
  /// In pt, this message translates to:
  /// **'Copiar relatório de diagnóstico'**
  String get uxDiagCopyReport;

  /// No description provided for @uxDiagSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Buscar por evento, rota ou erro…'**
  String get uxDiagSearchHint;

  /// No description provided for @uxDiagNoEventsMatch.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum evento corresponde aos filtros.'**
  String get uxDiagNoEventsMatch;

  /// No description provided for @uxDiagSeverity.
  ///
  /// In pt, this message translates to:
  /// **'Severidade'**
  String get uxDiagSeverity;

  /// No description provided for @uxDiagCategory.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get uxDiagCategory;

  /// No description provided for @uxDiagFilterAll.
  ///
  /// In pt, this message translates to:
  /// **'Todas'**
  String get uxDiagFilterAll;

  /// No description provided for @uxDiagReportCopied.
  ///
  /// In pt, this message translates to:
  /// **'Relatório copiado para a área de transferência.'**
  String get uxDiagReportCopied;

  /// No description provided for @uxDiagRouteValue.
  ///
  /// In pt, this message translates to:
  /// **'rota: {route}'**
  String uxDiagRouteValue(String route);

  /// No description provided for @uxDriveLoginCancelled.
  ///
  /// In pt, this message translates to:
  /// **'Login cancelado.'**
  String get uxDriveLoginCancelled;

  /// No description provided for @uxDriveConfigError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível conectar ao Google (erro de configuração).\nUse o tipo \"URL\" e cole o link de compartilhamento do Google Docs, ou use o tipo \"Arquivo\" para importar PDFs locais.'**
  String get uxDriveConfigError;

  /// No description provided for @uxDriveNoInternet.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão com a internet. Verifique sua rede e tente novamente.'**
  String get uxDriveNoInternet;

  /// No description provided for @uxDriveConnectError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível conectar ao Google Drive. Tente novamente.'**
  String get uxDriveConnectError;

  /// No description provided for @uxDriveLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar seus arquivos do Drive. Tente novamente.'**
  String get uxDriveLoadError;

  /// No description provided for @uxDriveDownloadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível baixar o arquivo. Tente novamente.'**
  String get uxDriveDownloadError;

  /// No description provided for @uxDriveImportTitle.
  ///
  /// In pt, this message translates to:
  /// **'Importar do Google Drive'**
  String get uxDriveImportTitle;

  /// No description provided for @uxDriveSignOut.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get uxDriveSignOut;

  /// No description provided for @uxDriveDownloading.
  ///
  /// In pt, this message translates to:
  /// **'Baixando arquivo…'**
  String get uxDriveDownloading;

  /// No description provided for @uxDriveConnectTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conectar Google Drive'**
  String get uxDriveConnectTitle;

  /// No description provided for @uxDriveConnectBody.
  ///
  /// In pt, this message translates to:
  /// **'Importe PDFs, Google Docs e documentos de texto diretamente para o Cofre de Conhecimento.'**
  String get uxDriveConnectBody;

  /// No description provided for @uxDriveConnecting.
  ///
  /// In pt, this message translates to:
  /// **'Conectando…'**
  String get uxDriveConnecting;

  /// No description provided for @uxDriveSignInGoogle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com Google'**
  String get uxDriveSignInGoogle;

  /// No description provided for @uxDriveConnectedAs.
  ///
  /// In pt, this message translates to:
  /// **'Conectado como {name}'**
  String uxDriveConnectedAs(String name);

  /// No description provided for @uxDriveSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Buscar arquivo no Drive…'**
  String get uxDriveSearchHint;

  /// No description provided for @uxDriveNoFiles.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum arquivo encontrado.\nSão suportados: Google Docs, PDF, DOCX, TXT e CSV.'**
  String get uxDriveNoFiles;

  /// No description provided for @uxDriveTypeText.
  ///
  /// In pt, this message translates to:
  /// **'Texto'**
  String get uxDriveTypeText;

  /// No description provided for @uxKnowledgeActionGenerateStrategy.
  ///
  /// In pt, this message translates to:
  /// **'Gerar Estratégia'**
  String get uxKnowledgeActionGenerateStrategy;

  /// No description provided for @uxKnowledgeActionCreateCampaign.
  ///
  /// In pt, this message translates to:
  /// **'Criar Campanha'**
  String get uxKnowledgeActionCreateCampaign;

  /// No description provided for @uxKnowledgeActionTrainPersona.
  ///
  /// In pt, this message translates to:
  /// **'Treinar Persona'**
  String get uxKnowledgeActionTrainPersona;

  /// No description provided for @uxKnowledgeActionAskIve.
  ///
  /// In pt, this message translates to:
  /// **'Perguntar à IVE'**
  String get uxKnowledgeActionAskIve;

  /// No description provided for @uxKnowledgeAskIveMessage.
  ///
  /// In pt, this message translates to:
  /// **'Analise o item de conhecimento \"{title}\" e me diga como aplicar os insights na estratégia do projeto.'**
  String uxKnowledgeAskIveMessage(String title);

  /// No description provided for @uxKnowledgeNoPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma persona encontrada. Crie uma persona primeiro.'**
  String get uxKnowledgeNoPersonas;

  /// No description provided for @uxKnowledgePersonaTrained.
  ///
  /// In pt, this message translates to:
  /// **'Persona treinada com sucesso!'**
  String get uxKnowledgePersonaTrained;

  /// No description provided for @uxKnowledgeTrain.
  ///
  /// In pt, this message translates to:
  /// **'Treinar'**
  String get uxKnowledgeTrain;

  /// No description provided for @uxKnowledgeOppHigh.
  ///
  /// In pt, this message translates to:
  /// **'Alta Oportunidade'**
  String get uxKnowledgeOppHigh;

  /// No description provided for @uxKnowledgeOppGood.
  ///
  /// In pt, this message translates to:
  /// **'Boa Oportunidade'**
  String get uxKnowledgeOppGood;

  /// No description provided for @uxKnowledgeOppModerate.
  ///
  /// In pt, this message translates to:
  /// **'Oportunidade Moderada'**
  String get uxKnowledgeOppModerate;

  /// No description provided for @uxKnowledgeOppLow.
  ///
  /// In pt, this message translates to:
  /// **'Baixa Oportunidade'**
  String get uxKnowledgeOppLow;

  /// No description provided for @uxKnowledgeFieldProduct.
  ///
  /// In pt, this message translates to:
  /// **'Produto'**
  String get uxKnowledgeFieldProduct;

  /// No description provided for @uxKnowledgeFieldPromise.
  ///
  /// In pt, this message translates to:
  /// **'Promessa'**
  String get uxKnowledgeFieldPromise;

  /// No description provided for @uxKnowledgeFieldFormat.
  ///
  /// In pt, this message translates to:
  /// **'Formato'**
  String get uxKnowledgeFieldFormat;

  /// No description provided for @uxKnowledgeFieldPrice.
  ///
  /// In pt, this message translates to:
  /// **'Preço'**
  String get uxKnowledgeFieldPrice;

  /// No description provided for @uxKnowledgeFieldDescription.
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get uxKnowledgeFieldDescription;

  /// No description provided for @uxKnowledgeStrengths.
  ///
  /// In pt, this message translates to:
  /// **'Pontos Fortes'**
  String get uxKnowledgeStrengths;

  /// No description provided for @uxKnowledgeWeaknesses.
  ///
  /// In pt, this message translates to:
  /// **'Pontos Fracos'**
  String get uxKnowledgeWeaknesses;

  /// No description provided for @uxKnowledgeImprovements.
  ///
  /// In pt, this message translates to:
  /// **'Melhorias'**
  String get uxKnowledgeImprovements;

  /// No description provided for @uxResultSavedToHistory.
  ///
  /// In pt, this message translates to:
  /// **'Salvo no histórico!'**
  String get uxResultSavedToHistory;

  /// No description provided for @uxResultSaveError.
  ///
  /// In pt, this message translates to:
  /// **'Erro ao salvar. Tente novamente.'**
  String get uxResultSaveError;

  /// No description provided for @uxPostImproved.
  ///
  /// In pt, this message translates to:
  /// **'Post Melhorado'**
  String get uxPostImproved;

  /// No description provided for @uxPostProfessional.
  ///
  /// In pt, this message translates to:
  /// **'Versão Profissional'**
  String get uxPostProfessional;

  /// No description provided for @uxPostCasual.
  ///
  /// In pt, this message translates to:
  /// **'Versão Descontraída'**
  String get uxPostCasual;

  /// No description provided for @uxPostPersuasive.
  ///
  /// In pt, this message translates to:
  /// **'Versão Persuasiva'**
  String get uxPostPersuasive;

  /// No description provided for @uxPostCommentReply.
  ///
  /// In pt, this message translates to:
  /// **'Sugestão de Resposta a Comentários'**
  String get uxPostCommentReply;

  /// No description provided for @uxContentCopied.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdo copiado com sucesso!'**
  String get uxContentCopied;

  /// No description provided for @uxResultTitle.
  ///
  /// In pt, this message translates to:
  /// **'Resultado'**
  String get uxResultTitle;

  /// No description provided for @uxCopyAll.
  ///
  /// In pt, this message translates to:
  /// **'Copiar Tudo'**
  String get uxCopyAll;

  /// No description provided for @uxResultGeneratedIn.
  ///
  /// In pt, this message translates to:
  /// **'Gerado em {seconds} segundos'**
  String uxResultGeneratedIn(String seconds);

  /// No description provided for @uxScoreClarity.
  ///
  /// In pt, this message translates to:
  /// **'Clareza'**
  String get uxScoreClarity;

  /// No description provided for @uxScoreEngagement.
  ///
  /// In pt, this message translates to:
  /// **'Engajamento'**
  String get uxScoreEngagement;

  /// No description provided for @uxScoreClarityShort.
  ///
  /// In pt, this message translates to:
  /// **'C'**
  String get uxScoreClarityShort;

  /// No description provided for @uxScoreImpactShort.
  ///
  /// In pt, this message translates to:
  /// **'I'**
  String get uxScoreImpactShort;

  /// No description provided for @uxScoreEngagementShort.
  ///
  /// In pt, this message translates to:
  /// **'E'**
  String get uxScoreEngagementShort;

  /// No description provided for @uxDateAtTime.
  ///
  /// In pt, this message translates to:
  /// **'{date} às {time}'**
  String uxDateAtTime(String date, String time);

  /// No description provided for @uxHistoryItemLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar este item.'**
  String get uxHistoryItemLoadError;

  /// No description provided for @uxHistoryOriginalText.
  ///
  /// In pt, this message translates to:
  /// **'Texto original'**
  String get uxHistoryOriginalText;

  /// No description provided for @uxHistoryLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar o histórico.'**
  String get uxHistoryLoadError;

  /// No description provided for @uxHistoryEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum conteúdo salvo ainda'**
  String get uxHistoryEmptyTitle;

  /// No description provided for @uxHistoryEmptyBody.
  ///
  /// In pt, this message translates to:
  /// **'Volte à tela principal, escreva um post\ne toque em \"Salvar\" após gerar o resultado.'**
  String get uxHistoryEmptyBody;

  /// No description provided for @uxContentTypeBook.
  ///
  /// In pt, this message translates to:
  /// **'Livro'**
  String get uxContentTypeBook;

  /// No description provided for @uxContentTypeEbook.
  ///
  /// In pt, this message translates to:
  /// **'E-book'**
  String get uxContentTypeEbook;

  /// No description provided for @uxContentTypeArticle.
  ///
  /// In pt, this message translates to:
  /// **'Artigo'**
  String get uxContentTypeArticle;

  /// No description provided for @uxContentTypePost.
  ///
  /// In pt, this message translates to:
  /// **'Post'**
  String get uxContentTypePost;

  /// No description provided for @uxContentTypeIdea.
  ///
  /// In pt, this message translates to:
  /// **'Ideia'**
  String get uxContentTypeIdea;

  /// No description provided for @uxContentTypeRawText.
  ///
  /// In pt, this message translates to:
  /// **'Texto Bruto'**
  String get uxContentTypeRawText;

  /// No description provided for @uxContentTypeCampaign.
  ///
  /// In pt, this message translates to:
  /// **'Campanha'**
  String get uxContentTypeCampaign;

  /// No description provided for @uxContentTypeDigitalProduct.
  ///
  /// In pt, this message translates to:
  /// **'Produto Digital'**
  String get uxContentTypeDigitalProduct;

  /// No description provided for @uxContentTypeBrand.
  ///
  /// In pt, this message translates to:
  /// **'Marca'**
  String get uxContentTypeBrand;

  /// No description provided for @uxContentTypeProject.
  ///
  /// In pt, this message translates to:
  /// **'Projeto'**
  String get uxContentTypeProject;

  /// No description provided for @uxContentFormEditTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar Item'**
  String get uxContentFormEditTitle;

  /// No description provided for @uxContentFormNewTitle.
  ///
  /// In pt, this message translates to:
  /// **'Novo Item'**
  String get uxContentFormNewTitle;

  /// No description provided for @uxContentFormTypeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo de conteúdo'**
  String get uxContentFormTypeLabel;

  /// No description provided for @uxContentFormTitleLabel.
  ///
  /// In pt, this message translates to:
  /// **'Título *'**
  String get uxContentFormTitleLabel;

  /// No description provided for @uxContentFormTitleHint.
  ///
  /// In pt, this message translates to:
  /// **'Nome do conteúdo'**
  String get uxContentFormTitleHint;

  /// No description provided for @uxFieldRequired.
  ///
  /// In pt, this message translates to:
  /// **'Obrigatório'**
  String get uxFieldRequired;

  /// No description provided for @uxContentFormDescLabel.
  ///
  /// In pt, this message translates to:
  /// **'Descrição / Resumo'**
  String get uxContentFormDescLabel;

  /// No description provided for @uxContentFormDescHint.
  ///
  /// In pt, this message translates to:
  /// **'Breve descrição...'**
  String get uxContentFormDescHint;

  /// No description provided for @uxContentFormBodyLabel.
  ///
  /// In pt, this message translates to:
  /// **'Texto Base / Conteúdo'**
  String get uxContentFormBodyLabel;

  /// No description provided for @uxContentFormBodyHint.
  ///
  /// In pt, this message translates to:
  /// **'Cole o texto, trecho ou anotações...'**
  String get uxContentFormBodyHint;

  /// No description provided for @uxContentFormNicheLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nicho'**
  String get uxContentFormNicheLabel;

  /// No description provided for @uxContentFormNicheHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Marketing Digital, Fitness'**
  String get uxContentFormNicheHint;

  /// No description provided for @uxContentFormAudienceLabel.
  ///
  /// In pt, this message translates to:
  /// **'Público-alvo'**
  String get uxContentFormAudienceLabel;

  /// No description provided for @uxContentFormAudienceHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex: Empreendedores iniciantes'**
  String get uxContentFormAudienceHint;

  /// No description provided for @uxContentFormSaveChanges.
  ///
  /// In pt, this message translates to:
  /// **'Salvar Alterações'**
  String get uxContentFormSaveChanges;

  /// No description provided for @uxContentFormAddToLibrary.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar à Biblioteca'**
  String get uxContentFormAddToLibrary;

  /// No description provided for @uxAdvisorRoleStrategy.
  ///
  /// In pt, this message translates to:
  /// **'Estratégia'**
  String get uxAdvisorRoleStrategy;

  /// No description provided for @uxAdvisorRoleMarketing.
  ///
  /// In pt, this message translates to:
  /// **'Marketing'**
  String get uxAdvisorRoleMarketing;

  /// No description provided for @uxAdvisorRoleMonetization.
  ///
  /// In pt, this message translates to:
  /// **'Monetização'**
  String get uxAdvisorRoleMonetization;

  /// No description provided for @uxAdvisorRoleBusiness.
  ///
  /// In pt, this message translates to:
  /// **'Negócios'**
  String get uxAdvisorRoleBusiness;

  /// No description provided for @uxAdvisorRoleGeneral.
  ///
  /// In pt, this message translates to:
  /// **'Geral'**
  String get uxAdvisorRoleGeneral;

  /// No description provided for @uxAdvisorStyleExecutive.
  ///
  /// In pt, this message translates to:
  /// **'Executivo'**
  String get uxAdvisorStyleExecutive;

  /// No description provided for @uxAdvisorStyleAnalytical.
  ///
  /// In pt, this message translates to:
  /// **'Analítico'**
  String get uxAdvisorStyleAnalytical;

  /// No description provided for @uxAdvisorStyleTeacher.
  ///
  /// In pt, this message translates to:
  /// **'Professor'**
  String get uxAdvisorStyleTeacher;

  /// No description provided for @uxAdvisorStyleMentor.
  ///
  /// In pt, this message translates to:
  /// **'Mentor'**
  String get uxAdvisorStyleMentor;

  /// No description provided for @uxAdvisorStyleDirect.
  ///
  /// In pt, this message translates to:
  /// **'Direto'**
  String get uxAdvisorStyleDirect;

  /// No description provided for @uxAdvisorStyleExecutiveDesc.
  ///
  /// In pt, this message translates to:
  /// **'Direto ao ponto, orientado a resultados e ROI.'**
  String get uxAdvisorStyleExecutiveDesc;

  /// No description provided for @uxAdvisorStyleAnalyticalDesc.
  ///
  /// In pt, this message translates to:
  /// **'Dados primeiro, análise profunda antes de recomendar.'**
  String get uxAdvisorStyleAnalyticalDesc;

  /// No description provided for @uxAdvisorStyleTeacherDesc.
  ///
  /// In pt, this message translates to:
  /// **'Explica cada conceito, ideal para aprendizado.'**
  String get uxAdvisorStyleTeacherDesc;

  /// No description provided for @uxAdvisorStyleMentorDesc.
  ///
  /// In pt, this message translates to:
  /// **'Guia com experiência, questionamentos estratégicos.'**
  String get uxAdvisorStyleMentorDesc;

  /// No description provided for @uxAdvisorStyleDirectDesc.
  ///
  /// In pt, this message translates to:
  /// **'Sem rodeios, vai direto para a solução.'**
  String get uxAdvisorStyleDirectDesc;

  /// No description provided for @uxAdvisorNext.
  ///
  /// In pt, this message translates to:
  /// **'Próximo'**
  String get uxAdvisorNext;

  /// No description provided for @uxAdvisorActivate.
  ///
  /// In pt, this message translates to:
  /// **'Ativar Advisor'**
  String get uxAdvisorActivate;

  /// No description provided for @uxAdvisorNameTitle.
  ///
  /// In pt, this message translates to:
  /// **'Escolha o nome do seu\nPersonal AI Advisor'**
  String get uxAdvisorNameTitle;

  /// No description provided for @uxAdvisorNameSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Este será seu parceiro estratégico de negócios.'**
  String get uxAdvisorNameSubtitle;

  /// No description provided for @uxAdvisorCustomNameHint.
  ///
  /// In pt, this message translates to:
  /// **'Ou digite um nome personalizado...'**
  String get uxAdvisorCustomNameHint;

  /// No description provided for @uxAdvisorRoleTitle.
  ///
  /// In pt, this message translates to:
  /// **'Qual será a especialidade\ndo seu Advisor?'**
  String get uxAdvisorRoleTitle;

  /// No description provided for @uxAdvisorRoleSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Define o foco das análises e recomendações.'**
  String get uxAdvisorRoleSubtitle;

  /// No description provided for @uxAdvisorStyleTitle.
  ///
  /// In pt, this message translates to:
  /// **'Como {name} deve\nse comunicar?'**
  String uxAdvisorStyleTitle(String name);

  /// No description provided for @uxAdvisorStyleSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Define o estilo das respostas e interações.'**
  String get uxAdvisorStyleSubtitle;

  /// No description provided for @uxImpactInvestigationActive.
  ///
  /// In pt, this message translates to:
  /// **'Ativa'**
  String get uxImpactInvestigationActive;

  /// No description provided for @uxImpactInvestigationArchived.
  ///
  /// In pt, this message translates to:
  /// **'Arquivada'**
  String get uxImpactInvestigationArchived;

  /// No description provided for @uxSupportSubjectProblemReport.
  ///
  /// In pt, this message translates to:
  /// **'Relato de problema'**
  String get uxSupportSubjectProblemReport;

  /// No description provided for @uxSupportSubjectFeedback.
  ///
  /// In pt, this message translates to:
  /// **'Feedback'**
  String get uxSupportSubjectFeedback;

  /// No description provided for @uxStrategyScoreWeight.
  ///
  /// In pt, this message translates to:
  /// **'peso {weight}'**
  String uxStrategyScoreWeight(String weight);

  /// No description provided for @uxActionPriorityShort.
  ///
  /// In pt, this message translates to:
  /// **'prio'**
  String get uxActionPriorityShort;

  /// No description provided for @uxErrorEmptyResponse.
  ///
  /// In pt, this message translates to:
  /// **'O serviço não retornou dados. Tente novamente.'**
  String get uxErrorEmptyResponse;

  /// No description provided for @uxErrorNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Item não encontrado.'**
  String get uxErrorNotFound;

  /// No description provided for @uxErrorFileTooLarge.
  ///
  /// In pt, this message translates to:
  /// **'Arquivo muito grande para importar. O limite é de aproximadamente 6 MB.'**
  String get uxErrorFileTooLarge;

  /// No description provided for @uxErrorFileUnreadable.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível ler o arquivo.'**
  String get uxErrorFileUnreadable;

  /// No description provided for @uxErrorFileTimeout.
  ///
  /// In pt, this message translates to:
  /// **'Tempo esgotado ao processar o arquivo. Tente novamente.'**
  String get uxErrorFileTimeout;

  /// No description provided for @uxErrorExtractionTimeout.
  ///
  /// In pt, this message translates to:
  /// **'O servidor demorou demais para extrair o texto. Tente novamente.'**
  String get uxErrorExtractionTimeout;

  /// No description provided for @uxErrorExtractedTextTooShort.
  ///
  /// In pt, this message translates to:
  /// **'Conteúdo extraído muito curto. O arquivo pode estar protegido ou corrompido — tente copiar e colar o texto manualmente.'**
  String get uxErrorExtractedTextTooShort;

  /// No description provided for @uxErrorGoogleNotConfigured.
  ///
  /// In pt, this message translates to:
  /// **'Login com Google não está configurado neste ambiente.'**
  String get uxErrorGoogleNotConfigured;

  /// No description provided for @uxErrorGoogleCredentials.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível obter as credenciais do Google.'**
  String get uxErrorGoogleCredentials;

  /// No description provided for @uxErrorSignUpFailed.
  ///
  /// In pt, this message translates to:
  /// **'Cadastro falhou. Tente novamente.'**
  String get uxErrorSignUpFailed;

  /// No description provided for @uxAllocHoursNegative.
  ///
  /// In pt, this message translates to:
  /// **'Horas não podem ser negativas.'**
  String get uxAllocHoursNegative;

  /// No description provided for @uxAllocHoursTooHigh.
  ///
  /// In pt, this message translates to:
  /// **'Valor de horas excede o limite permitido.'**
  String get uxAllocHoursTooHigh;

  /// No description provided for @uxAllocBudgetNegative.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento não pode ser negativo.'**
  String get uxAllocBudgetNegative;

  /// No description provided for @uxAllocBudgetTooHigh.
  ///
  /// In pt, this message translates to:
  /// **'Valor de orçamento excede o limite permitido.'**
  String get uxAllocBudgetTooHigh;

  /// No description provided for @uxOppAskIveMessage.
  ///
  /// In pt, this message translates to:
  /// **'Analise a oportunidade \"{title}\" (score {score}) e diga como aproveitá-la.'**
  String uxOppAskIveMessage(String title, String score);

  /// No description provided for @uxPersonaTrainingSummary.
  ///
  /// In pt, this message translates to:
  /// **'Treinamento com: {title}. Tom: {tone}. Estilo: {style}.'**
  String uxPersonaTrainingSummary(String title, String tone, String style);

  /// No description provided for @uxCalStatusIdea.
  ///
  /// In pt, this message translates to:
  /// **'Ideia'**
  String get uxCalStatusIdea;

  /// No description provided for @uxCalStatusPlanned.
  ///
  /// In pt, this message translates to:
  /// **'Planejado'**
  String get uxCalStatusPlanned;

  /// No description provided for @uxCalStatusGenerated.
  ///
  /// In pt, this message translates to:
  /// **'Gerado'**
  String get uxCalStatusGenerated;

  /// No description provided for @uxCalStatusApproved.
  ///
  /// In pt, this message translates to:
  /// **'Aprovado'**
  String get uxCalStatusApproved;

  /// No description provided for @uxCalStatusReadyToPublish.
  ///
  /// In pt, this message translates to:
  /// **'Pronto p/ Publicar'**
  String get uxCalStatusReadyToPublish;

  /// No description provided for @uxCalStatusPublished.
  ///
  /// In pt, this message translates to:
  /// **'Publicado'**
  String get uxCalStatusPublished;

  /// No description provided for @uxCalStatusPublishFailed.
  ///
  /// In pt, this message translates to:
  /// **'Falha na Publicação'**
  String get uxCalStatusPublishFailed;

  /// No description provided for @uxCalStatusArchived.
  ///
  /// In pt, this message translates to:
  /// **'Arquivado'**
  String get uxCalStatusArchived;

  /// No description provided for @uxCalFormatShortPost.
  ///
  /// In pt, this message translates to:
  /// **'Post Curto'**
  String get uxCalFormatShortPost;

  /// No description provided for @uxCalFormatLongPost.
  ///
  /// In pt, this message translates to:
  /// **'Post Longo'**
  String get uxCalFormatLongPost;

  /// No description provided for @uxCalFormatCarousel.
  ///
  /// In pt, this message translates to:
  /// **'Carrossel'**
  String get uxCalFormatCarousel;

  /// No description provided for @uxCalFormatReels.
  ///
  /// In pt, this message translates to:
  /// **'Reels/Vídeo'**
  String get uxCalFormatReels;

  /// No description provided for @uxCalFormatEmail.
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get uxCalFormatEmail;

  /// No description provided for @uxCalFormatSeoArticle.
  ///
  /// In pt, this message translates to:
  /// **'Artigo SEO'**
  String get uxCalFormatSeoArticle;

  /// No description provided for @uxCalFormatSalesCta.
  ///
  /// In pt, this message translates to:
  /// **'CTA de Venda'**
  String get uxCalFormatSalesCta;

  /// No description provided for @uxCalFormatThread.
  ///
  /// In pt, this message translates to:
  /// **'Thread/X'**
  String get uxCalFormatThread;

  /// No description provided for @bootstrapStepStarting.
  ///
  /// In pt, this message translates to:
  /// **'Iniciando'**
  String get bootstrapStepStarting;

  /// No description provided for @bootstrapStepGeneratingOpportunities.
  ///
  /// In pt, this message translates to:
  /// **'Gerando oportunidades'**
  String get bootstrapStepGeneratingOpportunities;

  /// No description provided for @bootstrapStepGeneratingActions.
  ///
  /// In pt, this message translates to:
  /// **'Gerando ações'**
  String get bootstrapStepGeneratingActions;

  /// No description provided for @bootstrapStepGeneratingRevenuePlan.
  ///
  /// In pt, this message translates to:
  /// **'Gerando plano de receita'**
  String get bootstrapStepGeneratingRevenuePlan;

  /// No description provided for @bootstrapStepTrainingPersonas.
  ///
  /// In pt, this message translates to:
  /// **'Treinando personas'**
  String get bootstrapStepTrainingPersonas;

  /// No description provided for @bootstrapProgressProject.
  ///
  /// In pt, this message translates to:
  /// **'Projeto {current}/{total}'**
  String bootstrapProgressProject(int current, int total);

  /// No description provided for @bootstrapProgressProjectStep.
  ///
  /// In pt, this message translates to:
  /// **'Projeto {current}/{total} — {step}'**
  String bootstrapProgressProjectStep(int current, int total, String step);

  /// No description provided for @ecoGateKnowledgeCoverage.
  ///
  /// In pt, this message translates to:
  /// **'Cobertura de conhecimento'**
  String get ecoGateKnowledgeCoverage;

  /// No description provided for @ecoGateLearningScore.
  ///
  /// In pt, this message translates to:
  /// **'Score de aprendizado'**
  String get ecoGateLearningScore;

  /// No description provided for @ecoGateIntelligenceProfile.
  ///
  /// In pt, this message translates to:
  /// **'Perfil de inteligência'**
  String get ecoGateIntelligenceProfile;

  /// No description provided for @r16TranslatedFrom.
  ///
  /// In pt, this message translates to:
  /// **'Traduzido automaticamente do {language}'**
  String r16TranslatedFrom(String language);

  /// No description provided for @r16ShowingOriginalContent.
  ///
  /// In pt, this message translates to:
  /// **'Exibindo o conteúdo no idioma original'**
  String get r16ShowingOriginalContent;

  /// No description provided for @r16ViewOriginal.
  ///
  /// In pt, this message translates to:
  /// **'Ver original'**
  String get r16ViewOriginal;

  /// No description provided for @r16ViewTranslation.
  ///
  /// In pt, this message translates to:
  /// **'Ver tradução'**
  String get r16ViewTranslation;

  /// No description provided for @uxfAdminSetRole.
  ///
  /// In pt, this message translates to:
  /// **'→ {role}'**
  String uxfAdminSetRole(String role);

  /// No description provided for @uxfAdminRoleBetaTester.
  ///
  /// In pt, this message translates to:
  /// **'Beta Tester'**
  String get uxfAdminRoleBetaTester;

  /// No description provided for @uxfAdminRoleAdmin.
  ///
  /// In pt, this message translates to:
  /// **'Admin'**
  String get uxfAdminRoleAdmin;

  /// No description provided for @uxfEcoAllocationScoreLine.
  ///
  /// In pt, this message translates to:
  /// **'Ecosystem Score: {score}/100  •  {emoji} {verdict}'**
  String uxfEcoAllocationScoreLine(String score, String emoji, String verdict);
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
