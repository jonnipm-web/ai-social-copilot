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
  String get aboutTagline => 'Strategic intelligence for founders and decision-makers.';

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
  String get iveChatAskLabel => 'Ask IVE';

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
  String get actionEngineTypeTask => 'Task';

  @override
  String get actionEngineTypeOpportunity => 'Opportunity';

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
  String get miCompetitorEmptyBody =>
      'Discover direct, indirect, and aspirational competitors and compare positioning, authority, and relevance.';

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
  String get miCompetitorTypeDirect => 'Direct';

  @override
  String get miCompetitorTypeIndirect => 'Indirect';

  @override
  String get miCompetitorTypeAspirational => 'Aspirational';

  @override
  String get miGapTitle => 'Gap Analysis';

  @override
  String get miGapAnalyzing => 'Analyzing...';

  @override
  String get miGapAnalyzeButton => 'Analyze';

  @override
  String get miGapEmptyTitle => 'No gap analysis yet';

  @override
  String get miGapEmptyBody =>
      'Identify content, SEO, authority, monetization, and product gaps your competitors already exploit and you don\'t yet.';

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
  String get miNicheEmptyBody =>
      'Discover and rank niches and sub-niches with the highest potential within your market.';

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
  String get miOpportunityEmptyBody =>
      'Find business opportunities prioritized by score and potential within your market.';

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
  String get miClusterTitle => 'Content Cluster';

  @override
  String get miClusterKeywordRequired => 'Enter the main keyword';

  @override
  String get miClusterEmptyTitle => 'No cluster yet';

  @override
  String get miClusterEmptyBody =>
      'Generate a content cluster with silos, articles, and an editorial roadmap from a main keyword.';

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
  String get miRevenueEmptyBody =>
      'Project conservative, moderate, and aggressive revenue scenarios based on real data from your project.';

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
  String get miHubNichesSummaryTitle => 'Niches';

  @override
  String get miHubNichesViewAll => 'View all';

  @override
  String get miHubNichesEmptyMessage =>
      'No niches evaluated yet. Discover and evaluate niches to find the best candidate for this project.';

  @override
  String get miHubNichesEmptyCta => 'Discover Niches';

  @override
  String get miHubNichesBestCandidateLabel => 'Best candidate';

  @override
  String miHubNichesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count niches evaluated',
      one: '1 niche evaluated',
      zero: 'No niches evaluated',
    );
    return '$_temp0';
  }

  @override
  String get miHubClusterSummaryTitle => 'Content Cluster';

  @override
  String get miHubClusterViewAll => 'View all';

  @override
  String get miHubClusterEmptyMessage =>
      'No content cluster generated yet. Generate a cluster to plan your content strategy around the main keyword.';

  @override
  String get miHubClusterEmptyCta => 'Generate Cluster';

  @override
  String miHubClusterCountBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clusters',
      one: '1 cluster',
      zero: '0 clusters',
    );
    return '$_temp0';
  }

  @override
  String miHubClusterArticlesBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
      zero: '0 articles',
    );
    return '$_temp0';
  }

  @override
  String get miHubRevenuePlannerSummaryTitle => 'Revenue Planning';

  @override
  String get miHubRevenuePlannerViewAll => 'View all';

  @override
  String get miHubRevenuePlannerEmptyMessage =>
      'No revenue plan created yet. Create a plan to project revenue scenarios based on real data.';

  @override
  String get miHubRevenuePlannerEmptyCta => 'Create Plan';

  @override
  String miHubRevenuePlannerMonthly(String value) {
    return '$value/mo (moderate)';
  }

  @override
  String miHubRevenueMilestonesBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count milestones',
      one: '1 milestone',
      zero: '0 milestones',
    );
    return '$_temp0';
  }

  @override
  String miHubRevenueSourcesBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count revenue sources',
      one: '1 revenue source',
      zero: '0 revenue sources',
    );
    return '$_temp0';
  }

  @override
  String get miHubRevenueNextMilestoneLabel => 'Next milestone';

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
  String get knowledgeStrategyTitle => 'Strategy';

  @override
  String knowledgeStrategyGenericError(String error) {
    return 'Error: $error';
  }

  @override
  String get knowledgeStrategyItemNotFound => 'Item not found.';

  @override
  String get knowledgeStrategyAnalysisRequiredTitle => 'Analysis required';

  @override
  String get knowledgeStrategyAnalysisRequiredBody =>
      'First analyze this item with AI, then generate the strategy.';

  @override
  String get knowledgeStrategyBackAndAnalyze => 'Back and Analyze';

  @override
  String get knowledgeStrategyGenerateTitle => 'Generate Full Strategy';

  @override
  String get knowledgeStrategyGenerateBody =>
      'AI will create a complete strategic plan with target audience, positioning, channels, funnel, commercial opportunities, and growth plan.';

  @override
  String get knowledgeStrategyGenerating => 'Generating strategy…';

  @override
  String get knowledgeStrategyGenerateButton => 'Generate Strategy';

  @override
  String get knowledgeStrategyRegenerateButton => 'Regenerate Strategy';

  @override
  String get knowledgeStrategyCopied => 'Copied!';

  @override
  String knowledgeStrategyCopiedKeyword(String keyword) {
    return 'Copied: $keyword';
  }

  @override
  String get knowledgeStrategySectionSummary => 'Strategic Summary';

  @override
  String get knowledgeStrategySectionValueProp => 'Value Proposition';

  @override
  String get knowledgeStrategySectionPositioning => 'Positioning';

  @override
  String get knowledgeStrategySectionAudience => 'Target Audience';

  @override
  String get knowledgeStrategySectionChannels => 'Recommended Channels';

  @override
  String get knowledgeStrategySectionFunnel => 'Marketing Funnel';

  @override
  String get knowledgeStrategySectionOpportunities =>
      'Commercial Opportunities';

  @override
  String get knowledgeStrategySectionKeywords => 'Priority Keywords';

  @override
  String get knowledgeStrategySectionQuickWins => 'Quick Wins';

  @override
  String get knowledgeStrategySectionGrowthPlan => 'Growth Plan';

  @override
  String get knowledgeStrategyFunnelAwareness => 'Awareness';

  @override
  String get knowledgeStrategyFunnelConsideration => 'Consideration';

  @override
  String get knowledgeStrategyFunnelConversion => 'Conversion';

  @override
  String get knowledgeStrategyFunnelRetention => 'Retention';

  @override
  String knowledgeStrategyMonth(int n) {
    return 'Month $n';
  }

  @override
  String get knowledgeStrategyKpisLabel => 'KPIs';

  @override
  String get knowledgeStrategyAudiencePrimary => 'Primary';

  @override
  String get knowledgeStrategyAudienceSecondary => 'Secondary';

  @override
  String get knowledgeStrategyAudienceAgeRange => 'Age range';

  @override
  String get knowledgeAnalysisTitle => 'Knowledge Analysis';

  @override
  String get knowledgeAnalysisReanalyzeTooltip => 'Re-analyze';

  @override
  String get knowledgeAnalysisLoadingLabel => 'Analyzing with AI…';

  @override
  String get knowledgeAnalysisNotYetLabel =>
      'This item hasn\'t been analyzed yet.';

  @override
  String get knowledgeAnalysisCopied => 'Copied!';

  @override
  String knowledgeAnalysisCopiedKeyword(String keyword) {
    return 'Copied: $keyword';
  }

  @override
  String get knowledgeAnalysisSectionSummary => 'Summary';

  @override
  String get knowledgeAnalysisSectionChannelScores => 'Scores by Channel';

  @override
  String get knowledgeAnalysisSectionKeywords => 'Keywords';

  @override
  String get knowledgeAnalysisKeywordsPrimary => 'Primary';

  @override
  String get knowledgeAnalysisKeywordsSecondary => 'Secondary';

  @override
  String get knowledgeAnalysisKeywordsLongtail => 'Long-tail';

  @override
  String get knowledgeAnalysisSectionAudiencePainPoints =>
      'Audience Pain Points';

  @override
  String get knowledgeAnalysisSectionAudienceDesires => 'Audience Desires';

  @override
  String get knowledgeAnalysisSectionContentPillars => 'Content Pillars';

  @override
  String get knowledgeAnalysisSectionTopics => 'Main Topics';

  @override
  String get knowledgeAnalysisSectionPostIdeas => 'Social Media Post Ideas';

  @override
  String get knowledgeAnalysisSectionCampaignIdeas => 'Campaign Ideas';

  @override
  String get knowledgeAnalysisSectionArticleIdeas => 'Article / Blog Ideas';

  @override
  String get knowledgeAnalysisSectionCommercialAngles => 'Commercial Angles';

  @override
  String get knowledgeAnalysisSectionCtas => 'Suggested CTAs';

  @override
  String get knowledgeAnalysisSectionSeoOpportunities => 'SEO Opportunities';

  @override
  String get knowledgeAnalysisSectionAdsenseOpportunities =>
      'AdSense Opportunities';

  @override
  String get knowledgeAnalysisSectionAmazonKdpOpportunities =>
      'Amazon KDP Opportunities';

  @override
  String get knowledgeAnalysisSectionHotmartEngine => 'Hotmart Engine';

  @override
  String get knowledgeAnalysisSectionShopifyEngine => 'Shopify Engine';

  @override
  String get knowledgeAnalysisSectionChannelDetails => 'Channel Details';

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
  String projectCommandAskProfilePrompt(String name, String niche,
      String audience, String maturity, String gaps) {
    return 'Analyze the intelligence profile for project \"$name\": niche $niche, audience $audience, maturity $maturity. ${gaps}What should I prioritize now?';
  }

  @override
  String projectCommandAskProfileGaps(String list) {
    return 'Gaps: $list. ';
  }

  @override
  String projectCommandAskAllocationPrompt(
      String name, int hours, String budget, String dirtyNote) {
    return 'Based on the SAVED resource allocation for project \"$name\" (${hours}h, $budget), is this allocation adequate for the project\'s current priorities? What should be adjusted?$dirtyNote';
  }

  @override
  String get projectCommandAskAllocationDirtyNote =>
      ' Note: there are unsaved allocation edits not reflected in this analysis.';

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
  String get oppLabFeatureGatedBody =>
      'Opportunity Lab is being prepared for launch.\nSoon you\'ll be able to generate and evaluate business opportunities massively and intelligently.';

  @override
  String get oppLabFeatureGatedProBadge => 'Coming soon — Pro Plan';

  @override
  String get oppLabApprove => 'Approve';

  @override
  String get oppLabConvertToAction => '→ Action';

  @override
  String get oppLabViewActionShort => 'View';

  @override
  String get oppLabEmptyTitle => 'Opportunity Lab is empty';

  @override
  String get oppLabEmptyBody =>
      'Add opportunities to analyze, prioritize, and execute.';

  @override
  String get oppLabAddButton => 'Add Opportunity';

  @override
  String get oppStatusPending => 'Pending';

  @override
  String get oppStatusAnalyzing => 'Analyzing';

  @override
  String get oppStatusApproved => 'Approved';

  @override
  String get oppStatusRejected => 'Rejected';

  @override
  String get oppStatusExecuting => 'Executing';

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

  @override
  String get miRootProjectSelectorLabel => 'Link to a project (optional)';

  @override
  String get miRootProjectSelectorNone => 'None';

  @override
  String get r16LanguageNamePortuguese => 'Portuguese';

  @override
  String get r16LanguageNameEnglish => 'English';

  @override
  String get r16LanguageNameSpanish => 'Spanish';

  @override
  String get r16LanguageNameOther => 'another language';

  @override
  String get ecoVerdictScale => 'SCALE';

  @override
  String get ecoVerdictAccelerate => 'ACCELERATE';

  @override
  String get ecoVerdictMaintain => 'MAINTAIN';

  @override
  String get ecoVerdictValidate => 'VALIDATE';

  @override
  String get ecoVerdictPause => 'PAUSE';

  @override
  String get ecoVerdictIncomplete => 'INCOMPLETE ANALYSIS';

  @override
  String get ecoRecTypeInvest => 'Invest';

  @override
  String get ecoRecTypeExecute => 'Execute';

  @override
  String get ecoRecTypeAction => 'Action';

  @override
  String get ecoRecTypePause => 'Pause';

  @override
  String get ecoRecTypeRisk => 'Risk';

  @override
  String get ecoRecTypeQuickWin => 'Quick Win';

  @override
  String get ecoRecTypeWaste => 'Waste';

  @override
  String ecoRecScaleTitle(String name) {
    return 'Scale "$name"';
  }

  @override
  String ecoRecInvestTitle(String name) {
    return 'Invest more in "$name"';
  }

  @override
  String ecoRecTopReason(int score) {
    return 'Ecosystem Score $score/100 — the highest potential in your portfolio';
  }

  @override
  String ecoRecTopData(int opportunity, int fit, int market) {
    return 'Scores: opportunity $opportunity, fit $fit, market $market';
  }

  @override
  String ecoRecTopImpact(int count) {
    return 'Faster revenue and execution of $count mapped opportunities';
  }

  @override
  String ecoRecValidateTitle(String name) {
    return 'Validate the assumptions behind "$name"';
  }

  @override
  String ecoRecValidateReason(int score) {
    return 'Score $score/100 — the potential is there, but there is not yet enough data to decide';
  }

  @override
  String ecoRecValidateData(int market, int roi, int execution) {
    return 'Market score $market, ROI $roi, execution $execution';
  }

  @override
  String get ecoRecValidateImpact => 'Strategic clarity to scale or pivot';

  @override
  String ecoRecOppTitle(String title) {
    return 'Execute the "$title" opportunity';
  }

  @override
  String ecoRecOppReason(int score) {
    return 'Final score $score/100 — the highest expected ROI in the Lab';
  }

  @override
  String ecoRecOppData(int market, int revenue) {
    return 'Market score $market, revenue score $revenue';
  }

  @override
  String get ecoRecOppImpactFallback => 'High leverage across the portfolio';

  @override
  String ecoRecQuickWinTitle(String title) {
    return 'Quick win: "$title"';
  }

  @override
  String ecoRecQuickWinReason(int impact, int effort) {
    return 'Impact $impact for just $effort effort — the best ratio in your portfolio';
  }

  @override
  String ecoRecQuickWinData(int impact, int effort) {
    return 'Impact score $impact, effort score $effort';
  }

  @override
  String get ecoRecQuickWinImpact => 'Fast execution with a high relative return';

  @override
  String ecoRecPauseTitle(String name) {
    return 'Pause or rework "$name"';
  }

  @override
  String ecoRecPauseReason(int score) {
    return 'Ecosystem Score $score/100 — resources spent with no visible return';
  }

  @override
  String ecoRecPauseData(int roi, int momentum, int count) {
    return 'ROI score $roi, momentum $momentum, $count actions not completed';
  }

  @override
  String get ecoRecPauseImpact => 'Frees up time and focus for higher-potential projects';

  @override
  String ecoRecRiskTitle(String name, String risk) {
    return 'Risk in "$name": $risk';
  }

  @override
  String get ecoRecRiskReason => 'Flagged by Ecosystem Intelligence based on the project data';

  @override
  String ecoRecRiskData(int score, int momentum) {
    return 'Ecosystem Score $score, momentum $momentum';
  }

  @override
  String get ecoRecRiskImpact => 'Preventive mitigation before it hits the portfolio';

  @override
  String get ecoAllocEmptySummary => 'No project has a high enough score for allocation yet. Run the Knowledge → Action Engine to generate operational intelligence.';

  @override
  String get ecoAllocUnitHours => 'hours';

  @override
  String get ecoAllocResourceBudget => 'budget';

  @override
  String ecoAllocSummary(String name, String amount, String unit, int percent, int score) {
    return 'Prioritize "$name" with $amount $unit ($percent% of the budget). Score: $score/100.';
  }

  @override
  String ecoAllocReasonScale(String resource) {
    return 'Highest potential — scale up the $resource invested here';
  }

  @override
  String ecoAllocReasonAccelerate(String resource) {
    return 'High potential — put as much $resource here as you can';
  }

  @override
  String get ecoAllocReasonMaintain => 'Healthy project — keep investment steady';

  @override
  String get ecoAllocReasonValidate => 'Reduced allocation until the assumptions are validated';

  @override
  String get ecoAllocReasonPause => 'Not recommended — consider pausing this project';

  @override
  String get ecoResourceAllocationTitle => 'Resource Allocation';

  @override
  String get ecoAllocModeHours => '⏱ Time (Hours)';

  @override
  String get ecoAllocModeMoney => '💰 Money (R\$)';

  @override
  String get ecoAllocBudgetQuestion => 'How much do I have available?';

  @override
  String get ecoAllocExecutiveRecommendation => 'Executive Recommendation';

  @override
  String get ecoAllocEmpty => 'Add projects with analyses to see the allocation.';

  @override
  String ecoAllocDistribution(int total, String unit) {
    return 'How the $total $unit are split';
  }

  @override
  String ecoBriefNewAnalysesTitle(int count) {
    return 'New market analyses: $count';
  }

  @override
  String get ecoBriefNewAnalysesDetail => 'New opportunities mapped by Market Intelligence';

  @override
  String ecoBriefNewActionsTitle(int count) {
    return 'New actions created: $count';
  }

  @override
  String get ecoBriefNewActionsDetail => 'Action Engine is in motion';

  @override
  String ecoBriefNewLabTitle(int count) {
    return 'New Opportunity Lab items: $count';
  }

  @override
  String get ecoBriefNewLabDetail => 'Opportunities under evaluation';

  @override
  String ecoBriefNewRoiTitle(int count) {
    return 'New ROI records: $count';
  }

  @override
  String get ecoBriefNewRoiDetail => 'Financial results updated';

  @override
  String get ecoBriefNoActivityTitle => 'No new activity this week';

  @override
  String get ecoBriefNoActivityDetail => 'Add analyses or actions to generate insights';

  @override
  String ecoBriefProjectScoreTitle(String name, int score) {
    return '$name — Ecosystem Score $score';
  }

  @override
  String ecoBriefRecommendationDetail(String verdict, String note) {
    return 'Recommendation: $verdict. $note';
  }

  @override
  String get ecoBriefGrewFallback => 'High potential identified.';

  @override
  String get ecoBriefDeclinedFallback => 'Low return identified.';

  @override
  String ecoBriefToPauseDetail(int score) {
    return 'Score $score/100 — free up resources for higher-potential projects';
  }

  @override
  String ecoBriefRiskProjectDetail(String name) {
    return 'Project: $name';
  }

  @override
  String get ecoBriefSummaryEmpty => 'No projects yet. Start by adding projects and running analyses.';

  @override
  String ecoBriefSummary(int count, int health, int growing, int pausing) {
    return 'Your ecosystem has $count project(s) with an overall health of $health/100. Growing: $growing. Needing review: $pausing.';
  }

  @override
  String get ecoExecNoActions => 'No actions recorded';

  @override
  String get ecoExecRoadmapPresent => 'Roadmap in place → +20pts';

  @override
  String get ecoExecNoRoadmap => 'No roadmap → +0pts';

  @override
  String ecoExecCompleted(int completed, int total, int points) {
    return '$completed/$total actions completed → ${points}pts';
  }

  @override
  String ecoExecApproved(int approved, int points) {
    return '$approved approved opportunities × 10 = ${points}pts (max 30)';
  }

  @override
  String get ecoStrengthMarket => 'High-potential market identified';

  @override
  String get ecoStrengthOpportunity => 'Strong market opportunity score';

  @override
  String get ecoStrengthRoi => 'Positive ROI recorded';

  @override
  String get ecoStrengthSynergy => 'Strong synergy with the rest of the portfolio';

  @override
  String get ecoStrengthMomentum => 'High recent activity';

  @override
  String get ecoStrengthPriority => 'High strategic priority';

  @override
  String get ecoStrengthDefault => 'Potential still to be developed';

  @override
  String get ecoRiskInsufficientData => 'Not enough data to assess value';

  @override
  String ecoRiskPendingActions(int count) {
    return '$count pending actions piling up without execution';
  }

  @override
  String get ecoRiskNoRoi => 'No ROI recorded despite actions in progress';

  @override
  String get ecoRiskLowActivity => 'Low activity in the last 30 days';

  @override
  String get ecoRiskIdeaStage => 'Still at the idea stage — execution has not started';

  @override
  String ecoIveCriticalProjects(int count) {
    return 'Heads up: $count project(s) with a critical score. I can help you fix that.';
  }

  @override
  String get ecoDecisionCenterTitle => 'Decision Center';

  @override
  String get ecoTabTop5 => 'TOP 5';

  @override
  String get ecoTabEcosystem => 'ECOSYSTEM';

  @override
  String get ecoTabRecommendations => 'RECOMMENDATIONS';

  @override
  String get ecoWeeklyBriefingTooltip => 'Weekly Briefing';

  @override
  String ecoBootstrapPending(int count) {
    return 'Projects without operational intelligence: $count';
  }

  @override
  String get ecoHealthTitle => 'Ecosystem Health';

  @override
  String ecoIveAskHealth(int health) {
    return 'Why is my ecosystem health at $health? What is holding it back and how can I improve it?';
  }

  @override
  String get ecoHealthNarrativeExcellent => 'Your ecosystem is running at full potential. Projects are aligned and scaling.';

  @override
  String get ecoHealthNarrativeHealthy => 'Your ecosystem is healthy and growing. There are levers ready to accelerate.';

  @override
  String get ecoHealthNarrativeStable => 'Your ecosystem is stable. A few areas need attention to unlock growth.';

  @override
  String get ecoHealthNarrativeValidating => 'Your ecosystem is in a validation phase. Add more analyses to sharpen the intelligence.';

  @override
  String get ecoHealthNarrativeReview => 'Your ecosystem needs a strategic review. IVE can help pinpoint the blockers.';

  @override
  String ecoErrorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String get ecoTop5Empty => 'No projects found.\nAdd content to the Vault and create projects.';

  @override
  String get ecoTop5ProjectsTitle => '🚀 TOP 5 PROJECTS';

  @override
  String get ecoTop5ProjectsSubtitle => 'Ranked by Ecosystem Score';

  @override
  String get ecoTop5OpportunitiesTitle => '💡 TOP 5 OPPORTUNITIES';

  @override
  String get ecoTop5OpportunitiesSubtitle => 'Highest potential in the Opportunity Lab';

  @override
  String ecoOppExplanation(String type, int score, String status) {
    return 'A "$type" opportunity scoring $score/100. Current status: $status.';
  }

  @override
  String get ecoLabelType => 'Type';

  @override
  String get ecoLabelFinalScore => 'Final Score';

  @override
  String get ecoLabelStatus => 'Status';

  @override
  String get ecoAskIveOpportunity => 'Ask IVE about this opportunity';

  @override
  String ecoIveAskOpportunity(String title, int score) {
    return 'Analyze the "$title" opportunity (score $score) and tell me how to capitalize on it.';
  }

  @override
  String get ecoTop5QuickWinsTitle => '⚡ TOP 5 QUICK WINS';

  @override
  String get ecoTop5QuickWinsSubtitle => 'High impact, low effort';

  @override
  String ecoImpactEffort(int impact, int effort) {
    return 'Impact $impact / Effort $effort';
  }

  @override
  String ecoQuickWinExplanation(int impact, int effort) {
    return 'Quick win: high impact ($impact/100) and low effort ($effort/100). Prioritize this action for immediate results.';
  }

  @override
  String get ecoLabelImpact => 'Impact';

  @override
  String get ecoLabelEffort => 'Effort';

  @override
  String get ecoTop5RisksTitle => '⚠️ TOP 5 RISKS';

  @override
  String get ecoTop5RisksSubtitle => 'Actions in low-scoring projects';

  @override
  String get ecoBadgeRisk => 'risk';

  @override
  String get ecoRiskActionExplanation => 'This action belongs to a project with a critical Ecosystem Score (below 30). It needs urgent attention to avoid losing the opportunity.';

  @override
  String get ecoTop5WastesTitle => '🗑️ TOP 5 WASTES';

  @override
  String get ecoTop5WastesSubtitle => 'Low impact, high effort';

  @override
  String get ecoBadgeReview => 'review';

  @override
  String ecoWasteExplanation(int impact, int effort) {
    return 'Waste: low impact ($impact/100) and high effort ($effort/100). Consider dropping or reworking this action to free up capacity.';
  }

  @override
  String get ecoNoItemsYet => 'No items yet';

  @override
  String ecoProjectExplanation(String name, int score, String verdict) {
    return '$name has an Ecosystem Score of $score/100, which classifies it as "$verdict". The score combines market opportunity, strategic fit, potential ROI and execution capacity.';
  }

  @override
  String get ecoLabelOpportunity => 'Opportunity';

  @override
  String get ecoLabelStrategicFit => 'Strategic Fit';

  @override
  String get ecoLabelRoiScore => 'ROI Score';

  @override
  String get ecoLabelMarket => 'Market';

  @override
  String get ecoLabelExecution => 'Execution';

  @override
  String get ecoLabelMomentum => 'Momentum';

  @override
  String get ecoLabelSynergy => 'Synergy';

  @override
  String get ecoLabelTotalRoi => 'Total ROI';

  @override
  String get ecoLabelEcosystem => 'Ecosystem';

  @override
  String get ecoAskIveImproveScore => 'Ask IVE how to improve this score';

  @override
  String get ecoAskIveImproveScoreDesc => 'Open a chat with this project\'s context';

  @override
  String ecoIveAskImproveProject(String name, int score) {
    return 'How can I improve the Ecosystem Score of "$name", currently at $score/100? Explain each component and which actions have the biggest impact.';
  }

  @override
  String ecoShortMarket(int score) {
    return 'Mkt $score';
  }

  @override
  String ecoShortFit(int score) {
    return 'Fit $score';
  }

  @override
  String ecoShortExec(int score) {
    return 'Exec $score';
  }

  @override
  String ecoIveAskProjectScore(String name, int score) {
    return 'Why does $name have a score of $score? Explain each component and how to improve it.';
  }

  @override
  String get ecoEcosystemEmpty => 'Add projects to see the Ecosystem Score.';

  @override
  String ecoCardFooter(int count, int percent, String roi) {
    return '$count actions  •  $percent% completed  •  R\$$roi ROI';
  }

  @override
  String get ecoStrengthsTitle => 'Strengths';

  @override
  String get ecoRisksTitle => 'Risks';

  @override
  String get ecoQuickWinsTitle => 'Quick Wins';

  @override
  String get ecoRecsEmpty => 'Add projects and analyses to generate recommendations.';

  @override
  String get ecoBlockedBadge => '🔒 BLOCKED';

  @override
  String get ecoGateDocuments => 'Documents';

  @override
  String get ecoGateIndexing => 'Indexing';

  @override
  String get ecoGateAssets => 'Assets';

  @override
  String get ecoGateOpportunities => 'Opportunities';

  @override
  String get ecoGateBlockReasons => 'Why it is blocked:';

  @override
  String ecoExpectedImpact(String impact) {
    return 'Expected impact: $impact';
  }

  @override
  String get ecoLabelConfidence => 'Confidence';

  @override
  String get ecoLabelDataUsed => 'Data used';

  @override
  String get ecoAskIveRecommendation => 'Ask IVE about this recommendation';

  @override
  String ecoIveAskRecommendation(String title) {
    return 'Explain the recommendation "$title" and give me a concrete action plan.';
  }

  @override
  String ecoConfidencePct(int percent) {
    return '$percent% confidence';
  }

  @override
  String ecoDataPrefix(String data) {
    return 'Data: $data';
  }

  @override
  String get ecoWeeklyBriefingTitle => 'Weekly Executive Briefing';

  @override
  String ecoBriefingError(String error) {
    return 'Could not generate the briefing: $error';
  }

  @override
  String get ecoBriefSectionChanged => '🔄 What changed';

  @override
  String get ecoBriefSectionGrew => '📈 What grew';

  @override
  String get ecoBriefSectionDeclined => '📉 What declined';

  @override
  String get ecoBriefSectionPriorities => '🎯 What to prioritize';

  @override
  String get ecoBriefSectionPause => '⏸️ What to pause';

  @override
  String get ecoBriefSectionNewOpps => '💡 New opportunities';

  @override
  String get ecoBriefSectionRisks => '⚠️ Risks';

  @override
  String get ecoBriefSectionRisksIdentified => '⚠️ Identified risks';

  @override
  String get ecoBriefOverallHealth => 'Overall Health';

  @override
  String ecoBriefOverallHealthValue(int score) {
    return 'Overall Health: $score/100';
  }

  @override
  String get ecoBriefLowScoreHint => '⚠ Low score. Review the risks and priorities below to improve it.';

  @override
  String get ecoBriefHeaderLabel => 'EXECUTIVE BRIEFING';

  @override
  String ecoBriefWeekOf(String date) {
    return 'Week of $date';
  }

  @override
  String get ecoBriefExecutiveSummary => 'Executive Summary';

  @override
  String get ecoBriefNoItemsThisWeek => 'Nothing this week';

  @override
  String get ecoBriefDataAnalyzed => 'DATA ANALYZED';

  @override
  String ecoBriefGeneratedAt(String date, String time) {
    return 'Generated on $date at $time';
  }

  @override
  String get ecoCountProjects => 'Projects';

  @override
  String get ecoCountAnalyses => 'Analyses';

  @override
  String get ecoCountActions => 'Actions';

  @override
  String get ecoBriefIncludedProjects => 'Included projects';

  @override
  String get ctxIveProjectsMsg1 => 'Hi! I\'m IVE, your executive advisor. I can analyze your portfolio right now.';

  @override
  String get ctxIveProjectsMsg2 => 'Want to know which project has the most potential to scale right now?';

  @override
  String get ctxIveProjectsMsg3 => 'I spot patterns across your projects. Any strategic questions?';

  @override
  String get ctxIveOppLabMsg1 => 'I\'ve found high-ROI opportunities in this list. I can prioritize them for you.';

  @override
  String get ctxIveOppLabMsg2 => 'Every opportunity here has measurable criteria. I can explain any of them.';

  @override
  String get ctxIveOppLabMsg3 => 'Want me to point out which opportunities to execute first this week?';

  @override
  String get ctxIveEcosystemMsg1 => 'This is your decision center. I can explain any score in plain language.';

  @override
  String get ctxIveEcosystemMsg2 => 'I see projects with untapped potential. Want a detailed analysis?';

  @override
  String get ctxIveEcosystemMsg3 => 'I can simulate the impact of approving opportunities or completing actions.';

  @override
  String get ctxIveBriefingMsg1 => 'Your executive briefing is ready. I can highlight what\'s most urgent.';

  @override
  String get ctxIveBriefingMsg2 => 'Want me to turn this report into concrete next steps?';

  @override
  String get ctxIveBriefingMsg3 => 'I can identify what changed this week and why.';

  @override
  String get ctxIvePersonasMsg1 => 'Your personas are your market presence. I can compare how each one performs.';

  @override
  String get ctxIvePersonasMsg2 => 'Want to know which persona has the most growth potential right now?';

  @override
  String get ctxIvePersonasMsg3 => 'I can recommend specific strategies for each niche.';

  @override
  String get ctxIveKnowledgeMsg1 => 'Your knowledge vault powers all of the system\'s intelligence.';

  @override
  String get ctxIveKnowledgeMsg2 => 'Which document would you like me to analyze or connect to your projects?';

  @override
  String get ctxIveKnowledgeMsg3 => 'I can show which knowledge is generating the most insights.';

  @override
  String get ctxIveActionsMsg1 => 'Your action queue sets your execution speed.';

  @override
  String get ctxIveActionsMsg2 => 'I can help you prioritize: which actions have the biggest impact on your score?';

  @override
  String get ctxIveActionsMsg3 => 'Want me to identify what\'s blocking your progress?';

  @override
  String get ctxIveDebugMsg1 => 'Full observability center. I can audit any calculation.';

  @override
  String get ctxIveDebugMsg2 => 'Want to understand how a score was generated? Just ask.';

  @override
  String get ctxIveDebugMsg3 => 'I can trace the origin of any data point or recommendation.';

  @override
  String ctxIveAnalysisCompleted(String name) {
    return 'Analysis of "$name" complete!';
  }

  @override
  String ctxIveAnalyzing(String name) {
    return 'Analyzing "$name"...';
  }

  @override
  String ctxIveProjectCreated(String name) {
    return 'Project "$name" created!';
  }

  @override
  String ctxIveProjectRemoved(String name) {
    return 'Project "$name" removed.';
  }

  @override
  String ctxIveProjectStatusChanged(String name, String status) {
    return '"$name" $status.';
  }

  @override
  String get ctxIveStatusActivated => 'activated';

  @override
  String get ctxIveStatusPaused => 'paused';

  @override
  String get ctxIveStatusCompleted => 'completed';

  @override
  String ctxIveCtxEcosystem(int score, String bottleneck) {
    return 'Ecosystem at $score/100. Main bottleneck: $bottleneck. I can walk you through how to improve it.';
  }

  @override
  String get ctxIveCtxBottleneckFallback => 'execution';

  @override
  String ctxIveCtxProjectLeads(String name, int score) {
    return '$name leads with a score of $score.';
  }

  @override
  String ctxIveCtxPendingDetected(int count) {
    return 'Pending actions detected: $count.';
  }

  @override
  String get ctxIveCtxAnalyzeOpportunities => 'Want to review opportunities?';

  @override
  String ctxIveCtxOppLab(int count) {
    return 'Opportunities awaiting your review: $count. I can prioritize the highest-ROI ones.';
  }

  @override
  String ctxIveCtxBriefing(int score) {
    return 'Briefing generated with overall health at $score/100. I can turn the data into concrete actions.';
  }

  @override
  String ctxIveCtxActions(int count) {
    return 'Pending actions: $count. I can identify the ones with the biggest impact on your execution score.';
  }

  @override
  String ctxIssueAnalysisFailed(String name) {
    return 'I couldn\'t analyze "$name".\nThe failure happened during AI processing.\nYou can try again.';
  }

  @override
  String ctxIssueDownloadFailed(String name) {
    return 'I couldn\'t import "$name".\nThe failure happened while downloading the file.\nThe content hasn\'t been analyzed yet.';
  }

  @override
  String ctxIssueActionMutationFailed(String name) {
    return 'I couldn\'t update "$name".\nCheck your connection and try again.';
  }

  @override
  String get ctxIssueActionViewDetails => 'View details';

  @override
  String get ctxIssueActionUpdateLink => 'Update link';

  @override
  String get ctxIssueActionSendFile => 'Send file';

  @override
  String get ctxIssueActionDismiss => 'Dismiss';

  @override
  String ctxAlertHealthLow(int health) {
    return 'Ecosystem health at $health/100. Immediate action recommended.';
  }

  @override
  String ctxAlertProjectCritical(String name, int score) {
    return '$name has a critical score ($score/100). I can identify what\'s holding it back.';
  }

  @override
  String ctxAlertActionsOverdue(int count) {
    return 'Pending actions piling up: $count. This is hurting your execution score.';
  }

  @override
  String ctxDocCoverageWarning(int total, int used, int unused) {
    return '$total linked sources · $used used in this analysis · $unused not used in this run.';
  }

  @override
  String ctxGroundingEmptyContent(String title) {
    return '"$title": registered but has no processable content.';
  }

  @override
  String ctxGroundingBudgetExceeded(int maxChars) {
    return '$maxChars-character limit reached. Remaining documents were omitted.';
  }

  @override
  String ctxDvReasonCoverage(int score, int min) {
    return 'Insufficient Knowledge Coverage ($score% < $min%)';
  }

  @override
  String ctxDvReasonLearning(int score, int min) {
    return 'Insufficient average Learning Score ($score% < $min%)';
  }

  @override
  String get ctxDvReasonProfile => 'Incomplete intelligence profile — link a market analysis';

  @override
  String get ctxDvReasonStructuring => 'No opportunities or actions generated yet — run Knowledge → Action Engine';

  @override
  String get ctxDvBlockStructuring => 'Project is still being structured. Knowledge is available, but there isn\'t enough operational intelligence for a strategic recommendation.';

  @override
  String get ctxDvBlockInsufficient => 'Not enough data for a strategic decision.';

  @override
  String get ctxDvNoDocuments => 'No documents';

  @override
  String ctxDvIndexedCount(int indexed, int total) {
    return '$indexed/$total indexed';
  }

  @override
  String ctxDvThresholdLabel(String mark, int score, int min) {
    return '$mark $score% (minimum $min%)';
  }

  @override
  String get ctxDvProfileComplete => '✅ Complete';

  @override
  String get ctxDvProfileIncomplete => '❌ Incomplete — link a market analysis';

  @override
  String get ctxCoverageExcellent => 'Excellent';

  @override
  String get ctxCoverageGood => 'Good';

  @override
  String get ctxCoverageModerate => 'Moderate';

  @override
  String get ctxCoverageBasic => 'Basic';

  @override
  String get ctxCoverageMinimal => 'Minimal';

  @override
  String get ctxGapNoDocuments => 'Add documents to the Knowledge Vault';

  @override
  String get ctxGapNoOpportunities => 'No opportunities — run Knowledge → Action Engine';

  @override
  String get ctxGapNoActions => 'No actions defined for the project';

  @override
  String get ctxGapNoRoadmap => 'Roadmap not generated — run Bootstrap';

  @override
  String get ctxGapNoRevenuePlan => 'Revenue plan not created';

  @override
  String get ctxGapUntrainedPersonas => 'Personas without knowledge training';

  @override
  String get ctxStrengthKnowledgeBase => 'Established knowledge base';

  @override
  String get ctxStrengthOpportunities => 'Opportunities mapped';

  @override
  String get ctxStrengthActions => 'Actions planned';

  @override
  String get ctxStrengthRoadmap => 'Structured roadmap';

  @override
  String get ctxStrengthRevenuePlan => 'Revenue plan projected';

  @override
  String get ctxStrengthTrainedPersonas => 'Personas with trained knowledge';

  @override
  String get ctxLearningExpert => 'Expert';

  @override
  String get ctxLearningAdvanced => 'Advanced';

  @override
  String get ctxLearningIntermediate => 'Intermediate';

  @override
  String get ctxLearningBeginner => 'Beginner';

  @override
  String get ctxLearningUntrained => 'Untrained';

  @override
  String get ctxMaturityMature => 'Mature';

  @override
  String get ctxMaturityGrowing => 'Growing';

  @override
  String get ctxMaturityValidating => 'Validating';

  @override
  String get ctxMaturityIdea => 'Idea';

  @override
  String get ctxProfileWarningNoAnalysis => 'Run a market analysis to get intelligence.';

  @override
  String get ctxProfileWarningLowData => 'Not enough data. Add actions and opportunities.';

  @override
  String get ctxProfileNotDefined => 'Not defined';

  @override
  String get ctxEmptyServerResponse => 'Empty response from the server.';

  @override
  String ctxDurationYears(int count) {
    return '${count}y';
  }

  @override
  String ctxDurationMonths(int count) {
    return '${count}mo';
  }

  @override
  String ctxDurationDays(int count) {
    return '${count}d';
  }

  @override
  String get ctxProjectTypeWebsite => 'Website';

  @override
  String get ctxProjectTypeApp => 'App';

  @override
  String get ctxProjectTypeProduct => 'Product';

  @override
  String get ctxProjectTypeService => 'Service';

  @override
  String get ctxProjectTypeContent => 'Content';

  @override
  String get ctxHomeFeatureUnavailable => 'This feature is not available yet.';

  @override
  String get ctxHomeCommandCenter => 'Command Center';

  @override
  String get ctxHomeImprovePostTooltip => 'Improve Post';

  @override
  String get ctxHomeRefreshTooltip => 'Refresh';

  @override
  String get ctxHomeExecCommandCenter => 'Executive Command Center';

  @override
  String get ctxHomeMetricProjects => 'Projects';

  @override
  String get ctxHomeMetricOpportunities => 'Opportunities';

  @override
  String get ctxHomeMetricPendingActions => 'Pending Actions';

  @override
  String get ctxHomeMetricKnowledge => 'Knowledge';

  @override
  String get ctxHomeMetricLearning => 'Learning Score';

  @override
  String get ctxHomeQuickDecisionCenter => 'Decision Center';

  @override
  String get ctxHomeQuickBriefing => 'Briefing';

  @override
  String get ctxHomePriorityProjects => 'Priority Projects';

  @override
  String get ctxHomeNoProjects => 'No projects yet.';

  @override
  String get ctxHomeAddProject => 'Add project';

  @override
  String get ctxHomeNextBestAction => 'Next Best Action';

  @override
  String get ctxHomeNoRecommendations => 'No recommendations available.';

  @override
  String get ctxHomeViewOpportunityLab => 'View Opportunity Lab';

  @override
  String ctxHomeConfidence(int value) {
    return '$value% confidence';
  }

  @override
  String ctxHomeExpectedImpact(String impact) {
    return 'Expected impact: $impact';
  }

  @override
  String get ctxHomePersonas => 'Personas';

  @override
  String get ctxHomeNoPersonas => 'No personas created yet.';

  @override
  String get ctxHomeCreatePersona => 'Create persona';

  @override
  String get ctxHomeEcosystemIntelligence => 'Ecosystem Intelligence';

  @override
  String ctxHomeStatProjects(int count) {
    return 'Projects: $count';
  }

  @override
  String ctxHomeStatOpportunities(int count) {
    return 'Opportunities: $count';
  }

  @override
  String ctxHomeStatActions(int count) {
    return 'Actions: $count';
  }

  @override
  String ctxHomeStatConnections(int count) {
    return 'Connections: $count';
  }

  @override
  String get ctxHomeConnectionsFound => 'Connections found:';

  @override
  String get ctxHomeNoConnections => 'Run market analyses to discover connections between your projects.';

  @override
  String get ctxHomeSeeAll => 'see all';

  @override
  String ctxHomeHealth(int score) {
    return 'Health $score/100';
  }

  @override
  String ctxHomeCoverage(String emoji, int score) {
    return '$emoji $score% coverage';
  }

  @override
  String ctxHomePersonaStats(int trainings, int words) {
    return 'Trainings: $trainings · Words: $words';
  }

  @override
  String ctxHomeError(String message) {
    return 'Error: $message';
  }

  @override
  String get ctxGraphSharesNiche => 'shares niche with';

  @override
  String get ctxGraphUsesKnowledge => 'uses knowledge';

  @override
  String get ctxGraphOpportunityOf => 'opportunity of';

  @override
  String get ctxGraphPersonaKnows => 'persona knows';

  @override
  String ctxGraphEdge(String source, String relation, String target) {
    return '$source → $relation → $target';
  }

  @override
  String get ctxExecNotEstimated => 'Not estimated yet';

  @override
  String get ctxExecSubtitle => 'InsightValues · Executive Dashboard';

  @override
  String get ctxExecAskIve => 'Ask IVE';

  @override
  String get ctxExecReload => 'Reload';

  @override
  String get ctxExecPortfolioTitle => 'EXECUTIVE PORTFOLIO';

  @override
  String get ctxExecActiveProjects => 'Active Projects';

  @override
  String get ctxExecTotalProjects => 'Total Projects';

  @override
  String get ctxExecMiAnalyses => 'MI Analyses';

  @override
  String get ctxExecAvgScore => 'Average Score';

  @override
  String get ctxExecFinancialTitle => 'FINANCIAL';

  @override
  String get ctxExecRecordedRevenue => 'Recorded Revenue';

  @override
  String get ctxExecMonthlyPotential => 'Monthly Potential';

  @override
  String get ctxExecModProjects => 'Projects';

  @override
  String get ctxExecTotal => 'Total';

  @override
  String get ctxExecActive => 'Active';

  @override
  String get ctxExecInIdea => 'Idea stage';

  @override
  String get ctxExecNoAnalysis => 'No analysis';

  @override
  String get ctxExecEmptyProjects => 'Add your first project to get started.';

  @override
  String get ctxExecViewProjects => 'View Projects';

  @override
  String get ctxExecAnalyses => 'Analyses';

  @override
  String get ctxExecAvgScoreShort => 'Avg. score';

  @override
  String get ctxExecHighQuality => 'High quality';

  @override
  String get ctxExecNoProject => 'No project';

  @override
  String get ctxExecEmptyMi => 'Run a market analysis in Market Intelligence.';

  @override
  String get ctxExecAnalyzeMarket => 'Analyze Market';

  @override
  String get ctxExecModOpportunities => 'Opportunities';

  @override
  String get ctxExecHighPriority => 'High priority';

  @override
  String get ctxExecApproved => 'Approved';

  @override
  String get ctxExecPending => 'Pending';

  @override
  String get ctxExecEmptyOpportunities => 'Generate opportunities from your market analyses.';

  @override
  String get ctxExecViewOpportunities => 'View Opportunities';

  @override
  String get ctxExecInProgress => 'In progress';

  @override
  String get ctxExecBlocked => 'Blocked';

  @override
  String get ctxExecCompleted => 'Completed';

  @override
  String get ctxExecEmptyActions => 'Approve opportunities to generate actionable tasks.';

  @override
  String get ctxExecOpenDecisions => 'Open Decisions';

  @override
  String get ctxExecWeeklyBriefing => 'Weekly Briefing';

  @override
  String get ctxExecAllocation => 'Allocation';

  @override
  String get ctxExecQuickAccess => 'QUICK ACCESS';

  @override
  String get ctxExecPendingEmpty => 'No pending actions. Action Engine will fill this in automatically.';

  @override
  String get ctxExecModulesTitle => 'BUSINESS OS MODULES';

  @override
  String ctxExecOpenModule(String label) {
    return 'Open $label';
  }

  @override
  String get ctxExecModuleUnavailable => 'Module not available';

  @override
  String get ctxIveDetailExplanation => 'IVE Explanation';

  @override
  String get ctxIveDetailNumbers => 'Numbers and formulas';

  @override
  String get ctxIveDetailSuggestedActions => 'Suggested actions';

  @override
  String get ctxIveExplainCompact => 'Explain';

  @override
  String get ctxIveExplainFull => 'Explain with IVE';

  @override
  String ctxResultCopied(String title) {
    return '"$title" copied!';
  }

  @override
  String get ctxResultCopyTooltip => 'Copy';

  @override
  String ctxCopilotConfidenceBadge(int value) {
    return '$value% conf.';
  }

  @override
  String get uxAiInvestmentYes => 'YES';

  @override
  String get uxAiInvestmentConditional => 'CONDITIONAL';

  @override
  String get uxAiInvestmentNo => 'NO';

  @override
  String get uxAiLevelLow => 'Low';

  @override
  String get uxAiLevelMedium => 'Medium';

  @override
  String get uxAiLevelHigh => 'High';

  @override
  String get uxAiLevelCritical => 'Critical';

  @override
  String get uxAiPriorityLow => 'Low';

  @override
  String get uxAiPriorityMedium => 'Medium';

  @override
  String get uxAiPriorityHigh => 'High';

  @override
  String get uxAiPriorityCritical => 'Critical';

  @override
  String get uxAiSearchIntentInformational => 'Informational';

  @override
  String get uxAiSearchIntentNavigational => 'Navigational';

  @override
  String get uxAiSearchIntentTransactional => 'Transactional';

  @override
  String get uxAiSearchIntentCommercial => 'Commercial';

  @override
  String get uxAiArticleTypePillar => 'Pillar page';

  @override
  String get uxAiArticleTypeSupporting => 'Supporting content';

  @override
  String get uxAiArticleTypeLandingPage => 'Landing page';

  @override
  String get uxAiArticleTypeComparison => 'Comparison';

  @override
  String get uxAiOpportunityTypeContent => 'Content';

  @override
  String get uxAiOpportunityTypeSeo => 'SEO';

  @override
  String get uxAiOpportunityTypeProduct => 'Product';

  @override
  String get uxAiOpportunityTypeMonetization => 'Monetization';

  @override
  String get uxAiOpportunityTypePartnership => 'Partnership';

  @override
  String get uxAiOpportunityTypePlatform => 'Platform';

  @override
  String get uxAiOpportunityTypeAudience => 'Audience';

  @override
  String uxAiTimeframeMonths(String range) {
    return '$range months';
  }

  @override
  String uxAiTimeframeWeeks(String range) {
    return '$range weeks';
  }

  @override
  String uxAiTimeframeDays(String range) {
    return '$range days';
  }

  @override
  String get uxCampaignObjectiveSales => 'Sales';

  @override
  String get uxCampaignObjectiveAuthority => 'Authority';

  @override
  String get uxCampaignObjectiveLeads => 'Leads';

  @override
  String get uxCampaignObjectiveEngagement => 'Engagement';

  @override
  String get uxCampaignObjectiveLaunch => 'Launch';

  @override
  String get uxCampaignObjectiveTraffic => 'Traffic';

  @override
  String uxCampaignObjectiveSalesOn(String platform) {
    return '$platform sales';
  }

  @override
  String get uxCampaignObjectiveSubscription => 'Subscription';

  @override
  String get uxAiTimeframeOneMonth => '1 month';

  @override
  String get uxAiTimeframeOneWeek => '1 week';

  @override
  String get uxAiTimeframeOneDay => '1 day';

  @override
  String uxMiRoiNoteOpportunities(String count, String input) {
    return '$count opportunities — $input';
  }

  @override
  String get uxNotAvailableShort => 'N/A';

  @override
  String uxOppSeedDescription(String impact, String effort) {
    return 'Impact: $impact · Effort: $effort';
  }

  @override
  String uxOppSeedRationaleFallback(String input) {
    return 'Identified by Market Intelligence based on the analysis of $input.';
  }

  @override
  String uxOppSeedRiskEffort(String effort) {
    return 'Effort: $effort';
  }

  @override
  String uxOppSeedEstimatedTimeframe(String timeframe) {
    return 'Estimated timeframe: $timeframe';
  }

  @override
  String get uxActionDefaultTitle => 'Action';

  @override
  String get uxErrorNotAuthenticated => 'Your session has expired. Please sign in again to continue.';

  @override
  String get uxMemoryCampaignSucceeded => 'Successful campaign';

  @override
  String get uxMemoryCampaignFailed => 'Unsuccessful campaign';

  @override
  String uxMemoryRoiTitle(String value) {
    return 'ROI: R\$ $value';
  }

  @override
  String get uxAuthErrorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get uxAuthErrorEmailNotConfirmed => 'Please confirm your email before signing in.';

  @override
  String get uxAuthErrorAlreadyRegistered => 'This email is already registered.';

  @override
  String get uxAuthErrorRateLimited => 'Too many attempts. Please wait a few seconds.';

  @override
  String get uxAuthErrorWeakPassword => 'Password is too weak. Use at least 6 characters.';

  @override
  String get uxAuthErrorGeneric => 'We couldn\'t complete sign-in. Please try again.';

  @override
  String get uxErrorQuotaExceeded => 'You\'ve reached your plan\'s monthly AI analysis limit. Upgrade to Pro to continue.';

  @override
  String get uxErrorPlanRequired => 'This feature is part of a higher plan. Upgrade to continue.';

  @override
  String get uxErrorModuleNotAvailable => 'This feature isn\'t available for your account yet.';

  @override
  String get uxErrorModuleDisabled => 'This feature has been disabled.';

  @override
  String get uxErrorEntitlementUnavailable => 'We couldn\'t verify your access right now. Please try again.';

  @override
  String get uxErrorSessionExpired => 'Your session has expired. Please sign in again.';

  @override
  String get uxErrorNoConnection => 'Couldn\'t connect. Please check your internet connection.';

  @override
  String get uxErrorTimeout => 'The connection took too long. Please try again.';

  @override
  String get uxErrorServiceUnavailable => 'Service temporarily unavailable. Please try again.';

  @override
  String get uxOriginManual => 'Added manually';

  @override
  String get uxOriginMarketAnalysis => 'Market Analysis';

  @override
  String get uxOriginAutoBootstrap => 'Automatic Bootstrap';

  @override
  String get uxKnowledgeFormSourceLanguageLabel => 'Document language';

  @override
  String get uxAdminAccessDeniedTitle => 'Access denied';

  @override
  String get uxAdminAccessDeniedBody => 'You don\'t have permission to access this area.';

  @override
  String get uxAdminPanelTitle => 'Admin Panel';

  @override
  String get uxAdminTabUsers => 'Users';

  @override
  String get uxAdminTabPersonas => 'Personas';

  @override
  String get uxAdminTabOverview => 'Overview';

  @override
  String get uxAdminTabModules => 'Modules';

  @override
  String get uxAdminTabDiagnostics => 'Diagnostics';

  @override
  String get uxAdminNoUsers => 'No users found.';

  @override
  String get uxAdminNoEmail => 'No email';

  @override
  String uxAdminUserPlanLine(String role, String limit) {
    return '$role · $limit generations/month';
  }

  @override
  String get uxAdminDeactivate => 'Deactivate';

  @override
  String get uxAdminActivate => 'Activate';

  @override
  String get uxAdminManagePersonas => 'Manage all personas';

  @override
  String get uxAdminNewPersona => 'New Persona';

  @override
  String get uxAdminOpenPersonas => 'Open Persona management';

  @override
  String get uxAdminUserDistribution => 'User Distribution';

  @override
  String get uxAdminTotalUsers => 'Total Users';

  @override
  String get uxAdminModuleNotCommercial => 'Not commercial';

  @override
  String get uxAdminModuleTables => 'Tables';

  @override
  String get uxDiagActive => 'DIAGNOSTICS ACTIVE';

  @override
  String get uxDiagInactive => 'Diagnostics inactive';

  @override
  String get uxDiagCopySessionId => 'Copy session ID';

  @override
  String get uxDiagIdCopied => 'ID copied.';

  @override
  String uxDiagLabelValue(String label) {
    return 'Label: $label';
  }

  @override
  String get uxDiagStopSession => 'END SESSION';

  @override
  String get uxDiagLabelHint => 'Label (optional) — e.g. COMMERCIAL-E2E-001';

  @override
  String get uxDiagStartSession => 'START DIAGNOSTIC SESSION';

  @override
  String get uxDiagStartFailed => 'Couldn\'t start the session.';

  @override
  String get uxDiagSessionsTitle => 'Diagnostic Sessions';

  @override
  String uxDiagSessionsLoadError(String error) {
    return 'Error loading sessions: $error';
  }

  @override
  String get uxDiagNoSessions => 'No sessions recorded.';

  @override
  String uxDiagSessionShort(String id) {
    return 'Session $id…';
  }

  @override
  String get uxDiagCopyReport => 'Copy diagnostic report';

  @override
  String get uxDiagSearchHint => 'Search by event, route or error…';

  @override
  String get uxDiagNoEventsMatch => 'No events match the filters.';

  @override
  String get uxDiagSeverity => 'Severity';

  @override
  String get uxDiagCategory => 'Category';

  @override
  String get uxDiagFilterAll => 'All';

  @override
  String get uxDiagReportCopied => 'Report copied to clipboard.';

  @override
  String uxDiagRouteValue(String route) {
    return 'route: $route';
  }

  @override
  String get uxDriveLoginCancelled => 'Sign-in cancelled.';

  @override
  String get uxDriveConfigError => 'Couldn\'t connect to Google (configuration error).\nUse the "URL" type and paste the Google Docs sharing link, or use the "File" type to import local PDFs.';

  @override
  String get uxDriveNoInternet => 'No internet connection. Check your network and try again.';

  @override
  String get uxDriveConnectError => 'Couldn\'t connect to Google Drive. Please try again.';

  @override
  String get uxDriveLoadError => 'Couldn\'t load your Drive files. Please try again.';

  @override
  String get uxDriveDownloadError => 'Couldn\'t download the file. Please try again.';

  @override
  String get uxDriveImportTitle => 'Import from Google Drive';

  @override
  String get uxDriveSignOut => 'Sign out';

  @override
  String get uxDriveDownloading => 'Downloading file…';

  @override
  String get uxDriveConnectTitle => 'Connect Google Drive';

  @override
  String get uxDriveConnectBody => 'Import PDFs, Google Docs and text documents directly into the Knowledge Vault.';

  @override
  String get uxDriveConnecting => 'Connecting…';

  @override
  String get uxDriveSignInGoogle => 'Sign in with Google';

  @override
  String uxDriveConnectedAs(String name) {
    return 'Connected as $name';
  }

  @override
  String get uxDriveSearchHint => 'Search files in Drive…';

  @override
  String get uxDriveNoFiles => 'No files found.\nSupported: Google Docs, PDF, DOCX, TXT and CSV.';

  @override
  String get uxDriveTypeText => 'Text';

  @override
  String get uxKnowledgeActionGenerateStrategy => 'Generate Strategy';

  @override
  String get uxKnowledgeActionCreateCampaign => 'Create Campaign';

  @override
  String get uxKnowledgeActionTrainPersona => 'Train Persona';

  @override
  String get uxKnowledgeActionAskIve => 'Ask IVE';

  @override
  String uxKnowledgeAskIveMessage(String title) {
    return 'Analyze the knowledge item "$title" and tell me how to apply the insights to the project strategy.';
  }

  @override
  String get uxKnowledgeNoPersonas => 'No personas found. Create a persona first.';

  @override
  String get uxKnowledgePersonaTrained => 'Persona trained successfully!';

  @override
  String get uxKnowledgeTrain => 'Train';

  @override
  String get uxKnowledgeOppHigh => 'High Opportunity';

  @override
  String get uxKnowledgeOppGood => 'Good Opportunity';

  @override
  String get uxKnowledgeOppModerate => 'Moderate Opportunity';

  @override
  String get uxKnowledgeOppLow => 'Low Opportunity';

  @override
  String get uxKnowledgeFieldProduct => 'Product';

  @override
  String get uxKnowledgeFieldPromise => 'Promise';

  @override
  String get uxKnowledgeFieldFormat => 'Format';

  @override
  String get uxKnowledgeFieldPrice => 'Price';

  @override
  String get uxKnowledgeFieldDescription => 'Description';

  @override
  String get uxKnowledgeStrengths => 'Strengths';

  @override
  String get uxKnowledgeWeaknesses => 'Weaknesses';

  @override
  String get uxKnowledgeImprovements => 'Improvements';

  @override
  String get uxResultSavedToHistory => 'Saved to history!';

  @override
  String get uxResultSaveError => 'Error saving. Please try again.';

  @override
  String get uxPostImproved => 'Improved Post';

  @override
  String get uxPostProfessional => 'Professional Version';

  @override
  String get uxPostCasual => 'Casual Version';

  @override
  String get uxPostPersuasive => 'Persuasive Version';

  @override
  String get uxPostCommentReply => 'Suggested Comment Reply';

  @override
  String get uxContentCopied => 'Content copied successfully!';

  @override
  String get uxResultTitle => 'Result';

  @override
  String get uxCopyAll => 'Copy All';

  @override
  String uxResultGeneratedIn(String seconds) {
    return 'Generated in $seconds seconds';
  }

  @override
  String get uxScoreClarity => 'Clarity';

  @override
  String get uxScoreEngagement => 'Engagement';

  @override
  String get uxScoreClarityShort => 'C';

  @override
  String get uxScoreImpactShort => 'I';

  @override
  String get uxScoreEngagementShort => 'E';

  @override
  String uxDateAtTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String get uxHistoryItemLoadError => 'Couldn\'t load this item.';

  @override
  String get uxHistoryOriginalText => 'Original text';

  @override
  String get uxHistoryLoadError => 'Couldn\'t load your history.';

  @override
  String get uxHistoryEmptyTitle => 'No saved content yet';

  @override
  String get uxHistoryEmptyBody => 'Go back to the main screen, write a post\nand tap "Save" after generating the result.';

  @override
  String get uxContentTypeBook => 'Book';

  @override
  String get uxContentTypeEbook => 'E-book';

  @override
  String get uxContentTypeArticle => 'Article';

  @override
  String get uxContentTypePost => 'Post';

  @override
  String get uxContentTypeIdea => 'Idea';

  @override
  String get uxContentTypeRawText => 'Raw Text';

  @override
  String get uxContentTypeCampaign => 'Campaign';

  @override
  String get uxContentTypeDigitalProduct => 'Digital Product';

  @override
  String get uxContentTypeBrand => 'Brand';

  @override
  String get uxContentTypeProject => 'Project';

  @override
  String get uxContentFormEditTitle => 'Edit Item';

  @override
  String get uxContentFormNewTitle => 'New Item';

  @override
  String get uxContentFormTypeLabel => 'Content type';

  @override
  String get uxContentFormTitleLabel => 'Title *';

  @override
  String get uxContentFormTitleHint => 'Content name';

  @override
  String get uxFieldRequired => 'Required';

  @override
  String get uxContentFormDescLabel => 'Description / Summary';

  @override
  String get uxContentFormDescHint => 'Short description...';

  @override
  String get uxContentFormBodyLabel => 'Base Text / Content';

  @override
  String get uxContentFormBodyHint => 'Paste the text, excerpt or notes...';

  @override
  String get uxContentFormNicheLabel => 'Niche';

  @override
  String get uxContentFormNicheHint => 'E.g. Digital Marketing, Fitness';

  @override
  String get uxContentFormAudienceLabel => 'Target audience';

  @override
  String get uxContentFormAudienceHint => 'E.g. Early-stage entrepreneurs';

  @override
  String get uxContentFormSaveChanges => 'Save Changes';

  @override
  String get uxContentFormAddToLibrary => 'Add to Library';

  @override
  String get uxAdvisorRoleStrategy => 'Strategy';

  @override
  String get uxAdvisorRoleMarketing => 'Marketing';

  @override
  String get uxAdvisorRoleMonetization => 'Monetization';

  @override
  String get uxAdvisorRoleBusiness => 'Business';

  @override
  String get uxAdvisorRoleGeneral => 'General';

  @override
  String get uxAdvisorStyleExecutive => 'Executive';

  @override
  String get uxAdvisorStyleAnalytical => 'Analytical';

  @override
  String get uxAdvisorStyleTeacher => 'Teacher';

  @override
  String get uxAdvisorStyleMentor => 'Mentor';

  @override
  String get uxAdvisorStyleDirect => 'Direct';

  @override
  String get uxAdvisorStyleExecutiveDesc => 'Straight to the point, focused on results and ROI.';

  @override
  String get uxAdvisorStyleAnalyticalDesc => 'Data first, in-depth analysis before recommending.';

  @override
  String get uxAdvisorStyleTeacherDesc => 'Explains every concept, ideal for learning.';

  @override
  String get uxAdvisorStyleMentorDesc => 'Guides with experience and strategic questions.';

  @override
  String get uxAdvisorStyleDirectDesc => 'No detours, goes straight to the solution.';

  @override
  String get uxAdvisorNext => 'Next';

  @override
  String get uxAdvisorActivate => 'Activate Advisor';

  @override
  String get uxAdvisorNameTitle => 'Choose a name for your\nPersonal AI Advisor';

  @override
  String get uxAdvisorNameSubtitle => 'This will be your strategic business partner.';

  @override
  String get uxAdvisorCustomNameHint => 'Or type a custom name...';

  @override
  String get uxAdvisorRoleTitle => 'What will your Advisor\nspecialize in?';

  @override
  String get uxAdvisorRoleSubtitle => 'Sets the focus of analyses and recommendations.';

  @override
  String uxAdvisorStyleTitle(String name) {
    return 'How should $name\ncommunicate?';
  }

  @override
  String get uxAdvisorStyleSubtitle => 'Sets the style of responses and interactions.';

  @override
  String get uxImpactInvestigationActive => 'Active';

  @override
  String get uxImpactInvestigationArchived => 'Archived';

  @override
  String get uxSupportSubjectProblemReport => 'Problem report';

  @override
  String get uxSupportSubjectFeedback => 'Feedback';

  @override
  String uxStrategyScoreWeight(String weight) {
    return 'weight $weight';
  }

  @override
  String get uxActionPriorityShort => 'prio';

  @override
  String get uxErrorEmptyResponse => 'The service returned no data. Please try again.';

  @override
  String get uxErrorNotFound => 'Item not found.';

  @override
  String get uxErrorFileTooLarge => 'File is too large to import. The limit is about 6 MB.';

  @override
  String get uxErrorFileUnreadable => 'Couldn\'t read the file.';

  @override
  String get uxErrorFileTimeout => 'Timed out while processing the file. Please try again.';

  @override
  String get uxErrorExtractionTimeout => 'The server took too long to extract the text. Please try again.';

  @override
  String get uxErrorExtractedTextTooShort => 'The extracted content is too short. The file may be protected or corrupted — try copying and pasting the text manually.';

  @override
  String get uxErrorGoogleNotConfigured => 'Google sign-in isn\'t configured in this environment.';

  @override
  String get uxErrorGoogleCredentials => 'Couldn\'t obtain Google credentials.';

  @override
  String get uxErrorSignUpFailed => 'Sign-up failed. Please try again.';

  @override
  String get uxAllocHoursNegative => 'Hours can\'t be negative.';

  @override
  String get uxAllocHoursTooHigh => 'Hours exceed the allowed limit.';

  @override
  String get uxAllocBudgetNegative => 'Budget can\'t be negative.';

  @override
  String get uxAllocBudgetTooHigh => 'Budget exceeds the allowed limit.';

  @override
  String uxOppAskIveMessage(String title, String score) {
    return 'Analyze the opportunity "$title" (score $score) and tell me how to make the most of it.';
  }

  @override
  String uxPersonaTrainingSummary(String title, String tone, String style) {
    return 'Trained with: $title. Tone: $tone. Style: $style.';
  }

  @override
  String get uxCalStatusIdea => 'Idea';

  @override
  String get uxCalStatusPlanned => 'Planned';

  @override
  String get uxCalStatusGenerated => 'Generated';

  @override
  String get uxCalStatusApproved => 'Approved';

  @override
  String get uxCalStatusReadyToPublish => 'Ready to Publish';

  @override
  String get uxCalStatusPublished => 'Published';

  @override
  String get uxCalStatusPublishFailed => 'Publishing Failed';

  @override
  String get uxCalStatusArchived => 'Archived';

  @override
  String get uxCalFormatShortPost => 'Short Post';

  @override
  String get uxCalFormatLongPost => 'Long Post';

  @override
  String get uxCalFormatCarousel => 'Carousel';

  @override
  String get uxCalFormatReels => 'Reels/Video';

  @override
  String get uxCalFormatEmail => 'Email';

  @override
  String get uxCalFormatSeoArticle => 'SEO Article';

  @override
  String get uxCalFormatSalesCta => 'Sales CTA';

  @override
  String get uxCalFormatThread => 'Thread/X';

  @override
  String get bootstrapStepStarting => 'Starting';

  @override
  String get bootstrapStepGeneratingOpportunities => 'Generating opportunities';

  @override
  String get bootstrapStepGeneratingActions => 'Generating actions';

  @override
  String get bootstrapStepGeneratingRevenuePlan => 'Generating revenue plan';

  @override
  String get bootstrapStepTrainingPersonas => 'Training personas';

  @override
  String bootstrapProgressProject(int current, int total) {
    return 'Project $current/$total';
  }

  @override
  String bootstrapProgressProjectStep(int current, int total, String step) {
    return 'Project $current/$total — $step';
  }

  @override
  String get ecoGateKnowledgeCoverage => 'Knowledge coverage';

  @override
  String get ecoGateLearningScore => 'Learning score';

  @override
  String get ecoGateIntelligenceProfile => 'Intelligence profile';

  @override
  String r16TranslatedFrom(String language) {
    return 'Automatically translated from $language';
  }

  @override
  String get r16ShowingOriginalContent => 'Showing content in its original language';

  @override
  String get r16ViewOriginal => 'View original';

  @override
  String get r16ViewTranslation => 'View translation';

  @override
  String uxfAdminSetRole(String role) {
    return '→ $role';
  }

  @override
  String get uxfAdminRoleBetaTester => 'Beta Tester';

  @override
  String get uxfAdminRoleAdmin => 'Admin';

  @override
  String uxfEcoAllocationScoreLine(String score, String emoji, String verdict) {
    return 'Ecosystem Score: $score/100  •  $emoji $verdict';
  }
}
