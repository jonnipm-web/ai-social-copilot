import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/niches.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/post_generation.dart';
import '../../../features/niche/screens/niche_screen.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/post_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/loading_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _textCtrl = TextEditingController();
  final _picker = ImagePicker();
  File? _selectedImage;
  bool _nicheSheetShown = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeShowNicheSheet();
  }

  void _maybeShowNicheSheet() {
    if (_nicheSheetShown) return;
    final profileState = ref.read(profileProvider);
    // Quando o perfil carregou e é null (primeiro acesso), mostra seleção de nicho
    if (profileState is AsyncData && profileState.value == null) {
      _nicheSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showNicheSheet(context);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _selectedImage = File(picked.path));
    } catch (_) {
      if (mounted) {
        showErrorSnack(context, 'Não foi possível acessar a câmera/galeria.');
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Adicionar foto',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Câmera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _removeImage() => setState(() => _selectedImage = null);

  void _applyTemplate(String template) {
    _textCtrl.text = template;
    _textCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: template.length),
    );
  }

  Future<void> _generate() async {
    final text = _textCtrl.text.trim();
    final hasImage = _selectedImage != null;

    if (!hasImage && text.length < AppConstants.minTextLength) {
      showErrorSnack(
        context,
        'Escreva pelo menos ${AppConstants.minTextLength} caracteres.',
      );
      return;
    }

    final nicheHint =
        nicheById(ref.read(profileProvider.notifier).currentNiche)
            .systemPromptHint;

    final result = await ref
        .read(postNotifierProvider.notifier)
        .improvePost(text, imageFile: _selectedImage, nicheHint: nicheHint);

    if (!mounted) return;

    final state = ref.read(postNotifierProvider);
    if (state.hasError) {
      showErrorSnack(context, state.error.toString());
      return;
    }

    if (result != null) {
      context.push(AppConstants.routeResult, extra: {
        'originalText': text,
        'result': _generationToMap(result),
      });
    }
  }

  Map<String, dynamic> _generationToMap(PostGeneration g) => {
        'improved_text': g.improvedText,
        'professional_version': g.professionalVersion,
        'casual_version': g.casualVersion,
        'persuasive_version': g.persuasiveVersion,
        'comment_reply': g.commentReply,
        'scores': {
          'clarity': g.clarityScore,
          'impact': g.impactScore,
          'engagement': g.engagementScore,
        },
        '_generation': g,
      };

  Future<void> _signOut() async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go(AppConstants.routeLogin);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(postNotifierProvider).isLoading;
    final hasImage = _selectedImage != null;

    // Detecta perfil carregado para mostrar sheet no primeiro acesso
    ref.listen(profileProvider, (_, next) {
      if (next is AsyncData && next.value == null && !_nicheSheetShown) {
        _nicheSheetShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showNicheSheet(context);
        });
      }
    });

    final profileState = ref.watch(profileProvider);
    final nicheId =
        profileState.valueOrNull?.niche ?? 'geral';
    final niche = nicheById(nicheId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Histórico',
            onPressed: () => context.push(AppConstants.routeHistory),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sair',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Chip de nicho
            _NicheChip(
              niche: niche,
              onTap: () => showNicheSheet(context),
            ),
            const SizedBox(height: 16),

            // Prévia da imagem selecionada
            if (hasImage) ...[
              _ImagePreview(
                file: _selectedImage!,
                onRemove: _removeImage,
              ),
              const SizedBox(height: 12),
            ],

            Text(
              hasImage
                  ? 'Contexto adicional (opcional)'
                  : 'Cole ou escreva seu post',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: TextFormField(
                controller: _textCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 15, height: 1.6),
                decoration: InputDecoration(
                  hintText: hasImage
                      ? 'Ex: produto novo, evento especial...'
                      : 'Ex: Hoje aprendi algo incrível sobre produtividade...',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Templates do nicho
            _TemplateChips(
              templates: niche.templates,
              onSelected: _applyTemplate,
            ),
            const SizedBox(height: 12),

            // Botão câmera/galeria
            OutlinedButton.icon(
              onPressed: isLoading ? null : _showImageSourceSheet,
              icon: Icon(
                hasImage
                    ? Icons.camera_alt_rounded
                    : Icons.add_a_photo_outlined,
                size: 18,
              ),
              label: Text(hasImage ? 'Trocar foto' : 'Adicionar foto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 10),

            LoadingButton(
              label:
                  hasImage ? '✨  Gerar post da foto' : '✨  Melhorar post',
              isLoading: isLoading,
              onPressed: _generate,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ── Widgets internos ────────────────────────────────────────────────────────

class _NicheChip extends StatelessWidget {
  const _NicheChip({required this.niche, required this.onTap});

  final NicheDefinition niche;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(niche.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              niche.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit_rounded, size: 13, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _TemplateChips extends StatelessWidget {
  const _TemplateChips({required this.templates, required this.onSelected});

  final List<String> templates;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = templates[i];
          return GestureDetector(
            onTap: () => onSelected(t),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                t,
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.file, required this.onRemove});

  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
