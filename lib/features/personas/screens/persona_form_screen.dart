import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/persona.dart';
import '../../../providers/persona_provider.dart';

class PersonaFormScreen extends ConsumerStatefulWidget {
  const PersonaFormScreen({super.key, this.personaId});
  final String? personaId;

  @override
  ConsumerState<PersonaFormScreen> createState() => _PersonaFormScreenState();
}

class _PersonaFormScreenState extends ConsumerState<PersonaFormScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _nameCtrl        = TextEditingController();
  final _nicheCtrl       = TextEditingController();
  final _voiceToneCtrl   = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _audienceCtrl    = TextEditingController();
  final _wordsUseCtrl    = TextEditingController();
  final _wordsAvoidCtrl  = TextEditingController();

  bool _isGlobal   = false;
  bool _loading    = false;
  bool _initialized = false;

  bool get isEdit => widget.personaId != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicheCtrl.dispose();
    _voiceToneCtrl.dispose();
    _descCtrl.dispose();
    _audienceCtrl.dispose();
    _wordsUseCtrl.dispose();
    _wordsAvoidCtrl.dispose();
    super.dispose();
  }

  void _populateFromPersona(Persona p) {
    _nameCtrl.text       = p.name;
    _nicheCtrl.text      = p.niche ?? '';
    _voiceToneCtrl.text  = p.voiceTone ?? '';
    _descCtrl.text       = p.description ?? '';
    _audienceCtrl.text   = p.targetAudience ?? '';
    _wordsUseCtrl.text   = p.wordsToUse.join(', ');
    _wordsAvoidCtrl.text = p.wordsToAvoid.join(', ');
    _isGlobal            = p.isGlobal;
  }

  List<String> _splitWords(String text) => text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      if (isEdit) {
        final data = {
          'name':           _nameCtrl.text.trim(),
          'niche':          _nicheCtrl.text.trim().isEmpty ? null : _nicheCtrl.text.trim(),
          'voice_tone':     _voiceToneCtrl.text.trim().isEmpty ? null : _voiceToneCtrl.text.trim(),
          'description':    _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          'target_audience': _audienceCtrl.text.trim().isEmpty ? null : _audienceCtrl.text.trim(),
          'words_to_use':   _splitWords(_wordsUseCtrl.text),
          'words_to_avoid': _splitWords(_wordsAvoidCtrl.text),
          'is_global':      _isGlobal,
        };
        await ref.read(personaNotifierProvider.notifier).update(widget.personaId!, data);
      } else {
        final persona = Persona(
          id:             '',
          isGlobal:       _isGlobal,
          name:           _nameCtrl.text.trim(),
          niche:          _nicheCtrl.text.trim().isEmpty ? null : _nicheCtrl.text.trim(),
          voiceTone:      _voiceToneCtrl.text.trim().isEmpty ? null : _voiceToneCtrl.text.trim(),
          description:    _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          targetAudience: _audienceCtrl.text.trim().isEmpty ? null : _audienceCtrl.text.trim(),
          wordsToUse:     _splitWords(_wordsUseCtrl.text),
          wordsToAvoid:   _splitWords(_wordsAvoidCtrl.text),
          isActive:       true,
          createdAt:      DateTime.now(),
          updatedAt:      DateTime.now(),
        );
        await ref.read(personaNotifierProvider.notifier).create(persona);
      }
      ref.invalidate(personasProvider);
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
      final personaAsync = ref.watch(personaByIdProvider(widget.personaId!));
      personaAsync.whenData((p) {
        if (p != null && !_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _populateFromPersona(p));
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Persona' : 'Nova Persona'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Field(
                controller: _nameCtrl,
                label: 'Nome da Persona / Marca *',
                hint: 'Ex: Marca Pessoal do João',
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _nicheCtrl,
                label: 'Nicho / Segmento',
                hint: 'Ex: Marketing Digital, Fitness, Gastronomia',
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _voiceToneCtrl,
                label: 'Tom de Voz',
                hint: 'Ex: Descontraído e inspirador, Profissional e direto',
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _audienceCtrl,
                label: 'Público-alvo',
                hint: 'Ex: Empreendedores iniciantes de 25–40 anos',
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _descCtrl,
                label: 'Descrição / Posicionamento',
                hint: 'Descreva a essência desta persona ou marca...',
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _wordsUseCtrl,
                label: 'Palavras que DEVE usar (separadas por vírgula)',
                hint: 'Ex: inovação, transformação, resultado',
              ),
              const SizedBox(height: 16),
              _Field(
                controller: _wordsAvoidCtrl,
                label: 'Palavras que DEVE EVITAR (separadas por vírgula)',
                hint: 'Ex: barato, simples, fácil',
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  'Persona Global',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Visível para todos os usuários (apenas admin)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: _isGlobal,
                onChanged: (v) => setState(() => _isGlobal = v),
                activeColor: const Color(0xFFFFD700),
                tileColor: Colors.white.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.white12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                        isEdit ? 'Salvar Alterações' : 'Criar Persona',
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
