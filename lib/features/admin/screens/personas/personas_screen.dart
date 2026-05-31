import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/persona.dart';
import '../../../../providers/brand_provider.dart';
import '../../../../providers/persona_provider.dart';
import '../../../../shared/widgets/admin_nav_drawer.dart';
import '../../../../shared/widgets/feature_gate.dart';

class PersonasScreen extends ConsumerStatefulWidget {
  const PersonasScreen({super.key});

  @override
  ConsumerState<PersonasScreen> createState() => _PersonasScreenState();
}

class _PersonasScreenState extends ConsumerState<PersonasScreen> {
  String? _selectedBrandId;

  @override
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(brandsProvider);
    final personasAsync = _selectedBrandId != null
        ? ref.watch(personasByBrandProvider(_selectedBrandId!))
        : ref.watch(allPersonasProvider);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Personas'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push(AppConstants.routeAdminPersonasNew),
            ),
          ],
        ),
        drawer: const AdminNavDrawer(),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
            child: Column(
              children: [
                // Filtro por marca
                brandsAsync.whenOrNull(
                      data: (brands) => brands.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: DropdownButtonFormField<String?>(
                                value: _selectedBrandId,
                                decoration: const InputDecoration(
                                    labelText: 'Filtrar por Marca'),
                                items: [
                                  const DropdownMenuItem(
                                      value: null,
                                      child: Text('Todas as marcas')),
                                  ...brands.map((b) => DropdownMenuItem(
                                        value: b.id,
                                        child: Text(b.name),
                                      )),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedBrandId = v),
                              ),
                            )
                          : null,
                    ) ??
                    const SizedBox.shrink(),
                const SizedBox(height: 8),
                Expanded(
                  child: personasAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                        child: Text('Erro: $e',
                            style: const TextStyle(color: Colors.white54))),
                    data: (personas) {
                      if (personas.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 48, color: Colors.white12),
                              SizedBox(height: 16),
                              Text('Nenhuma persona criada',
                                  style: TextStyle(color: Colors.white38)),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: personas.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _PersonaCard(persona: personas[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonaCard extends ConsumerWidget {
  final Persona persona;

  const _PersonaCard({required this.persona});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
            '${AppConstants.routeAdminPersonas}/${persona.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF03DAC6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.person_outline,
                      color: Color(0xFF03DAC6), size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(persona.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    if (persona.audienceProfile.isNotEmpty)
                      Text(
                        persona.audienceProfile,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white38),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (val) async {
                  await ref
                      .read(personaNotifierProvider.notifier)
                      .setStatus(persona.id, persona.brandId, val);
                  if (context.mounted) {
                    showSuccessSnack(context, 'Status atualizado!');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'active', child: Text('Ativar')),
                  PopupMenuItem(value: 'inactive', child: Text('Desativar')),
                  PopupMenuItem(value: 'archived', child: Text('Arquivar')),
                ],
                icon: const Icon(Icons.more_vert,
                    size: 18, color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
