import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';

/// IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — "Ajuda e Suporte". Usa apenas
/// o canal de contato já evidenciado no próprio repositório
/// (AppConstants.supportEmail) -- nunca inventa e-mail, URL ou telefone.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final subjectReport = Uri.encodeComponent(
      Localizations.localeOf(context).languageCode == 'en' ? 'Problem report' : 'Relato de problema',
    );
    final subjectFeedback = Uri.encodeComponent(
      Localizations.localeOf(context).languageCode == 'en' ? 'Feedback' : 'Feedback',
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.supportTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t.supportContactEmail(AppConstants.supportEmail),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded, color: Colors.white70),
            title: Text(t.supportContact),
            subtitle: Text(AppConstants.supportEmail, style: const TextStyle(color: Colors.white38)),
            onTap: () => launchUrl(Uri.parse('mailto:${AppConstants.supportEmail}')),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined, color: Colors.white70),
            title: Text(t.supportReportProblem),
            onTap: () => launchUrl(Uri.parse('mailto:${AppConstants.supportEmail}?subject=$subjectReport')),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70),
            title: Text(t.supportSendFeedback),
            onTap: () => launchUrl(Uri.parse('mailto:${AppConstants.supportEmail}?subject=$subjectFeedback')),
          ),
        ],
      ),
    );
  }
}
