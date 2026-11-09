import 'package:flutter/material.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/campaign.dart';
import '../../../core/utils/ai_enum_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/campaign_provider.dart';
import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class CampaignDetailScreen extends ConsumerWidget {
  const CampaignDetailScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final campaignAsync = ref.watch(campaignByIdProvider(campaignId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        title: Text(
          l10n.campaignDetailTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: IvBody(child: campaignAsync.when(
        loading: () => const IvLoadingSkeleton(),
        error: (e, _) => Center(
            child: Text(l10n.iveChatErrorPrefix(extractErrorMessage(e, l10n)),
                style: const TextStyle(color: AppColors.inkMuted))),
        data: (campaign) {
          if (campaign == null) {
            return Center(
                child: Text(l10n.campaignDetailNotFound,
                    style: const TextStyle(color: AppColors.inkMuted)));
          }
          return _CampaignContent(campaign: campaign);
        },
      )),
    );
  }
}

class _CampaignContent extends StatelessWidget {
  const _CampaignContent({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = campaign.campaignJson;
    final emails = _list(c['email_sequence']);
    final metrics = _strList(c['success_metrics']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // Header
        _Header(campaign: campaign),
        const SizedBox(height: 16),

        // Overview
        if (campaign.overview.isNotEmpty) ...[
          _SectionTitle(l10n.campaignDetailOverviewTitle),
          _Card(
            child: Text(campaign.overview,
                style: const TextStyle(
                    color: AppColors.inkMuted, fontSize: 14, height: 1.6)),
          ),
          const SizedBox(height: 16),
        ],

        // Key messages | expected results — side by side on wide screens
        if (campaign.keyMessages.isNotEmpty ||
            campaign.expectedResults.isNotEmpty) ...[
          IvCardGrid(
            minTileWidth: 360,
            maxColumns: 2,
            children: [
              if (campaign.keyMessages.isNotEmpty)
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(l10n.campaignDetailKeyMessagesTitle),
                      ...campaign.keyMessages.map((m) => _BulletItem(
                          m, Icons.message_rounded, AppColors.accent)),
                    ],
                  ),
                ),
              if (campaign.expectedResults.isNotEmpty)
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(l10n.campaignDetailExpectedResultsTitle),
                      ...campaign.expectedResults.map((r) => _BulletItem(
                          r, Icons.check_circle_rounded, AppColors.positive)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Calendar
        if (campaign.calendar.isNotEmpty) ...[
          _SectionTitle(l10n.campaignDetailCalendarTitle),
          const SizedBox(height: 8),
          IvCardGrid(
            minTileWidth: 360,
            maxColumns: 2,
            gap: AppSpace.s2,
            children: [
              for (final entry in campaign.calendar) _CalendarEntry(entry),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Email sequence
        if (emails.isNotEmpty) ...[
          _SectionTitle(l10n.campaignDetailEmailSequenceTitle),
          const SizedBox(height: 8),
          ...emails.map((e) {
            final em =
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
            return _EmailEntry(em);
          }),
          const SizedBox(height: 16),
        ],

        // Success metrics
        if (metrics.isNotEmpty) ...[
          _SectionTitle(l10n.campaignDetailMetricsTitle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: metrics
                .map((m) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.positive.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: AppColors.positive.withOpacity(0.3)),
                      ),
                      child: Text(m,
                          style: const TextStyle(
                              color: AppColors.positive, fontSize: 12)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  static List<dynamic> _list(dynamic v) {
    if (v is List) return v;
    return [];
  }

  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.campaign});
  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.info.withOpacity(0.3),
            AppColors.info.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded,
                  color: AppColors.info, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  campaign.title,
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (campaign.campaignJson['tagline'] != null) ...[
            const SizedBox(height: 4),
            Text(
              campaign.campaignJson['tagline'].toString(),
              style: const TextStyle(
                  color: AppColors.info,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _Tag(campaignObjectiveLabel(campaign.objective, l10n),
                  AppColors.accent),
              _Tag(l10n.campaignsDurationDays(campaign.durationDays),
                  AppColors.warning),
              ...campaign.channels.take(3).map(
                    (ch) => _Tag(ch, AppColors.info),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: child,
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text, this.icon, this.color);
  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _CalendarEntry extends StatelessWidget {
  const _CalendarEntry(this.entry);
  final Map<String, dynamic> entry;

  Color _channelColor(String ch) {
    switch (ch.toLowerCase()) {
      case 'instagram':
        return AppColors.accent;
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'linkedin':
        return const Color(0xFF0077B5);
      case 'youtube':
        return AppColors.negative;
      case 'tiktok':
        return const Color(0xFF00F2EA);
      case 'email':
        return AppColors.warning;
      case 'blog':
        return AppColors.positive;
      case 'hotmart':
        return AppColors.accent;
      case 'shopify':
        return AppColors.info;
      case 'amazon':
        return AppColors.warning;
      default:
        return AppColors.inkSubtle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final day = entry['day']?.toString() ?? '';
    final channel = entry['channel'] as String? ?? '';
    final contentType = entry['content_type'] as String? ?? '';
    final topic = entry['topic'] as String? ?? '';
    final hook = entry['hook'] as String? ?? '';
    final cta = entry['cta'] as String? ?? '';
    final brief = entry['content_brief'] as String? ?? '';
    final color = _channelColor(channel);

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text('D$day',
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _Tag(channel, color),
                          const SizedBox(width: 6),
                          if (contentType.isNotEmpty)
                            _Tag(contentType, AppColors.inkSubtle),
                        ],
                      ),
                      if (topic.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(topic,
                            style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final fullContent = [
                      if (topic.isNotEmpty)
                        '${l10n.campaignDetailTopicLabel}: $topic',
                      if (hook.isNotEmpty)
                        '${l10n.campaignDetailHookLabel}: $hook',
                      if (cta.isNotEmpty)
                        '${l10n.campaignDetailCtaLabel}: $cta',
                      if (brief.isNotEmpty) brief,
                    ].join('\n\n');
                    Clipboard.setData(ClipboardData(text: fullContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.campaignDetailCopied),
                        duration: const Duration(seconds: 1),
                        backgroundColor: AppColors.surface,
                      ),
                    );
                  },
                  child: const Icon(Icons.copy_rounded,
                      color: AppColors.inkSubtle, size: 16),
                ),
              ],
            ),
            if (hook.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow(l10n.campaignDetailHookLabel, hook, AppColors.inkMuted),
            ],
            if (cta.isNotEmpty) ...[
              const SizedBox(height: 4),
              _DetailRow(
                  l10n.campaignDetailCtaLabel, cta, AppColors.gold),
            ],
            if (brief.isNotEmpty) ...[
              const SizedBox(height: 4),
              _DetailRow(l10n.campaignDetailBriefLabel, brief, AppColors.inkSubtle),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 38,
          child: Text('$label:',
              style: const TextStyle(
                  color: AppColors.inkSubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(color: color, fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}

class _EmailEntry extends StatelessWidget {
  const _EmailEntry(this.data);
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final day = data['day']?.toString() ?? '';
    final subject = data['subject'] as String? ?? '';
    final preview = data['preview'] as String? ?? '';
    final obj = data['objective'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text('D$day',
                style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subject.isNotEmpty)
                  Text(subject,
                      style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(preview,
                      style:
                          const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                ],
                if (obj.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(obj,
                      style: const TextStyle(
                          color: AppColors.warning, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
