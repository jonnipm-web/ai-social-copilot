import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart'
    show showErrorSnack, showSuccessSnack, extractErrorMessage;
import '../../../data/models/post_generation.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/post_provider.dart';
import '../../../shared/widgets/loading_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _textCtrl = TextEditingController();
  int _charCount = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() {
      setState(() => _charCount = _textCtrl.text.length);
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _improve() async {
    final text = _textCtrl.text.trim();
    if (text.length < AppConstants.minTextLength) {
      showErrorSnack(
        context,
        'Escreva pelo menos ${AppConstants.minTextLength} caracteres.',
      );
      return;
    }

    _startTime = DateTime.now();

    final result =
        await ref.read(postNotifierProvider.notifier).improvePost(text);

    if (!mounted) return;

    final state = ref.read(postNotifierProvider);
    if (state.hasError) {
      showErrorSnack(context, extractErrorMessage(state.error));
      return;
    }

    if (result != null) {
      final elapsed = _startTime != null
          ? DateTime.now().difference(_startTime!).inMilliseconds / 1000
          : null;

      if (mounted) showSuccessSnack(context, 'Resultado gerado com sucesso!');

      context.push(AppConstants.routeResult, extra: {
        'originalText': text,
        'result': _generationToMap(result),
        'processingSeconds': elapsed,
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

  Future<void> _clear() async {
    if (_textCtrl.text.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar texto'),
        content: const Text('Deseja apagar todo o conteúdo digitado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Limpar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) _textCtrl.clear();
  }

  Future<void> _signOut() async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go(AppConstants.routeLogin);
  }

  Color _counterColor() {
    if (_charCount >= AppConstants.maxTextLength) return Colors.red;
    if (_charCount >= AppConstants.maxTextLength - 200) return Colors.orange;
    if (_charCount >= AppConstants.maxTextLength - 500) return Colors.amber;
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    final postState = ref.watch(postNotifierProvider);
    final isLoading = postState.isLoading;

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Cole ou escreva seu post',
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
                    maxLength: AppConstants.maxTextLength,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                        const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 15, height: 1.6),
                    decoration: const InputDecoration(
                      hintText:
                          'Ex: Hoje aprendi algo incrível sobre produtividade...',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '$_charCount / ${AppConstants.maxTextLength} caracteres',
                      style: TextStyle(
                        fontSize: 12,
                        color: _counterColor(),
                      ),
                    ),
                    const Spacer(),
                    if (_charCount > 0)
                      TextButton.icon(
                        onPressed: isLoading ? null : _clear,
                        icon: const Icon(Icons.clear, size: 14),
                        label: const Text('Limpar'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white38,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LoadingButton(
                  label: '✨  Melhorar post',
                  loadingLabel: 'Analisando seu conteúdo...',
                  isLoading: isLoading,
                  onPressed: _improve,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
