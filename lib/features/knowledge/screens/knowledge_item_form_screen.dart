import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/knowledge_item.dart';
import '../../../data/services/file_import_service.dart';
import '../../../providers/knowledge_provider.dart';

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

  String _sourceType = 'manual';
  String _language   = 'pt-BR';
  bool   _loading    = false;
  bool   _init       = false;
  bool   _importing  = false;
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
    if (_init || !_isEdit) { _init = true; return; }
    _init = true;

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
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final content = _sourceType == 'url'
        ? _urlCtrl.text.trim()
        : _contentCtrl.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Importe ou cole o conteúdo antes de salvar.'),
          backgroundColor: Color(0xFFF44336),
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
          'source_type':     _sourceType,
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
          title:          _titleCtrl.text.trim(),
          sourceType:     _sourceType,
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
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
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

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: Text(
          _isEdit ? 'Editar Conhecimento' : 'Novo Conhecimento',
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
              // ── Tipo de fonte ────────────────────────────────
              const _Label('Tipo de fonte'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SourceTypeButton(
                    icon:  Icons.edit_note_rounded,
                    label: 'Texto Manual',
                    value: 'manual',
                    current: _sourceType,
                    onTap: (v) => setState(() => _sourceType = v),
                  ),
                  _SourceTypeButton(
                    icon:  Icons.link_rounded,
                    label: 'URL',
                    value: 'url',
                    current: _sourceType,
                    onTap: (v) => setState(() => _sourceType = v),
                  ),
                  _SourceTypeButton(
                    icon:  Icons.upload_file_rounded,
                    label: 'Arquivo',
                    value: 'file',
                    current: _sourceType,
                    onTap: (v) => setState(() => _sourceType = v),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Título ───────────────────────────────────────
              const _Label('Título *'),
              const SizedBox(height: 8),
              _Field(
                controller: _titleCtrl,
                hint: 'Ex.: Livro sobre Marketing Digital',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe o título.' : null,
              ),

              const SizedBox(height: 20),

              // ── Conteúdo ─────────────────────────────────────
              if (_sourceType == 'file') ...[
                const _Label('Importar Arquivo (PDF, DOCX, TXT)'),
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
                const _Label('URL do conteúdo *'),
                const SizedBox(height: 8),
                _Field(
                  controller: _urlCtrl,
                  hint: 'https://docs.google.com/document/d/...',
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe a URL.';
                    if (!v.trim().startsWith('http')) {
                      return 'URL deve começar com http ou https.';
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
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📄 Para Google Docs / Livros:',
                        style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '1. Abra o documento no Google Docs\n'
                        '2. Clique em Compartilhar\n'
                        '3. Mude para "Qualquer pessoa com o link pode visualizar"\n'
                        '4. Copie o link e cole aqui',
                        style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const _Label('Conteúdo *'),
                const SizedBox(height: 8),
                _Field(
                  controller: _contentCtrl,
                  hint:
                      'Cole aqui o texto do livro, artigo, post, roteiro ou qualquer conteúdo que deseja analisar…',
                  maxLines: 10,
                  validator: (v) {
                    if (v == null || v.trim().length < 20) {
                      return 'Conteúdo muito curto (mínimo 20 caracteres).';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 20),

              // ── Nicho ────────────────────────────────────────
              const _Label('Nicho (opcional)'),
              const SizedBox(height: 8),
              _Field(
                controller: _nicheCtrl,
                hint: 'Ex.: Marketing Digital, Saúde, Finanças',
              ),

              const SizedBox(height: 20),

              // ── Audiência ────────────────────────────────────
              const _Label('Audiência-alvo (opcional)'),
              const SizedBox(height: 8),
              _Field(
                controller: _audienceCtrl,
                hint: 'Ex.: Empreendedores iniciantes, Mães de primeira viagem',
              ),

              const SizedBox(height: 20),

              // ── Idioma ───────────────────────────────────────
              const _Label('Idioma'),
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
                items: const [
                  DropdownMenuItem(value: 'pt-BR', child: Text('Português (BR)')),
                  DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                  DropdownMenuItem(value: 'es',    child: Text('Español')),
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
                      Text(_loading ? 'Salvando…' : (_isEdit ? 'Salvar' : 'Adicionar ao Cofre')),
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
    if (importing) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)),
            ),
            SizedBox(width: 12),
            Text('Extraindo texto…', style: TextStyle(color: Colors.white54)),
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
                    '${contentCtrl.text.length} caracteres extraídos',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _pickFile(context),
              child: const Text('Trocar',
                  style: TextStyle(color: Color(0xFF6C63FF), fontSize: 12)),
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
            child: const Column(
              children: [
                Icon(Icons.upload_file_rounded,
                    color: Color(0xFF6C63FF), size: 40),
                SizedBox(height: 8),
                Text(
                  'Clique para selecionar arquivo',
                  style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  'PDF, DOCX ou TXT',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
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
          child: const Text(
            'PDF deve ter texto selecionável (não imagem escaneada). Para melhores resultados, use TXT ou DOCX.',
            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile(BuildContext context) async {
    onImporting();
    try {
      final service = FileImportService();
      final result  = await service.pickAndExtract();
      if (result == null) {
        onError();
        return;
      }
      contentCtrl.text = result.text;
      if (titleCtrl.text.trim().isEmpty) {
        final name = result.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
        titleCtrl.text = name;
      }
      onImport(result.fileName);
    } catch (e) {
      onError();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
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
