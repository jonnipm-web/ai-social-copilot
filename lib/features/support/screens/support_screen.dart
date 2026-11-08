import 'package:flutter/material.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ive_intro_sheet.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

/// IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — "Ajuda e Suporte". Usa apenas
/// o canal de contato já evidenciado no próprio repositório
/// (AppConstants.supportEmail) -- nunca inventa e-mail, URL ou telefone.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final subjectReport = Uri.encodeComponent(t.uxSupportSubjectProblemReport);
    final subjectFeedback = Uri.encodeComponent(t.uxSupportSubjectFeedback);

    return Scaffold(
      appBar: AppBar(title: Text(t.supportTitle)),
      body: IvBody(child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t.supportContactEmail(AppConstants.supportEmail),
            style: const TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 20),
          // IVE-EXPERIENCE-V1-06 (Section 16) — permanent "Meet IVE" replay
          // entry point. Always available regardless of first-use state
          // (does not read/write ive_intro_provider's shouldShow) — replay
          // is a deliberate re-watch, not a first-use trigger.
          IvCardGrid(
            minTileWidth: 300,
            maxColumns: 2,
            gap: AppSpace.s3,
            children: [
              _SupportTile(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.accent,
                title: t.ivIntroReplayLabel,
                onTap: () => showIveIntroSheet(context, trigger: 'replay'),
              ),
              _SupportTile(
                icon: Icons.mail_outline_rounded,
                color: AppColors.info,
                title: t.supportContact,
                subtitle: AppConstants.supportEmail,
                onTap: () =>
                    launchUrl(Uri.parse('mailto:${AppConstants.supportEmail}')),
              ),
              _SupportTile(
                icon: Icons.bug_report_outlined,
                color: AppColors.warning,
                title: t.supportReportProblem,
                onTap: () => launchUrl(Uri.parse(
                    'mailto:${AppConstants.supportEmail}?subject=$subjectReport')),
              ),
              _SupportTile(
                icon: Icons.chat_bubble_outline_rounded,
                color: AppColors.positive,
                title: t.supportSendFeedback,
                onTap: () => launchUrl(Uri.parse(
                    'mailto:${AppConstants.supportEmail}?subject=$subjectFeedback')),
              ),
            ],
          ),
        ],
      )),
    );
  }
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IvCard(
      onTap: onTap,
      child: Row(
        children: [
          IvIconTile(icon, color: color),
          const SizedBox(width: AppSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: const TextStyle(
                          color: AppColors.inkMuted, fontSize: 13)),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
        ],
      ),
    );
  }
}
