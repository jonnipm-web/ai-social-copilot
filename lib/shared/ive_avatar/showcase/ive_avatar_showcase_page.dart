import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ive_avatar_configuration.dart';
import '../models/ive_avatar_context.dart';
import '../models/ive_avatar_lab_scope.dart';
import '../models/ive_avatar_state_v2.dart';
import '../theme/ive_avatar_tokens.dart';
import '../widgets/ive_avatar_assistant_button.dart';
import '../widgets/ive_avatar_card.dart';
import '../widgets/ive_avatar_compact.dart';
import '../widgets/ive_avatar_v2.dart';

// ── IveAvatarShowcasePage ─────────────────────────────────────────────────────
//
// Lab de avaliação do Avatar V2. Disponível apenas em builds debug ou na rota
// protegida /debug/ive-avatar-v2.
//
// Dois modos:
//   • Apresentação — visão limpa para avaliação do Product Owner
//   • Diagnóstico  — controles técnicos completos para desenvolvimento

class IveAvatarShowcasePage extends StatefulWidget {
  const IveAvatarShowcasePage({super.key});

  @override
  State<IveAvatarShowcasePage> createState() => _IveAvatarShowcasePageState();
}

class _IveAvatarShowcasePageState extends State<IveAvatarShowcasePage> {
  IveAvatarStateV2 _selectedState = IveAvatarStateV2.idle;
  bool _presentationMode = false;
  bool _reducedMotion = false;
  bool _showKeyboard = false;
  bool _darkMode = true;
  double _textScale = 1.0;
  double _screenWidth = 390;
  bool _interactive = true;
  bool _showLabel = true;
  String? _runningScenario;

  // ── Scenarios ───────────────────────────────────────────────────────────────

  static const _scenarios = <String, List<(IveAvatarStateV2, int)>>{
    'Consulta': [
      (IveAvatarStateV2.idle, 400),
      (IveAvatarStateV2.listening, 1200),
      (IveAvatarStateV2.thinking, 1500),
      (IveAvatarStateV2.generating, 2000),
      (IveAvatarStateV2.success, 1800),
      (IveAvatarStateV2.idle, 1000),
    ],
    'Análise': [
      (IveAvatarStateV2.idle, 400),
      (IveAvatarStateV2.thinking, 800),
      (IveAvatarStateV2.analyzing, 2000),
      (IveAvatarStateV2.researching, 1500),
      (IveAvatarStateV2.success, 1800),
      (IveAvatarStateV2.idle, 1000),
    ],
    'Erro': [
      (IveAvatarStateV2.idle, 400),
      (IveAvatarStateV2.listening, 800),
      (IveAvatarStateV2.analyzing, 1200),
      (IveAvatarStateV2.error, 2000),
      (IveAvatarStateV2.idle, 1000),
    ],
  };

