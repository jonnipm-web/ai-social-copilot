import 'package:flutter/material.dart';

import '../models/ive_avatar_configuration.dart';
import '../models/ive_avatar_context.dart';
import '../models/ive_avatar_state_v2.dart';
import '../theme/ive_avatar_tokens.dart';
import '../widgets/ive_avatar_assistant_button.dart';
import '../widgets/ive_avatar_card.dart';
import '../widgets/ive_avatar_compact.dart';
import '../widgets/ive_avatar_v2.dart';

// ── IveAvatarShowcasePage ─────────────────────────────────────────────────────
//
// Internal development preview. Available only on debug builds or the
// protected route /debug/ive-avatar-v2.
//
// Allows visualising all states, sizes, placements, motion policies,
// text scale, simulated keyboard, and interactive modes — without a backend.

class IveAvatarShowcasePage extends StatefulWidget {
  const IveAvatarShowcasePage({super.key});

  @override
  State<IveAvatarShowcasePage> createState() => _IveAvatarShowcasePageState();
}

class _IveAvatarShowcasePageState extends State<IveAvatarShowcasePage> {
  IveAvatarStateV2 _selectedState = IveAvatarStateV2.idle;
  bool             _reducedMotion = false;
  bool             _showKeyboard  = false;
  bool             _darkMode      = true;
  double           _textScale     = 1.0;
  double           _screenWidth   = 390;
  bool             _interactive   = true;
  bool             _showLabel     = true;

