import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/brand.dart';
import '../../../../providers/brand_provider.dart';
import '../../../../shared/widgets/feature_gate.dart';

class BrandFormScreen extends ConsumerStatefulWidget {
  final String? brandId;

  const BrandFormScreen({super.key, this.brandId});

  bool get isEditing => brandId != null;

  @override
  ConsumerState<BrandFormScreen> createState() => _BrandFormScreenState();
}

class _BrandFormScreenState extends ConsumerState<BrandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  Brand? _original;
  bool _loading = false;

  late final _name = TextEditingController();
  late final _description = TextEditingController();
  late final _niche = TextEditingController();
  late final _targetAudience = TextEditingController();
  late final _toneOfVoice = TextEditingController();
  late final _writingStyle = TextEditingController();
  late final _brandPrompt = TextEditingController();
  String _primaryLanguage = 'pt-BR';
  String _status = 'active';

  // Listas editáveis como texto separado por vírgulas
  late final _platforms = TextEditingController();
  late final _defaultCtas = TextEditingController();
  late final _allowedTopics = TextEditingController();
  late final _forbiddenTopics = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadBrand();
  }

  Future<void> _loadBrand() async {
    setState(() => _loading = true);
    try {
      final brand = await ref.read(brandServiceProvider).fetchById(widget.brandId!);
      _original = brand;
      _name.text = brand.name;
      _description.text = brand.description;
      _niche.text = brand.niche;
      _targetAudience.text = brand.targetAudience;
      _toneOfVoice.text = brand.toneOfVoice;
      _writingStyle.text = brand.writingStyle;
      _brandPrompt.text = brand.brandPrompt;
      _primaryLanguage = brand.primaryLanguage;
      _status = brand.status;
      _platforms.text = brand.platforms.join(', ');
      _defaultCtas.text = brand.defaultCtas.join('\n');
      _allowedTopics.text = brand.allowedTopics.join(', ');
      _forbiddenTopics.text = brand.forbiddenTopics.join(', ');
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Erro ao carregar marca');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _parseComma(String text) =>
      text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  List<String> _parseLines(String text) =>
      text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = Supabase.instance.client.auth.currentUser!.id;
    final brand = Brand(
      id: _original?.id ?? '',
      userId: uid,
      name: _name.text.trim(),
      description: _description.text.trim(),
      niche: _niche.text.trim(),
      targetAudience: _targetAudience.text.trim(),
      toneOfVoice: _toneOfVoice.text.trim(),
      primaryLanguage: _primaryLanguage,
      platforms: _parseComma(_platforms.text),
      defaultCtas: _parseLines(_defaultCtas.text),
      allowedTopics: _parseComma(_allowedTopics.text),
      forbiddenTopics: _parseComma(_forbiddenTopics.text),
      writingStyle: _writingStyle.text.trim(),
      brandPrompt: _brandPrompt.text.trim(),
      status: _status,
      createdAt: _original?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() => _loading = true);
    try {
      if (widget.isEditing) {
        await ref
            .read(brandNotifierProvider.notifier)
            .update(widget.brandId!, brand.toInsertMap());
      } else {
        await ref.read(brandNotifierProvider.notifier).create(brand);
      }
      if (mounted) {
        showSuccessSnack(context,
            widget.isEditing ? 'Marca atualizada!' : 'Marca criada!');
        context.go(AppConstants.routeAdminBrands);
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
    _niche.dispose();
    _targetAudience.dispose();
    _toneOfVoice.dispose();
    _writingStyle.dispose();
    _brandPrompt.dispose();
    _platforms.dispose();
    _defaultCtas.dispose();
    _allowedTopics.dispose();
    _forbiddenTopics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Editar Marca' : 'Nova Marca'),
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
                        _section('Identidade'),
                        _field('Nome da Marca *', _name, required: true),
                        _field('Descrição', _description, maxLines: 2),
                        _field('Nicho / Temas',
                            _niche,
                            hint: 'Ex: saúde, produtividade, fé'),
                        _field('Público-Alvo', _targetAudience, maxLines: 2),
                        const SizedBox(height: 16),
                        _section('Voz e Tom'),
                        _field('Tom de Voz', _toneOfVoice,
                            hint: 'Ex: direto, empático, profissional'),
                        _field('Estilo de Escrita', _writingStyle, maxLines: 3),
                        _field('Plataformas',
                            _platforms,
                            hint: 'Ex: Instagram, LinkedIn, YouTube'),
                        const SizedBox(height: 16),
                        _section('CTAs e Tópicos'),
                        _field('CTAs Padrão (um por linha)',
                            _defaultCtas,
                            maxLines: 4,
                            hint: 'Ex: Salve esse post\nCompartilhe com alguém'),
                        _field('Tópicos Permitidos',
                            _allowedTopics,
                            hint: 'Ex: foco, ansiedade, sono'),
                        _field('Tópicos Proibidos',
                            _forbiddenTopics,
                            hint: 'Ex: política, concorrentes'),
                        const SizedBox(height: 16),
                        _section('Prompt da Marca'),
                        const Text(
                          'Este texto é injetado na IA para guiar toda geração de conteúdo.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.white38, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        _field(
                          'Prompt da Marca',
                          _brandPrompt,
                          maxLines: 6,
                          hint:
                              'Descreva em detalhes como a IA deve escrever para esta marca...',
                        ),
                        const SizedBox(height: 16),
                        _section('Configurações'),
                        DropdownButtonFormField<String>(
                          value: _primaryLanguage,
                          decoration: const InputDecoration(
                              labelText: 'Idioma Principal'),
                          items: const [
                            DropdownMenuItem(
                                value: 'pt-BR', child: Text('Português (BR)')),
                            DropdownMenuItem(
                                value: 'en-US', child: Text('English (US)')),
                            DropdownMenuItem(
                                value: 'es-ES', child: Text('Español')),
                          ],
                          onChanged: (v) =>
                              setState(() => _primaryLanguage = v!),
                        ),
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
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : Text(widget.isEditing
                                  ? 'Salvar Alterações'
                                  : 'Criar Marca'),
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
