import 'package:flutter/material.dart';
import 'package:ai_social_copilot/shared/ui/iv_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/ai_enum_labels.dart';
import '../../../data/models/campaign.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/campaign_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final campaignsAsync = ref.watch(campaignsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: const AppDrawer(),
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
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        title: Text(
          l10n.campaignsTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(campaignsProvider),
            tooltip: l10n.campaignsRefreshTooltip,
          ),
        ],
      ),
      body: IvBody(child: campaignsAsync.when(
        loading: () => const IvLoadingSkeleton(),
        error: (e, _) => Center(
          child: Text(l10n.commonError,
              style: const TextStyle(color: AppColors.inkMuted)),
        ),
        data: (campaigns) => campaigns.isEmpty
            ? _EmptyState(
                onTap: () => context.push(AppConstants.routeKnowledge),
              )
            : _CampaignList(campaigns: campaigns),
      )),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IvEmptyState(
      icon: Icons.campaign_rounded,
      color: AppColors.info,
      title: l10n.campaignsEmpty,
      message: l10n.campaignsEmptyHint,
      actionLabel: l10n.campaignsGoToVault,
      onAction: onTap,
    );
  }
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({required this.campaigns});
  final List<Campaign> campaigns;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 64),
      child: IvCardGrid(children: [
        for (var i = 0; i < campaigns.length; i++)
          FadeSlideIn(index: i, child: _CampaignCard(campaign: campaigns[i])),
      ]),
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
        return AppColors.positive;
      case 'lançamento':
        return AppColors.warning;
      case 'leads':
        return AppColors.accent;
      case 'autoridade':
        return AppColors.gold;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final color = _objColor(campaign.objective);

    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Text(
                        campaignObjectiveLabel(campaign.objective, l10n),
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              if (campaign.campaignJson['tagline'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  campaign.campaignJson['tagline'].toString(),
                  style: const TextStyle(
                      color: AppColors.inkSubtle,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: AppColors.inkSubtle, size: 12),
                  const SizedBox(width: 4),
                  Text(l10n.campaignsDurationDays(campaign.durationDays),
                      style:
                          const TextStyle(color: AppColors.inkSubtle, fontSize: 11)),
                  const SizedBox(width: 12),
                  const Icon(Icons.broadcast_on_personal_rounded,
                      color: AppColors.inkSubtle, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    campaign.channels.take(3).join(', '),
                    style: const TextStyle(color: AppColors.inkSubtle, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: Text(l10n.campaignsDeleteTitle,
                              style: const TextStyle(color: AppColors.ink)),
                          content: Text(
                            l10n.campaignsDeleteConfirm(campaign.title),
                            style: const TextStyle(color: AppColors.inkMuted),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(l10n.commonCancel,
                                  style:
                                      const TextStyle(color: AppColors.inkMuted)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(l10n.commonDelete,
                                  style: const TextStyle(
                                      color: AppColors.negative)),
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
                        color: AppColors.inkSubtle, size: 18),
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