  @override
  Widget build(BuildContext context) {
    final theme = _darkMode ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'IVE Avatar V2 — Showcase',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          backgroundColor: IveAvatarTokens.backgroundDark,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
              tooltip: 'Alternar tema',
              onPressed: () => setState(() => _darkMode = !_darkMode),
            ),
          ],
        ),
        backgroundColor: _darkMode
            ? IveAvatarTokens.backgroundDark
            : Colors.grey[100],
        body: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler:          TextScaler.linear(_textScale),
            disableAnimations:   _reducedMotion,
          ),
          child: Row(
            children: [
              // ── Controls panel ─────────────────────────────────────────
              SizedBox(
                width: 220,
                child: _ControlsPanel(
                  selectedState:  _selectedState,
                  reducedMotion:  _reducedMotion,
                  showKeyboard:   _showKeyboard,
                  textScale:      _textScale,
                  screenWidth:    _screenWidth,
                  interactive:    _interactive,
                  showLabel:      _showLabel,
                  onStateChanged: (s)  => setState(() => _selectedState = s),
                  onReducedMotion: (v) => setState(() => _reducedMotion  = v),
                  onShowKeyboard:  (v) => setState(() => _showKeyboard   = v),
                  onTextScale:     (v) => setState(() => _textScale      = v),
                  onScreenWidth:   (v) => setState(() => _screenWidth    = v),
                  onInteractive:   (v) => setState(() => _interactive    = v),
                  onShowLabel:     (v) => setState(() => _showLabel      = v),
                ),
              ),
              // ── Preview area ───────────────────────────────────────────
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _screenWidth.clamp(
                              300, constraints.maxWidth,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader('Estado: ${_selectedState.name}'),
                              const SizedBox(height: 16),

                              // Full mode
                              _SectionHeader('Modo Full'),
                              const SizedBox(height: 12),
                              Center(
                                child: IveAvatarV2(
                                  overrideState: _selectedState,
                                  overrideContext: IveAvatarContext(
                                    isAuthenticated: true,
                                    routeName:      '/showcase',
                                    title:          'IVE',
                                    currentTask:    _selectedState.name,
                                  ),
                                  configuration: IveAvatarConfiguration.full.copyWith(
                                    showLabel:   _showLabel,
                                    interactive: _interactive,
                                  ),
                                  onTap: _interactive
                                      ? () => _showSnack('IVE tapped (full)')
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Card mode
                              _SectionHeader('Modo Card'),
                              const SizedBox(height: 12),
                              IveAvatarCard(
                                state:   _selectedState,
                                context: IveAvatarContext(
                                  isAuthenticated: true,
                                  routeName:       '/showcase',
                                  title:           'Business OS',
                                  currentTask:     _selectedState.name,
                                  hasUnreadInsight: _selectedState == IveAvatarStateV2.attention,
                                ),
                                onTap: _interactive
                                    ? () => _showSnack('IVE tapped (card)')
                                    : null,
                              ),
                              const SizedBox(height: 32),

                              // Compact mode — all sizes
                              _SectionHeader('Modo Compact — Tamanhos'),
                              const SizedBox(height: 12),
                              _AllSizesRow(
                                state:       _selectedState,
                                interactive: _interactive,
                                onTap: () => _showSnack('IVE tapped (compact)'),
                              ),
                              const SizedBox(height: 32),

                              // All states grid
                              _SectionHeader('Todos os Estados'),
                              const SizedBox(height: 12),
                              _AllStatesGrid(
                                interactive: _interactive,
                                onTap: (s) {
                                  setState(() => _selectedState = s);
                                  _showSnack('Estado: ${s.name}');
                                },
                              ),
                              const SizedBox(height: 32),

                              // Assistant button
                              _SectionHeader('Botão Assistente'),
                              const SizedBox(height: 12),
                              Center(
                                child: IveAvatarAssistantButton(
                                  state:           _selectedState,
                                  hasNotification: _selectedState == IveAvatarStateV2.attention,
                                  onTap: _interactive
                                      ? () => _showSnack('IVE tapped (assistant)')
                                      : null,
                                  margin: EdgeInsets.zero,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Keyboard simulation indicator
                              if (_showKeyboard)
                                Container(
                                  height:           200,
                                  decoration:       BoxDecoration(
                                    color:         Colors.grey.withValues(alpha: 0.15),
                                    borderRadius:  BorderRadius.circular(12),
                                    border:        Border.all(
                                      color: Colors.grey.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '⌨  Teclado simulado (200dp)',
                                      style: TextStyle(
                                        color:    Colors.white54,
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
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:  Text(msg),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

// ── Controls panel ────────────────────────────────────────────────────────────

class _ControlsPanel extends StatelessWidget {
  final IveAvatarStateV2      selectedState;
  final bool                  reducedMotion;
  final bool                  showKeyboard;
  final double                textScale;
  final double                screenWidth;
  final bool                  interactive;
  final bool                  showLabel;
  final ValueChanged<IveAvatarStateV2> onStateChanged;
  final ValueChanged<bool>             onReducedMotion;
  final ValueChanged<bool>             onShowKeyboard;
  final ValueChanged<double>           onTextScale;
  final ValueChanged<double>           onScreenWidth;
  final ValueChanged<bool>             onInteractive;
  final ValueChanged<bool>             onShowLabel;

  const _ControlsPanel({
    required this.selectedState,
    required this.reducedMotion,
    required this.showKeyboard,
    required this.textScale,
    required this.screenWidth,
    required this.interactive,
    required this.showLabel,
    required this.onStateChanged,
    required this.onReducedMotion,
    required this.onShowKeyboard,
    required this.onTextScale,
    required this.onScreenWidth,
    required this.onInteractive,
    required this.onShowLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D1C),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: ListView(
        children: [
          const Text(
            'CONTROLES',
            style: TextStyle(
              color:         Color(0xFF6C63FF),
              fontSize:      10,
              fontWeight:    FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text('Estado', style: _labelStyle),
          const SizedBox(height: 6),
          ...IveAvatarStateV2.values.map(
            (s) => _StateChip(
              state:    s,
              selected: s == selectedState,
              onTap:    () => onStateChanged(s),
            ),
          ),
          const Divider(height: 24, color: Colors.white12),
          _Switch('Reduced Motion', reducedMotion, onReducedMotion),
          _Switch('Teclado aberto', showKeyboard,  onShowKeyboard),
          _Switch('Interativo',     interactive,   onInteractive),
          _Switch('Mostrar label',  showLabel,     onShowLabel),
          const Divider(height: 24, color: Colors.white12),
          const Text('Text scale', style: _labelStyle),
          Slider(
            value:    textScale,
            min:      0.8,
            max:      2.0,
            divisions: 12,
            label:    textScale.toStringAsFixed(1),
            onChanged: onTextScale,
            activeColor: const Color(0xFF6C63FF),
          ),
          const Text('Largura (dp)', style: _labelStyle),
          Slider(
            value:    screenWidth,
            min:      300,
            max:      900,
            divisions: 30,
            label:    screenWidth.toInt().toString(),
            onChanged: onScreenWidth,
            activeColor: const Color(0xFF6C63FF),
          ),
        ],
      ),
    );
  }

  static const _labelStyle = TextStyle(
    color:    Colors.white54,
    fontSize: 11,
  );
}

class _StateChip extends StatelessWidget {
  final IveAvatarStateV2 state;
  final bool             selected;
  final VoidCallback     onTap;

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
        margin:   const EdgeInsets.only(bottom: 4),
        padding:  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(
            color: selected ? color : Colors.white12,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width:  6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              state.name,
              style: TextStyle(
                color:      selected ? color : Colors.white54,
                fontSize:   11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final String           label;
  final bool             value;
  final ValueChanged<bool> onChanged;

  const _Switch(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Switch(
          value:           value,
          onChanged:       onChanged,
          activeThumbColor: const Color(0xFF6C63FF),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color:         Color(0xFF6C63FF),
        fontSize:      11,
        fontWeight:    FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── All sizes row ─────────────────────────────────────────────────────────────

class _AllSizesRow extends StatelessWidget {
  final IveAvatarStateV2 state;
  final bool             interactive;
  final VoidCallback     onTap;

  const _AllSizesRow({
    required this.state,
    required this.interactive,
    required this.onTap,
  });

  static const _sizes = [
    (IveAvatarTokens.sizeCompact,  'xs'),
    (IveAvatarTokens.sizeSmall,    'sm'),
    (IveAvatarTokens.sizeStandard, 'md'),
    (IveAvatarTokens.sizeLarge,    'lg'),
    (IveAvatarTokens.sizeChat,     'xl'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _sizes.map((pair) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IveAvatarCompact(
              state:       state,
              size:        pair.$1,
              interactive: interactive,
              onTap:       interactive ? onTap : null,
            ),
            const SizedBox(height: 6),
            Text(
              pair.$2,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ── All states grid ───────────────────────────────────────────────────────────

class _AllStatesGrid extends StatelessWidget {
  final bool                  interactive;
  final ValueChanged<IveAvatarStateV2> onTap;

  const _AllStatesGrid({
    required this.interactive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount:   5,
      shrinkWrap:       true,
      physics:          const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing:  16,
      children: IveAvatarStateV2.values.map((s) {
        final label = IveAvatarStateConfigV2.forState(s).fallbackLabel;
        return ClipRect(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IveAvatarCompact(
                state:       s,
                size:        IveAvatarTokens.sizeSmall,
                interactive: interactive,
                onTap:       interactive ? () => onTap(s) : null,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 8.5),
                textAlign: TextAlign.center,
                overflow:  TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
