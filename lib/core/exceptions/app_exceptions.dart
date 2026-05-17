class LimitReachedException implements Exception {
  const LimitReachedException();
  @override
  String toString() => 'Limite de gerações gratuitas atingido este mês.';
}
