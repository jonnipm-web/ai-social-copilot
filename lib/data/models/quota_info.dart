/// Estado de cota de IA do usuário — espelha public.profiles.role/
/// monthly_limit + public.ai_usage.request_count (IVE-COMMERCIAL-
/// ENTITLEMENTS-01). O servidor é sempre a fonte da verdade; este modelo
/// só existe para exibição, nunca para decidir se uma ação é permitida.
class QuotaInfo {
  const QuotaInfo({
    required this.role,
    required this.limit,
    required this.used,
  });

  final String role;
  final int limit;
  final int used;

  int get remaining => (limit - used).clamp(0, limit);
  bool get isExhausted => used >= limit;
  double get fractionUsed => limit <= 0 ? 1.0 : (used / limit).clamp(0.0, 1.0);
  bool get isPro => role == 'pro' || role == 'premium' || role == 'admin';
}
