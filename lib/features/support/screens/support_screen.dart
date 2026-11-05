import 'package:flutter/material.dart';
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
      body: ListView(
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
          ListTile(
            leading:
                const Icon(Icons.auto_awesome_rounded, color: AppColors.inkMuted),
            title: Text(t.ivIntroReplayLabel),
            onTap: () => showIveIntroSheet(context, trigger: 'replay'),
          ),
          ListTile(
            leading:
                const Icon(Icons.mail_outline_rounded, color: AppColors.inkMuted),
            title: Text(t.supportContact),
            subtitle: Text(AppConstants.supportEmail,
                style: const TextStyle(color: AppColors.inkSubtle)),
            onTap: () =>
                launchUrl(Uri.parse('mailto:${AppConstants.supportEmail}')),
          ),
          ListTile(
            leading:
                const Icon(Icons.bug_report_outlined, color: AppColors.inkMuted),
            title: Text(t.supportReportProblem),
            onTap: () => launchUrl(Uri.parse(
                'mailto:${AppConstants.supportEmail}?subject=$subjectReport')),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.inkMuted),
            title: Text(t.supportSendFeedback),
            onTap: () => launchUrl(Uri.parse(
                'mailto:${AppConstants.supportEmail}?subject=$subjectFeedback')),
          ),
        ],
      ),
    );
  }
}
