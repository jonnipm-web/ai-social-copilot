import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/brand.dart';
import '../../../../data/models/excerpt_result.dart';
import '../../../../data/models/persona.dart';
import '../../../../data/services/editorial_service.dart';
import '../../../../providers/brand_provider.dart';
import '../../../../providers/editorial_provider.dart';
import '../../../../providers/persona_provider.dart';
import '../../../../shared/widgets/admin_nav_drawer.dart';
import '../../../../shared/widgets/feature_gate.dart';

class RepurposingScreen extends ConsumerStatefulWidget {
  const RepurposingScreen({super.key});

  @override
  ConsumerState<RepurposingScreen> createState() => _RepurposingScreenState();
}

class _RepurposingScreenState extends ConsumerState<RepurposingScreen> {
  final _textCtrl = TextEditingController();
  Brand? _brand;
  Persona? _persona;
  String _platform = '';
  String _objective = '';

  static const _platforms = [
    '', 'Instagram', 'LinkedIn', 'YouTube', 'TikTok', 'Facebook', 'Twitter/X'
  ];
  static const _objectives = [
    '', 'Vendas', 'Autoridade', 'Engajamento', 'Seguidores', 'Lançamento'
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _repurpose() async {
    final text = _textCtrl.text.trim();
    if (text.length < 100) {
      showErrorSnack(context, 'Digite pelo menos 100 caracteres');
      return;
    }

    await ref.read(repurposingNotifierProvider.notifier).repurpose(
          text,
          brand: _brand,
          persona: _persona,
          platform: _platform,
          objective: _objective,
        );

    final state = ref.read(repurposingNotifierProvider);
    if (state.hasError && mounted) {
      showErrorSnack(context, 'Erro: ${state.error}');
    } else if (state.hasValue && mounted) {
      await ref.read(editorialServiceProvider).saveToHistory(
            featureUsed: 'repurposing',
            brandId: _brand?.id,
            personaId: _persona?.id,
            platform: _platform,
            objective: _objective,
            contentType: 'repurposed_content',
            inputText: text,
            outputText: 'Conteúdo reaproveitado com sucesso',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(repurposingNotifierProvider);
    final brandsAsync = ref.watch(brandsProvider);
    final personasAsync = _brand != null
        ? ref.watch(personasByBrandProvider(_brand!.id))
        : const AsyncValue<List<Persona>>.data([]);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: const Text('Motor de Reaproveitamento')),
        drawer: const AdminNavDrawer(),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: brandsAsync.whenOrNull(
                            data: (brands) => DropdownButtonFormField<Brand?>(
                              value: _brand,
                              decoration:
                                  const InputDecoration(labelText: 'Marca'),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('Nenhuma')),
                                ...brands.map((b) => DropdownMenuItem(
                                      value: b,
                                      child: Text(b.name),
                                    )),
                              ],
                              onChanged: (v) =>
                                  setState(() {
                                    _brand = v;
                                    _persona = null;
                                  }),
                            ),
                          ) ??
                          const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: personasAsync.whenOrNull(
                            data: (personas) => DropdownButtonFormField<Persona?>(
                              value: _persona,
                              decoration:
                                  const InputDecoration(labelText: 'Persona'),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('Nenhuma')),
                                ...personas.map((p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p.name),
                                    )),
                              ],
                              onChanged: (v) =>
                                  setState(() => _persona = v),
                            ),
                          ) ??
                          const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _platform,
                        decoration:
                            const InputDecoration(labelText: 'Plataforma'),
                        items: _platforms
                            .map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.isEmpty ? 'Todas' : p),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _platform = v ?? ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _objective,
                        decoration:
                            const InputDecoration(labelText: 'Objetivo'),
                        items: _objectives
                            .map((o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(o.isEmpty ? 'Geral' : o),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _objective = v ?? ''),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _textCtrl,
                  maxLines: 10,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Texto ou Capítulo',
                    hintText:
                        'Cole aqui o texto completo que deseja reaproveitar...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: resultAsync.isLoading ? null : _repurpose,
                  icon: resultAsync.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: Text(resultAsync.isLoading
                      ? 'Gerando...'
                      : 'Reaproveitar Conteúdo'),
                ),
                if (resultAsync.hasValue &&
                    resultAsync.valueOrNull != null) ...[
                  const SizedBox(height: 24),
                  _RepurposedResult(result: resultAsync.value!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RepurposedResult extends StatelessWidget {
  final RepurposedContent result;

  const _RepurposedResult({required this.result});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _copyableList('Posts Instagram/Facebook', Icons.image_outlined,
              result.instagramPosts),
          const SizedBox(height: 16),
          _copyableList(
              'Roteiros Reels/Shorts', Icons.videocam_outlined, result.reelsScripts),
          const SizedBox(height: 16),
          _copyableList(
              'Títulos Alternativos', Icons.title, result.alternativeTitles),
          const SizedBox(height: 16),
          _carousels(result.carousels),
          const SizedBox(height: 16),
          _longText('Artigo para Blog', Icons.article_outlined,
              result.blogArticle),
          const SizedBox(height: 12),
          _longText('E-mail', Icons.email_outlined, result.email),
          const SizedBox(height: 32),
        ],
      );

  Widget _copyableList(String title, IconData icon, List<String> items) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title, icon),
          const SizedBox(height: 8),
          ...items.asMap().entries.map(
                (e) => _CopyTile(index: e.key + 1, text: e.value),
              ),
        ],
      );

  Widget _carousels(List<Map<String, dynamic>> carousels) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Carrosséis Completos', Icons.view_carousel_outlined),
          const SizedBox(height: 8),
          ...carousels.asMap().entries.map((e) {
            final c = e.value;
            final slides = (c['slides'] as List?)?.cast<String>() ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Carrossel ${e.key + 1}: ${c['title'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...slides.asMap().entries.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Slide ${s.key + 1}: ${s.value}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      ),
                ],
              ),
            );
          }),
        ],
      );

  Widget _longText(String title, IconData icon, String content) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(title, icon),
          const SizedBox(height: 8),
          Builder(
            builder: (context) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(content,
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      showSuccessSnack(context, 'Copiado!');
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copiar'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        textStyle: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _sectionHeader(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      );
}

class _CopyTile extends StatelessWidget {
  final int index;
  final String text;

  const _CopyTile({required this.index, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$index.',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white38,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style:
                        const TextStyle(fontSize: 13, height: 1.4))),
            IconButton(
              icon: const Icon(Icons.copy, size: 14, color: Colors.white38),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: text));
                showSuccessSnack(context, 'Copiado!');
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
}
