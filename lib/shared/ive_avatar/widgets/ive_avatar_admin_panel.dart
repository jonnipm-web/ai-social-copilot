import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../models/ive_avatar_state_v2.dart';
import '../providers/effective_avatar_version_provider.dart';
import '../providers/ive_avatar_provider_v2.dart';
import '../providers/ive_operational_state_provider.dart';

// ── IveAvatarAdminPanel ───────────────────────────────────────────────────────
//
// Admin/debug panel for controlling the IVE avatar version on this device.
// Visible only when kDebugMode == true or user has admin role.
// Does NOT modify the remote feature flag.

class IveAvatarAdminPanel extends ConsumerWidget {
  const IveAvatarAdminPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) {
      // In release, only render if admin role is confirmed.
      // Until role check is wired, panel is debug-only.
      return const SizedBox.shrink();
    }

    final localOverride = ref.watch(iveAvatarLocalOverrideProvider);
    final effectiveVer = ref.watch(effectiveIveAvatarVersionProvider);
    final remoteFlag = ref.watch(iveAvatarV2FlagProvider);
    final opState = ref.watch(iveOperationalStateProvider);
    final controllerState = ref.watch(iveAvatarV2Provider);

    return Card(
      color: const Color(0xFF12132A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2B55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.smart_toy_rounded,
                  color: Color(0xFF7B5CF6),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Avatar da IVE',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1F40),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Admin · Debug',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Status info
            _InfoRow(
              label: 'Versão ativa',
              value: _versionLabel(effectiveVer),
              valueColor: _versionColor(effectiveVer),
            ),
            _InfoRow(
              label: 'Flag remota (Supabase)',
              value: remoteFlag ? 'ativada' : 'desativada (padrão)',
              valueColor:
                  remoteFlag ? const Color(0xFF00E875) : Colors.white54,
            ),
            _InfoRow(
              label: 'Override local',
              value: _overrideLabel(localOverride),
              valueColor: localOverride != IveAvatarLocalOverride.automatic
                  ? const Color(0xFFFFB020)
                  : Colors.white54,
            ),
            _InfoRow(
              label: 'Estado operacional',
              value: opState.name,
              valueColor: Colors.white70,
            ),
            _InfoRow(
              label: 'Estado V2 provider',
              value: controllerState.avatarState.name,
              valueColor: Colors.white70,
            ),

            const Divider(color: Color(0xFF2A2B55), height: 24),

            // Override selector
            Text(
              'Override local (este dispositivo)',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            _OverrideButton(
              label: 'Automático',
              subtitle: 'Segue a feature flag remota',
              value: IveAvatarLocalOverride.automatic,
              current: localOverride,
              onTap: () => ref
                  .read(iveAvatarLocalOverrideProvider.notifier)
                  .set(IveAvatarLocalOverride.automatic),
            ),
            _OverrideButton(
              label: 'Avatar Legado',
              subtitle: 'Força widget legado (IveOverlay)',
              value: IveAvatarLocalOverride.legacy,
              current: localOverride,
              onTap: () => ref
                  .read(iveAvatarLocalOverrideProvider.notifier)
                  .set(IveAvatarLocalOverride.legacy),
            ),
            _OverrideButton(
              label: 'Avatar V2',
              subtitle: 'Força Avatar V2 neste dispositivo',
              value: IveAvatarLocalOverride.v2,
              current: localOverride,
              onTap: () => ref
                  .read(iveAvatarLocalOverrideProvider.notifier)
                  .set(IveAvatarLocalOverride.v2),
            ),
            _OverrideButton(
              label: 'Ocultar Avatar',
              subtitle: 'Remove avatar deste dispositivo',
              value: IveAvatarLocalOverride.hidden,
              current: localOverride,
              onTap: () => ref
                  .read(iveAvatarLocalOverrideProvider.notifier)
                  .set(IveAvatarLocalOverride.hidden),
            ),

            const SizedBox(height: 12),

            // Showcase button (debug only)
            if (kDebugMode)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.palette_rounded, size: 16),
                  label: const Text('Abrir Showcase do Avatar V2'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7B5CF6),
                    side: const BorderSide(color: Color(0xFF7B5CF6)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppConstants.routeIveAvatarShowcase,
                    );
                  },
                ),
              ),

            if (localOverride != IveAvatarLocalOverride.automatic)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Color(0xFFFFB020),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Override local ativo — afeta apenas este dispositivo',
                      style: TextStyle(
                        color: const Color(0xFFFFB020).withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _versionLabel(IveAvatarVersion v) {
    switch (v) {
      case IveAvatarVersion.legacy:
        return 'Legado';
      case IveAvatarVersion.v2:
        return 'V2';
      case IveAvatarVersion.hidden:
        return 'Oculto';
    }
  }

  Color _versionColor(IveAvatarVersion v) {
    switch (v) {
      case IveAvatarVersion.legacy:
        return Colors.white70;
      case IveAvatarVersion.v2:
        return const Color(0xFF7B5CF6);
      case IveAvatarVersion.hidden:
        return Colors.white38;
    }
  }

  String _overrideLabel(IveAvatarLocalOverride o) {
    switch (o) {
      case IveAvatarLocalOverride.automatic:
        return 'automático';
      case IveAvatarLocalOverride.legacy:
        return 'legado';
      case IveAvatarLocalOverride.v2:
        return 'V2';
      case IveAvatarLocalOverride.hidden:
        return 'oculto';
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white70,
  });
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverrideButton extends StatelessWidget {
  const _OverrideButton({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.current,
    required this.onTap,
  });
  final String label;
  final String subtitle;
  final IveAvatarLocalOverride value;
  final IveAvatarLocalOverride current;
  final VoidCallback onTap;

  bool get _selected => value == current;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _selected
              ? const Color(0xFF7B5CF6).withOpacity(0.15)
              : const Color(0xFF1A1B38),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _selected
                ? const Color(0xFF7B5CF6)
                : const Color(0xFF2A2B55),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: _selected ? const Color(0xFF7B5CF6) : Colors.white38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: _selected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
