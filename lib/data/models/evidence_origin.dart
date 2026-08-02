enum EvidenceOrigin {
  userProvided,
  documentExtracted,
  analysisDerived,
  externallyVerified,
  inferred,
  unknown;

  String toJson() => name;

  static EvidenceOrigin fromJson(String? value) {
    return EvidenceOrigin.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EvidenceOrigin.unknown,
    );
  }
}
