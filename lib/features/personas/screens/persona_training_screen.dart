import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/persona_training.dart';
import '../../../providers/persona_training_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

const _bgColor = Color(0xFF0F0F1A);
const _primaryColor = Color(0xFF6C63FF);
const _cardColor = Color(0xFF1A1A2E);
const _surfaceColor = Color(0xFF16213E);
const _textSecondary = Color(0xFF9E9E9E);

class PersonaTrainingScreen extends ConsumerWidget {
  final String personaId;
  final String personaName;

  const PersonaTrainingScreen({
    super.key,
    required this.personaId,
    required this.personaName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingAsync = ref.watch(personaTrainingProvider(personaId));

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(
          'Treinamento: $personaName',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: _cardColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: trainingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _primaryColor),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar treinamentos: $error',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (trainings) {
          if (trainings.isEmpty) {
            return _EmptyState();
          }
          return _TrainingContent(
            trainings: trainings,
            personaId: personaId,
            ref: ref,
          );
        },
      ),
    );
  }
}

class _TrainingContent extends StatelessWidget {
  final List<PersonaTraining> trainings;
  final String personaId;
  final WidgetRef ref;

  const _TrainingContent({
    required this.trainings,
    required this.personaId,
    required this.ref,
  });

  List<String> _combinedUniqueVocabulary() {
    final all = <String>{};
    for (final t in trainings) {
      all.addAll(t.vocabularyJson);
    }
    return all.toList();
  }

  List<String> _combinedUniqueValues() {
    final all = <String>{};
    for (final t in trainings) {
      all.addAll(t.brandValuesJson);
    }
    return all.toList();
  }

  Map<String, dynamic>? _mostRecentToneProfile() {
    if (trainings.isEmpty) return null;
    final sorted = List<PersonaTraining>.from(trainings)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.first.toneProfileJson;
  }

  @override
  Widget build(BuildContext context) {
    final vocabulary = _combinedUniqueVocabulary();
    final values = _combinedUniqueValues();
    final toneProfile = _mostRecentToneProfile();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(
          count: trainings.length,
          toneProfile: toneProfile,
          vocabulary: vocabulary,
          values: values,
        ),
        const SizedBox(height: 20),
        const Text(
          'Histórico de Treinamentos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        ...trainings.map(
          (training) => _TrainingItemCard(
            training: training,
            personaId: personaId,
            ref: ref,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int count;
  final Map<String, dynamic>? toneProfile;
  final List<String> vocabulary;
  final List<String> values;

  const _SummaryCard({
    required this.count,
    required this.toneProfile,
    required this.vocabulary,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology, color: _primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Resumo do Treinamento',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            icon: Icons.layers,
            label: 'Itens treinados',
            value: '$count ${count == 1 ? "item" : "itens"}',
          ),
          if (toneProfile != null && toneProfile!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Perfil de Tom (mais recente)',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _ToneProfileDisplay(toneProfile: toneProfile!),
          ],
          if (vocabulary.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Vocabulário Combinado',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _ChipWrap(
              items: vocabulary.take(10).toList(),
              color: _primaryColor,
            ),
          ],
          if (values.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Valores Combinados',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _ChipWrap(
              items: values,
              color: const Color(0xFF9C27B0),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: _textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ToneProfileDisplay extends StatelessWidget {
  final Map<String, dynamic> toneProfile;

  const _ToneProfileDisplay({required this.toneProfile});

  @override
  Widget build(BuildContext context) {
    final entries = toneProfile.entries.toList();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: entries.map((e) {
        final value = e.value;
        final display = value is double
            ? '${(value * 100).toStringAsFixed(0)}%'
            : value.toString();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _primaryColor.withOpacity(0.3)),
          ),
          child: Text(
            '${e.key}: $display',
            style: const TextStyle(
              color: _primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> items;
  final Color color;

  const _ChipWrap({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(
                item,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TrainingItemCard extends StatelessWidget {
  final PersonaTraining training;
  final String personaId;
  final WidgetRef ref;

  const _TrainingItemCard({
    required this.training,
    required this.personaId,
    required this.ref,
  });

  String _formattedDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remover treinamento?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Este item de treinamento será removido permanentemente da persona.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(personaTrainingServiceProvider).delete(training.id);
      ref.invalidate(personaTrainingProvider(personaId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocabulary = training.vocabularyJson;
    final tone = training.tone ?? '';

    return Dismissible(
      key: Key(training.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 28),
      ),
      confirmDismiss: (_) async {
        await _delete(context);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _primaryColor.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.article_outlined,
                      color: _primaryColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          training.trainingSummary ?? 'Item sem título',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formattedDate(training.createdAt),
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    tooltip: 'Remover',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              if (tone.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: _textSecondary, size: 14),
                    const SizedBox(width: 6),
                    const Text(
                      'Tom: ',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _primaryColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        tone,
                        style: const TextStyle(
                          color: _primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (vocabulary.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'Vocabulário:',
                  style: TextStyle(color: _textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: vocabulary
                      .take(6)
                      .map(
                        (word) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF9C27B0).withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            word,
                            style: const TextStyle(
                              color: Color(0xFFCE93D8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                if (vocabulary.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${vocabulary.length - 6} palavras',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primaryColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.psychology_outlined,
                color: _primaryColor,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum treinamento ainda.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Analise um item no Cofre de Conhecimento e clique em Treinar Persona.',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
