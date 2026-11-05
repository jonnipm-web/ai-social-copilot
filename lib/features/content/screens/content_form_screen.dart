import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import '../../../data/models/content_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/content_provider.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class ContentFormScreen extends ConsumerStatefulWidget {
  const ContentFormScreen({super.key, this.itemId});
  final String? itemId;

  @override
  ConsumerState<ContentFormScreen> createState() => _ContentFormScreenState();
}

class _ContentFormScreenState extends ConsumerState<ContentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _nicheCtrl = TextEditingController();
  final _audienceCtrl = TextEditingController();

  String _selectedType = ContentItem.types.first;
  bool _loading = false;
  bool _initialized = false;

  bool get isEdit => widget.itemId != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _bodyCtrl.dispose();
    _nicheCtrl.dispose();
    _audienceCtrl.dispose();
    super.dispose();
  }

  void _populateFromItem(ContentItem item) {
    _titleCtrl.text = item.title;
    _descCtrl.text = item.description ?? '';
    _bodyCtrl.text = item.baseText ?? '';
    _nicheCtrl.text = item.niche ?? '';
    _audienceCtrl.text = item.targetAudience ?? '';
    _selectedType = item.type;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (isEdit) {
        final data = {
          'title': _titleCtrl.text.trim(),
          'type': _selectedType,
          'description':
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'base_text':
              _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
          'niche':
              _nicheCtrl.text.trim().isEmpty ? null : _nicheCtrl.text.trim(),
          'target_audience': _audienceCtrl.text.trim().isEmpty
              ? null
              : _audienceCtrl.text.trim(),
        };
        await ref
            .read(contentNotifierProvider.notifier)
            .update(widget.itemId!, data);
      } else {
        final item = ContentItem(
          id: '',
          userId: '',
          type: _selectedType,
          title: _titleCtrl.text.trim(),
          description:
              _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          baseText:
              _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
          niche: _nicheCtrl.text.trim().isEmpty ? null : _nicheCtrl.text.trim(),
          targetAudience: _audienceCtrl.text.trim().isEmpty
              ? null
              : _audienceCtrl.text.trim(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await ref.read(contentNotifierProvider.notifier).create(item);
      }
      ref.invalidate(contentItemsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.iveChatErrorPrefix(
                  extractErrorMessage(e, AppLocalizations.of(context)!))),
              backgroundColor: AppColors.negative),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isEdit) {
      final itemAsync = ref.watch(contentItemByIdProvider(widget.itemId!));
      itemAsync.whenData((item) {
        if (item != null && !_initialized) {
          _initialized = true;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _populateFromItem(item));
        }
      });
    }

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            isEdit ? l10n.uxContentFormEditTitle : l10n.uxContentFormNewTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.uxContentFormTypeLabel,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ContentItem.types.map((t) {
                  final selected = _selectedType == t;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = t),
                    child: Chip(
                      label: Text(
                        ContentItem.localizedTypeLabel(t, l10n),
                        style: TextStyle(
                          color: selected ? AppColors.ink : AppColors.inkMuted,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: selected
                          ? AppColors.accent
                          : AppColors.ink.withOpacity(0.07),
                      side: BorderSide(
                        color:
                            selected ? AppColors.accent : AppColors.line,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _Field(
                controller: _titleCtrl,
                label: l10n.uxContentFormTitleLabel,
                hint: l10n.uxContentFormTitleHint,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.uxFieldRequired : null,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _descCtrl,
                label: l10n.uxContentFormDescLabel,
                hint: l10n.uxContentFormDescHint,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _bodyCtrl,
                label: l10n.uxContentFormBodyLabel,
                hint: l10n.uxContentFormBodyHint,
                maxLines: 6,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _nicheCtrl,
                label: l10n.uxContentFormNicheLabel,
                hint: l10n.uxContentFormNicheHint,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _audienceCtrl,
                label: l10n.uxContentFormAudienceLabel,
                hint: l10n.uxContentFormAudienceHint,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.ink,
                        ),
                      )
                    : Text(
                        isEdit
                            ? l10n.uxContentFormSaveChanges
                            : l10n.uxContentFormAddToLibrary,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.inkSubtle, fontSize: 12),
        filled: true,
        fillColor: AppColors.ink.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}
