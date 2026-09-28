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
  String get adminModulesOpen => 'Open module';

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
  String get iveCoreRequiresAef =>
      'This action has consequences outside the app (publishing, sending, paying, trading or deleting). IVE does not execute actions like this: they require approval through the governed execution flow.';

  @override
  String get iveCoreProjectForbidden =>
      'This project is not available to your account.';

  @override
  String get iveCoreModelUnavailable =>
      'IVE is temporarily unavailable. No analysis was charged. Please try again.';

  @override
  String get iveCoreContextUnavailable =>
      'The project context could not be loaded right now. Please try again.';

  @override
  String get iveCoreInvalidRequest =>
      'This question could not be sent. Please review it and try again.';

  @override
  String get iveCoreSurfaceNotSupported =>
      'IVE is not available on this platform yet.';

  @override
  String get iveCoreSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get iveCoreAccessDenied =>
      'This feature is not available to your account.';

  @override
  String get iveCoreQuotaExceeded =>
      'You have reached your plan\'s AI analysis limit.';

  @override
  String get iveCoreGenericError =>
      'Something went wrong while talking to IVE. Please try again.';

  @override
  String get iveCoreDegradedContext =>
      'Answer with partial context: some of your data could not be loaded.';

  @override
  String get aefLabTitle => 'Action proposed by IVE (LAB)';

  @override
  String get aefLabIntro =>
      'Nothing has been executed. Review the details: the action only runs after your explicit approval.';

  @override
  String get aefLabActionLabel => 'Action';

  @override
  String get aefLabRisk => 'Risk: consequential — requires your approval.';

  @override
  String get aefLabConsequencePublish =>
      'Consequence: publishes this text on the chosen channel (simulated in the LAB, nothing leaves the app).';

  @override
  String get aefLabConsequenceSend =>
      'Consequence: sends this message to the chosen audience (simulated in the LAB, nothing leaves the app).';

  @override
  String get aefLabConsequenceCompleteAction =>
      'Consequence: marks this action as done, with a governed receipt and audit trail. You performed this yourself — the app records it, it does not do it for you.';

  @override
  String get aefLabConsequenceApproveSimulation =>
      'Consequence: records your formal approval of this simulation result, with a governed receipt and audit trail. The simulation itself already ran safely and deterministically -- this is only the formal human approval, never real money, never an order.';

  @override
  String get aefLabFieldChannel => 'Channel';

  @override
  String get aefLabFieldText => 'Text';

  @override
  String get aefLabFieldAudience => 'Audience';

  @override
  String get aefLabFieldSubject => 'Subject';

  @override
  String get aefLabFieldActionId => 'Action';

  @override
  String get aefLabFieldSummary => 'Summary';

  @override
  String get aefLabFieldBody => 'Message';

  @override
  String get aefLabFieldExperimentId => 'Experiment ID';

  @override
  String get aefLabFieldNote => 'Approval note';

  @override
  String get aefLabTitleStrategySimulation =>
      'Formal simulation approval (AEF)';

  @override
  String get aefLabTitleActionEngine => 'Confirm completion';

  @override
  String get actionEngineExecuteSheetIntro =>
      'This requires your explicit approval and creates an auditable receipt. Nothing is sent to any external system.';

  @override
  String get aefLabActionPublishContent => 'Publish content';

  @override
  String get aefLabActionSendMessage => 'Send message';

  @override
  String get aefLabActionCompleteAction => 'Complete action';

  @override
  String get aefLabActionApproveSimulation => 'Approve simulation result';

  @override
  String get aefLabRequestApproval => 'Request approval';

  @override
  String get aefLabApprove => 'Approve';

  @override
  String get aefLabReject => 'Reject';

  @override
  String get aefLabExecute => 'Run now';

  @override
  String get aefLabPhaseAwaiting =>
      'Waiting for your approval. Nothing has been executed.';

  @override
  String get aefLabPhaseAuthorized => 'Approved — not executed yet.';

  @override
  String get aefLabPhaseExecuting => 'Running…';

  @override
  String get aefLabPhaseSucceeded => 'Done. Receipt recorded.';

  @override
  String get aefLabPhaseUnconfirmed =>
      'Completion not confirmed by the server.';

  @override
  String get aefLabPhaseFailed => 'Failed. Nothing was completed.';

  @override
  String get aefLabPhaseUnknown =>
      'Unknown outcome: the action may have happened. Reconciliation is required — do not try again.';

  @override
  String get aefLabPhaseRejected => 'Rejected. Nothing was executed.';

  @override
  String get aefLabPhaseExpired => 'Expired. Nothing was executed.';

  @override
  String get aefLabPhaseCancelled => 'Cancelled. Nothing was executed.';

  @override
  String get aefLabPhaseInvalidated =>
      'Invalidated (the rules changed). Nothing was executed.';

  @override
  String get aefLabPhaseDenied => 'Action not allowed.';

  @override
  String get aefLabPhaseNetwork =>
      'No reliable server response: the state was not confirmed.';

  @override
  String aefLabReceipt(String receiptId) {
    return 'Receipt: $receiptId';
  }

  @override
  String get impactTitle => 'Impact Lab';

  @override
  String get impactInvestigations => 'Investigations';

  @override
  String get impactInvestigationsEmpty => 'No investigations yet.';

  @override
  String get impactAdminOnly => 'Impact Lab is restricted to administrators.';

  @override
  String get impactNoScoreNote =>
      'This dossier organizes evidence. It gives the organization no score, ranking or verdict.';

  @override
  String get impactLiveView => 'Live view';

  @override
  String get impactLiveViewHint =>
      'Reflects the current state and changes when the evidence changes.';

  @override
  String get impactSnapshot => 'Issued snapshot';

  @override
  String get impactSnapshotHint =>
      'Historical record: it is not rewritten when the evidence changes.';

  @override
  String impactAsOf(String date) {
    return 'As of $date';
  }

  @override
  String get impactAsOfUnknown => 'No reference date yet';

  @override
  String get impactSummary => 'Summary';

  @override
  String get impactIdentity => 'Identity';

  @override
  String get impactClaims => 'Claims';

  @override
  String get impactEvidence => 'Evidence';

  @override
  String get impactConflicts => 'Disagreements';

  @override
  String get impactLimitations => 'Limitations';

  @override
  String get impactNotEstablished => 'What this dossier does NOT establish';

  @override
  String get impactDisputes => 'Disputes';

  @override
  String get impactSources => 'Sources and provenance';

  @override
  String get impactIntegrity => 'Integrity';

  @override
  String get impactOpenDisputes => 'Open disputes';

  @override
  String get impactReverifyPending => 'Re-verification pending';

  @override
  String get impactNotVerifiedYet => 'Not verified yet.';

  @override
  String get impactNoClaims => 'No claims recorded yet.';

  @override
  String get impactNoEvidence => 'No evidence is linked to this claim.';

  @override
  String get impactNoConflicts => 'No disagreement recorded.';

  @override
  String get impactNoDisputes => 'No dispute recorded.';

  @override
  String get impactNoLimitations => 'No limitation recorded.';

  @override
  String get impactNoRegistry =>
      'No official registry record is attached. This does not mean the organization is unregistered.';

  @override
  String get impactNoSnapshot => 'No snapshot issued yet.';

  @override
  String get impactQuotedFromSource => 'Quoted from the source';

  @override
  String get impactQuotedFromUpload =>
      'Quoted from an uploaded document — context, never authority';

  @override
  String get impactWithheld => 'Excerpt withheld for privacy';

  @override
  String get impactRedactedNote => 'Personal data was removed from this text.';

  @override
  String get impactPublisher => 'Publisher';

  @override
  String impactHostedOn(String host) {
    return 'Hosted on $host (not the publisher)';
  }

  @override
  String get impactUserSubmitted => 'User-submitted — context, never authority';

  @override
  String impactVoices(int voices, int documents) {
    return 'Independent voices: $voices · sources assessed: $documents';
  }

  @override
  String get impactVoicesNote =>
      'Several documents do not mean several independent sources.';

  @override
  String get impactRules => 'Rules applied';

  @override
  String get impactGaps => 'Gaps';

  @override
  String get impactLocator => 'Location in the document';

  @override
  String get impactProvenanceChain =>
      'Source → document → location → evidence → claim';

  @override
  String get impactPositionsNoWinner =>
      'Every position side by side — none is chosen.';

  @override
  String get impactContentHash => 'Content hash';

  @override
  String get impactHashNotTruth =>
      'The hash proves the content was not altered — it does not prove it is true.';

  @override
  String get impactSnapshotRef => 'Snapshot reference';

  @override
  String get impactVerifyCurrent =>
      'Current snapshot: the content has not changed since it was issued.';

  @override
  String get impactVerifyStale =>
      'Stale snapshot: the dossier content changed after it was issued (evidence or presentation policy). It remains valid as a historical record.';

  @override
  String get impactVerifyNotIssued =>
      'This hash was not issued for this investigation.';

  @override
  String get impactEnvelopeMismatch =>
      'The snapshot metadata does not match the register.';

  @override
  String get impactVerifySnapshot => 'Verify snapshot';

  @override
  String get impactExport => 'Issue snapshot';

  @override
  String get impactExportConfirmTitle => 'Before issuing the snapshot';

  @override
  String impactExportLimitations(int count) {
    return 'Limitations carried by this dossier: $count';
  }

  @override
  String get impactExportPrivacy =>
      'The export is private and authenticated: there is no public link and no sharing.';

  @override
  String get impactExportFormats =>
      'Available formats: JSON and text. PDF is not available.';

  @override
  String get impactExportConfirm => 'Issue';

  @override
  String get impactExportDone => 'Snapshot issued';

  @override
  String get impactCopyJson => 'Copy JSON';

  @override
  String get impactCopyText => 'Copy text';

  @override
  String get impactCopied => 'Copied';

  @override
  String get impactErrorAuth => 'Your session expired. Please sign in again.';

  @override
  String get impactErrorNotAvailable =>
      'Investigation not found or unavailable.';

  @override
  String get impactErrorTooLarge =>
      'This dossier exceeds the limit and was not truncated. Nothing partial is shown.';

  @override
  String impactErrorRateLimited(int seconds) {
    return 'Too many requests. Try again in $seconds s.';
  }

  @override
  String get impactErrorNetwork =>
      'No connection. Check the network and try again.';

  @override
  String get impactErrorServer => 'The service did not respond. Try again.';

  @override
  String impactShowMore(int count) {
    return 'Show more ($count)';
  }

  @override
  String get impactExpand => 'Expand';

  @override
  String get impactCollapse => 'Collapse';

  @override
  String get impactClaimDetail => 'Claim detail';

  @override
  String get impactErrorContract =>
      'Unsupported server response format. Nothing was shown, to avoid displaying an incomplete dossier.';

  @override
  String get impactRetry => 'Try again';

  @override
  String get impactEvidenceExcluded =>
      'Excluded from the assessment (reason in the rules)';

  @override
  String get impactDeclaredQuote =>
      'Identity as declared for this investigation — quoted, not verified';

  @override
  String get impactRegistryQuote => 'As recorded in the registry — quoted';

  @override
  String get impactClaimCaveats => 'Before reading this claim';

  @override
  String get impactClaimLimitations => 'Limitations that apply to this claim';

  @override
  String get impactSnapshotCaveats =>
      'The confirmation described the live view at that moment. The issued snapshot carries these caveats:';

  @override
  String get impactClaimScopeNote =>
      'Status of this claim only — not a verdict on the organization.';

  @override
  String get impactIdentityScopeNote =>
      'Identity only — not an assessment of the organization’s conduct.';

  @override
  String impactPosition(int index, int total) {
    return 'Position $index of $total';
  }

  @override
  String get impactVerifyInconclusive =>
      'Verification inconclusive: do not rely on this snapshot’s metadata. Issue a new export before using it.';

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

  @override
  String get quantLabAsOf => 'As of';

  @override
  String get quantLabProviderLabel => 'Provider';

  @override
  String get quantLabTrustLabel => 'Trust level';

  @override
  String get quantLabRetrievedAt => 'Retrieved at';

  @override
  String get quantLabContentHash => 'Content hash';

  @override
  String get quantLabEngine => 'Engine';

  @override
  String quantLabSessionsBehind(int count) {
    return 'sessions behind: $count';
  }

  @override
  String get quantLabKind => 'Type';

  @override
  String get quantLabCacheLabel => 'Cache';

  @override
  String quantLabCacheValue(int hits, int misses) {
    return 'hits $hits · misses $misses';
  }

  @override
  String get quantLabIdLabel => 'ID';

  @override
  String get quantLabPolicy => 'Policy';

  @override
  String get quantLabBars => 'Bars';

  @override
  String get strategyLabTitle => 'Strategy Lab (Robot Builder)';

  @override
  String get strategyLabAccessDenied =>
      'You do not have permission to access the Strategy Lab.';

  @override
  String get strategyLabBanner =>
      'MVP phase. Create, configure, backtest and compare your own strategies below. No broker connection, no real money, no live order.';

  @override
  String get strategyLabDisclaimer =>
      'Research reference only. NOT a proven profitable strategy. NOT approved for paper or live trading. Not investment advice.';

  @override
  String get strategyLabStatusLabel => 'Status';

  @override
  String get strategyLabRulesSection => 'Rules';

  @override
  String get strategyLabEntry => 'Entry';

  @override
  String get strategyLabStop => 'Stop';

  @override
  String get strategyLabTarget => 'Target';

  @override
  String get strategyLabBreakEven => 'Break-even';

  @override
  String get strategyLabSession => 'Session';

  @override
  String get strategyLabForcedExit => 'Forced exit';

  @override
  String get strategyLabPositionSize => 'Position size';

  @override
  String get strategyLabHistoricalReference =>
      'Historical reference (real WIN1! dataset)';

  @override
  String get strategyLabZeroCost => 'Zero cost';

  @override
  String get strategyLabWithCost => 'With cost assumptions';

  @override
  String get strategyBuilderMyStrategies => 'My Strategies';

  @override
  String get strategyBuilderNewButton => 'New strategy';

  @override
  String get strategyBuilderCloneV10 => 'Clone Strategy #001 (V10)';

  @override
  String get strategyBuilderCloneGeneric => 'Clone generic reference';

  @override
  String get strategyBuilderEmptyList => 'No strategies yet.';

  @override
  String get strategyBuilderNewTitle => 'New strategy';

  @override
  String get strategyBuilderEditTitle =>
      'Edit strategy (creates a new version)';

  @override
  String get strategyBuilderName => 'Name';

  @override
  String get strategyBuilderDescription => 'Description';

  @override
  String get strategyBuilderEntryMode => 'Entry style';

  @override
  String get strategyBuilderEntryModeGeneric =>
      'Generic session-open (safe demo, synthetic data)';

  @override
  String get strategyBuilderEntryModeV10 =>
      'Pullback in trend (Strategy #001 style, real WIN1! data)';

  @override
  String get strategyBuilderDirection => 'Direction';

  @override
  String get strategyBuilderDirectionLong => 'Long';

  @override
  String get strategyBuilderDirectionShort => 'Short';

  @override
  String get strategyBuilderStopDistance => 'Stop distance';

  @override
  String get strategyBuilderTargetDistance => 'Target distance';

  @override
  String get strategyBuilderBreakEven => 'Break-even';

  @override
  String get strategyBuilderBreakEvenTrigger => 'Trigger';

  @override
  String get strategyBuilderBreakEvenInitial => 'Initial protection';

  @override
  String get strategyBuilderBreakEvenStep => 'Step';

  @override
  String get strategyBuilderSessionStart => 'Session start (HH:MM)';

  @override
  String get strategyBuilderSessionEnd => 'Session end (HH:MM)';

  @override
  String get strategyBuilderForcedExit => 'Forced exit (HH:MM)';

  @override
  String get strategyBuilderQuantity => 'Contracts';

  @override
  String get strategyBuilderValidate => 'Validate';

  @override
  String get strategyBuilderSave => 'Save';

  @override
  String get strategyBuilderValidationOk => 'Configuration valid.';

  @override
  String strategyBuilderValidationError(String code) {
    return 'Invalid configuration: $code';
  }

  @override
  String get strategyBuilderSaved => 'Saved.';

  @override
  String strategyBuilderSaveError(String code) {
    return 'Could not save: $code';
  }

  @override
  String get strategyBuilderSummaryTitle => 'Summary';

  @override
  String get strategyBuilderSummaryInstrument => 'Instrument';

  @override
  String get strategyBuilderSummarySignal => 'Signal';

  @override
  String get strategyBuilderSummaryPosition => 'Position';

  @override
  String get strategyBuilderBack => 'Back';

  @override
  String strategyBuilderVersion(int n) {
    return 'Version $n';
  }

  @override
  String get strategyBuilderRunBacktest => 'Run backtest';

  @override
  String get strategyBuilderBacktestRunning => 'Running…';

  @override
  String get strategyBuilderBacktestSucceeded => 'Backtest complete.';

  @override
  String strategyBuilderBacktestFailed(String reason) {
    return 'Backtest failed: $reason';
  }

  @override
  String get strategyBuilderNetPnl => 'Net P&L';

  @override
  String get strategyBuilderTradeCount => 'Trades';

  @override
  String get strategyBuilderResultHash => 'Hash';

  @override
  String get strategyBuilderCompare => 'Compare with previous version';

  @override
  String strategyBuilderNotComparable(String reasons) {
    return 'Not directly comparable: $reasons';
  }

  @override
  String get strategyBuilderNewVersionButton => 'New version from this';

  @override
  String get strategyDetailIntelligenceTitle => 'Strategy Intelligence';

  @override
  String get strategyDetailUnavailableForV10 =>
      'These research tools only work with the in-process generic engine right now.';

  @override
  String get strategyDetailAnalyzeFit => 'Analyze market fit';

  @override
  String get strategyDetailFitEvidenceTitle => 'Market fit evidence';

  @override
  String get strategyDetailFitFlagged => 'flagged';

  @override
  String get strategyDetailProposalsTitle => 'Bounded proposals';

  @override
  String get strategyDetailNoProposals =>
      'No evidence-based proposal right now.';

  @override
  String get strategyDetailRunSimulation => 'Run simulation';

  @override
  String strategyDetailSimulationResult(String trades, String netPnl) {
    return 'Simulation: $trades trades, net $netPnl';
  }

  @override
  String get strategyDetailRunResearchLoop => 'Run automated research loop';

  @override
  String strategyDetailResearchLoopSummary(String count) {
    return '$count candidate(s) generated';
  }

  @override
  String get strategyDetailNoCandidates =>
      'No candidates were generated (no evidence-based proposal).';

  @override
  String get strategyDetailRequiresMoreEvidence => 'REQUIRES MORE EVIDENCE';

  @override
  String get strategyDetailMoreRobust => 'MORE ROBUST UNDER TESTED ASSUMPTIONS';

  @override
  String planUpgradeBannerTitle(String requiredPlan) {
    return '$requiredPlan plan feature';
  }

  @override
  String planUpgradeBannerBody(String currentPlan, String requiredPlan) {
    return 'You are on the $currentPlan plan. Upgrade to $requiredPlan to use this feature.';
  }

  @override
  String get planUpgradeBannerCta => 'View plans';

  @override
  String get planNameFree => 'Free';

  @override
  String get planNamePro => 'Pro';

  @override
  String get planNamePremium => 'Premium';

  @override
  String get strategyDetailRecordExperiment => 'Record as experiment';

  @override
  String strategyDetailExperimentRecorded(String id) {
    return 'Recorded as experiment #$id.';
  }

  @override
  String strategyDetailRecordExperimentError(String code) {
    return 'Could not record the experiment ($code).';
  }

  @override
  String get strategyDetailSimulationGovernanceTitle =>
      'Formal approval (AEF governance)';

  @override
  String get strategyDetailSimulationRuntimeUnavailable =>
      'Unavailable in this environment: the AEF governance runtime only exists on a local Supabase stack (LAB) -- never in production. Your simulation was recorded normally; the formal approval step stays pending until a compatible environment is available.';

  @override
  String get strategyDetailSimulationRuntimePlanRequired =>
      'This formal approval step requires beta program participation (beta_tester role) plus an eligible plan. Contact support if you want to join.';

  @override
  String strategyDetailSimulationRuntimePolicyBlocked(Object code) {
    return 'The server refused this approval request ($code).';
  }

  @override
  String get strategyDetailExperimentHistoryTitle => 'Experiment history';

  @override
  String get strategyDetailExperimentHistoryEmpty =>
      'No experiments recorded yet. Run a backtest or a simulation and record it to start the history.';

  @override
  String get strategyDetailExperimentCategoryBacktest => 'Backtest';

  @override
  String get strategyDetailExperimentCategoryRobustness =>
      'Robustness experiment';

  @override
  String get strategyDetailExperimentCategorySimulation => 'Simulation';

  @override
  String get strategyDetailExperimentCategoryUserDecision => 'User decision';

  @override
  String get strategyDetailExperimentCategoryIveRecommendation =>
      'IVE recommendation';

  @override
  String get strategyDetailExperimentContaminated =>
      'contaminated (seen after holdout started)';

  @override
  String strategyDetailExperimentSegment(String segment) {
    return 'segment: $segment';
  }

  @override
  String get strategyDetailUserDecisionTitle =>
      'What do you decide about this candidate?';

  @override
  String get strategyDetailUserDecisionKeepCurrent => 'Keep current version';

  @override
  String get strategyDetailUserDecisionPreferCandidate => 'Prefer candidate';

  @override
  String get strategyDetailUserDecisionRejectCandidate => 'Reject candidate';

  @override
  String get strategyDetailUserDecisionNeedsMoreEvidence =>
      'Needs more evidence';

  @override
  String strategyDetailUserDecisionRecorded(String decision) {
    return 'Decision recorded: $decision.';
  }

  @override
  String get strategyDetailAnalyzeRobustness => 'View evidence and robustness';

  @override
  String get strategyDetailRobustnessEvidenceTitle =>
      'Evidence (traceable claims, not generic model opinion)';

  @override
  String get strategyDetailNoRobustnessClaims =>
      'No claims available for this result.';

  @override
  String get strategyDetailScoreComponentsTitle =>
      'Score components (transparent, never a single opaque number)';

  @override
  String strategyDetailScoreOverall(String overall, String language) {
    return 'Overall score: $overall/100 ($language)';
  }

  @override
  String get strategyDetailScoreLanguageMoreRobust =>
      'more robust under tested assumptions';

  @override
  String get strategyDetailScoreLanguageRequiresEvidence =>
      'requires more evidence';

  @override
  String strategyDetailSampleSizeInsufficient(String count, String threshold) {
    return 'Small sample: $count trades (below the $threshold-trade threshold) -- result should not be treated as conclusive.';
  }

  @override
  String strategyDetailDirectionalUntested(String direction) {
    return 'The $direction direction was never tested in this result -- no evidence about that side.';
  }
}
