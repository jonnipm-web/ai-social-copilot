import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/brand.dart';
import '../../../../data/models/excerpt_result.dart';
import '../../../../data/services/editorial_service.dart';
import '../../../../providers/brand_provider.dart';
import '../../../../providers/editorial_provider.dart';
import '../../../../shared/widgets/admin_nav_drawer.dart';
import '../../../../shared/widgets/feature_gate.dart';

class ExcerptExtractorScreen extends ConsumerStatefulWidget {
  const ExcerptExtractorScreen({super.key});

  @override
  ConsumerState<ExcerptExtractorScreen> createState() =>
      _ExcerptExtractorScreenState();
}

class _ExcerptExtractorScreenState
    extends ConsumerState<ExcerptExtractorScreen> {
  final _textCtrl = TextEditingController();
  Brand? _selectedBrand;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    final text = _textCtrl.text.trim();
    if (text.length < 50) {
      showErrorSnack(context, 'Digite pelo menos 50 caracteres');
      return;
    }

    await ref
        .read(excerptNotifierProvider.notifier)
        .extract(text, brand: _selectedBrand);

    final state = ref.read(excerptNotifierProvider);
    if (state.hasError && mounted) {
      showErrorSnack(context, 'Erro: ${state.error}');
    } else if (state.hasValue && mounted) {
      // Salva no histórico
      await ref.read(editorialServiceProvider).saveToHistory(
            featureUsed: 'excerpt_extractor',
            brandId: _selectedBrand?.id,
            contentType: 'excerpts',
            inputText: text,
            outputText: 'Extraídos ${state.valueOrNull?.impactPhrases.length ?? 0} trechos',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(excerptNotifierProvider);
    final brandsAsync = ref.watch(brandsProvider);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Extrator de Trechos'),
          drawer: const AdminNavDrawer(),
        ),
        drawer: const AdminNavDrawer(),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                brandsAsync.whenOrNull(
                      data: (brands) => brands.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: DropdownButtonFormField<Brand?>(
                                value: _selectedBrand,
                                decoration: const InputDecoration(
                                    labelText: 'Marca (opcional)'),
                                items: [
                                  const DropdownMenuItem(
                                      value: null,
                                      child: Text('Sem marca')),
                                  ...brands.map((b) => DropdownMenuItem(
                                        value: b,
                                        child: Text(b.name),
                                      )),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedBrand = v),
                              ),
                            )
                          : null,
                    ) ??
                    const SizedBox.shrink(),
                TextFormField(
                  controller: _textCtrl,
                  maxLines: 8,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Texto-Base',
                    hintText: 'Cole aqui o capítulo ou texto para extrair trechos...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: resultAsync.isLoading ? null : _extract,
                  icon: resultAsync.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.format_quote_outlined, size: 18),
                  label: Text(resultAsync.isLoading
                      ? 'Extraindo...'
                      : 'Extrair Trechos'),
                ),
                if (resultAsync.hasValue && resultAsync.valueOrNull != null) ...[
                  const SizedBox(height: 24),
                  _ResultSection(result: resultAsync.value!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final ExcerptResult result;

  const _ResultSection({required this.result});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ListBlock(
            title: 'Frases de Impacto',
            icon: Icons.flash_on,
            items: result.impactPhrases,
          ),
          const SizedBox(height: 16),
          _ListBlock(
            title: 'Posts Curtos',
            icon: Icons.post_add,
            items: result.shortPosts,
          ),
          const SizedBox(height: 16),
          _ListBlock(
            title: 'Ideias de Carrossel',
            icon: Icons.view_carousel_outlined,
            items: result.carouselIdeas,
          ),
          const SizedBox(height: 16),
          _ListBlock(
            title: 'Roteiros de Vídeo Curto',
            icon: Icons.videocam_outlined,
            items: result.videoScripts,
          ),
          const SizedBox(height: 16),
          _SingleBlock(
              title: 'CTA de Compra', icon: Icons.shopping_cart_outlined, content: result.purchaseCta),
          const SizedBox(height: 12),
          _SingleBlock(
              title: 'CTA para Seguir', icon: Icons.person_add_outlined, content: result.followCta),
          const SizedBox(height: 32),
        ],
      );
}

class _ListBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _ListBlock(
      {required this.title, required this.icon, required this.items});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF6C63FF)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.asMap().entries.map(
                (e) => _ItemTile(index: e.key + 1, text: e.value),
              ),
        ],
      );
}

class _ItemTile extends StatelessWidget {
  final int index;
  final String text;

  const _ItemTile({required this.index, required this.text});

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
            Text(
              '$index.',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white38,
                  fontWeight: FontWeight.w600),
            ),
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

class _SingleBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;

  const _SingleBlock(
      {required this.title, required this.icon, required this.content});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF6C63FF)),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy,
                      size: 14, color: Colors.white38),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    showSuccessSnack(context, 'Copiado!');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(content,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ),
      );
}
