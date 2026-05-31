import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/brand.dart';

class BrandService {
  final _db = Supabase.instance.client;

  Future<List<Brand>> fetchAll({bool includeArchived = false}) async {
    var query = _db.from('brands').select();
    if (!includeArchived) {
      query = query.neq('status', 'archived');
    }
    final rows = await query.order('created_at');
    return rows.map(Brand.fromMap).toList();
  }

  Future<Brand> fetchById(String id) async {
    final row = await _db.from('brands').select().eq('id', id).single();
    return Brand.fromMap(row);
  }

  Future<Brand> create(Brand brand) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final row = await _db
        .from('brands')
        .insert({...brand.toInsertMap(), 'user_id': uid})
        .select()
        .single();
    return Brand.fromMap(row);
  }

  Future<Brand> update(String id, Map<String, dynamic> fields) async {
    final row = await _db
        .from('brands')
        .update(fields)
        .eq('id', id)
        .select()
        .single();
    return Brand.fromMap(row);
  }

  Future<void> setStatus(String id, String status) async {
    await _db.from('brands').update({'status': status}).eq('id', id);
  }

  Future<void> seedInitialBrands() async {
    final existing = await _db.from('brands').select('id').limit(1);
    if (existing.isNotEmpty) return;

    final uid = Supabase.instance.client.auth.currentUser!.id;

    final seeds = [
      {
        'user_id': uid,
        'name': 'Mente Acelerada',
        'description': 'Conteúdo sobre saúde mental, foco e produtividade',
        'niche': 'saúde mental, foco, TDAH, ansiedade, sono, produtividade, performance',
        'target_audience': 'Pessoas que buscam alta performance e bem-estar mental',
        'tone_of_voice': 'Direto, prático, moderno e inteligente',
        'primary_language': 'pt-BR',
        'platforms': ['Instagram', 'LinkedIn', 'YouTube'],
        'default_ctas': ['Salve esse post', 'Compartilhe com alguém que precisa', 'Comente sua experiência'],
        'allowed_topics': ['foco', 'produtividade', 'TDAH', 'ansiedade', 'sono', 'performance', 'saúde mental'],
        'forbidden_topics': ['automedicação', 'diagnósticos médicos'],
        'writing_style': 'Linguagem acessível, científica mas não rebuscada. Frases curtas. Exemplos práticos.',
        'brand_prompt': 'Você escreve para a marca Mente Acelerada. Tom: direto, prático, moderno. Foco em saúde mental e produtividade. Evite linguagem clínica ou complexa.',
        'status': 'active',
      },
      {
        'user_id': uid,
        'name': 'ZoeLogos',
        'description': 'Conteúdo cristão sobre fé prática e propósito',
        'niche': 'fé prática, propósito, relacionamentos, trabalho, cristianismo',
        'target_audience': 'Cristãos que buscam integrar fé e vida cotidiana',
        'tone_of_voice': 'Pastoral, profundo, bíblico e aplicável',
        'primary_language': 'pt-BR',
        'platforms': ['Instagram', 'YouTube', 'WhatsApp'],
        'default_ctas': ['Compartilhe com um amigo', 'Salve para meditar', 'Comente uma palavra que te tocou'],
        'allowed_topics': ['fé', 'propósito', 'relacionamentos', 'trabalho', 'família', 'Bíblia'],
        'forbidden_topics': ['política partidária', 'denominações específicas'],
        'writing_style': 'Profundo mas acessível. Referências bíblicas aplicadas ao cotidiano. Esperançoso.',
        'brand_prompt': 'Você escreve para ZoeLogos. Tom: pastoral, profundo, bíblico. Sempre aplique a mensagem à vida prática. Linguagem acolhedora e esperançosa.',
        'status': 'active',
      },
      {
        'user_id': uid,
        'name': 'Filho Rico',
        'description': 'Educação financeira para crianças e famílias',
        'niche': 'educação financeira infantil, finanças familiares',
        'target_audience': 'Pais e responsáveis que querem educar filhos sobre dinheiro',
        'tone_of_voice': 'Educativo, familiar, claro e inspirador',
        'primary_language': 'pt-BR',
        'platforms': ['Instagram', 'YouTube', 'TikTok'],
        'default_ctas': ['Mostre para seu filho', 'Salve para aplicar hoje', 'Compartilhe com outros pais'],
        'allowed_topics': ['poupança', 'mesada', 'investimentos infantis', 'hábitos financeiros', 'empreendedorismo infantil'],
        'forbidden_topics': ['produtos financeiros específicos', 'promessas de retorno'],
        'writing_style': 'Lúdico e didático. Exemplos do cotidiano familiar. Linguagem simples para qualquer idade.',
        'brand_prompt': 'Você escreve para Filho Rico. Tom: educativo, familiar e inspirador. Foque em educação financeira infantil. Exemplos simples e práticos que pais e filhos entendem juntos.',
        'status': 'active',
      },
    ];

    for (final seed in seeds) {
      await _db.from('brands').insert(seed);
    }
  }
}
