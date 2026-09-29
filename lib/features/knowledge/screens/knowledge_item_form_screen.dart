import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/diagnostics/diagnostic_container.dart';
import '../../../core/diagnostics/diagnostic_models.dart';
import '../../../data/models/knowledge_item.dart';
import '../../../data/services/file_import_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/project_provider.dart';
import 'drive_picker_screen.dart';

class KnowledgeItemFormScreen extends ConsumerStatefulWidget {
  const KnowledgeItemFormScreen({super.key, this.itemId});

  final String? itemId;

  @override
  ConsumerState<KnowledgeItemFormScreen> createState() =>
      _KnowledgeItemFormScreenState();
}

class _KnowledgeItemFormScreenState
    extends ConsumerState<KnowledgeItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl          = TextEditingController();
  final _contentCtrl        = TextEditingController();
  final _urlCtrl            = TextEditingController();
  final _nicheCtrl          = TextEditingController();
  final _audienceCtrl       = TextEditingController();

  String  _sourceType = 'manual';
  String  _language   = 'pt-BR';
  String? _projectId;
  bool    _loading    = false;
  bool    _init       = false;
  bool    _importing  = false;
  String? _importedFileName;

  KnowledgeItem? _existing;

  bool get _isEdit => widget.itemId != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _urlCtrl.dispose();
    _nicheCtrl.dispose();
    _audienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_init) return;
    _init = true;

    // Load projectId passed via GoRouter extra (new item from vault filter)
    if (!_isEdit) {
      final extra = GoRouterState.of(context).extra;
      if (extra is Map && extra['projectId'] is String) {
        setState(() => _projectId = extra['projectId'] as String);
      }
      return;
    }

    final item = await ref
        .read(knowledgeServiceProvider)
        .fetchById(widget.itemId!);
    if (item == null || !mounted) return;

    _existing = item;
    _titleCtrl.text    = item.title;
    _contentCtrl.text  = item.content;
    _urlCtrl.text      = item.sourceUrl ?? '';
    _nicheCtrl.text    = item.niche ?? '';
    _audienceCtrl.text = item.targetAudience ?? '';
    setState(() {
      _sourceType = item.sourceType;
      _language   = item.language;
      _projectId  = item.projectId;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final content = _sourceType == 'url'
        ? _urlCtrl.text.trim()
        : _contentCtrl.text.trim();

    final sourceTypeToSave =
        _sourceType == 'drive' ? 'file' : _sourceType;

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.knowledgeFormContentEmptyError),
          backgroundColor: const Color(0xFFF44336),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final notifier = ref.read(knowledgeItemNotifierProvider.notifier);

      if (_isEdit && _existing != null) {
        await notifier.update(_existing!.id, {
          'title':           _titleCtrl.text.trim(),
          'source_type':     sourceTypeToSave,
          'source_url':      _sourceType == 'url' ? _urlCtrl.text.trim() : null,
          'content':         content,
          'niche':           _nicheCtrl.text.trim().isEmpty
              ? null
              : _nicheCtrl.text.trim(),
          'target_audience': _audienceCtrl.text.trim().isEmpty
              ? null
              : _audienceCtrl.text.trim(),
          'language':        _language,
          'status':          'pending',
        });
      } else {
        await notifier.create(KnowledgeItem(
          id:             '',
          userId:         uid,
          projectId:      _projectId,
          title:          _titleCtrl.text.trim(),
          sourceType:     sourceTypeToSave,
          sourceUrl:      _sourceType == 'url' ? _urlCtrl.text.trim() : null,
          content:        _sourceType == 'url' ? _urlCtrl.text.trim() : content,
          niche:          _nicheCtrl.text.trim().isEmpty
              ? null
              : _nicheCtrl.text.trim(),
          targetAudience: _audienceCtrl.text.trim().isEmpty
              ? null
              : _audienceCtrl.text.trim(),
          language:       _language,
          createdAt:      DateTime.now(),
          updatedAt:      DateTime.now(),
        ));
      }

      ref.invalidate(knowledgeItemsProvider);
      if (_projectId != null) {
        ref.invalidate(knowledgeItemsByProjectProvider(_projectId!));
      }

      // Confirmação com nome do projeto
      if (mounted) {
        final projects = ref.read(projectsNotifierProvider).valueOrNull ?? [];
        final projectName = _projectId == null
            ? null
            : projects
                .where((p) => p.id == _projectId)
                .map((p) => p.name)
                .firstOrNull;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              projectName != null
                  ? l10n.knowledgeFormSavedWithProject(projectName)
                  : l10n.knowledgeFormSavedNoProject,
            ),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 3),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.iveChatErrorPrefix('$e')),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadExisting();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: Text(
          _isEdit ? l10n.knowledgeFormEditTitle : l10n.knowledgeFormNewTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Projeto (opcional) ───────────────────────────
              _ProjectSelector(
                selectedId: _projectId,
                onChanged: (id) => setState(() => _projectId = id),
              ),

              const SizedBox(height: 20),

              // ── Tipo de fonte ────────────────────────────────
              _Label(l10n.knowledgeFormSourceTypeLabel),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SourceTypeButton(
                    icon:  Icons.edit_note_rounded,
                    label: l10n.knowledgeFormSourceManual,
                    value: 'manual',
                    current: _sourceType,
                    onTap: (v) => setState(() => _sourceType = v),
                  ),
                  _SourceTypeButton(
                    icon:  Icons.link_rounded,
                    label: l10n.knowledgeFormSourceUrl,
                    value: 'url',
                    current: _sourceType,
                    onTap: (v) => setState(() => _sourceType = v),
                  ),
                  _SourceTypeButton(
                    icon:  Icons.upload_file_rounded,
                    label: l10n.knowledgeFormSourceFile,
                    value: 'file',
                    current: _sourceType,
                    onTap: (v) => setState(() => _sourceType = v),
                  ),
                  _SourceTypeButton(
                    icon:  Icons.add_to_drive_rounded,
                    label: l10n.knowledgeFormSourceDrive,
                    value: 'drive',
                    current: _sourceType,
                    onTap: (v) => setState(() => _sourceType = v),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Título ───────────────────────────────────────
              _Label(l10n.knowledgeFormTitleLabel),
              const SizedBox(height: 8),
              _Field(
                controller: _titleCtrl,
                hint: l10n.knowledgeFormTitleHint,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.knowledgeFormTitleRequired : null,
              ),

              const SizedBox(height: 20),

              // ── Conteúdo ─────────────────────────────────────
              if (_sourceType == 'drive') ...[
                _Label(l10n.knowledgeFormImportFromDrive),
                const SizedBox(height: 8),
                _DriveImportSection(
                  importedFileName: _importedFileName,
                  contentCtrl:     _contentCtrl,
                  titleCtrl:       _titleCtrl,
                  onImported: (name) => setState(() => _importedFileName = name),
                ),
              ] else if (_sourceType == 'file') ...[
                _Label(l10n.knowledgeFormImportFile),
                const SizedBox(height: 8),
                _FileImportSection(
                  importing:        _importing,
                  importedFileName: _importedFileName,
                  contentCtrl:      _contentCtrl,
                  titleCtrl:        _titleCtrl,
                  onImport: (fileName) => setState(() {
                    _importedFileName = fileName;
                    _importing = false;
                  }),
                  onImporting: () => setState(() => _importing = true),
                  onError: () => setState(() => _importing = false),
                ),
              ] else if (_sourceType == 'url') ...[
                _Label(l10n.knowledgeFormUrlLabel),
                const SizedBox(height: 8),
                _Field(
                  controller: _urlCtrl,
                  hint: l10n.knowledgeFormUrlHint,
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.knowledgeFormUrlRequired;
                    if (!v.trim().startsWith('http')) {
                      return l10n.knowledgeFormUrlInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.knowledgeFormGoogleDocsHintTitle,
                        style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.knowledgeFormGoogleDocsHintBody,
                        style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _Label(l10n.knowledgeFormContentLabel),
                const SizedBox(height: 8),
                _Field(
                  controller: _contentCtrl,
                  hint: l10n.knowledgeFormContentHint,
                  maxLines: 10,
                  validator: (v) {
                    if (v == null || v.trim().length < 20) {
                      return l10n.knowledgeFormContentTooShort;
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 20),

              // ── Nicho ────────────────────────────────────────
              _Label(l10n.knowledgeFormNicheLabel),
              const SizedBox(height: 8),
              _Field(
                controller: _nicheCtrl,
                hint: l10n.knowledgeFormNicheHint,
              ),

              const SizedBox(height: 20),

              // ── Audiência ────────────────────────────────────
              _Label(l10n.knowledgeFormAudienceLabel),
              const SizedBox(height: 8),
              _Field(
                controller: _audienceCtrl,
                hint: l10n.knowledgeFormAudienceHint,
              ),

              const SizedBox(height: 20),

              // ── Idioma ───────────────────────────────────────
              _Label(l10n.knowledgeFormLanguageLabel),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _language,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: [
                  DropdownMenuItem(value: 'pt-BR', child: Text(l10n.knowledgeFormLanguagePtBr)),
                  DropdownMenuItem(value: 'en-US', child: Text(l10n.knowledgeFormLanguageEnUs)),
                  DropdownMenuItem(value: 'es',    child: Text(l10n.knowledgeFormLanguageEs)),
                ],
                onChanged: (v) => setState(() => _language = v ?? 'pt-BR'),
              ),

              const SizedBox(height: 32),

              // ── Salvar ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label:
                      Text(_loading ? l10n.knowledgeFormSaving : (_isEdit ? l10n.commonSave : l10n.knowledgeFormAddToVault)),
                  onPressed: _loading ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String?               hint;
  final int                   maxLines;
  final TextInputType?        keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:    controller,
      maxLines:      maxLines,
      keyboardType:  keyboardType,
      validator:     validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText:        hint,
        hintStyle:       const TextStyle(color: Colors.white30, fontSize: 13),
        filled:          true,
        fillColor:       const Color(0xFF1A1A2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide.none,
        ),
        errorStyle: const TextStyle(color: Color(0xFFF44336)),
      ),
    );
  }
}

class _FileImportSection extends StatelessWidget {
  const _FileImportSection({
    required this.importing,
    required this.importedFileName,
    required this.contentCtrl,
    required this.titleCtrl,
    required this.onImport,
    required this.onImporting,
    required this.onError,
  });

  final bool                    importing;
  final String?                 importedFileName;
  final TextEditingController   contentCtrl;
  final TextEditingController   titleCtrl;
  final void Function(String)   onImport;
  final VoidCallback            onImporting;
  final VoidCallback            onError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (importing) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(width: 12),
            Text(l10n.knowledgeFormExtracting, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (importedFileName != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    importedFileName!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    l10n.knowledgeFormCharsExtracted(contentCtrl.text.length),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _pickFile(context),
              child: Text(l10n.knowledgeFormChangeFile,
                  style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickFile(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(Icons.upload_file_rounded,
                    color: Color(0xFF6C63FF), size: 40),
                const SizedBox(height: 8),
                Text(
                  l10n.knowledgeFormClickToSelectFile,
                  style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.knowledgeFormFileTypes,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFFFF9800).withOpacity(0.25)),
          ),
          child: Text(
            l10n.knowledgeFormPdfWarning,
            style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }

  // IVE-COMMERCIAL-OBSERVABILITY-07A — KNOWLEDGE/IMPORT category (mission
  // section 04): "file selection event, safe file type, safe file size,
  // extraction stage, success/failure, duration. Do NOT log file
  // contents." Only the extension and character count are logged — never
  // result.text/fileName themselves.
  String? _safeFileType(String fileName) {
    final match = RegExp(r'\.([A-Za-z0-9]+)$').firstMatch(fileName);
    return match?.group(1)?.toLowerCase();
  }

  Future<void> _pickFile(BuildContext context) async {
    onImporting();
    final stopwatch = Stopwatch()..start();
    try {
      final service = FileImportService();
      final result  = await service.pickAndExtract();
      if (result == null) {
        diagnosticLogger.logEvent(
          category: DiagnosticCategory.knowledge,
          eventName: 'local_import',
          status: 'cancelled',
          durationMs: stopwatch.elapsedMilliseconds,
        );
        onError();
        return;
      }
      contentCtrl.text = result.text;
      if (titleCtrl.text.trim().isEmpty) {
        final name = result.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
        titleCtrl.text = name;
      }
      diagnosticLogger.logEvent(
        category: DiagnosticCategory.knowledge,
        eventName: 'local_import',
        status: 'success',
        durationMs: stopwatch.elapsedMilliseconds,
        metadata: {
          'file_type': _safeFileType(result.fileName),
          'file_size_bytes': result.text.length,
          'stage': 'extraction',
        },
      );
      onImport(result.fileName);
    } catch (e) {
      diagnosticLogger.logEvent(
        category: DiagnosticCategory.knowledge,
        eventName: 'local_import',
        severity: DiagnosticSeverity.warn,
        status: 'failure',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
      );
      onError();
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.knowledgeFormImportError('$e')),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }
}

class _DriveImportSection extends StatelessWidget {
  const _DriveImportSection({
    required this.importedFileName,
    required this.contentCtrl,
    required this.titleCtrl,
    required this.onImported,
  });

  final String?                importedFileName;
  final TextEditingController  contentCtrl;
  final TextEditingController  titleCtrl;
  final void Function(String)  onImported;

  Future<void> _openPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(builder: (_) => const DrivePickerScreen()),
    );
    if (result == null || !context.mounted) return;

    contentCtrl.text = result['content'] ?? '';
    if (titleCtrl.text.trim().isEmpty) {
      final name = (result['name'] ?? '').replaceAll(RegExp(r'\.[^.]+$'), '');
      titleCtrl.text = name;
    }
    onImported(result['name'] ?? l10n.knowledgeFormDriveDefaultName);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (importedFileName != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(importedFileName!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  Text(
                    l10n.knowledgeFormCharsExtracted(contentCtrl.text.length),
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _openPicker(context),
              child: Text(l10n.knowledgeFormChangeFile,
                  style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.add_to_drive_rounded,
                color: Color(0xFF6C63FF), size: 40),
            const SizedBox(height: 8),
            Text(
              l10n.knowledgeFormSelectDriveFile,
              style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.knowledgeFormDriveFileTypes,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectSelector extends ConsumerWidget {
  const _ProjectSelector({
    required this.selectedId,
    required this.onChanged,
  });

  final String? selectedId;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsNotifierProvider);
    final projects = projectsAsync.valueOrNull ?? [];

    if (projects.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(l10n.knowledgeFormProjectLabel),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: selectedId,
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          hint: Text(l10n.knowledgeFormNoProject,
              style: const TextStyle(color: Colors.white38)),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.knowledgeFormNoProject,
                  style: const TextStyle(color: Colors.white54)),
            ),
            ...projects.map((p) => DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(p.name,
                      style: const TextStyle(color: Colors.white)),
                )),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SourceTypeButton extends StatelessWidget {
  const _SourceTypeButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  final IconData icon;
  final String   label;
  final String   value;
  final String   current;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C63FF).withOpacity(0.2)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C63FF)
                : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? const Color(0xFF6C63FF) : Colors.white38,
                size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF6C63FF) : Colors.white54,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
