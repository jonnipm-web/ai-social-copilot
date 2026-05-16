import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart';
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

    final result =
        await ref.read(postNotifierProvider.notifier).improvePost(text);

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
      body: Padding(
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
                style: const TextStyle(fontSize: 15, height: 1.6),
                decoration: const InputDecoration(
                  hintText:
                      'Ex: Hoje aprendi algo incrível sobre produtividade...',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 20),
            LoadingButton(
              label: '✨  Melhorar post',
              isLoading: isLoading,
              onPressed: _improve,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
