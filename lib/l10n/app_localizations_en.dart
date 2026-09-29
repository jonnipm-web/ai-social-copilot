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

  @override
  String strategyDetailUnsupportedParameter(String parameter) {
    return 'Bounded exploration of $parameter is not yet supported by this engine -- no suggestion was invented.';
  }

  @override
  String get dashWelcome => 'Hi! Welcome back 👋';

  @override
  String dashPlanLabel(String plan) {
    return 'Plan: $plan';
  }

  @override
  String dashUsageRemaining(String remaining, String limit) {
    return '$remaining of $limit generations remaining';
  }

  @override
  String get dashUsageLimitReached => 'Limit reached';

  @override
  String get dashUsageThisMonth => 'this month';

  @override
  String get dashImproveWithAi => 'Improve Post with AI';

  @override
  String get dashImproveWithAiSubtitle => 'Transform your text now';

  @override
  String get dashShortcutPersonas => 'Personas';

  @override
  String get dashShortcutLibrary => 'Library';

  @override
  String get dashShortcutCalendar => 'Calendar';

  @override
  String get dashShortcutHistory => 'History';

  @override
  String get dashShortcutVault => 'Vault';

  @override
  String get dashShortcutCampaigns => 'Campaigns';

  @override
  String get dashShortcutWebsiteAnalyzer => 'Website\nAnalyzer';

  @override
  String get dashShortcutPerformance => 'Performance';

  @override
  String get dashFeatureUnavailable => 'This feature is not available yet.';

  @override
  String get dashAdminSectionTitle => 'Admin';

  @override
  String get dashAdminStatUsers => 'Users';

  @override
  String get dashAdminStatPersonas => 'Personas';

  @override
  String get dashAdminStatContent => 'Content';

  @override
  String get dashAdminStatSites => 'Sites';

  @override
  String get dashAdminStatVault => 'Vault';

  @override
  String get dashAdminStatCampaigns => 'Campaigns';

  @override
  String get dashAdminStatAnalyzed => 'Analyzed';

  @override
  String get dashAdminPanelButton => 'Admin Panel';

  @override
  String get dashAdminPanelSubtitle => 'Users, personas and plans';

  @override
  String get dashProBadge => 'PRO';

  @override
  String get dashProIncluded => 'Included in your plan';

  @override
  String get dashProUpgradeCta => 'Tap to unlock';

  @override
  String get dashProBenefitPersonas => 'Create brand personas with AI';

  @override
  String get dashProBenefitLibrary => 'Organize all your generated content';

  @override
  String get dashProBenefitCalendar => 'Plan your content production';

  @override
  String get dashProBenefitCampaigns => 'Generate complete campaigns with AI';

  @override
  String get dashProBenefitPerformance => 'Track performance metrics';

  @override
  String get dashPortfolioTitle => 'PORTFOLIO';

  @override
  String get dashPortfolioActiveProjects => 'Active projects';

  @override
  String get dashPortfolioAnalyses => 'Market analyses';

  @override
  String get dashPortfolioAvgScore => 'Average score';

  @override
  String get dashRecommendationsTitle => 'Executive Recommendations';

  @override
  String get dashRecEmptyProjectTitle => 'Add your first project';

  @override
  String get dashRecEmptyProjectBody =>
      'Go to Projects and add at least one to unlock analyses and opportunities.';

  @override
  String get dashRecEmptyAnalysisTitle => 'Run your first market analysis';

  @override
  String dashRecEmptyAnalysisBody(String projectName) {
    return 'Go to Market Intelligence and analyze the niche for $projectName.';
  }

  @override
  String dashRecPendingActionsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count actions awaiting approval',
      one: '1 action awaiting approval',
    );
    return '$_temp0';
  }

  @override
  String get dashRecPendingActionsBody =>
      'Review and approve the pending actions in Action Engine to start execution.';

  @override
  String dashRecTopOpportunityTitle(String niche) {
    return 'High-scoring opportunity: $niche';
  }

  @override
  String dashRecTopOpportunityBody(int score) {
    return 'Score $score/100. Open Opportunity Lab to convert it into tasks.';
  }

  @override
  String get dashRecNoRevenueTitle => 'No revenue recorded yet';

  @override
  String get dashRecNoRevenueBody =>
      'Add entries in ROI Tracker to track the real return of your projects.';

  @override
  String get dashPendingActionsTitle => 'This Week\'s Priorities';

  @override
  String get dashPendingActionsViewAll => 'View all';

  @override
  String get dashPendingActionsEmpty =>
      'No pending actions. Action Engine will fill this in automatically based on your analyses.';

  @override
  String get commonAll => 'All';

  @override
  String get commonDelete => 'Delete';

  @override
  String get actionEngineComingSoonBody =>
      'The action engine is being calibrated.\nSoon you\'ll have an intelligent system that turns analyses into executable tasks with automatic prioritization.';

  @override
  String get actionEngineComingSoonPro => 'Coming soon — Pro plan';

  @override
  String get actionEngineSectionPending => 'Pending';

  @override
  String get actionEngineSectionActive => 'In Progress';

  @override
  String get actionEngineSectionCompleted => 'Completed';

  @override
  String get actionEngineSummaryPending => 'Pending';

  @override
  String get actionEngineSummaryActive => 'Active';

  @override
  String get actionEngineSummaryCompleted => 'Completed';

  @override
  String get actionEngineDeleteTitle => 'Delete action?';

  @override
  String actionEngineDeleteBody(String title) {
    return 'The action \"$title\" will be permanently removed.';
  }

  @override
  String get actionEngineDelete => 'Delete';

  @override
  String get actionEngineApprove => 'Approve';

  @override
  String get actionEngineExecute => 'Execute';

  @override
  String get actionEngineVerify => 'Verify';

  @override
  String get actionEnginePause => 'Pause';

  @override
  String get actionEngineScoreRoi => 'ROI';

  @override
  String get actionEngineScoreImpact => 'Impact';

  @override
  String get actionEngineScoreEffort => 'Effort';

  @override
  String get actionEngineScorePriority => 'Prio.';

  @override
  String get actionEngineFilterAll => 'All';

  @override
  String get actionEngineEmptyTitle => 'Empty action queue';

  @override
  String get actionEngineEmptyBody =>
      'Actions will be generated automatically from market analyses and opportunities.';

  @override
  String get actionEngineStatusPending => 'Pending';

  @override
  String get actionEngineStatusApproved => 'Approved';

  @override
  String get actionEngineStatusExecuting => 'In progress';

  @override
  String get actionEngineStatusCompleted => 'Completed';

  @override
  String get actionEngineStatusCancelled => 'Cancelled';

  @override
  String get actionDetailTitle => 'Action Detail';

  @override
  String get actionDetailNotFound => 'Action not found.';

  @override
  String get actionDetailExecuteWithApproval => 'Execute (with AEF approval)';

  @override
  String get actionDetailRecheck => 'Check again';

  @override
  String actionDetailDeleteBody(String title) {
    return '\"$title\" will be removed.';
  }

  @override
  String get actionDetailSectionScoreBreakdown => 'Score Breakdown';

  @override
  String get actionDetailSectionOrigin => 'Origin';

  @override
  String get actionDetailSectionSources => 'Sources';

  @override
  String get actionDetailSectionDescription => 'Description';

  @override
  String get actionDetailSectionRationale => 'AI Rationale';

  @override
  String get actionDetailSectionPlan => 'Execution Plan';

  @override
  String get actionDetailSectionRisks => 'Risks';

  @override
  String get actionDetailScoreMarket => 'Market';

  @override
  String get actionDetailScoreRevenue => 'Revenue';

  @override
  String get actionDetailScoreRoiFinal => 'ROI / Final';

  @override
  String get actionDetailScorePriority => 'Priority';

  @override
  String get actionDetailScoreConfidence => 'Confidence';

  @override
  String get actionDetailOriginGeneratedBy => 'Generated by';

  @override
  String get actionDetailOriginProject => 'Project';

  @override
  String get actionDetailOriginOpportunity => 'Opportunity';

  @override
  String actionDetailOriginOpportunityValue(String id) {
    return 'Lab #$id…';
  }

  @override
  String get actionDetailOriginMarketAnalysis => 'Market analysis';

  @override
  String actionDetailOriginMarketAnalysisValue(String id) {
    return 'Market #$id…';
  }

  @override
  String get actionDetailOriginCreatedAt => 'Created on';

  @override
  String get actionDetailOriginUpdatedAt => 'Updated on';

  @override
  String get actionDetailApproveAction => 'Approve Action';

  @override
  String get actionDetailReconciliationNeeded =>
      'AEF did not confirm the result (reconciliation needed). Check again — the same request is safe to retry.';

  @override
  String get actionDetailCompletedVerified =>
      'Completed (AEF receipt verified)';

  @override
  String get actionDetailCompleted => 'Completed';

  @override
  String get actionDetailAskIve => 'Ask IVE about this action';

  @override
  String actionDetailAskIveMessage(String title) {
    return 'Analyze the action \"$title\" and give me guidance on how to carry it out.';
  }

  @override
  String get improvePostTitle => 'Improve Post';

  @override
  String improvePostMinLength(int min) {
    return 'Write at least $min characters.';
  }

  @override
  String improvePostLimitReached(int limit) {
    return 'You\'ve reached your limit of $limit generations this month.';
  }

  @override
  String get improvePostAnalysisLabel => 'Improve Content';

  @override
  String get improvePostSuccess => 'Result generated successfully!';

  @override
  String get improvePostClearTitle => 'Clear text';

  @override
  String get improvePostClearBody =>
      'Do you want to erase everything you\'ve typed?';

  @override
  String get improvePostClearConfirm => 'Clear';

  @override
  String improvePostLimitBanner(int limit) {
    return 'Limit reached ($limit/$limit generations this month).';
  }

  @override
  String improvePostRemainingBanner(int remaining, int limit) {
    return '$remaining of $limit generations remaining this month.';
  }

  @override
  String get improvePostUpgradeCta => 'Upgrade';

  @override
  String get improvePostSeePlans => 'See plans';

  @override
  String get improvePostHeading => 'Paste or write your post';

  @override
  String get improvePostHint =>
      'E.g.: Today I learned something amazing about productivity...';

  @override
  String improvePostCharCount(int count, int max) {
    return '$count / $max characters';
  }

  @override
  String get improvePostButtonLabel => '✨  Improve post';

  @override
  String get improvePostButtonLoading => 'Analyzing your content...';

  @override
  String miSubErrorPrefix(String error) {
    return 'Error: $error';
  }

  @override
  String get miCompetitorTitle => 'Competitors';

  @override
  String get miCompetitorSearching => 'Searching...';

  @override
  String get miCompetitorDiscoverButton => 'Discover';

  @override
  String get miCompetitorEmptyTitle => 'No competitors yet';

  @override
  String get miCompetitorEmptyButton => 'Discover Competitors';

  @override
  String get miCompetitorStrengthsLabel => 'Strengths:';

  @override
  String get miCompetitorWeaknessesLabel => 'Weaknesses:';

  @override
  String get miCompetitorScoreSimilarity => 'Simil.';

  @override
  String get miCompetitorScoreAuthority => 'Author.';

  @override
  String get miCompetitorScoreRelevance => 'Relev.';

  @override
  String get miCompetitorScoreOverall => 'Overall';

  @override
  String get miGapTitle => 'Gap Analysis';

  @override
  String get miGapAnalyzing => 'Analyzing...';

  @override
  String get miGapAnalyzeButton => 'Analyze';

  @override
  String get miGapEmptyTitle => 'No gap analysis yet';

  @override
  String get miGapEmptyButton => 'Analyze Gaps';

  @override
  String get miGapSectionContent => 'Content Gaps';

  @override
  String get miGapSectionSeo => 'SEO Gaps';

  @override
  String get miGapSectionAuthority => 'Authority Gaps';

  @override
  String get miGapSectionMonetization => 'Monetization Gaps';

  @override
  String get miGapSectionProduct => 'Product Gaps';

  @override
  String miGapTotalIdentified(int count) {
    return 'Total: $count gaps identified';
  }

  @override
  String get miNicheTitle => 'Niches & Sub-niches';

  @override
  String get miNicheDiscovering => 'Discovering...';

  @override
  String get miNicheDiscoverButton => 'Discover';

  @override
  String get miNicheEmptyTitle => 'No niches yet';

  @override
  String get miNicheEmptyButton => 'Discover Niches';

  @override
  String get miNicheLevelNiche => 'Niche';

  @override
  String get miNicheLevelSubNiche => 'Sub-niche';

  @override
  String get miNicheLevelMicroNiche => 'Micro-niche';

  @override
  String get miNicheScoreLabel => 'score';

  @override
  String get miNicheScorePotential => 'Potential';

  @override
  String get miNicheScoreGrowth => 'Growth';

  @override
  String get miNicheScoreMonetization => 'Monetization';

  @override
  String get miNicheScoreTrend => 'Trend';

  @override
  String get miOpportunityTitle => 'Opportunities';

  @override
  String get miOpportunitySearching => 'Searching...';

  @override
  String get miOpportunityDiscoverButton => 'Discover';

  @override
  String get miOpportunityEmptyTitle => 'No opportunities yet';

  @override
  String get miOpportunityEmptyButton => 'Discover Opportunities';

  @override
  String get miOpportunityScoreMarket => 'Market';

  @override
  String get miOpportunityScoreGrowth => 'Growth';

  @override
  String get miOpportunityScoreMonetization => 'Monetization';

  @override
  String get miOpportunityScoreDifficulty => 'Difficulty';

  @override
  String get miClusterTitle => 'Content Cluster Engine';

  @override
  String get miClusterKeywordRequired => 'Enter the main keyword';

  @override
  String get miClusterEmptyTitle => 'No cluster yet';

  @override
  String get miClusterKeywordFieldLabel => 'Main keyword';

  @override
  String get miClusterGenerating => 'Generating...';

  @override
  String get miClusterGenerateButton => 'Generate Content Cluster';

  @override
  String miClusterKeywordDisplay(String keyword) {
    return 'Keyword: $keyword';
  }

  @override
  String get miClusterSectionClusters => 'Content Clusters';

  @override
  String get miClusterSectionSilos => 'SEO Silos';

  @override
  String get miClusterSectionArticles => 'Suggested Articles';

  @override
  String miClusterArticleKeyword(String keyword) {
    return 'Keyword: $keyword';
  }

  @override
  String get miClusterSectionRoadmap => 'Editorial Roadmap';

  @override
  String miClusterRoadmapMonth(String month) {
    return 'Month $month';
  }

  @override
  String get miRevenueTitle => 'Revenue Planner';

  @override
  String get miRevenueProjectNameRequired => 'Enter the project name';

  @override
  String get miRevenueEmptyTitle => 'No revenue plan yet';

  @override
  String get miRevenueProjectFieldLabel => 'Project name';

  @override
  String get miRevenueCalculating => 'Calculating...';

  @override
  String get miRevenueGenerateButton => 'Generate Revenue Plan';

  @override
  String get miRevenueScenarioConservative => 'Conservative';

  @override
  String get miRevenueScenarioModerate => 'Moderate';

  @override
  String get miRevenueScenarioAggressive => 'Aggressive';

  @override
  String miRevenueMonthlyLabel(String amount) {
    return 'Monthly: $amount';
  }

  @override
  String get miRevenueAnnualLabel => 'Annual';

  @override
  String get miRevenueSectionSources => 'Revenue Sources';

  @override
  String get miRevenueSectionMilestones => 'Revenue Milestones';

  @override
  String miRevenueMilestoneTarget(String amount) {
    return 'Target: $amount';
  }

  @override
  String get miRevenueSectionAssumptions => 'Assumptions';

  @override
  String get miRootErrorNotFound =>
      'The analysis function was not found on the server. Check whether the Edge Functions are deployed in the Supabase Dashboard.';

  @override
  String get miRootErrorSession =>
      'Your session has expired. Sign out and sign in again.';

  @override
  String get miRootErrorTimeout =>
      'The analysis took too long. Please try again in a moment.';

  @override
  String get miRootErrorNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get miRootErrorApiKey =>
      'API key not configured on the server. Set GROQ_API_KEY in the Supabase secrets.';

  @override
  String get miRootErrorGeneric =>
      'Please try again in a moment. If the error persists, check the Supabase Dashboard.';

  @override
  String get miRootEngineTitle => 'Market Intelligence Engine';

  @override
  String get miRootEngineSubtitle =>
      'Analyze any URL, domain, or project to discover market opportunities, competitors, and revenue potential.';

  @override
  String get miRootInputTypeLabel => 'Input type';

  @override
  String get miRootInputTypeUrl => 'URL / Domain';

  @override
  String get miRootInputTypeNiche => 'Niche';

  @override
  String get miRootInputTypeProject => 'Project';

  @override
  String get miRootHintUrl => 'https://example.com or example.com';

  @override
  String get miRootHintNiche => 'E.g.: digital marketing for small businesses';

  @override
  String get miRootHintProject => 'Describe your project or idea';

  @override
  String get miRootAnalyzing => 'Analyzing...';

  @override
  String get miRootAnalyzeCta => 'Analyze Market';

  @override
  String get miRootConnectionErrorTitle =>
      'Could not connect to the analysis engine';

  @override
  String get miRootPreviousAnalysesTitle => 'Previous analyses';

  @override
  String get miRootNoAnalysesYet => 'No analyses yet.';

  @override
  String get miHubAppBarTitle => 'Market Intelligence';

  @override
  String get miHubCompareWithIveTooltip => 'Compare with IVE';

  @override
  String miHubCompareInitialMessage(String subject) {
    return 'Compare the results of this market analysis ($subject) and identify the biggest opportunity.';
  }

  @override
  String get miHubReloadTooltip => 'Reload data';

  @override
  String miHubLoadError(String error) {
    return 'Error loading analysis:\n$error';
  }

  @override
  String get miHubDescHigh =>
      'High growth potential. Strong monetization. Manageable competition.';

  @override
  String get miHubDescMedium =>
      'Moderate potential. Growing market. Evaluate your differentiators.';

  @override
  String get miHubDescLow =>
      'Limited potential. Saturated market or weak monetization. Consider pivoting.';

  @override
  String get miHubPriorityHigh => '🚀  High Priority';

  @override
  String get miHubPriorityMedium => '⚡  Medium Priority';

  @override
  String get miHubPriorityLow => '⚠️  Low Priority';

  @override
  String get miHubOpportunityScoreLabel => 'OPPORTUNITY SCORE';

  @override
  String get miHubScoreSeo => 'SEO';

  @override
  String get miHubScoreMonetization => 'Monetization';

  @override
  String get miHubScoreCompetition => 'Competition';

  @override
  String get miHubScoreGrowth => 'Growth';

  @override
  String get miHubRevenuePotentialTitle => 'Revenue Potential';

  @override
  String get miHubRevenueNoDataHint =>
      'Run the Revenue Planner for detailed estimates.';

  @override
  String miHubRevenueRangeMonthly(String min, String max) {
    return '$min – $max/mo';
  }

  @override
  String miHubRevenueSingleMonthly(String max) {
    return '$max/mo';
  }

  @override
  String miHubRevenueAnnual(String value) {
    return 'Annual: $value';
  }

  @override
  String get miHubLabelDeadline => 'Timeline';

  @override
  String get miHubLabelConfidence => 'Confidence';

  @override
  String miHubMonthsValue(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get miHubInvestmentTitle => 'Worth Investing?';

  @override
  String miHubInvestmentScoreLabel(int score) {
    return 'Score: $score/100';
  }

  @override
  String get miHubNextActionsTitle => 'Recommended Next Actions';

  @override
  String miHubBadgeImpact(String value) {
    return 'Impact: $value';
  }

  @override
  String miHubBadgeEffort(String value) {
    return 'Effort: $value';
  }

  @override
  String miHubBadgeRoi(String value) {
    return 'ROI: $value';
  }

  @override
  String get miHubCompetitorsTitle => 'Top Competitors';

  @override
  String get miHubCompetitorsViewAll => 'View all';

  @override
  String get miHubCompetitorsEmptyMessage => 'Competitors not discovered yet.';

  @override
  String get miHubCompetitorsEmptyCta => 'Discover Competitors';

  @override
  String get miHubThCompetitor => 'Competitor';

  @override
  String get miHubThSimilarity => 'Similar.';

  @override
  String get miHubThAuthority => 'Authority';

  @override
  String get miHubThScore => 'Score';

  @override
  String get miHubAnalyzeCompetitorCta => 'Analyze Competitor';

  @override
  String get miHubGapSummaryTitle => 'Gap Summary';

  @override
  String get miHubGapDetailCta => 'Details';

  @override
  String get miHubGapEmptyMessage => 'Gap Analysis not run yet.';

  @override
  String get miHubGapEmptyCta => 'Run Gap Analysis';

  @override
  String get miHubGapSeo => 'SEO Gap';

  @override
  String get miHubGapContent => 'Content Gap';

  @override
  String get miHubGapAuthority => 'Authority Gap';

  @override
  String get miHubGapMonetization => 'Monetization Gap';

  @override
  String get miHubGapProduct => 'Product Gap';

  @override
  String miHubGapTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gaps identified',
      one: '1 gap identified',
    );
    return 'Total: $_temp0';
  }

  @override
  String get miHubOpportunitiesTitle => 'Detected Opportunities';

  @override
  String get miHubOpportunitiesViewAll => 'View all';

  @override
  String get miHubOpportunitiesEmptyMessage => 'Opportunities not mapped yet.';

  @override
  String get miHubOpportunitiesEmptyCta => 'Discover Opportunities';

  @override
  String miHubOppEffortBadge(String value) {
    return 'Effort: $value';
  }

  @override
  String miHubOppRevenueBadge(String value) {
    return 'Revenue: $value';
  }

  @override
  String miHubOppDifficultyBadge(String value) {
    return 'Difficulty: $value';
  }

  @override
  String get miHubScoreLevelHigh => 'High';

  @override
  String get miHubScoreLevelMedium => 'Medium';

  @override
  String get miHubScoreLevelLow => 'Low';

  @override
  String get miHubModulesGridTitle => 'ANALYSIS MODULES';

  @override
  String get miHubModCompetitors => 'Competitors';

  @override
  String get miHubModGapAnalysis => 'Gap Analysis';

  @override
  String get miHubModOpportunities => 'Opportunities';

  @override
  String get miHubModNiches => 'Niches';

  @override
  String get miHubModContentCluster => 'Content Cluster';

  @override
  String get miHubModRevenuePlanner => 'Revenue Planner';

  @override
  String get miHubRoiTrackerTitle => 'ROI Tracker';

  @override
  String get miHubRoiOpportunityScoreLabel => 'Opportunity Score';

  @override
  String get miHubRoiOpportunitiesLabel => 'Opportunities';

  @override
  String get miHubRoiAvgScoreLabel => 'Average Score';

  @override
  String get miHubRoiRevenueLabel => 'Revenue/mo';

  @override
  String get miHubRoiSavedMessage => 'Data recorded in ROI Tracker!';

  @override
  String get miHubRoiSavingCta => 'Recording...';

  @override
  String get miHubRoiSaveCta => 'Record in ROI Tracker';

  @override
  String miHubRoiSaveError(String error) {
    return 'Error recording: $error';
  }

  @override
  String get calendarTitle => 'Editorial Calendar';

  @override
  String get calendarNewPost => 'New Post';

  @override
  String get calendarEmpty => 'No posts scheduled.';

  @override
  String get calendarEmptyHint =>
      'Create your first post using the button below.';

  @override
  String get calendarNoTheme => '(no theme)';

  @override
  String get calendarNewPostSheetTitle => 'New Calendar Post';

  @override
  String get calendarThemeLabel => 'Theme / Post subject *';

  @override
  String get calendarThemeHint => 'E.g.: Monday productivity tip';

  @override
  String get calendarObjectiveLabel => 'Objective (optional)';

  @override
  String get calendarObjectiveHint => 'E.g.: Drive engagement, Sell product X';

  @override
  String get calendarPlatformLabel => 'Platform';

  @override
  String get calendarFormatLabel => 'Format';

  @override
  String get calendarSetSuggestedDate => 'Set suggested date';

  @override
  String calendarSuggestedDateValue(int day, int month, int year) {
    return 'Date: $day/$month/$year';
  }

  @override
  String get calendarAddButton => 'Add to Calendar';

  @override
  String get performanceTitle => 'Performance';

  @override
  String performanceLoadError(String error) {
    return 'Error loading metrics:\n$error';
  }

  @override
  String get performanceEmpty => 'No metrics recorded yet.';

  @override
  String get performanceEmptyHint => 'Tap + to add an entry.';

  @override
  String get performanceDeleteTitle => 'Delete metric';

  @override
  String performanceDeleteConfirm(String platform) {
    return 'Delete the metric for $platform?';
  }

  @override
  String get performanceDeleteSuccess => 'Metric deleted successfully.';

  @override
  String performanceDeleteError(String error) {
    return 'Error deleting: $error';
  }

  @override
  String get performanceAddSuccess => 'Metric added successfully!';

  @override
  String get performanceMetricImpressions => 'Impressions';

  @override
  String get performanceMetricClicks => 'Clicks';

  @override
  String get performanceMetricEngagement => 'Eng%';

  @override
  String get performanceMetricConversion => 'Conv%';

  @override
  String get performanceScoreLabel => 'Score';

  @override
  String get performanceSelectPlatform => 'Select a platform.';

  @override
  String performanceSaveError(String error) {
    return 'Error saving: $error';
  }

  @override
  String get performanceNewMetricTitle => 'New Metric';

  @override
  String get performanceFieldPlatform => 'Platform';

  @override
  String get performanceFieldLikes => 'Likes';

  @override
  String get performanceFieldComments => 'Comments';

  @override
  String get performanceFieldShares => 'Shares';

  @override
  String get performanceFieldSaves => 'Saves';

  @override
  String get performanceFieldLeads => 'Leads';

  @override
  String get performanceFieldSales => 'Sales';

  @override
  String get performanceFieldRevenue => 'Revenue (R\$)';

  @override
  String get performanceFieldNotes => 'Notes (optional)';

  @override
  String get contentLibraryTitle => 'Content Library';

  @override
  String get contentLibraryNewItem => 'New Item';

  @override
  String get contentLibraryEmptyType => 'No items of this type.';

  @override
  String get contentLibraryEmptyProject => 'No items in this project.';

  @override
  String get contentLibraryEmpty => 'Empty library.';

  @override
  String get contentLibraryEmptyHint => 'Add items using the button below.';

  @override
  String get contentLibraryDeleteTitle => 'Delete item';

  @override
  String contentLibraryDeleteConfirm(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String contentLibraryDeleteError(String error) {
    return 'Error deleting: $error';
  }

  @override
  String get personasTitle => 'Personas / Brands';

  @override
  String get personasNewPersona => 'New Persona';

  @override
  String get personasEmpty => 'No personas yet.';

  @override
  String get personasEmptyHint =>
      'Create your first one using the button below.';

  @override
  String get personasGlobalSection => 'Global Personas';

  @override
  String get personasMineSection => 'My Personas';

  @override
  String personasToneLabel(String tone) {
    return 'Tone: $tone';
  }

  @override
  String get personasDeleteTitle => 'Delete persona';

  @override
  String personasDeleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String personaTrainingTitle(String name) {
    return 'Training: $name';
  }

  @override
  String personaTrainingLoadError(String error) {
    return 'Error loading training data: $error';
  }

  @override
  String get personaTrainingHistoryTitle => 'Training History';

  @override
  String get personaTrainingSummaryTitle => 'Training Summary';

  @override
  String get personaTrainingItemsLabel => 'Items trained';

  @override
  String personaTrainingItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get personaTrainingToneProfileLabel => 'Tone Profile (latest)';

  @override
  String get personaTrainingVocabularyLabel => 'Combined Vocabulary';

  @override
  String get personaTrainingValuesLabel => 'Combined Values';

  @override
  String get personaTrainingDeleteTitle => 'Remove training item?';

  @override
  String get personaTrainingDeleteBody =>
      'This training item will be permanently removed from the persona.';

  @override
  String get personaTrainingRemove => 'Remove';

  @override
  String get personaTrainingNoTitle => 'Untitled item';

  @override
  String get personaTrainingToneLabel => 'Tone: ';

  @override
  String get personaTrainingItemVocabularyLabel => 'Vocabulary:';

  @override
  String personaTrainingMoreWords(int count) {
    return '+$count words';
  }

  @override
  String get personaTrainingEmptyTitle => 'No training yet.';

  @override
  String get personaTrainingEmptyBody =>
      'Analyze an item in the Knowledge Vault and click Train Persona.';

  @override
  String get personaFormEditTitle => 'Edit Persona';

  @override
  String get personaFormNewTitle => 'New Persona';

  @override
  String get personaFormNameLabel => 'Persona / Brand Name *';

  @override
  String get personaFormNameHint => 'E.g.: João\'s Personal Brand';

  @override
  String get personaFormRequired => 'Required';

  @override
  String get personaFormNicheLabel => 'Niche / Segment';

  @override
  String get personaFormNicheHint => 'E.g.: Digital Marketing, Fitness, Food';

  @override
  String get personaFormToneLabel => 'Voice Tone';

  @override
  String get personaFormToneHint =>
      'E.g.: Casual and inspiring, Professional and direct';

  @override
  String get personaFormAudienceLabel => 'Target Audience';

  @override
  String get personaFormAudienceHint =>
      'E.g.: First-time entrepreneurs aged 25–40';

  @override
  String get personaFormDescLabel => 'Description / Positioning';

  @override
  String get personaFormDescHint =>
      'Describe the essence of this persona or brand...';

  @override
  String get personaFormWordsUseLabel => 'Words you MUST use (comma-separated)';

  @override
  String get personaFormWordsUseHint =>
      'E.g.: innovation, transformation, results';

  @override
  String get personaFormWordsAvoidLabel =>
      'Words you MUST AVOID (comma-separated)';

  @override
  String get personaFormWordsAvoidHint => 'E.g.: cheap, simple, easy';

  @override
  String get personaFormGlobalTitle => 'Global Persona';

  @override
  String get personaFormGlobalSubtitle => 'Visible to all users (admin only)';

  @override
  String get personaFormSaveChanges => 'Save Changes';

  @override
  String get personaFormCreate => 'Create Persona';

  @override
  String get campaignsTitle => 'Campaigns';

  @override
  String get campaignsRefreshTooltip => 'Refresh';

  @override
  String get campaignsEmpty => 'No campaigns';

  @override
  String get campaignsEmptyHint =>
      'Go to the Knowledge Vault, analyze an item, and create your first campaign with AI.';

  @override
  String get campaignsGoToVault => 'Go to Vault';

  @override
  String campaignsDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get campaignsDeleteTitle => 'Delete campaign?';

  @override
  String campaignsDeleteConfirm(String title) {
    return 'The campaign \"$title\" will be removed.';
  }

  @override
  String get campaignBuilderTitle => 'Create Campaign';

  @override
  String get campaignBuilderItemNotFound => 'Item not found.';

  @override
  String get campaignBuilderNoAnalysisBody =>
      'Analyze the item first to create a campaign.';

  @override
  String get campaignBuilderObjectiveLabel => 'Campaign Objective';

  @override
  String get campaignBuilderDurationLabel => 'Duration';

  @override
  String get campaignBuilderChannelsLabel => 'Channels (select at least 1)';

  @override
  String get campaignBuilderGenerating => 'Generating campaign…';

  @override
  String get campaignBuilderGenerateCta => 'Generate Campaign with AI';

  @override
  String get campaignBuilderGenerateLabel => 'Generate Campaign';

  @override
  String get campaignBuilderSelectChannelWarning =>
      'Select at least one channel.';

  @override
  String get campaignBuilderGenerateError =>
      'Error generating campaign. Please try again.';

  @override
  String get campaignDetailTitle => 'Campaign';

  @override
  String get campaignDetailNotFound => 'Campaign not found.';

  @override
  String get campaignDetailOverviewTitle => 'Overview';

  @override
  String get campaignDetailKeyMessagesTitle => 'Key Messages';

  @override
  String get campaignDetailExpectedResultsTitle => 'Expected Results';

  @override
  String get campaignDetailCalendarTitle => 'Content Calendar';

  @override
  String get campaignDetailEmailSequenceTitle => 'Email Sequence';

  @override
  String get campaignDetailMetricsTitle => 'Success Metrics';

  @override
  String get campaignDetailCopied => 'Copied!';

  @override
  String get campaignDetailHookLabel => 'Hook';

  @override
  String get campaignDetailCtaLabel => 'CTA';

  @override
  String get campaignDetailBriefLabel => 'Brief';

  @override
  String get campaignDetailTopicLabel => 'Topic';

  @override
  String get roiTrackerTitle => 'ROI Tracker';

  @override
  String get roiTrackerTypeRevenue => 'Revenue';

  @override
  String get roiTrackerTypeInvestment => 'Investment';

  @override
  String get roiTrackerTypeTraffic => 'Traffic';

  @override
  String get roiTrackerTypeLeads => 'Leads';

  @override
  String get roiTrackerTypeConversions => 'Conversions';

  @override
  String get roiTrackerTypeOpportunities => 'Opportunities';

  @override
  String get roiTrackerTypeRevenuePotential => 'Potential Revenue';

  @override
  String get roiTrackerTypeRevenueEstimated => 'Estimated Revenue';

  @override
  String get roiTrackerTypeHoursSaved => 'Hours Saved';

  @override
  String get roiTrackerTypeStrategiesExecuted => 'Strategies Executed';

  @override
  String get roiTrackerTypeCampaignsExecuted => 'Campaigns Executed';

  @override
  String get roiTrackerTypeDecisionsMade => 'Decisions Made';

  @override
  String get roiTrackerTypeOpportunityScore => 'Opportunity Score';

  @override
  String get roiTrackerTypeAvgOpportunityScore => 'Avg Opportunity Score';

  @override
  String get roiTrackerTypeOther => 'Other';

  @override
  String get roiTrackerInvalidValue => 'Invalid value';

  @override
  String get roiTrackerRecordsTitle => 'Records';

  @override
  String get roiTrackerEmptyRecords => 'No records yet';

  @override
  String get roiTrackerSummaryTitle => 'ROI Summary';

  @override
  String roiTrackerRoiPercent(String value) {
    return 'ROI: $value%';
  }

  @override
  String get roiTrackerExecutiveDashboardTitle => 'Executive Dashboard';

  @override
  String get roiTrackerRevenueSectionTitle => 'REVENUE';

  @override
  String get roiTrackerRevenueRegistered => 'Registered';

  @override
  String get roiTrackerRevenuePotentialLabel => 'Potential';

  @override
  String get roiTrackerRevenueEstimatedLabel => 'Estimated';

  @override
  String get roiTrackerActivitySectionTitle => 'ACTIVITY';

  @override
  String get roiTrackerHoursSavedShort => 'Hrs Saved';

  @override
  String get roiTrackerNewRecordTitle => 'New Record';

  @override
  String get roiTrackerTypeLabel => 'Type';

  @override
  String get roiTrackerProjectOptionalLabel => 'Project (optional)';

  @override
  String get roiTrackerNoneOption => 'None';

  @override
  String get roiTrackerValueLabel => 'Value *';

  @override
  String get roiTrackerNotesOptionalLabel => 'Notes (optional)';

  @override
  String get roiTrackerNewRecord => 'New Record';

  @override
  String get roiTrackerProjectOptional => 'Project (optional)';

  @override
  String get roiTrackerProjectNone => 'None';

  @override
  String get roiTrackerNotesLabel => 'Notes (optional)';

  @override
  String get knowledgeVaultTitle => 'Knowledge Vault';

  @override
  String get knowledgeVaultFilterAll => 'All';

  @override
  String get knowledgeVaultEmptyTitle => 'No items yet';

  @override
  String knowledgeVaultEmptyProjectTitle(String project) {
    return 'No items in $project';
  }

  @override
  String get knowledgeVaultThisProject => 'this project';

  @override
  String knowledgeVaultLinkToProject(String title) {
    return 'Link \"$title\" to a project';
  }

  @override
  String knowledgeVaultCurrentProject(String name) {
    return 'Current project: $name';
  }

  @override
  String get knowledgeVaultNoProject => 'No project';

  @override
  String get knowledgeVaultUnlinkedSnack => 'Item unlinked from project';

  @override
  String knowledgeVaultLinkedSnack(String name) {
    return 'Item linked to $name';
  }

  @override
  String knowledgeVaultNicheLabel(String niche) {
    return 'Niche: $niche';
  }

  @override
  String get knowledgeVaultAnalyzeWithAi => 'Analyze with AI';

  @override
  String knowledgeVaultAnalyzeError(String error) {
    return 'Error analyzing: $error';
  }

  @override
  String get knowledgeVaultEdit => 'Edit';

  @override
  String get knowledgeVaultExplainWithIve => 'Explain with IVE';

  @override
  String knowledgeVaultExplainPrompt(String title) {
    return 'Summarize and explain the document \"$title\".';
  }

  @override
  String get knowledgeVaultDelete => 'Delete';

  @override
  String knowledgeVaultDeleteError(String error) {
    return 'Error deleting: $error';
  }

  @override
  String get knowledgeVaultStatusAnalyzed => 'Analyzed';

  @override
  String get knowledgeVaultStatusProcessing => 'Processing';

  @override
  String get knowledgeVaultStatusError => 'Error';

  @override
  String get knowledgeVaultStatusPending => 'Pending';

  @override
  String get knowledgeFormContentEmptyError => 'Content cannot be empty';

  @override
  String knowledgeFormSavedWithProject(String project) {
    return 'Item saved in $project';
  }

  @override
  String get knowledgeFormSavedNoProject => 'Item saved';

  @override
  String get knowledgeFormExtracting => 'Extracting text...';

  @override
  String knowledgeFormCharsExtracted(int count) {
    return '$count characters extracted';
  }

  @override
  String get knowledgeFormChangeFile => 'Change';

  @override
  String get knowledgeFormSelectFilePrompt => 'Click to select a file';

  @override
  String get knowledgeFormFileTypesHint => 'PDF, DOCX, TXT or CSV';

  @override
  String knowledgeFormImportError(String error) {
    return 'Error importing: $error';
  }

  @override
  String get knowledgeFormDriveDefaultName => 'Drive file';

  @override
  String get knowledgeFormSelectDriveFile => 'Select file from Drive';

  @override
  String get knowledgeFormDriveFileTypesHint =>
      'Google Docs, PDF, DOCX, TXT or CSV';

  @override
  String get knowledgeFormProjectLabel => 'Project (optional)';

  @override
  String get knowledgeFormNoProject => 'No project';

  @override
  String get knowledgeFormEditTitle => 'Edit Knowledge';

  @override
  String get knowledgeFormNewTitle => 'New Knowledge';

  @override
  String get knowledgeFormSourceTypeLabel => 'Source type';

  @override
  String get knowledgeFormSourceManual => 'Manual Text';

  @override
  String get knowledgeFormSourceUrl => 'URL';

  @override
  String get knowledgeFormSourceFile => 'File';

  @override
  String get knowledgeFormSourceDrive => 'Google Drive';

  @override
  String get knowledgeFormTitleLabel => 'Title *';

  @override
  String get knowledgeFormTitleHint => 'E.g.: Book on Digital Marketing';

  @override
  String get knowledgeFormTitleRequired => 'Enter the title.';

  @override
  String get knowledgeFormImportFromDrive => 'Import from Google Drive';

  @override
  String get knowledgeFormImportFile => 'Import File (PDF, DOCX, TXT, CSV)';

  @override
  String get knowledgeFormUrlLabel => 'Content URL *';

  @override
  String get knowledgeFormUrlHint => 'https://docs.google.com/document/d/...';

  @override
  String get knowledgeFormUrlRequired => 'Enter the URL.';

  @override
  String get knowledgeFormUrlInvalid => 'URL must start with http or https.';

  @override
  String get knowledgeFormGoogleDocsHintTitle => '📄 For Google Docs / Books:';

  @override
  String get knowledgeFormGoogleDocsHintBody =>
      '1. Open the document in Google Docs\n2. Click Share\n3. Switch to \"Anyone with the link can view\"\n4. Copy the link and paste it here';

  @override
  String get knowledgeFormContentLabel => 'Content *';

  @override
  String get knowledgeFormContentHint =>
      'Paste the text of the book, article, post, script, or any content you want to analyze here…';

  @override
  String get knowledgeFormContentTooShort =>
      'Content too short (minimum 20 characters).';

  @override
  String get knowledgeFormNicheLabel => 'Niche (optional)';

  @override
  String get knowledgeFormNicheHint =>
      'E.g.: Digital Marketing, Health, Finance';

  @override
  String get knowledgeFormAudienceLabel => 'Target audience (optional)';

  @override
  String get knowledgeFormAudienceHint =>
      'E.g.: First-time entrepreneurs, New mothers';

  @override
  String get knowledgeFormLanguageLabel => 'Language';

  @override
  String get knowledgeFormLanguagePtBr => 'Portuguese (BR)';

  @override
  String get knowledgeFormLanguageEnUs => 'English (US)';

  @override
  String get knowledgeFormLanguageEs => 'Spanish';

  @override
  String get knowledgeFormSaving => 'Saving…';

  @override
  String get knowledgeFormAddToVault => 'Add to Vault';

  @override
  String get knowledgeFormClickToSelectFile => 'Click to select a file';

  @override
  String get knowledgeFormFileTypes => 'PDF, DOCX, TXT or CSV';

  @override
  String get knowledgeFormPdfWarning =>
      'PDF must have selectable text (not a scanned image). For best results, use TXT or DOCX.';

  @override
  String get knowledgeFormDriveFileTypes =>
      'Google Docs, PDF, DOCX, TXT or CSV';

  @override
  String get knowledgeVaultRefreshTooltip => 'Refresh';

  @override
  String get knowledgeVaultNewItem => 'New Item';

  @override
  String get knowledgeVaultEmptyProjectBody =>
      'Add knowledge to this project so AI can extract personalized insights.';

  @override
  String get knowledgeVaultEmptyBody =>
      'Add text, URLs, or files so AI can extract marketing, SEO, and monetization insights.';

  @override
  String get knowledgeVaultAddKnowledge => 'Add Knowledge';

  @override
  String get knowledgeVaultViewAnalysis => 'View Analysis';

  @override
  String get knowledgeVaultProcessing => 'Processing…';

  @override
  String get knowledgeVaultAddToProject => 'Add to Project';

  @override
  String get knowledgeVaultChangeProject => 'Change Project';

  @override
  String get knowledgeVaultDeleteItemTitle => 'Delete item?';

  @override
  String knowledgeVaultDeleteItemBody(String title) {
    return 'The item \"$title\" and its analysis will be removed.';
  }

  @override
  String get websiteAnalyzerAnalyzeButton => 'Analyze Site';

  @override
  String websiteAnalyzerAnalyzeError(String error) {
    return 'Error analyzing: $error';
  }

  @override
  String websiteAnalyzerLoadError(String error) {
    return 'Error loading: $error';
  }

  @override
  String get websiteAnalyzerScoreSite => 'Site';

  @override
  String get websiteAnalyzerScoreAdsense => 'AdSense';

  @override
  String get websiteAnalyzerHeaderTitle => 'Analyze Website';

  @override
  String get websiteAnalyzerHeaderBody =>
      'Analyze your site and get a complete diagnostic with SEO, AdSense, and monetization opportunities.';

  @override
  String get websiteAnalyzerUrlLabel => 'Site URL (e.g.: https://mysite.com)';

  @override
  String get websiteAnalyzerUrlHint => 'https://mysite.com';

  @override
  String get websiteAnalyzerUrlRequired => 'Please enter the site URL';

  @override
  String get websiteAnalyzerUrlInvalid =>
      'Invalid URL. Use the format https://mysite.com';

  @override
  String get websiteAnalyzerAnalyzing => 'Analyzing...';

  @override
  String get websiteAnalyzerPreviousTitle => 'Previous Analyses';

  @override
  String get websiteAnalyzerEmptyTitle => 'No analyses yet';

  @override
  String get websiteAnalyzerEmptyBody => 'Enter a URL above to get started';

  @override
  String get websiteResultTitle => 'Site Analysis';

  @override
  String get websiteResultSavedSnack => 'Analysis already saved to the vault!';

  @override
  String get websiteResultSaveToVault => 'Save to Vault';

  @override
  String get websiteResultCreateStrategy => 'Create Strategy';

  @override
  String websiteResultExplainPrompt(String url, String scoreWebsite,
      String scoreSeo, String scoreAdsense, String scoreMonetization) {
    return 'Explain the results of the site analysis for $url (overall score $scoreWebsite, SEO $scoreSeo, AdSense $scoreAdsense, monetization $scoreMonetization).';
  }

  @override
  String get websiteResultLoadingAnalysis => 'Loading analysis...';

  @override
  String get websiteResultLoadError => 'Error loading analysis';

  @override
  String get websiteResultScoreWebsite => 'Website';

  @override
  String get websiteResultScoreSeo => 'SEO';

  @override
  String get websiteResultScoreMonetization => 'Monetization';

  @override
  String get websiteResultSectionDiagnostic => 'Diagnostics';

  @override
  String get websiteResultSectionStrengths => 'Strengths';

  @override
  String get websiteResultSectionWeaknesses => 'Weaknesses';

  @override
  String get websiteResultSectionCriticalIssues => 'Critical Issues';

  @override
  String get websiteResultSectionSeoAnalysis => 'SEO Analysis';

  @override
  String get websiteResultSectionAdsenseAnalysis => 'AdSense Analysis';

  @override
  String get websiteResultSectionQuickWins => 'Quick Wins';

  @override
  String get websiteResultSectionPlan7Days => '7-Day Plan';

  @override
  String get websiteResultSectionPlan30Days => '30-Day Plan';

  @override
  String get websiteResultSectionArticleIdeas => 'Article Ideas';

  @override
  String get websiteResultSectionMonetizationOpportunities =>
      'Monetization Opportunities';

  @override
  String get websiteResultSectionCommercialOpportunities =>
      'Commercial Opportunities';

  @override
  String get websiteResultMainTopicsLabel => 'Main Topics:';

  @override
  String get websiteResultPolicyPrivacy => 'Privacy Policy';

  @override
  String get websiteResultPolicyAbout => 'About';

  @override
  String get websiteResultPolicyContact => 'Contact';

  @override
  String get websiteResultCreateCampaign => 'Create Campaign';

  @override
  String get websiteResultSeoPlan => 'SEO Plan';

  @override
  String get websiteResultAdsensePlan => 'AdSense Plan';

  @override
  String get websiteResultSeoPlanComingSoon =>
      'SEO Plan — available in Phase 9';

  @override
  String get websiteResultAdsensePlanComingSoon =>
      'AdSense Plan — available in Phase 9';

  @override
  String get projectCommandTitle => 'Project Command Center';

  @override
  String get projectCommandRefreshTooltip => 'Refresh';

  @override
  String projectCommandLoadError(String error) {
    return 'Error: $error';
  }

  @override
  String get projectCommandEmptyTitle => 'No projects yet';

  @override
  String get projectCommandEmptySubtitle => 'Add your first project';

  @override
  String get projectCommandNewProject => 'New Project';

  @override
  String get projectCommandFieldNameLabel => 'Project name *';

  @override
  String get projectCommandFieldNameHint => 'E.g.: Personal Finance Blog';

  @override
  String get projectCommandFieldDescLabel => 'Description';

  @override
  String get projectCommandFieldDescHint => 'Briefly describe the project';

  @override
  String get projectCommandFieldUrlLabel => 'URL (optional)';

  @override
  String get projectCommandFieldUrlHint => 'https://...';

  @override
  String get projectCommandFieldTypeLabel => 'Type';

  @override
  String get projectCommandDeleteConfirmTitle => 'Confirm deletion';

  @override
  String projectCommandDeleteConfirmBody(String name) {
    return 'Delete \"$name\"?\nThis action cannot be undone.';
  }

  @override
  String get projectCommandDelete => 'Delete';

  @override
  String projectCommandDeleteError(String error) {
    return 'Error deleting: $error';
  }

  @override
  String get projectCommandNoKnowledgeWarning =>
      'Add knowledge to the project before analyzing.';

  @override
  String get projectCommandAnalyzeWithKnowledgeLabel =>
      'Analyze with Knowledge';

  @override
  String projectCommandAnalyzingSnackbar(String name, int count) {
    return 'Analyzing project \"$name\" with $count knowledge item(s)…';
  }

  @override
  String projectCommandOpportunitiesGenerated(int count, String name) {
    return '$count opportunity(ies) generated for \"$name\"!';
  }

  @override
  String get projectCommandView => 'View';

  @override
  String projectCommandAnalyzeError(String error) {
    return 'Error analyzing: $error';
  }

  @override
  String get projectCommandAutoBootstrapLabel =>
      'Automatically generate opportunities, actions, and revenue plan';

  @override
  String get projectCommandStatusActive => 'Active';

  @override
  String get projectCommandStatusCompleted => 'Completed';

  @override
  String get projectCommandStatusPaused => 'Paused';

  @override
  String get projectCommandStatusIdea => 'Idea';

  @override
  String get projectCommandRevenueNotEstimated => 'Not estimated';

  @override
  String get projectCommandRevenueNotEstimatedYet => 'Not estimated yet';

  @override
  String get projectCommandStatOpportunity => 'Opportunity';

  @override
  String get projectCommandStatPotential => 'Potential';

  @override
  String get projectCommandStatDeadline => 'Timeline';

  @override
  String get projectCommandActionDetail => 'Details';

  @override
  String get projectCommandActionAnalysis => 'Analysis';

  @override
  String get projectCommandActionActivate => 'Activate';

  @override
  String get projectCommandEcoScoreLabel => 'eco score';

  @override
  String get projectCommandSectionRecommendation => 'AI Recommendation';

  @override
  String get projectCommandSectionEcosystemScores => 'Ecosystem Scores';

  @override
  String get projectCommandScoreStrategicFit => 'Strategic Fit';

  @override
  String get projectCommandScoreSynergy => 'Synergy';

  @override
  String get projectCommandScoreRoi => 'ROI';

  @override
  String get projectCommandScoreMomentum => 'Momentum';

  @override
  String get projectCommandScoreExecution => 'Execution';

  @override
  String projectCommandActionsStats(int completed, int total, int rate) {
    return 'Actions: $completed/$total ($rate%)';
  }

  @override
  String projectCommandTotalRoi(String value) {
    return 'Total ROI: $value';
  }

  @override
  String get projectCommandSectionProjectMetrics => 'Project Metrics';

  @override
  String get projectCommandMetricComplexity => 'Complexity';

  @override
  String get projectCommandSectionStrengths => 'Strengths';

  @override
  String get projectCommandSectionQuickWins => 'Quick Wins';

  @override
  String get projectCommandSectionNextActions => 'Next Actions';

  @override
  String get projectCommandSectionIntelligenceProfile => 'Intelligence Profile';

  @override
  String get projectCommandSectionResourceAllocation => 'Resource Allocation';

  @override
  String get projectCommandViewMarketAnalysis => 'View Market Analysis';

  @override
  String get projectCommandViewKnowledge => 'View Knowledge';

  @override
  String get projectCommandAnalyzeWithAi => 'Analyze with AI';

  @override
  String get projectCommandActionPause => 'Pause';

  @override
  String get projectCommandActionComplete => 'Complete';

  @override
  String get projectCommandDeleteProject => 'Delete Project';

  @override
  String projectCommandMaturityLabel(String label) {
    return 'Maturity: $label';
  }

  @override
  String get projectCommandNiche => 'Niche';

  @override
  String get projectCommandAudience => 'Audience';

  @override
  String get projectCommandMonetization => 'Monetization';

  @override
  String get projectCommandValueProposition => 'Value proposition';

  @override
  String get projectCommandIdentifiedTopics => 'Identified topics';

  @override
  String get projectCommandKnowledgeGaps => 'Knowledge gaps';

  @override
  String get projectCommandRelatedProjects => 'Related';

  @override
  String get projectCommandAskIveAboutProfile => 'Ask IVE about this profile';

  @override
  String get projectCommandResourceLoadError =>
      'Could not load this project\'s resource allocation.';

  @override
  String get projectCommandInvalidBudgetValue =>
      'Invalid value. Use numbers only, e.g.: 1500.00';

  @override
  String projectCommandSavedAllocation(
      int hours, String amount, String currency) {
    return 'Saved: ${hours}h · $amount ($currency)';
  }

  @override
  String get projectCommandEditingBadge => 'EDITING';

  @override
  String get projectCommandHoursLabel => 'Hours';

  @override
  String projectCommandBudgetLabel(String currency) {
    return 'Budget ($currency)';
  }

  @override
  String projectCommandSaveAllocationError(String error) {
    return 'Error saving: $error';
  }

  @override
  String get projectCommandAnalyzeResourcesWithIve =>
      'Analyze resources with IVE';

  @override
  String get opportunityDetailTitle => 'Opportunity Detail';

  @override
  String opportunityDetailLoadError(String error) {
    return 'Error: $error';
  }

  @override
  String get opportunityDetailNotFound => 'Opportunity not found.';

  @override
  String get opportunityDetailApprovedSentTitle =>
      'Approved and sent to Action Engine!';

  @override
  String get opportunityDetailViewAction => 'View Action';

  @override
  String get opportunityDetailApprovedTitle => 'Opportunity approved!';

  @override
  String get opportunityDetailDeleteConfirmTitle => 'Delete opportunity?';

  @override
  String opportunityDetailDeleteConfirmBody(String title) {
    return '\"$title\" will be permanently removed.';
  }

  @override
  String get opportunityDetailDelete => 'Delete';

  @override
  String get opportunityDetailApproveAndCreateMenu =>
      'Approve and create action';

  @override
  String get opportunityDetailScoreBreakdownTitle => 'Score Breakdown';

  @override
  String get opportunityDetailOriginTitle => 'Origin';

  @override
  String get opportunityDetailSourcesTitle => 'Sources';

  @override
  String get opportunityDetailAiRationaleTitle => 'AI Rationale';

  @override
  String get opportunityDetailConfidenceTitle => 'Confidence';

  @override
  String get opportunityDetailRisksTitle => 'Risks';

  @override
  String get opportunityDetailNextStepsTitle => 'Next Steps';

  @override
  String get opportunityDetailScoreMarket => 'Market';

  @override
  String get opportunityDetailScoreRevenue => 'Revenue';

  @override
  String get opportunityDetailScoreCompetition => 'Competition';

  @override
  String get opportunityDetailScoreSynergy => 'Synergy';

  @override
  String get opportunityDetailScoreStrategicFit => 'Strategic Fit';

  @override
  String get opportunityDetailOriginGeneratedBy => 'Generated by';

  @override
  String get opportunityDetailOriginProject => 'Project';

  @override
  String get opportunityDetailOriginMarketAnalysis => 'Market analysis';

  @override
  String get opportunityDetailOriginCreatedAt => 'Created on';

  @override
  String get opportunityDetailConfidenceHigh => 'High';

  @override
  String get opportunityDetailConfidenceMedium => 'Medium';

  @override
  String get opportunityDetailConfidenceLow => 'Low';

  @override
  String get opportunityDetailApproveCreateActionButton =>
      'Approve and Create Action';

  @override
  String opportunityDetailApprovedCreateActionError(String error) {
    return 'Approved! Error creating action: $error';
  }

  @override
  String get opportunityDetailSendToActionEngine => 'Send to Action Engine';

  @override
  String get opportunityDetailActionCreatedTitle =>
      'Action created in Action Engine!';

  @override
  String opportunityDetailGenericError(String error) {
    return 'Error: $error';
  }

  @override
  String get opportunityDetailAskIveButton => 'Ask IVE about this opportunity';

  @override
  String get upgradeFaqTitle => 'Frequently asked questions';

  @override
  String get upgradeFaqFreeLimitQ => 'How does the free limit work?';

  @override
  String upgradeFaqFreeLimitA(int limit) {
    return 'You can run up to $limit AI analyses per month on the free plan (site, strategy, market analysis, etc). The counter resets on the 1st of every month.';
  }

  @override
  String get upgradeFaqCancelQ => 'Can I cancel anytime?';

  @override
  String get upgradeFaqCancelA =>
      'Yes. The Pro plan is monthly and you can cancel anytime with no fee.';

  @override
  String get upgradeFaqDataQ => 'Is my data kept if I cancel?';

  @override
  String get upgradeFaqDataA =>
      'Yes. Your history and projects are kept, but the analysis limit reverts to the free plan\'s.';

  @override
  String get aiConfirmTitle => 'Confirm analysis';

  @override
  String aiConfirmCostSingle(String label) {
    return '\"$label\" will use 1 of your monthly analyses.';
  }

  @override
  String aiConfirmCostMultiple(String label, int units) {
    return '\"$label\" may use up to $units of your monthly analyses.';
  }

  @override
  String aiConfirmRemaining(int remaining, int limit) {
    return '$remaining of $limit analyses remaining this month.';
  }

  @override
  String get aiConfirmCancel => 'CANCEL';

  @override
  String get aiConfirmConfirm => 'CONFIRM';
}
