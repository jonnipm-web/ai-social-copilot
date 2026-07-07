import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/campaign.dart';
import '../../../providers/campaign_provider.dart';

class CampaignDetailScreen extends ConsumerWidget {
  const CampaignDetailScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaignAsync = ref.watch(campaignByIdProvider(campaignId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: const Text(
          'Campanha',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: campaignAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Erro: $e',
                style: const TextStyle(color: Colors.white70))),
        data: (campaign) {
          if (campaign == null) {
            return const Center(
                child: Text('Campanha não encontrada.',
                    style: TextStyle(color: Colors.white70)));
          }
          return _CampaignContent(campaign: campaign);
        },
      ),
    );
  }
}

class _CampaignContent extends StatelessWidget {
  const _CampaignContent({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
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
          _SectionTitle('Visão Geral'),
          _Card(
            child: Text(campaign.overview,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: 16),
        ],

        // Key messages
        if (campaign.keyMessages.isNotEmpty) ...[
          _SectionTitle('Mensagens-chave'),
          ...campaign.keyMessages.map((m) => _BulletItem(
              m, Icons.message_rounded, const Color(0xFF6C63FF))),
          const SizedBox(height: 16),
        ],

        // Expected results
        if (campaign.expectedResults.isNotEmpty) ...[
          _SectionTitle('Resultados Esperados'),
          ...campaign.expectedResults.map((r) => _BulletItem(
              r, Icons.check_circle_rounded, const Color(0xFF4CAF50))),
          const SizedBox(height: 16),
        ],

        // Calendar
        if (campaign.calendar.isNotEmpty) ...[
          _SectionTitle('Calendário de Conteúdo'),
          const SizedBox(height: 8),
          ...campaign.calendar.map((entry) => _CalendarEntry(entry)),
          const SizedBox(height: 16),
        ],

        // Email sequence
        if (emails.isNotEmpty) ...[
          _SectionTitle('Sequência de Emails'),
          const SizedBox(height: 8),
          ...emails.map((e) {
            final em = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
            return _EmailEntry(em);
          }),
          const SizedBox(height: 16),
        ],

        // Success metrics
        if (metrics.isNotEmpty) ...[
          _SectionTitle('Métricas de Sucesso'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: metrics
                .map((m) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF4CAF50).withOpacity(0.3)),
                      ),
                      child: Text(m,
                          style: const TextStyle(
                              color: Color(0xFF4CAF50), fontSize: 12)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00BCD4).withOpacity(0.3),
            const Color(0xFF00BCD4).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded,
                  color: Color(0xFF00BCD4), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  campaign.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (campaign.campaignJson['tagline'] != null) ...[
            const SizedBox(height: 4),
            Text(
              campaign.campaignJson['tagline'].toString(),
              style: const TextStyle(
                  color: Color(0xFF00BCD4),
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _Tag(campaign.objective, const Color(0xFF6C63FF)),
              _Tag('${campaign.durationDays} dias', const Color(0xFFFF9800)),
              ...campaign.channels.take(3).map(
                    (ch) => _Tag(ch, const Color(0xFF00BCD4)),
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
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
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
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text, this.icon, this.color);
  final String   text;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
      case 'instagram': return const Color(0xFFE91E63);
      case 'facebook':  return const Color(0xFF1877F2);
      case 'linkedin':  return const Color(0xFF0077B5);
      case 'youtube':   return const Color(0xFFF44336);
      case 'tiktok':    return const Color(0xFF00F2EA);
      case 'email':     return const Color(0xFFFF9800);
      case 'blog':      return const Color(0xFF4CAF50);
      case 'hotmart':   return const Color(0xFF6C63FF);
      case 'shopify':   return const Color(0xFF00BCD4);
      case 'amazon':    return const Color(0xFFFF5722);
      default:          return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final day         = entry['day']?.toString() ?? '';
    final channel     = entry['channel'] as String? ?? '';
    final contentType = entry['content_type'] as String? ?? '';
    final topic       = entry['topic'] as String? ?? '';
    final hook        = entry['hook'] as String? ?? '';
    final cta         = entry['cta'] as String? ?? '';
    final brief       = entry['content_brief'] as String? ?? '';
    final color       = _channelColor(channel);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
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
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text('D$day',
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
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
                            _Tag(contentType, Colors.white38),
                        ],
                      ),
                      if (topic.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(topic,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final fullContent = [
                      if (topic.isNotEmpty) 'Tópico: $topic',
                      if (hook.isNotEmpty) 'Hook: $hook',
                      if (cta.isNotEmpty) 'CTA: $cta',
                      if (brief.isNotEmpty) brief,
                    ].join('\n\n');
                    Clipboard.setData(ClipboardData(text: fullContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copiado!'),
                        duration: Duration(seconds: 1),
                        backgroundColor: Color(0xFF1A1A2E),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy_rounded,
                      color: Colors.white24, size: 16),
                ),
              ],
            ),
            if (hook.isNotEmpty) ...[
              const SizedBox(height: 8),
              _DetailRow('Hook', hook, Colors.white60),
            ],
            if (cta.isNotEmpty) ...[
              const SizedBox(height: 4),
              _DetailRow('CTA', cta, const Color(0xFFFFD700)),
            ],
            if (brief.isNotEmpty) ...[
              const SizedBox(height: 4),
              _DetailRow('Brief', brief, Colors.white38),
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
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 38,
          child: Text('$label:',
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
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
    final day     = data['day']?.toString() ?? '';
    final subject = data['subject'] as String? ?? '';
    final preview = data['preview'] as String? ?? '';
    final obj     = data['objective'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFFF9800).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('D$day',
                style: const TextStyle(
                    color: Color(0xFFFF9800),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subject.isNotEmpty)
                  Text(subject,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(preview,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
                if (obj.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(obj,
                      style: const TextStyle(
                          color: Color(0xFFFF9800), fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

