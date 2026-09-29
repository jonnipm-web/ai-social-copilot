import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/ai_enum_labels.dart';
import '../../../data/models/campaign.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/campaign_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final campaignsAsync = ref.watch(campaignsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.routeHome);
            }
          },
        ),
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: Text(
          l10n.campaignsTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(campaignsProvider),
            tooltip: l10n.campaignsRefreshTooltip,
          ),
        ],
      ),
      body: campaignsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(l10n.commonError,
              style: const TextStyle(color: Colors.white70)),
        ),
        data: (campaigns) => campaigns.isEmpty
            ? _EmptyState(
                onTap: () =>
                    context.push(AppConstants.routeKnowledge),
              )
            : _CampaignList(campaigns: campaigns),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.campaign_rounded,
                size: 72, color: Color(0xFF00BCD4)),
            const SizedBox(height: 16),
            Text(
              l10n.campaignsEmpty,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.campaignsEmptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.auto_stories_rounded),
              label: Text(l10n.campaignsGoToVault),
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({required this.campaigns});
  final List<Campaign> campaigns;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: campaigns.length,
      itemBuilder: (_, i) => _CampaignCard(campaign: campaigns[i]),
    );
  }
}

class _CampaignCard extends ConsumerWidget {
  const _CampaignCard({required this.campaign});
  final Campaign campaign;

  Color _objColor(String obj) {
    switch (obj.toLowerCase()) {
      case 'venda':
      case 'venda hotmart':
      case 'venda shopify':
      case 'venda amazon':
        return const Color(0xFF4CAF50);
      case 'lançamento':
        return const Color(0xFFFF9800);
      case 'leads':
        return const Color(0xFF6C63FF);
      case 'autoridade':
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFF00BCD4);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final color = _objColor(campaign.objective);

    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          AppConstants.routeCampaignDetail.replaceFirst(':id', campaign.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign_rounded, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      campaign.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Text(campaignObjectiveLabel(campaign.objective, l10n),
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              if (campaign.campaignJson['tagline'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  campaign.campaignJson['tagline'].toString(),
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: Colors.white24, size: 12),
                  const SizedBox(width: 4),
                  Text(l10n.campaignsDurationDays(campaign.durationDays),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                  const SizedBox(width: 12),
                  const Icon(Icons.broadcast_on_personal_rounded,
                      color: Colors.white24, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    campaign.channels.take(3).join(', '),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: const Color(0xFF1A1A2E),
                          title: Text(l10n.campaignsDeleteTitle,
                              style: const TextStyle(color: Colors.white)),
                          content: Text(
                            l10n.campaignsDeleteConfirm(campaign.title),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.commonCancel,
                                  style: const TextStyle(color: Colors.white54)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l10n.commonDelete,
                                  style: const TextStyle(
                                      color: Color(0xFFF44336))),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ref
                            .read(campaignNotifierProvider.notifier)
                            .delete(campaign.id);
                        ref.invalidate(campaignsProvider);
                      }
                    },
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.white24, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
