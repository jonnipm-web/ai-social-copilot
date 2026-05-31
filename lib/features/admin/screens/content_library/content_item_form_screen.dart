import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/content_item.dart';
import '../../../../providers/brand_provider.dart';
import '../../../../providers/content_library_provider.dart';
import '../../../../shared/widgets/feature_gate.dart';

class ContentItemFormScreen extends ConsumerStatefulWidget {
  final String? itemId;

  const ContentItemFormScreen({super.key, this.itemId});

  bool get isEditing => itemId != null;

  @override
  ConsumerState<ContentItemFormScreen> createState() =>
      _ContentItemFormScreenState();
}

class _ContentItemFormScreenState
    extends ConsumerState<ContentItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  ContentItem? _original;
  bool _loading = false;
  String? _brandId;
  String _status = 'draft';

  late final _title = TextEditingController();
  late final _baseText = TextEditingController();
  late final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadItem();
  }

  Future<void> _loadItem() async {
    setState(() => _loading = true);
    try {
      final item =
          await ref.read(contentLibraryServiceProvider).fetchById(widget.itemId!);
      _original = item;
      _brandId = item.brandId;
      _title.text = item.title;
      _baseText.text = item.baseText;
      _notes.text = item.notes;
      _status = item.status;
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Erro ao carregar item');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = Supabase.instance.client.auth.currentUser!.id;
    final item = ContentItem(
      id: _original?.id ?? '',
      userId: uid,
      brandId: _brandId,
      title: _title.text.trim(),
      baseText: _baseText.text.trim(),
      notes: _notes.text.trim(),
      status: _status,
      createdAt: _original?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() => _loading = true);
    try {
      if (widget.isEditing) {
        await ref
            .read(contentLibraryNotifierProvider.notifier)
            .update(widget.itemId!, item.toInsertMap());
      } else {
        await ref.read(contentLibraryNotifierProvider.notifier).create(item);
      }
      if (mounted) {
        showSuccessSnack(
            context, widget.isEditing ? 'Item atualizado!' : 'Item criado!');
        context.go(AppConstants.routeAdminLibrary);
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, 'Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _baseText.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(brandsProvider);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Editar Item' : 'Novo Item'),
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
                        brandsAsync.whenOrNull(
                              data: (brands) => brands.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: DropdownButtonFormField<String?>(
                                        value: _brandId,
                                        decoration: const InputDecoration(
                                            labelText: 'Marca (opcional)'),
                                        items: [
                                          const DropdownMenuItem(
                                              value: null,
                                              child: Text('Sem marca')),
                                          ...brands.map((b) => DropdownMenuItem(
                                                value: b.id,
                                                child: Text(b.name),
                                              )),
                                        ],
                                        onChanged: (v) =>
                                            setState(() => _brandId = v),
                                      ),
                                    )
                                  : null,
                            ) ??
                            const SizedBox.shrink(),
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(labelText: 'Título *'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _baseText,
                          maxLines: 12,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: const InputDecoration(
                            labelText: 'Texto-Base *',
                            hintText: 'Cole aqui o capítulo ou texto completo...',
                            alignLabelWithHint: true,
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notes,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notas / Observações',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'draft', child: Text('Rascunho')),
                            DropdownMenuItem(value: 'in_use', child: Text('Em uso')),
                            DropdownMenuItem(value: 'used', child: Text('Utilizado')),
                            DropdownMenuItem(
                                value: 'archived', child: Text('Arquivado')),
                          ],
                          onChanged: (v) => setState(() => _status = v!),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _loading ? null : _save,
                          child: Text(widget.isEditing
                              ? 'Salvar Alterações'
                              : 'Salvar na Biblioteca'),
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
}
