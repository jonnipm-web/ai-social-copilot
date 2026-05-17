import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/niches.dart';
import '../../../providers/profile_provider.dart';

class NicheScreen extends ConsumerStatefulWidget {
  const NicheScreen({super.key, this.onSaved});

  final VoidCallback? onSaved;

  @override
  ConsumerState<NicheScreen> createState() => _NicheScreenState();
}

class _NicheScreenState extends ConsumerState<NicheScreen> {
  String? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(profileProvider).valueOrNull?.niche ?? 'geral';
  }

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _saving = true);
    await ref.read(profileProvider.notifier).saveNiche(_selected!);
    if (mounted) {
      setState(() => _saving = false);
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Qual é o seu nicho?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'A IA vai adaptar o tom e as hashtags automaticamente.',
            style: TextStyle(fontSize: 13, color: Colors.white60),
          ),
        ),
        const SizedBox(height: 20),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: niches.length,
            itemBuilder: (_, i) {
              final n = niches[i];
              final isSelected = _selected == n.id;
              return GestureDetector(
                onTap: () => setState(() => _selected = n.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(n.emoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 6),
                      Text(
                        n.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton(
            onPressed: (_selected == null || _saving) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirmar nicho'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

void showNicheSheet(BuildContext context, {VoidCallback? onSaved}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => NicheScreen(onSaved: onSaved ?? () => Navigator.pop(context)),
  );
}
