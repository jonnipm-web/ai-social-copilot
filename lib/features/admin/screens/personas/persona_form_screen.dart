import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/persona.dart';
import '../../../../providers/brand_provider.dart';
import '../../../../providers/persona_provider.dart';
import '../../../../shared/widgets/feature_gate.dart';

class PersonaFormScreen extends ConsumerStatefulWidget {
  final String? personaId;

  const PersonaFormScreen({super.key, this.personaId});

  bool get isEditing => personaId != null;

  @override
  ConsumerState<PersonaFormScreen> createState() => _PersonaFormScreenState();
}

class _PersonaFormScreenState extends ConsumerState<PersonaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  Persona? _original;
  bool _loading = false;
  String? _brandId;

  late final _name = TextEditingController();
  late final _description = TextEditingController();
  late final _audienceProfile = TextEditingController();
  late final _communicationStyle = TextEditingController();
  late final _personaPrompt = TextEditingController();
  late final _painPoints = TextEditingController();
  late final _desires = TextEditingController();
  late final _objections = TextEditingController();
  late final _preferredHooks = TextEditingController();
  late final _avoidedLanguage = TextEditingController();
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadPersona();
  }

  Future<void> _loadPersona() async {
    setState(() => _loading = true);
    try {
      final persona =
          await ref.read(personaServiceProvider).fetchById(widget.personaId!);
      _original = persona;
      _brandId = persona.brandId;
      _name.text = persona.name;
      _description.text = persona.description;
      _audienceProfile.text = persona.audienceProfile;
      _communicationStyle.text = persona.communicationStyle;
      _personaPrompt.text = persona.personaPrompt;
      _painPoints.text = persona.painPoints.join('\n');
      _desires.text = persona.desires.join('\n');
      _objections.text = persona.objections.join('\n');
      _preferredHooks.text = persona.preferredHooks.join('\n');
      _avoidedLanguage.text = persona.avoidedLanguage.join(', ');
      _status = persona.status;
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Erro ao carregar persona');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _parseLines(String text) =>
      text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  List<String> _parseComma(String text) =>
      text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_brandId == null) {
      showErrorSnack(context, 'Selecione uma marca');
      return;
    }

    final uid = Supabase.instance.client.auth.currentUser!.id;
    final persona = Persona(
      id: _original?.id ?? '',
      userId: uid,
      brandId: _brandId!,
      name: _name.text.trim(),
      description: _description.text.trim(),
      audienceProfile: _audienceProfile.text.trim(),
      painPoints: _parseLines(_painPoints.text),
      desires: _parseLines(_desires.text),
      objections: _parseLines(_objections.text),
      communicationStyle: _communicationStyle.text.trim(),
      preferredHooks: _parseLines(_preferredHooks.text),
      avoidedLanguage: _parseComma(_avoidedLanguage.text),
      personaPrompt: _personaPrompt.text.trim(),
      status: _status,
      createdAt: _original?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() => _loading = true);
    try {
      if (widget.isEditing) {
        await ref
            .read(personaNotifierProvider.notifier)
            .update(widget.personaId!, _brandId!, persona.toInsertMap());
      } else {
        await ref.read(personaNotifierProvider.notifier).create(persona);
      }
      if (mounted) {
        showSuccessSnack(context,
            widget.isEditing ? 'Persona atualizada!' : 'Persona criada!');
        context.go(AppConstants.routeAdminPersonas);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _audienceProfile.dispose();
    _communicationStyle.dispose();
    _personaPrompt.dispose();
    _painPoints.dispose();
    _desires.dispose();
    _objections.dispose();
    _preferredHooks.dispose();
    _avoidedLanguage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(brandsProvider);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Editar Persona' : 'Nova Persona'),
          actions: [
            TextButton(
              onPressed: _loading ? null : _save,
              child: const Text('Salvar',
                  style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        body: _loading && _original == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _section('Vínculo'),
                        brandsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (brands) => DropdownButtonFormField<String>(
                            value: _brandId,
                            decoration:
                                const InputDecoration(labelText: 'Marca *'),
                            items: brands
                                .map((b) => DropdownMenuItem(
                                      value: b.id,
                                      child: Text(b.name),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _brandId = v),
                            validator: (v) =>
                                v == null ? 'Selecione uma marca' : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _section('Identidade'),
                        _field('Nome da Persona *', _name, required: true),
                        _field('Descrição', _description, maxLines: 2),
                        _field('Perfil do Público', _audienceProfile,
                            maxLines: 3,
                            hint: 'Quem é essa persona? Idade, rotina, contexto...'),
                        const SizedBox(height: 16),
                        _section('Psicografia'),
                        _field('Dores / Problemas (um por linha)',
                            _painPoints,
                            maxLines: 4),
                        _field('Desejos / Objetivos (um por linha)', _desires,
                            maxLines: 4),
                        _field('Objeções (um por linha)', _objections,
                            maxLines: 3),
                        const SizedBox(height: 16),
                        _section('Comunicação'),
                        _field('Estilo de Comunicação', _communicationStyle,
                            maxLines: 2),
                        _field('Ganchos Preferidos (um por linha)',
                            _preferredHooks,
                            maxLines: 3),
                        _field('Linguagem a Evitar (separar por vírgula)',
                            _avoidedLanguage),
                        const SizedBox(height: 16),
                        _section('Prompt da Persona'),
                        _field('Prompt da Persona', _personaPrompt,
                            maxLines: 5,
                            hint:
                                'Instruções para a IA sobre como falar COM essa persona...'),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration:
                              const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(
                                value: 'active', child: Text('Ativa')),
                            DropdownMenuItem(
                                value: 'inactive', child: Text('Inativa')),
                            DropdownMenuItem(
                                value: 'archived', child: Text('Arquivada')),
                          ],
                          onChanged: (v) => setState(() => _status = v!),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _loading ? null : _save,
                          child: Text(widget.isEditing
                              ? 'Salvar Alterações'
                              : 'Criar Persona'),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white38,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    String? hint,
    bool required = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            alignLabelWithHint: maxLines > 1,
          ),
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null
              : null,
        ),
      );
}
