import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/persona.dart';

class PersonaService {
  final _db = Supabase.instance.client;

  Future<List<Persona>> fetchByBrand(String brandId,
      {bool includeArchived = false}) async {
    var query = _db.from('personas').select().eq('brand_id', brandId);
    if (!includeArchived) {
      query = query.neq('status', 'archived');
    }
    final rows = await query.order('created_at');
    return rows.map(Persona.fromMap).toList();
  }

  Future<List<Persona>> fetchAll({bool includeArchived = false}) async {
    var query = _db.from('personas').select();
    if (!includeArchived) {
      query = query.neq('status', 'archived');
    }
    final rows = await query.order('created_at');
    return rows.map(Persona.fromMap).toList();
  }

  Future<Persona> fetchById(String id) async {
    final row = await _db.from('personas').select().eq('id', id).single();
    return Persona.fromMap(row);
  }

  Future<Persona> create(Persona persona) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final row = await _db
        .from('personas')
        .insert({...persona.toInsertMap(), 'user_id': uid})
        .select()
        .single();
    return Persona.fromMap(row);
  }

  Future<Persona> update(String id, Map<String, dynamic> fields) async {
    final row = await _db
        .from('personas')
        .update(fields)
        .eq('id', id)
        .select()
        .single();
    return Persona.fromMap(row);
  }

  Future<void> setStatus(String id, String status) async {
    await _db.from('personas').update({'status': status}).eq('id', id);
  }
}
