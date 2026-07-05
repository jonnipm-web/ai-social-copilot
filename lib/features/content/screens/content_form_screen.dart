import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/content_item.dart';
import '../../../providers/content_provider.dart';

class ContentFormScreen extends ConsumerStatefulWidget {
  const ContentFormScreen({super.key, this.itemId});
  final String? itemId;

  @override
  ConsumerState<ContentFormScreen> createState() => _ContentFormScreenState();
}

class _ContentFormScreenState extends ConsumerState<ContentFormScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _bodyCtrl     = TextEditingController();
  final _nicheCtrl    = TextEditingController();
  final _audienceCtrl = TextEditingController();

  String _selectedType = ContentItem.types.first;
  bool   _loading      = false;
  bool   _initialized  = false;

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
    _titleCtrl.text    = item.title;
    _descCtrl.text     = item.description ?? '';
    _bodyCtrl.text     = item.baseText ?? '';
    _nicheCtrl.text    = item.niche ?? '';
    _audienceCtrl.text = item.targetAudience ?? '';
    _selectedType      = item.type;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (isEdit) {
        final data = {
          'title':           _titleCtrl.text.trim(),
          'type':            _selectedType,
          'description':     _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'base_text':       _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
          'niche':           _nicheCtrl.text.trim().isEmpty ? null : _nicheCtrl.text.trim(),
          'target_audience': _audienceCtrl.text.trim().isEmpty ? null : _audienceCtrl.text.trim(),
        };
        await ref.read(contentNotifierProvider.notifier).update(widget.itemId!, data);
      } else {
        final item = ContentItem(
          id:          '',
          userId:      '',
          type:        _selectedType,
          title:       _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          baseText:    _bodyCtrl.text.trim().isEmpty ? null : _bodyCtrl.text.trim(),
          niche:       _nicheCtrl.text.trim().isEmpty ? null : _nicheCtrl.text.trim(),
          targetAudience: _audienceCtrl.text.trim().isEmpty ? null : _audienceCtrl.text.trim(),
          createdAt:   DateTime.now(),
          updatedAt:   DateTime.now(),
        );
        await ref.read(contentNotifierProvider.notifier).create(item);
      }
      ref.invalidate(contentItemsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
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
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _populateFromItem(item));
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Item' : 'Novo Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tipo de conteúdo',
                style: TextStyle(color: Colors.white54, fontSize: 13),
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
                        ContentItem.typeLabels[t] ?? t,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: selected
                          ? const Color(0xFF6C63FF)
                          : Colors.white.withOpacity(0.07),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF6C63FF)
                            : Colors.white12,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _Field(
                controller: _titleCtrl,
                label: 'Título *',
                hint: 'Nome do conteúdo',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _descCtrl,
                label: 'Descrição / Resumo',
                hint: 'Breve descrição...',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _bodyCtrl,
                label: 'Texto Base / Conteúdo',
                hint: 'Cole o texto, trecho ou anotações...',
                maxLines: 6,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _nicheCtrl,
                label: 'Nicho',
                hint: 'Ex: Marketing Digital, Fitness',
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _audienceCtrl,
                label: 'Público-alvo',
                hint: 'Ex: Empreendedores iniciantes',
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEdit ? 'Salvar Alterações' : 'Adicionar à Biblioteca',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
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
  final String                label;
  final String?               hint;
  final int                   maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines:   maxLines,
      validator:  validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText:  hint,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        hintStyle:  const TextStyle(color: Colors.white24, fontSize: 12),
        filled:     true,
        fillColor:  Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6C63FF)),
        ),
      ),
    );
  }
}
