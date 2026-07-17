import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/persona.dart';

class PersonaService {
  final _client = Supabase.instance.client;

  Future<List<Persona>> fetchAll() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');

    // Traz globais + próprias
    final rows = await _client
        .from(AppConstants.tablePersonas)
        .select()
        .or('is_global.eq.true,owner_id.eq.$uid')
        .eq('is_active', true)
        .order('name');

    return (rows as List).map((r) => Persona.fromMap(r)).toList();
  }

  Future<Persona?> fetchById(String id) async {
    final row = await _client
        .from(AppConstants.tablePersonas)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Persona.fromMap(row);
  }

  Future<Persona> create(Persona persona) async {
    final row = await _client
        .from(AppConstants.tablePersonas)
        .insert(persona.toInsertMap())
        .select()
        .single();
    return Persona.fromMap(row);
  }

  Future<Persona> update(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from(AppConstants.tablePersonas)
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return Persona.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client
        .from(AppConstants.tablePersonas)
        .update({'is_active': false})
        .eq('id', id);
  }

  // Admin: buscar todas (globais + de qualquer usuário)
  Future<List<Persona>> fetchAllAdmin() async {
    final rows = await _client
        .from(AppConstants.tablePersonas)
        .select()
        .order('name');
    return (rows as List).map((r) => Persona.fromMap(r)).toList();
  }
}
