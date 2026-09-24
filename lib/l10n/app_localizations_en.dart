// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'InsightValues';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonBack => 'Back';

  @override
  String get commonOr => 'or';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Something went wrong. Please try again.';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authCreateAccount => 'Create your account';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authEmailRequired => 'Enter your email';

  @override
  String get authEmailInvalid => 'Invalid email';

  @override
  String get authPasswordRequired => 'Enter your password';

  @override
  String get authPasswordMinLength => 'At least 6 characters';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignUp => 'Create account';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get checkoutOpening => 'Opening checkout...';

  @override
  String get authNoAccount => 'Don\'t have an account? Sign up';

  @override
  String get authHasAccount => 'Already have an account? Sign in';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get navCommandCenter => 'OS Command Center';

  @override
  String get navBusinessDashboard => 'Business Dashboard';

  @override
  String get navKnowledgeVault => 'Knowledge Vault';

  @override
  String get navWebsiteAnalyzer => 'Website Analyzer';

  @override
  String get navMarketIntelligence => 'Market Intelligence';

  @override
  String get navProjects => 'Projects';

  @override
  String get navOpportunityLab => 'Opportunity Lab';

  @override
  String get navActionEngine => 'Action Engine';

  @override
  String get navUpgrade => 'Plan / Upgrade';

  @override
  String get navAccount => 'Account & Settings';

  @override
  String get navAdminPanel => 'Admin Panel';

  @override
  String get navAdminModules => 'Modules (Admin)';

  @override
  String get navHelpSupport => 'Help & Support';

  @override
  String get navAbout => 'About';

  @override
  String get accountTitle => 'Account & Settings';

  @override
  String get accountProfile => 'Profile';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountLanguagePortuguese => 'Português';

  @override
  String get accountLanguageEnglish => 'English';

  @override
  String get accountCurrentPlan => 'Current plan';

  @override
  String get accountUsage => 'Usage / Quota';

  @override
  String get accountUpgradeManage => 'Upgrade / manage subscription';

  @override
  String get accountGoogleLinked => 'Connected with Google';

  @override
  String get accountHelpSupport => 'Help & Support';

  @override
  String get accountAbout => 'About InsightValues';

  @override
  String get accountPrivacy => 'Privacy Policy';

  @override
  String get accountTerms => 'Terms of Use';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get aboutTitle => 'About InsightValues';

  @override
  String get aboutTagline => 'AI copilot for marketing and content strategy.';

  @override
  String get aboutVersion => 'App version';

  @override
  String aboutCopyright(int year) {
    return '© $year InsightValues. All rights reserved.';
  }

  @override
  String get aboutWebsite => 'Official website';

  @override
  String get aboutSupportContact => 'Support';

  @override
  String get aboutPrivacyPolicy => 'Privacy Policy';

  @override
  String get aboutTermsOfUse => 'Terms of Use';

  @override
  String get aboutPlanInfo => 'Plan & subscription';

  @override
  String get aboutOwnerConfigRequired =>
      'Not yet configured by the product administrator.';

  @override
  String get supportTitle => 'Help & Support';

  @override
  String get supportContact => 'Contact';

  @override
  String get supportReportProblem => 'Report a problem';

  @override
  String get supportSendFeedback => 'Send feedback';

  @override
  String supportContactEmail(String email) {
    return 'Reach us by email: $email';
  }

  @override
  String get supportOwnerConfigRequired =>
      'Support channel not yet configured by the product administrator.';

  @override
  String get planFree => 'Free';

  @override
  String get planFreePrice => 'R\$ 0';

  @override
  String planFreeAnalyses(int count) {
    return '$count AI analyses per month';
  }

  @override
  String get planPro => 'Pro Founder';

  @override
  String get planProPrice => 'R\$ 29/month';

  @override
  String get planProPriceAmount => 'R\$ 29';

  @override
  String get planProPricePeriod => '/month';

  @override
  String planProAnalyses(int count) {
    return '$count AI analyses per month';
  }

  @override
  String get planFounderNote =>
      'Launch (founder) pricing -- not a permanent price.';

  @override
  String get planCurrentPlan => 'Current plan';

  @override
  String get planUpgradeCta => 'Subscribe to Pro';

  @override
  String get billingTestMode => 'Test mode (no real charges)';

  @override
  String get billingWaitingSecrets =>
      'Waiting on final payment provider configuration';

  @override
  String get checkoutOpeningError => 'Could not open the payment page.';

  @override
  String get upgradePlansTitle => 'Plans';

  @override
  String get upgradeLoadError =>
      'Could not load your plan right now. Please try again shortly.';

  @override
  String get upgradeUsageThisMonth => 'AI analyses this month';

  @override
  String get upgradeUsedAllAnalyses =>
      'You\'ve used all your AI analyses this month.';

  @override
  String upgradeAnalysesRemaining(int count, String plan) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count analyses remaining',
      one: '1 analysis remaining',
    );
    return '$_temp0 on the $plan plan.';
  }

  @override
  String get upgradeFreeSubtitle => 'Current plan';

  @override
  String get upgradeProSubtitle => 'For those already executing on strategy';

  @override
  String get upgradeFeatureWebsiteAnalysis =>
      'Website, market and competitor analysis';

  @override
  String get upgradeFeatureStrategyActions =>
      'Strategy and prioritized actions';

  @override
  String get upgradeFeatureUnlimited => 'Unlimited analyses';

  @override
  String get upgradeFeaturePriority => 'Processing priority';

  @override
  String get upgradeFeatureSupport => 'Priority support';

  @override
  String get upgradeFeatureSupportEmail => 'Priority email support';

  @override
  String get upgradeFeatureEarlyAccess => 'Early access to new features';

  @override
  String get upgradePreviousPlan => 'Previous plan';

  @override
  String get upgradeCurrentPlanBadge => 'Your plan';

  @override
  String get upgradeMostPopular => 'Most popular';

  @override
  String get upgradeSubscribeCta => '🚀  Subscribe to Pro — R\$ 29/month';

  @override
  String get adminModulesTitle => 'Module Inventory';

  @override
  String get adminModulesStatus => 'Status';

  @override
  String get adminModulesCommercial => 'Commercial';

  @override
  String get adminModulesPlan => 'Minimum plan';

  @override
  String get adminModulesRoute => 'Route';

  @override
  String get adminModulesAi => 'Uses AI';

  @override
  String get adminModulesReadiness => 'Readiness';

  @override
  String get adminModulesNotes => 'Notes';

  @override
  String get adminModulesNoRoute => 'No dedicated route';

  @override
  String get adminModulesYes => 'Yes';

  @override
  String get adminModulesNo => 'No';

  @override
  String get projectBriefingSectionTitle => 'Executive Briefing';

  @override
  String get projectBriefingNoKnowledge => 'No knowledge items yet';

  @override
  String projectBriefingKnowledgeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count knowledge items available',
      one: '1 knowledge item available',
      zero: 'No knowledge items',
    );
    return '$_temp0';
  }

  @override
  String get projectBriefingRecentChanges => 'What changed recently';

  @override
  String get projectAnalyzeIdea => 'Analyze Idea';

  @override
  String get projectOpenConfig => 'Settings';

  @override
  String get projectConfigTitle => 'Project Settings';

  @override
  String get projectConfigNameLabel => 'Name';

  @override
  String get projectConfigDescriptionLabel => 'Description';

  @override
  String get projectConfigUrlLabel => 'URL';

  @override
  String get projectConfigTypeLabel => 'Type';

  @override
  String get projectConfigStatusLabel => 'Status';

  @override
  String get projectConfigEdit => 'Edit';

  @override
  String get projectConfigNameRequired => 'Project name cannot be empty.';

  @override
  String projectConfigSaveError(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get ideaAnalysisProjectBannerText =>
      'This analysis will be linked to the selected project';

  @override
  String get ivIntroTitle => 'Meet IVE';

  @override
  String get ivIntroWhoBody =>
      'I\'m IVE, your strategic copilot inside InsightValues.';

  @override
  String get ivIntroWhatBody =>
      'I can explain your results, point out risks and opportunities, and suggest what to do next — always based on your project\'s real data.';

  @override
  String get ivIntroWhereBody =>
      'You can find me two ways: the floating icon appears on every screen, and some modules have a direct button to ask me about what you\'re looking at there.';

  @override
  String get ivIntroControlBody =>
      'I only answer when you ask — you decide when and what to ask.';

  @override
  String get ivIntroContinueButton => 'Got it';

  @override
  String get ivIntroSkipButton => 'Skip';

  @override
  String get ivIntroSemanticLabel =>
      'Introduction to IVE, your strategic copilot';

  @override
  String get ivIntroReplayLabel => 'Meet IVE';

  @override
  String get iveSemanticsLabel => 'IVE, executive copilot';

  @override
  String get iveBubbleChatCta => 'Chat with IVE';

  @override
  String get iveChatAskCta => 'Ask IVE';

  @override
  String get iveChatHint => 'Ask IVE…';

  @override
  String get iveChatClearHistory => 'Clear history';

  @override
  String iveChatErrorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get iveScreenActions => 'Actions';

  @override
  String get iveScreenWebsiteAnalyzer => 'Website Analyzer';

  @override
  String get iveScreenProjects => 'Projects';

  @override
  String get iveScreenDecisions => 'Decisions';

  @override
  String get iveScreenKnowledge => 'Knowledge';

  @override
  String get iveScreenMarketIntelligence => 'Market Intelligence';

  @override
  String get iveScreenBusinessOs => 'Business OS';

  @override
  String get iveScreenOpportunities => 'Opportunities';

  @override
  String get iveScreenBriefing => 'Briefing';

  @override
  String get iveScreenResources => 'Resources';

  @override
  String get iveScreenPersonas => 'Personas';

  @override
  String get iveScreenDebugHub => 'Debug Hub';

  @override
  String get iveScreenRoiTracker => 'ROI Tracker';

  @override
  String get iveScreenScores => 'Scores';

  @override
  String get iveSuggestionProjects1 => 'Which project should I focus on?';

  @override
  String get iveSuggestionProjects2 => 'Which projects carry the most risk?';

  @override
  String get iveSuggestionOpportunities1 =>
      'Which opportunity has the highest ROI?';

  @override
  String get iveSuggestionOpportunities2 => 'What should I approve now?';

  @override
  String get iveSuggestionScores1 => 'Why is my score low?';

  @override
  String get iveSuggestionScores2 => 'How can I improve the Ecosystem Score?';

  @override
  String get iveSuggestionDecisions1 => 'What should I escalate?';

  @override
  String get iveSuggestionDecisions2 =>
      'Simulate the impact of approving the top opportunity';

  @override
  String get iveSuggestionBriefing1 => 'Summarize my week';

  @override
  String get iveSuggestionBriefing2 => 'Which critical actions are overdue?';

  @override
  String get iveSuggestionKnowledge1 => 'What did I learn this week?';

  @override
  String get iveSuggestionKnowledge2 =>
      'Which document impacts my project the most?';

  @override
  String get iveSuggestionPersonas1 => 'Which persona has advanced the most?';

  @override
  String get iveSuggestionPersonas2 => 'Which niche has the most potential?';

  @override
  String get iveSuggestionDefault1 => 'Explain this screen\'s data to me';

  @override
  String get iveSuggestionDefault2 => 'What should I do now?';

  @override
  String iveActionSuggestionHint(String label) {
    return 'IVE\'s suggestion: $label. Finish the details on the screen that just opened.';
  }

  @override
  String get iveActionNoDestination =>
      'This action type doesn\'t have a direct destination yet. Ask IVE for more details.';

  @override
  String get oppNewTitle => 'New Opportunity';

  @override
  String get oppTypeLabel => 'Type';

  @override
  String get oppTitleLabel => 'Title';

  @override
  String get oppDescriptionLabel => 'Description (optional)';

  @override
  String get oppCancel => 'Cancel';

  @override
  String get oppAdd => 'Add';

  @override
  String get oppKnowledgeSectionTitle => 'Project knowledge';

  @override
  String get oppKnowledgeSectionHint =>
      'Select items from this project\'s Knowledge Vault to give the opportunity real context.';

  @override
  String get oppKnowledgeSelectProjectFirst =>
      'Select a project in the filter above to use project knowledge (optional).';

  @override
  String get oppKnowledgeEmpty =>
      'This project has no Knowledge Vault items yet.';

  @override
  String oppKnowledgeCountSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items selected',
      one: '1 item selected',
      zero: 'No items selected',
    );
    return '$_temp0';
  }

  @override
  String get oppLinkedKnowledgeTitle => 'Linked knowledge';

  @override
  String get oppTypeExpansao => 'Expansion';

  @override
  String get oppTypeNovoProduto => 'New Product';

  @override
  String get oppTypeNovoNicho => 'New Niche';

  @override
  String get oppTypeAfiliado => 'Affiliate';

  @override
  String get oppTypeSaas => 'SaaS';

  @override
  String get oppTypeEbook => 'Ebook';

  @override
  String get oppTypeCurso => 'Course';

  @override
  String get oppTypeAssinatura => 'Subscription';

  @override
  String get quantLabTitle => 'Quant Lab (internal)';

  @override
  String get quantLabInternalBanner =>
      'Internal analysis lab. Read-only: no orders, buying, selling or broker connection. Numbers are computed by the server\'s deterministic engine.';

  @override
  String get quantLabAccessDenied =>
      'You do not have permission to access the Quant Lab.';

  @override
  String get quantLabInstrument => 'Instrument';

  @override
  String get quantLabAssetClass => 'Asset class';

  @override
  String get quantLabSymbol => 'Symbol';

  @override
  String get quantLabVenue => 'Exchange (MIC)';

  @override
  String get quantLabVenueOther => 'Other / not specified';

  @override
  String get quantLabCurrency => 'Currency (ISO 4217)';

  @override
  String get quantLabAdjustment => 'Price adjustment';

  @override
  String get quantLabDataset => 'Data (OHLCV CSV)';

  @override
  String get quantLabCsvHint => 'date,open,high,low,close,volume';

  @override
  String get quantLabLoadSample => 'Load synthetic sample';

  @override
  String get quantLabPickCsv => 'Import CSV file';

  @override
  String get quantLabPeriodsPerYear =>
      'Periods per year (empty = no annualization)';

  @override
  String get quantLabSmaWindows => 'Moving-average windows (e.g. 20, 50)';

  @override
  String get quantLabAnalyze => 'Analyze';

  @override
  String get quantLabAnalyzing => 'Analyzing…';

  @override
  String get quantLabPeriod => 'Period';

  @override
  String get quantLabProvenance => 'Provenance';

  @override
  String get quantLabFreshness => 'Data freshness';

  @override
  String get quantLabCalendar => 'Market calendar';

  @override
  String get quantLabMetrics => 'Metrics';

  @override
  String get quantLabAssumptions => 'Assumptions';

  @override
  String get quantLabWarnings => 'Warnings';

  @override
  String get quantLabRiskNotImplemented => 'Risk not yet covered';

  @override
  String get quantLabSignals => 'Signals (descriptive, not recommendations)';

  @override
  String get quantLabNoSignals => 'No signals in the period.';

  @override
  String get quantLabFormula => 'Formula';

  @override
  String get quantLabObservations => 'Observations';

  @override
  String get quantLabEvidence => 'Evidence strength';

  @override
  String quantLabError(String code) {
    return 'The server refused the analysis: $code';
  }

  @override
  String quantLabErrorField(String code, String field) {
    return 'The server refused the analysis: $code ($field)';
  }

  @override
  String get quantLabInvalidInput =>
      'Fill in symbol, currency, CSV and valid numbers.';

  @override
  String get quantLabFileTooLarge => 'File larger than 5 MB.';

  @override
  String get quantLabFileUnreadable => 'Unreadable CSV file (use UTF-8).';

  @override
  String get quantLabTabSingle => 'Single series';

  @override
  String get quantLabTabWatchlist => 'Watchlist';

  @override
  String get quantLabWatchlists => 'Watchlists';

  @override
  String get quantLabWatchlistName => 'New watchlist name';

  @override
  String get quantLabCreate => 'Create';

  @override
  String get quantLabDeleteWatchlist => 'Delete watchlist';

  @override
  String get quantLabAddItem => 'Add instrument';

  @override
  String get quantLabRemoveItem => 'Remove';

  @override
  String get quantLabNoWatchlists => 'No watchlists yet.';

  @override
  String get quantLabNoItems => 'This watchlist is empty.';

  @override
  String quantLabSelectUpTo(int max) {
    return 'Select up to $max instruments to analyze.';
  }

  @override
  String get quantLabAnalyzeWatchlist => 'Analyze watchlist';

  @override
  String get quantLabSyntheticNotice =>
      'Watchlist analysis uses SYNTHETIC data generated by the server (no real market data, no vendor). It only tests the flow.';

  @override
  String get quantLabSeries => 'Series';

  @override
  String get quantLabAlignment => 'Alignment';

  @override
  String get quantLabCorrelation => 'Correlation of returns';

  @override
  String get quantLabDataSource => 'Data source';

  @override
  String get quantLabAlignedReturn => 'Return over the common window';

  @override
  String quantLabOperationError(String code) {
    return 'The server refused the operation: $code';
  }

  @override
  String get quantLabFileTypeNotSupported =>
      'File type not supported. Use a CSV file (or TXT with CSV content).';

  @override
  String get quantLabFileTypeNotImplemented =>
      'Spreadsheets (XLS, XLSX, ODS) and JSON are not supported yet. Export the data as CSV.';

  @override
  String get quantLabRetry => 'Retry';
}
