import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import '../../../data/models/advisor_profile.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/advisor_provider.dart';

// R16 — the persisted advisor role/style values (AdvisorProfile.roleOptions
// / styleOptions) are canonical PT codes; only their DISPLAY is localized.
String advisorRoleLabel(String role, AppLocalizations l10n) {
  switch (role) {
    case 'Estratégia':  return l10n.uxAdvisorRoleStrategy;
    case 'Marketing':   return l10n.uxAdvisorRoleMarketing;
    case 'SEO':         return 'SEO';
    case 'Monetização': return l10n.uxAdvisorRoleMonetization;
    case 'Negócios':    return l10n.uxAdvisorRoleBusiness;
    case 'Geral':       return l10n.uxAdvisorRoleGeneral;
    default:            return role;
  }
}

String advisorStyleLabel(String style, AppLocalizations l10n) {
  switch (style) {
    case 'Executivo':  return l10n.uxAdvisorStyleExecutive;
    case 'Analítico':  return l10n.uxAdvisorStyleAnalytical;
    case 'Professor':  return l10n.uxAdvisorStyleTeacher;
    case 'Mentor':     return l10n.uxAdvisorStyleMentor;
    case 'Direto':     return l10n.uxAdvisorStyleDirect;
    default:           return style;
  }
}

String advisorStyleDescription(String style, AppLocalizations l10n) {
  switch (style) {
    case 'Executivo':  return l10n.uxAdvisorStyleExecutiveDesc;
    case 'Analítico':  return l10n.uxAdvisorStyleAnalyticalDesc;
    case 'Professor':  return l10n.uxAdvisorStyleTeacherDesc;
    case 'Mentor':     return l10n.uxAdvisorStyleMentorDesc;
    case 'Direto':     return l10n.uxAdvisorStyleDirectDesc;
    default:           return '';
  }
}

// ── Colors ───────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F0F1A);
const _kCard    = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGold    = Color(0xFFFFD700);

// ════════════════════════════════════════════════════════════════════════════
// Advisor Onboarding Screen (M2)
// ════════════════════════════════════════════════════════════════════════════
class AdvisorOnboardingScreen extends ConsumerStatefulWidget {
  const AdvisorOnboardingScreen({super.key});

  @override
  ConsumerState<AdvisorOnboardingScreen> createState() =>
      _AdvisorOnboardingState();
}

class _AdvisorOnboardingState extends ConsumerState<AdvisorOnboardingScreen> {
  int _step = 0;
  String _name  = AdvisorProfile.nameOptions.first;
  String _role  = AdvisorProfile.roleOptions.last;
  String _style = AdvisorProfile.styleOptions.first;
  String _customName = '';

  bool _useCustomName = false;
  bool _saving = false;

  String get _effectiveName => _useCustomName ? _customName.trim() : _name;

  Future<void> _save() async {
    if (_effectiveName.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(advisorNotifierProvider.notifier).save(
            advisorName:  _effectiveName,
            advisorRole:  _role,
            advisorStyle: _style,
          );
      if (mounted) context.go(AppConstants.routeExecutiveDashboard);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.iveChatErrorPrefix(extractErrorMessage(e, AppLocalizations.of(context)!))), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Progress indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: i == _step ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= _step ? _kPrimary : Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 40),
              Expanded(child: _buildStep()),
              const SizedBox(height: 24),
              _buildNavButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepName(
          selected:     _name,
          useCustom:    _useCustomName,
          customName:   _customName,
          onSelect:     (v) => setState(() { _name = v; _useCustomName = false; }),
          onCustom:     (v) => setState(() { _customName = v; _useCustomName = true; }),
        );
      case 1:
        return _StepRole(
          selected: _role,
          onSelect: (v) => setState(() => _role = v),
        );
      case 2:
        return _StepStyle(
          selected: _style,
          onSelect: (v) => setState(() => _style = v),
          name:     _effectiveName,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavButtons() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        if (_step > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _step--),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l10n.commonBack),
            ),
          ),
        if (_step > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _saving
                ? null
                : () {
                    if (_step < 2) {
                      setState(() => _step++);
                    } else {
                      _save();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kPrimary.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(_step < 2 ? l10n.uxAdvisorNext : l10n.uxAdvisorActivate,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

// ── Step: Choose Name ────────────────────────────────────────────────────────
class _StepName extends StatelessWidget {
  const _StepName({
    required this.selected,
    required this.useCustom,
    required this.customName,
    required this.onSelect,
    required this.onCustom,
  });
  final String selected;
  final bool useCustom;
  final String customName;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onCustom;

  static const _avatars = {
    'Atlas':  '🌐',
    'Iris': '🔮',
    'Mentor': '🎓',
    'Nexus':  '⚡',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.uxAdvisorNameTitle,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.uxAdvisorNameSubtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 32),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.0,
          physics: const NeverScrollableScrollPhysics(),
          children: AdvisorProfile.nameOptions.map((name) {
            final isSelected = selected == name && !useCustom;
            return GestureDetector(
              onTap: () => onSelect(name),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kPrimary.withOpacity(0.2)
                      : _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _kPrimary : Colors.white12,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_avatars[name] ?? '🤖', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Text(name,
                        style: TextStyle(
                          color: isSelected ? _kPrimary : Colors.white70,
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: useCustom ? _kGold : Colors.white12,
              width: useCustom ? 2 : 1,
            ),
          ),
          child: TextField(
            onChanged: onCustom,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l10n.uxAdvisorCustomNameHint,
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.edit_rounded, color: Colors.white38, size: 18),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step: Choose Role ─────────────────────────────────────────────────────────
class _StepRole extends StatelessWidget {
  const _StepRole({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  static const _icons = {
    'Estratégia':  Icons.flag_rounded,
    'Marketing':   Icons.campaign_rounded,
    'SEO':         Icons.search_rounded,
    'Monetização': Icons.attach_money_rounded,
    'Negócios':    Icons.business_rounded,
    'Geral':       Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.uxAdvisorRoleTitle,
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.uxAdvisorRoleSubtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView(
            children: AdvisorProfile.roleOptions.map((role) {
              final isSelected = selected == role;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => onSelect(role),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kPrimary.withOpacity(0.15)
                          : _kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _kPrimary : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _icons[role] ?? Icons.auto_awesome_rounded,
                          color: isSelected ? _kPrimary : Colors.white38,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          advisorRoleLabel(role, l10n),
                          style: TextStyle(
                            color: isSelected ? _kPrimary : Colors.white70,
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (isSelected) ...[
                          const Spacer(),
                          const Icon(Icons.check_circle_rounded,
                              color: _kPrimary, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Step: Choose Style ────────────────────────────────────────────────────────
class _StepStyle extends StatelessWidget {
  const _StepStyle({
    required this.selected,
    required this.onSelect,
    required this.name,
  });
  final String selected;
  final ValueChanged<String> onSelect;
  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.uxAdvisorStyleTitle(name),
          style: const TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.uxAdvisorStyleSubtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: ListView(
            children: AdvisorProfile.styleOptions.map((style) {
              final isSelected = selected == style;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => onSelect(style),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kGold.withOpacity(0.1)
                          : _kCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _kGold : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              advisorStyleLabel(style, l10n),
                              style: TextStyle(
                                color: isSelected ? _kGold : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isSelected) ...[
                              const Spacer(),
                              const Icon(Icons.check_circle_rounded,
                                  color: _kGold, size: 20),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          advisorStyleDescription(style, l10n),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