  Future<void> _runScenario(String name) async {
    if (_runningScenario != null) return;
    final sequence = _scenarios[name];
    if (sequence == null) return;

    if (mounted) setState(() => _runningScenario = name);

    for (final (state, delayMs) in sequence) {
      if (!mounted) return;
      setState(() => _selectedState = state);
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    if (mounted) setState(() => _runningScenario = null);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = _darkMode
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return Theme(
      data: theme,
      child: IveAvatarLabScope(
        presentationMode: _presentationMode,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _presentationMode
                  ? 'IVE Avatar V2 — Apresentação'
                  : 'IVE Avatar V2 — Diagnóstico',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            backgroundColor: IveAvatarTokens.backgroundDark,
            foregroundColor: Colors.white,
            actions: [
              // Mode toggle
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton.icon(
                  icon: Icon(
                    _presentationMode
                        ? Icons.settings_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _presentationMode ? 'Diagnóstico' : 'Apresentação',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6C63FF)),
                  onPressed: () =>
                      setState(() => _presentationMode = !_presentationMode),
                ),
              ),
              IconButton(
                icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode,
                    size: 18),
                tooltip: 'Alternar tema',
                onPressed: () => setState(() => _darkMode = !_darkMode),
              ),
            ],
          ),
          backgroundColor:
              _darkMode ? IveAvatarTokens.backgroundDark : Colors.grey[100],
          body: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(_textScale),
              disableAnimations: _reducedMotion,
            ),
            child: _presentationMode
                ? _buildPresentationBody()
                : _buildDiagnosticBody(),
          ),
        ),
      ),
    );
  }

  // ── MODO APRESENTAÇÃO ────────────────────────────────────────────────────────

  Widget _buildPresentationBody() {
    final config = IveAvatarStateConfigV2.forState(_selectedState);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Identity header
              _IdentityHeader(selectedState: _selectedState),
              const SizedBox(height: 40),

              // Large avatar
              IveAvatarV2(
                overrideState: _selectedState,
                overrideContext: IveAvatarContext(
                  isAuthenticated: true,
                  routeName: '/showcase',
                  title: 'IVE',
                  currentTask: config.fallbackLabel,
                ),
                configuration: IveAvatarConfiguration.full.copyWith(
                  size: IveAvatarTokens.sizeFull,
                  showLabel: true,
                  interactive: _interactive,
                ),
                onTap: _interactive
                    ? () => _showSnack('IVE — ${config.fallbackLabel}')
                    : null,
              ),
              const SizedBox(height: 40),

              // Scenario simulation
              _ScenarioSection(
                running: _runningScenario,
                onRun: _runScenario,
              ),
              const SizedBox(height: 40),

              // State selector by family
              _PresentationFamilySelector(
                selected: _selectedState,
                onTap: (s) => setState(() => _selectedState = s),
              ),
              const SizedBox(height: 48),

              // Card demo
              _SectionLabel('MODO CARD'),
              const SizedBox(height: 12),
              IveAvatarCard(
                state: _selectedState,
                context: IveAvatarContext(
                  isAuthenticated: true,
                  routeName: '/showcase',
                  title: 'Business OS',
                  currentTask: config.fallbackLabel,
                  hasUnreadInsight:
                      _selectedState == IveAvatarStateV2.attention,
                ),
                onTap: _interactive ? () => _showSnack('Card tapped') : null,
              ),
              const SizedBox(height: 32),

              // Compact sizes
              _SectionLabel('TAMANHOS'),
              const SizedBox(height: 12),
              _AllSizesRow(
                state: _selectedState,
                interactive: _interactive,
                onTap: () => _showSnack('Compact tapped'),
              ),
              const SizedBox(height: 32),

              // Assistant button
              _SectionLabel('BOTÃO ASSISTENTE'),
              const SizedBox(height: 12),
              IveAvatarAssistantButton(
                state: _selectedState,
                hasNotification: _selectedState == IveAvatarStateV2.attention,
                onTap:
                    _interactive ? () => _showSnack('Assistente tapped') : null,
                margin: EdgeInsets.zero,
              ),
              const SizedBox(height: 48),

              // Footer
              Text(
                'Avatar V2 — Lab Preview · ${IveAvatarStateV2.values.length} estados · ${kIveStateFamilies.length} famílias',
                style: const TextStyle(color: Colors.white24, fontSize: 10),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── MODO DIAGNÓSTICO ─────────────────────────────────────────────────────────

  Widget _buildDiagnosticBody() {
    return Row(
      children: [
        // Controls panel
        SizedBox(
          width: 220,
          child: _ControlsPanel(
            selectedState: _selectedState,
            reducedMotion: _reducedMotion,
            showKeyboard: _showKeyboard,
            textScale: _textScale,
            screenWidth: _screenWidth,
            interactive: _interactive,
            showLabel: _showLabel,
            runningScenario: _runningScenario,
            onStateChanged: (s) => setState(() => _selectedState = s),
            onReducedMotion: (v) => setState(() => _reducedMotion = v),
            onShowKeyboard: (v) => setState(() => _showKeyboard = v),
            onTextScale: (v) => setState(() => _textScale = v),
            onScreenWidth: (v) => setState(() => _screenWidth = v),
            onInteractive: (v) => setState(() => _interactive = v),
            onShowLabel: (v) => setState(() => _showLabel = v),
            onRunScenario: _runScenario,
          ),
        ),
        // Preview area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth < 300
                          ? constraints.maxWidth
                          : _screenWidth.clamp(300.0, constraints.maxWidth),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('ESTADO: ${_selectedState.name}'),
                        const SizedBox(height: 16),

                        // Full mode
                        _SectionLabel('MODO FULL'),
                        const SizedBox(height: 12),
                        Center(
                          child: IveAvatarV2(
                            overrideState: _selectedState,
                            overrideContext: IveAvatarContext(
                              isAuthenticated: true,
                              routeName: '/showcase',
                              title: 'IVE',
                              currentTask: _selectedState.name,
                            ),
                            configuration: IveAvatarConfiguration.full.copyWith(
                              showLabel: _showLabel,
                              interactive: _interactive,
                            ),
                            onTap: _interactive
                                ? () => _showSnack('IVE tapped (full)')
                                : null,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Card mode
                        _SectionLabel('MODO CARD'),
                        const SizedBox(height: 12),
                        IveAvatarCard(
                          state: _selectedState,
                          context: IveAvatarContext(
                            isAuthenticated: true,
                            routeName: '/showcase',
                            title: 'Business OS',
                            currentTask: _selectedState.name,
                            hasUnreadInsight:
                                _selectedState == IveAvatarStateV2.attention,
                          ),
                          onTap: _interactive
                              ? () => _showSnack('IVE tapped (card)')
                              : null,
                        ),
                        const SizedBox(height: 32),

                        // Compact sizes
                        _SectionLabel('MODO COMPACT — TAMANHOS'),
                        const SizedBox(height: 12),
                        _AllSizesRow(
                          state: _selectedState,
                          interactive: _interactive,
                          onTap: () => _showSnack('IVE tapped (compact)'),
                        ),
                        const SizedBox(height: 32),

                        // All states by family
                        _SectionLabel('TODOS OS ESTADOS POR FAMÍLIA'),
                        const SizedBox(height: 12),
                        _FamilyStatesGrid(
                          selected: _selectedState,
                          interactive: _interactive,
                          onTap: (s) {
                            setState(() => _selectedState = s);
                            _showSnack('Estado: ${s.name}');
                          },
                        ),
                        const SizedBox(height: 32),

                        // Assistant button
                        _SectionLabel('BOTÃO ASSISTENTE'),
                        const SizedBox(height: 12),
                        Center(
                          child: IveAvatarAssistantButton(
                            state: _selectedState,
                            hasNotification:
                                _selectedState == IveAvatarStateV2.attention,
                            onTap: _interactive
                                ? () => _showSnack('IVE tapped (assistant)')
                                : null,
                            margin: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Floating positions demo
                        _SectionLabel('POSICIONAMENTO FLUTUANTE'),
                        const SizedBox(height: 12),
                        _FloatingPositionDemo(state: _selectedState),
                        const SizedBox(height: 32),

                        // Keyboard simulation
                        if (_showKeyboard)
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                '⌨  Teclado simulado (200dp)',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }
}

// ── Identity header (Presentation Mode) ──────────────────────────────────────

class _IdentityHeader extends StatelessWidget {
  final IveAvatarStateV2 selectedState;
  const _IdentityHeader({required this.selectedState});

  @override
  Widget build(BuildContext context) {
    final config = IveAvatarStateConfigV2.forState(selectedState);
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            config.fallbackLabel,
            key: ValueKey(selectedState),
            style: TextStyle(
              color: config.ringColor,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Assistente de Inteligência Contextual',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Scenario simulation section ───────────────────────────────────────────────

class _ScenarioSection extends StatelessWidget {
  final String? running;
  final Future<void> Function(String) onRun;

  const _ScenarioSection({required this.running, required this.onRun});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('SIMULAR CENÁRIO'),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['Consulta', 'Análise', 'Erro'].map((name) {
            final isRunning = running == name;
            final isDisabled = running != null && !isRunning;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: OutlinedButton.icon(
                icon: isRunning
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFF6C63FF),
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 14),
                label: Text(name, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isRunning ? const Color(0xFF6C63FF) : Colors.white60,
                  side: BorderSide(
                    color: isRunning ? const Color(0xFF6C63FF) : Colors.white24,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: isDisabled ? null : () => onRun(name),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Presentation family selector ──────────────────────────────────────────────

class _PresentationFamilySelector extends StatelessWidget {
  final IveAvatarStateV2 selected;
  final ValueChanged<IveAvatarStateV2> onTap;

  const _PresentationFamilySelector({
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('SELECIONAR ESTADO'),
        const SizedBox(height: 14),
        ...kIveStateFamilies.map((family) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: family.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        family.label.toUpperCase(),
                        style: TextStyle(
                          color: family.color.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: family.states.map((s) {
                      final cfg = IveAvatarStateConfigV2.forState(s);
                      final isSel = s == selected;
                      return GestureDetector(
                        onTap: () => onTap(s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? cfg.ringColor.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSel ? cfg.ringColor : Colors.white12,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IveAvatarCompact(
                                state: s,
                                size: 28,
                                showRing: true,
                                interactive: false,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                cfg.fallbackLabel,
                                style: TextStyle(
                                  color: isSel ? cfg.ringColor : Colors.white60,
                                  fontSize: 12,
                                  fontWeight: isSel
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ── Controls panel (Diagnostic Mode) ─────────────────────────────────────────

class _ControlsPanel extends StatelessWidget {
  final IveAvatarStateV2 selectedState;
  final bool reducedMotion;
  final bool showKeyboard;
  final double textScale;
  final double screenWidth;
  final bool interactive;
  final bool showLabel;
  final String? runningScenario;
  final ValueChanged<IveAvatarStateV2> onStateChanged;
  final ValueChanged<bool> onReducedMotion;
  final ValueChanged<bool> onShowKeyboard;
  final ValueChanged<double> onTextScale;
  final ValueChanged<double> onScreenWidth;
  final ValueChanged<bool> onInteractive;
  final ValueChanged<bool> onShowLabel;
  final Future<void> Function(String) onRunScenario;

  const _ControlsPanel({
    required this.selectedState,
    required this.reducedMotion,
    required this.showKeyboard,
    required this.textScale,
    required this.screenWidth,
    required this.interactive,
    required this.showLabel,
    required this.runningScenario,
    required this.onStateChanged,
    required this.onReducedMotion,
    required this.onShowKeyboard,
    required this.onTextScale,
    required this.onScreenWidth,
    required this.onInteractive,
    required this.onShowLabel,
    required this.onRunScenario,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D1C),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ListView(
        children: [
          const _PanelLabel('CONTROLES'),
          const SizedBox(height: 12),

          // State selector by family
          ...kIveStateFamilies.map((family) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            color: family.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        family.label,
                        style: TextStyle(
                          color: family.color.withValues(alpha: 0.7),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...family.states.map(
                    (s) => _StateChip(
                      state: s,
                      selected: s == selectedState,
                      onTap: () => onStateChanged(s),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              )),

          const Divider(height: 24, color: Colors.white12),

          // Scenarios
          const _PanelLabel('CENÁRIOS'),
          const SizedBox(height: 8),
          ...['Consulta', 'Análise', 'Erro'].map((name) {
            final isRunning = runningScenario == name;
            final isDisabled = runningScenario != null && !isRunning;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: OutlinedButton.icon(
                icon: isRunning
                    ? const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFF6C63FF),
                        ),
                      )
                    : const Icon(Icons.play_arrow, size: 12),
                label: Text(name, style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isRunning ? const Color(0xFF6C63FF) : Colors.white60,
                  side: BorderSide(
                    color: isRunning ? const Color(0xFF6C63FF) : Colors.white24,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: isDisabled ? null : () => onRunScenario(name),
              ),
            );
          }),

          const Divider(height: 24, color: Colors.white12),

          // Toggles
          _Switch('Reduced Motion', reducedMotion, onReducedMotion),
          _Switch('Teclado aberto', showKeyboard, onShowKeyboard),
          _Switch('Interativo', interactive, onInteractive),
          _Switch('Mostrar label', showLabel, onShowLabel),

          const Divider(height: 24, color: Colors.white12),

          const _PanelLabel('TEXT SCALE'),
          Slider(
            value: textScale,
            min: 0.8,
            max: 2.0,
            divisions: 12,
            label: textScale.toStringAsFixed(1),
            onChanged: onTextScale,
            activeColor: const Color(0xFF6C63FF),
          ),
          const _PanelLabel('LARGURA (DP)'),
          Slider(
            value: screenWidth,
            min: 300,
            max: 900,
            divisions: 30,
            label: screenWidth.toInt().toString(),
            onChanged: onScreenWidth,
            activeColor: const Color(0xFF6C63FF),
          ),
        ],
      ),
    );
  }
}

// ── Family states grid (Diagnostic Mode) ─────────────────────────────────────

class _FamilyStatesGrid extends StatelessWidget {
  final IveAvatarStateV2 selected;
  final bool interactive;
  final ValueChanged<IveAvatarStateV2> onTap;

  const _FamilyStatesGrid({
    required this.selected,
    required this.interactive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: kIveStateFamilies.map((family) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: family.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    family.label.toUpperCase(),
                    style: TextStyle(
                      color: family.color.withValues(alpha: 0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: family.states.map((s) {
                  final label =
                      IveAvatarStateConfigV2.forState(s).fallbackLabel;
                  final isSelected = s == selected;
                  return GestureDetector(
                    onTap: interactive ? () => onTap(s) : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IveAvatarCompact(
                          state: s,
                          size: IveAvatarTokens.sizeSmall,
                          interactive: false,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? IveAvatarStateConfigV2.forState(s).ringColor
                                : Colors.white38,
                            fontSize: 8.5,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Floating position demo ────────────────────────────────────────────────────

class _FloatingPositionDemo extends StatelessWidget {
  final IveAvatarStateV2 state;
  const _FloatingPositionDemo({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhoneFrame(
            label: 'Inferior direito',
            child: Stack(
              children: [
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: IveAvatarAssistantButton(
                    state: state,
                    size: 32,
                    margin: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _PhoneFrame(
            label: 'Inferior esquerdo',
            child: Stack(
              children: [
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: IveAvatarAssistantButton(
                    state: state,
                    size: 32,
                    margin: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _PhoneFrame(
            label: 'App Bar',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 28,
                  color: const Color(0xFF1A1A2E),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'IVE',
                          style: TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                      ),
                      IveAvatarCompact(
                        state: state,
                        size: 22,
                        showRing: true,
                        interactive: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _PhoneFrame(
            label: 'Card Header',
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IveAvatarCard(
                state: state,
                context: IveAvatarContext(
                  isAuthenticated: true,
                  routeName: '/showcase',
                  title: 'Projeto',
                  currentTask:
                      IveAvatarStateConfigV2.forState(state).fallbackLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  final String label;
  final Widget child;
  const _PhoneFrame({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0B1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A4A), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Container(
                height: 14,
                color: const Color(0xFF0D0D1C),
              ),
              Positioned.fill(
                top: 14,
                child: child,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 9),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── All sizes row ─────────────────────────────────────────────────────────────

class _AllSizesRow extends StatelessWidget {
  final IveAvatarStateV2 state;
  final bool interactive;
  final VoidCallback onTap;

  const _AllSizesRow({
    required this.state,
    required this.interactive,
    required this.onTap,
  });

  static const _sizes = [
    (IveAvatarTokens.sizeCompact, 'xs'),
    (IveAvatarTokens.sizeSmall, 'sm'),
    (IveAvatarTokens.sizeStandard, 'md'),
    (IveAvatarTokens.sizeLarge, 'lg'),
    (IveAvatarTokens.sizeChat, 'xl'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _sizes.map((pair) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IveAvatarCompact(
                  state: state,
                  size: pair.$1,
                  interactive: interactive,
                  onTap: interactive ? onTap : null,
                ),
                const SizedBox(height: 6),
                Text(
                  pair.$2,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _StateChip extends StatelessWidget {
  final IveAvatarStateV2 state;
  final bool selected;
  final VoidCallback onTap;

  const _StateChip({
    required this.state,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = IveAvatarStateConfigV2.forState(state).ringColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? color : Colors.white12,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                IveAvatarStateConfigV2.forState(state).fallbackLabel,
                style: TextStyle(
                  color: selected ? color : Colors.white54,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Switch(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF6C63FF),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF6C63FF),
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  final String text;
  const _PanelLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF6C63FF),
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }
}
