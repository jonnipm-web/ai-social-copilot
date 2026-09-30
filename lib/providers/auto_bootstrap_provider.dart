import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/bootstrap_result.dart';
import '../data/models/project.dart';
import '../core/utils/language_utils.dart';
import '../data/services/auto_bootstrap_service.dart';
import '../l10n/app_localizations.dart';
import 'action_queue_provider.dart';
import 'knowledge_provider.dart';
import 'market_analysis_provider.dart';
import 'opportunity_lab_provider.dart';
import 'persona_provider.dart';
import 'persona_training_provider.dart';
import 'project_intelligence_provider.dart';
import 'project_provider.dart';

final _bootstrapService = AutoBootstrapService();

// ── Projects that need bootstrapping ──────────────────────────────────────
final projectsNeedingBootstrapProvider =
    FutureProvider.autoDispose<List<Project>>((ref) async {
  final projects      = await ref.watch(projectsProvider.future);
  final actions       = await ref.watch(actionQueueProvider.future);
  final labItems      = await ref.watch(opportunityLabProvider.future);
  final knowledgeList = await ref.watch(knowledgeItemsProvider.future);

  return _bootstrapService.detectNeedingBootstrap(
    projects:      projects,
    actions:       actions,
    labItems:      labItems,
    knowledgeItems: knowledgeList,
  );
});

// ── Bootstrap state ────────────────────────────────────────────────────────

class BootstrapState {
  final bool isRunning;
  final String? currentStep;
  final int currentProject;
  final int totalProjects;
  final BootstrapReport? report;
  final String? error;

  /// R16 — localized "Project x/y — step" text, computed by the notifier in
  /// the presentation language. Null only for states built outside it.
  final String? progressText;

  const BootstrapState({
    this.isRunning = false,
    this.currentStep,
    this.currentProject = 0,
    this.totalProjects = 0,
    this.report,
    this.error,
    this.progressText,
  });

  BootstrapState copyWith({
    bool? isRunning,
    String? currentStep,
    int? currentProject,
    int? totalProjects,
    BootstrapReport? report,
    String? error,
    String? progressText,
  }) =>
      BootstrapState(
        isRunning:       isRunning ?? this.isRunning,
        currentStep:     currentStep ?? this.currentStep,
        currentProject:  currentProject ?? this.currentProject,
        totalProjects:   totalProjects ?? this.totalProjects,
        report:          report ?? this.report,
        error:           error ?? this.error,
        progressText:    progressText ?? this.progressText,
      );

  bool get isDone => !isRunning && report != null;
  String get progressLabel {
    if (!isRunning) return '';
    return progressText ?? '$currentProject/$totalProjects${currentStep != null ? " — $currentStep" : ""}';
  }

  /// R16 — builds the localized progress text for [current]/[total] and an
  /// optional (already localized) [step].
  static String buildProgressText(AppLocalizations l10n, int current, int total, String? step) =>
      step == null
          ? l10n.bootstrapProgressProject(current, total)
          : l10n.bootstrapProgressProjectStep(current, total, step);
}

class AutoBootstrapNotifier extends StateNotifier<BootstrapState> {
  AutoBootstrapNotifier(this._ref) : super(const BootstrapState());

  final Ref _ref;

  Future<void> runAll() async {
    if (state.isRunning) return;

    try {
      // Gather needed data
      final projects       = await _ref.read(projectsProvider.future);
      final actions        = await _ref.read(actionQueueProvider.future);
      final labItems       = await _ref.read(opportunityLabProvider.future);
      final knowledgeItems = await _ref.read(knowledgeItemsProvider.future);
      final personas       = await _ref.read(personasProvider.future);
      final trainings      = await _ref.read(allPersonaTrainingsProvider.future);
      final analyses       = await _ref.read(marketAnalysesProvider.future);

      final toBootstrap = _bootstrapService.detectNeedingBootstrap(
        projects:       projects,
        actions:        actions,
        labItems:       labItems,
        knowledgeItems: knowledgeItems,
      );

      if (toBootstrap.isEmpty) return;

      // Fetch AI analyses for persona training
      final aiAnalyses = await _bootstrapService.fetchAnalysesWithTraining();

      state = state.copyWith(
        isRunning:      true,
        totalProjects:  toBootstrap.length,
        currentProject: 0,
        report:         null,
        error:          null,
      );

      final results = <BootstrapProjectResult>[];
      int totalPersonasTrained = 0;

      for (int i = 0; i < toBootstrap.length; i++) {
        final project = toBootstrap[i];
        final linkedAnalysis = analyses.where(
          (a) => a.id == project.marketAnalysisId,
        );

        // R16 — step labels and AI output follow the presentation language.
        final l10n = _ref.read(appL10nProvider);
        final outputLanguage = _ref.read(outputLanguageCodeProvider);
        final startingStep = l10n.bootstrapStepStarting;
        state = state.copyWith(
          currentProject: i + 1,
          currentStep:    startingStep,
          progressText:   BootstrapState.buildProgressText(l10n, i + 1, toBootstrap.length, startingStep),
        );

        final result = await _bootstrapService.bootstrapProject(
          project:          project,
          knowledgeItems:   knowledgeItems,
          analyses:         aiAnalyses,
          personas:         personas,
          existingTrainings: trainings,
          linkedAnalysis:   linkedAnalysis.isEmpty ? null : linkedAnalysis.first,
          outputLanguage:   outputLanguage,
          l10n:             l10n,
          onStep: (step) => state = state.copyWith(
            currentStep:  step,
            progressText: BootstrapState.buildProgressText(l10n, i + 1, toBootstrap.length, step),
          ),
        );

        results.add(result);
        totalPersonasTrained += result.personasTrained;
      }

      final report = BootstrapReport(
        projectResults:      results,
        personasTrainedTotal: totalPersonasTrained,
        completedAt:         DateTime.now(),
      );

      // Invalidate all affected providers so UI refreshes
      _ref.invalidate(projectsProvider);
      _ref.invalidate(actionQueueProvider);
      _ref.invalidate(opportunityLabProvider);
      _ref.invalidate(allRevenuePlansProvider);
      _ref.invalidate(allPersonaTrainingsProvider);
      _ref.invalidate(projectIntelligenceProfilesProvider);
      _ref.invalidate(personaLearningProfilesProvider);
      _ref.invalidate(projectsNeedingBootstrapProvider);

      state = state.copyWith(isRunning: false, currentStep: null, report: report);
    } catch (e) {
      state = state.copyWith(isRunning: false, currentStep: null, error: e.toString());
    }
  }

  void reset() => state = const BootstrapState();
}

final autoBootstrapNotifierProvider =
    StateNotifierProvider<AutoBootstrapNotifier, BootstrapState>((ref) {
  return AutoBootstrapNotifier(ref);
});
