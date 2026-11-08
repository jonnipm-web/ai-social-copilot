import 'package:flutter/material.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/persona.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/persona_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class PersonasScreen extends ConsumerWidget {
  const PersonasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final personasAsync = ref.watch(personasProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, 
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.routeHome);
            }
          },
        ),
        title: Text(l10n.personasTitle),
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppConstants.routePersonaNew),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.personasNewPersona),
        backgroundColor: AppColors.accent,
      ),
      body: IvBody(child: personasAsync.when(
        loading: () => const IvLoadingSkeleton(),
        error: (e, _) => Center(
            child: Text(l10n.commonError,
                style: const TextStyle(color: AppColors.inkMuted))),
        data: (personas) {
          if (personas.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_pin_rounded,
                      size: 64, color: AppColors.inkSubtle),
                  const SizedBox(height: 12),
                  Text(l10n.personasEmpty,
                      style: const TextStyle(color: AppColors.inkMuted)),
                  const SizedBox(height: 4),
                  Text(l10n.personasEmptyHint,
                      style:
                          const TextStyle(color: AppColors.inkSubtle, fontSize: 12)),
                ],
              ),
            );
          }

          final globals = personas.where((p) => p.isGlobal).toList();
          final mine = personas.where((p) => !p.isGlobal).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (globals.isNotEmpty) ...[
                _SectionHeader(
                  label: l10n.personasGlobalSection,
                  icon: Icons.public_rounded,
                  color: AppColors.gold,
                ),
                const SizedBox(height: 8),
                IvCardGrid(minTileWidth: 340, gap: AppSpace.s3, children: [
                  for (final p in globals)
                    _PersonaCard(persona: p, isAdmin: isAdmin, ref: ref),
                ]),
                const SizedBox(height: 20),
              ],
              if (mine.isNotEmpty) ...[
                _SectionHeader(
                  label: l10n.personasMineSection,
                  icon: Icons.person_rounded,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 8),
                IvCardGrid(minTileWidth: 340, gap: AppSpace.s3, children: [
                  for (final p in mine)
                    _PersonaCard(persona: p, isAdmin: isAdmin, ref: ref),
                ]),
              ],
            ],
          );
        },
      )),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _PersonaCard extends ConsumerWidget {
  const _PersonaCard({
    required this.persona,
    required this.isAdmin,
    required this.ref,
  });
  final Persona persona;
  final bool isAdmin;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.ink.withOpacity(0.05),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: persona.isGlobal
              ? AppColors.gold.withOpacity(0.3)
              : AppColors.line,
        ),
      ),
      child: _PersonaRow(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withOpacity(0.2),
          child: Text(
            persona.name.isNotEmpty ? persona.name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          persona.name,
          style:
              const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (persona.niche != null)
              Text(persona.niche!,
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
            if (persona.voiceTone != null)
              Text(
                  AppLocalizations.of(context)!
                      .personasToneLabel(persona.voiceTone!),
                  style: const TextStyle(color: AppColors.inkSubtle, fontSize: 11)),
          ],
        ),
        trailing: (isAdmin || !persona.isGlobal)
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.inkSubtle, size: 20),
                color: AppColors.surface,
                onSelected: (value) async {
                  final l10n = AppLocalizations.of(context)!;
                  if (value == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.personasDeleteTitle),
                        content: Text(l10n.personasDeleteConfirm(persona.name)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.commonCancel)),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.commonDelete,
                                style: const TextStyle(color: AppColors.negative)),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(personaNotifierProvider.notifier)
                          .delete(persona.id);
                      ref.invalidate(personasProvider);
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'delete',
                      child: Text(AppLocalizations.of(context)!.commonDelete,
                          style: const TextStyle(color: AppColors.negative))),
                ],
              )
            : null,
      ),
    );
  }
}

/// ListTile reports unreliable intrinsic heights inside equal-height grid
/// rows (leading drifts to the bottom), so the card lays itself out.
class _PersonaRow extends StatelessWidget {
  const _PersonaRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s4, AppSpace.s3, AppSpace.s2, AppSpace.s3),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [title, const SizedBox(height: 2), subtitle],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
