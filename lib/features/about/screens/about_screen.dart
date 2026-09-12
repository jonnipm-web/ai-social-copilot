import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';

/// IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01 — "Sobre o InsightValues".
/// Nunca expõe infraestrutura técnica ou segredos -- só informação
/// comercial/legal voltada ao cliente final.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.auto_awesome, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(t.aboutTagline, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 28),
          _VersionTile(t: t),
          const Divider(color: Colors.white12, height: 32),
          _LinkTile(
            icon: Icons.public_rounded,
            label: t.aboutWebsite,
            url: AppConstants.officialWebsiteUrl,
          ),
          _LinkTile(
            icon: Icons.mail_outline_rounded,
            label: t.aboutSupportContact,
            url: 'mailto:${AppConstants.supportEmail}',
            subtitle: AppConstants.supportEmail,
          ),
          _LinkTile(
            icon: Icons.privacy_tip_outlined,
            label: t.aboutPrivacyPolicy,
            url: AppConstants.privacyPolicyUrl,
            unavailableText: t.aboutOwnerConfigRequired,
          ),
          _LinkTile(
            icon: Icons.description_outlined,
            label: t.aboutTermsOfUse,
            url: AppConstants.termsOfUseUrl,
            unavailableText: t.aboutOwnerConfigRequired,
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined, color: Colors.white70),
            title: Text(t.aboutPlanInfo),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            onTap: () => context.push(AppConstants.routeUpgrade),
          ),
          const SizedBox(height: 24),
          Text(
            t.aboutCopyright(DateTime.now().year),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.t});
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final versionText = info == null
            ? '...'
            : '${info.version} (build ${info.buildNumber})';
        return ListTile(
          leading: const Icon(Icons.info_outline_rounded, color: Colors.white70),
          title: Text(t.aboutVersion),
          trailing: Text(versionText, style: const TextStyle(color: Colors.white54)),
        );
      },
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.url,
    this.subtitle,
    this.unavailableText,
  });

  final IconData icon;
  final String label;
  final String? url;
  final String? subtitle;
  final String? unavailableText;

  @override
  Widget build(BuildContext context) {
    final available = url != null && url!.isNotEmpty;
    return ListTile(
      leading: Icon(icon, color: available ? Colors.white70 : Colors.white24),
      title: Text(label, style: TextStyle(color: available ? Colors.white : Colors.white38)),
      subtitle: available
          ? (subtitle != null ? Text(subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 12)) : null)
          : Text(unavailableText ?? '', style: const TextStyle(color: Colors.white24, fontSize: 12)),
      trailing: available ? const Icon(Icons.open_in_new_rounded, color: Colors.white38, size: 18) : null,
      onTap: available ? () => launchUrl(Uri.parse(url!)) : null,
    );
  }
}
