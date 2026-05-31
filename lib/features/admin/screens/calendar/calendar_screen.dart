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

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  Brand? _brand;
  Persona? _persona;
  String _objective = 'Engajamento';
  String _platform = 'Instagram';
  int _periodDays = 7;

  static const _platforms = [
    'Instagram', 'LinkedIn', 'YouTube', 'TikTok', 'Facebook', 'Twitter/X'
  ];
  static const _objectives = [
    'Vendas', 'Autoridade', 'Engajamento', 'Seguidores', 'Lançamento'
  ];
  static const _periods = [7, 15, 30];

  Future<void> _generate() async {
    if (_brand == null) {
      showErrorSnack(context, 'Selecione uma marca');
      return;
    }

    await ref.read(calendarNotifierProvider.notifier).generate(
          brand: _brand!,
          persona: _persona,
          objective: _objective,
          platform: _platform,
          periodDays: _periodDays,
        );

    final state = ref.read(calendarNotifierProvider);
    if (state.hasError && mounted) {
      showErrorSnack(context, 'Erro: ${state.error}');
    } else if (state.hasValue && mounted) {
      await ref.read(editorialServiceProvider).saveToHistory(
            featureUsed: 'editorial_calendar',
            brandId: _brand?.id,
            personaId: _persona?.id,
            platform: _platform,
            objective: _objective,
            contentType: 'calendar',
            inputText: 'Calendário $_periodDays dias — $_platform — $_objective',
            outputText: '${state.valueOrNull?.days.length ?? 0} dias gerados',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final calAsync = ref.watch(calendarNotifierProvider);
    final brandsAsync = ref.watch(brandsProvider);
    final personasAsync = _brand != null
        ? ref.watch(personasByBrandProvider(_brand!.id))
        : const AsyncValue<List<Persona>>.data([]);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: const Text('Calendário Editorial')),
        drawer: const AdminNavDrawer(),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Marca + Persona
                Row(
                  children: [
                    Expanded(
                      child: brandsAsync.whenOrNull(
                            data: (brands) =>
                                DropdownButtonFormField<Brand?>(
                              value: _brand,
                              decoration:
                                  const InputDecoration(labelText: 'Marca *'),
                              items: brands
                                  .map((b) => DropdownMenuItem(
                                        value: b,
                                        child: Text(b.name),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(
                                  () {
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
                            data: (personas) =>
                                DropdownButtonFormField<Persona?>(
                              value: _persona,
                              decoration: const InputDecoration(
                                  labelText: 'Persona'),
                              items: [
                                const DropdownMenuItem(
                                    value: null,
                                    child: Text('Nenhuma')),
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
                const SizedBox(height: 12),
                // Plataforma + Objetivo
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _platform,
                        decoration:
                            const InputDecoration(labelText: 'Plataforma'),
                        items: _platforms
                            .map((p) =>
                                DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _platform = v ?? 'Instagram'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _objective,
                        decoration:
                            const InputDecoration(labelText: 'Objetivo'),
                        items: _objectives
                            .map((o) =>
                                DropdownMenuItem(value: o, child: Text(o)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _objective = v ?? 'Engajamento'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Período
                const Text('Período',
                    style: TextStyle(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 8),
                Row(
                  children: _periods
                      .map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$d dias'),
                            selected: _periodDays == d,
                            onSelected: (_) =>
                                setState(() => _periodDays = d),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: calAsync.isLoading ? null : _generate,
                  icon: calAsync.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(calAsync.isLoading
                      ? 'Gerando calendário...'
                      : 'Gerar Calendário'),
                ),
                if (calAsync.hasValue && calAsync.valueOrNull != null) ...[
                  const SizedBox(height: 24),
                  _CalendarResult(plan: calAsync.value!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarResult extends StatelessWidget {
  final CalendarPlan plan;

  const _CalendarResult({required this.plan});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  size: 14, color: Color(0xFF6C63FF)),
              const SizedBox(width: 6),
              Text(
                '${plan.periodDays} dias — ${plan.platform} — ${plan.objective}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...plan.days.map((day) => _DayCard(day: day)),
        ],
      );
}

class _DayCard extends StatelessWidget {
  final CalendarDay day;

  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C63FF)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.theme,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(day.format,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14, color: Colors.white38),
                  onPressed: () {
                    final text =
                        'Dia ${day.day}\nTema: ${day.theme}\nFormato: ${day.format}\nGancho: ${day.hook}\nCTA: ${day.cta}\nNota: ${day.strategicNote}';
                    Clipboard.setData(ClipboardData(text: text));
                    showSuccessSnack(context, 'Dia copiado!');
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (day.hook.isNotEmpty) ...[
              const SizedBox(height: 8),
              _label('Gancho:', day.hook),
            ],
            if (day.cta.isNotEmpty) _label('CTA:', day.cta),
            if (day.strategicNote.isNotEmpty)
              _label('Nota estratégica:', day.strategicNote,
                  color: Colors.white38),
          ],
        ),
      );

  Widget _label(String prefix, String value,
          {Color color = Colors.white70}) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 12, color: color, height: 1.4),
            children: [
              TextSpan(
                  text: '$prefix ',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}
