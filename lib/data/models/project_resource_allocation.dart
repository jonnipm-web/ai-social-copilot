// IVE-COMMERCIAL-EXPERIENCE-12 (Phase B) — the persisted, per-project
// counterpart to lib/data/models/resource_allocation.dart's
// `ResourceAllocation`/`AllocationItem` (that pair remains the unrelated
// PORTFOLIO-WIDE "split a global budget across all projects" simulation
// on resource_allocation_screen.dart — untouched by this mission). This
// model is the CURRENT SAVED STATE for one specific project.
//
// Money is stored/transmitted as integer minor units (cents), never a
// double — mission Section 10. `hoursAllocated` is a plain non-negative
// int with the same upper bound as the database CHECK constraint
// (supabase/migrations/20260917000000_project_resource_allocations.sql).
class ProjectResourceAllocation {
  const ProjectResourceAllocation({
    required this.projectId,
    required this.hoursAllocated,
    required this.budgetAllocatedCents,
    required this.currency,
    required this.updatedAt,
  });

  final String projectId;
  final int hoursAllocated;
  final int budgetAllocatedCents;
  final String currency;
  final DateTime updatedAt;

  static const int maxHours = 100000;

  // Codex Gate 1 (mission 12, Phase B) P2 — parseMoneyInputToCents had no
  // application-level maximum, so a pasted string with an unbounded
  // number of digits could reach int.parse with no upper bound (well
  // under PostgreSQL bigint's real ~9.2e18 max, but a sane one for any
  // realistic project budget, and one this app can actually round-trip
  // through a 64-bit int without surprises on Dart web/JS).
  static const int maxBudgetAllocatedCents = 999999999999; // R$ 9.999.999.999,99

  /// The zero-state for a project that has never saved an allocation —
  /// distinct from "failed to load" (that stays a thrown error / null,
  /// never silently coerced to this).
  factory ProjectResourceAllocation.empty(String projectId) => ProjectResourceAllocation(
        projectId: projectId,
        hoursAllocated: 0,
        budgetAllocatedCents: 0,
        currency: 'BRL',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  factory ProjectResourceAllocation.fromMap(Map<String, dynamic> map) => ProjectResourceAllocation(
        projectId: map['project_id'] as String,
        hoursAllocated: (map['hours_allocated'] as num).toInt(),
        budgetAllocatedCents: (map['budget_allocated_cents'] as num).toInt(),
        currency: map['currency'] as String? ?? 'BRL',
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toUpsertMap() => {
        'project_id': projectId,
        'hours_allocated': hoursAllocated,
        'budget_allocated_cents': budgetAllocatedCents,
        'currency': currency,
      };

  /// Display-only conversion — never round-tripped back into a stored
  /// value (that always goes through the exact-integer cents field).
  double get budgetAllocatedDisplay => budgetAllocatedCents / 100;

  ProjectResourceAllocation copyWith({int? hoursAllocated, int? budgetAllocatedCents, String? currency}) =>
      ProjectResourceAllocation(
        projectId: projectId,
        hoursAllocated: hoursAllocated ?? this.hoursAllocated,
        budgetAllocatedCents: budgetAllocatedCents ?? this.budgetAllocatedCents,
        currency: currency ?? this.currency,
        updatedAt: updatedAt,
      );
}

/// Pure validation — mission Section 11: "No NaN/infinity/negative
/// allocation", bounded upper range. Extracted as a free function so it
/// is directly unit-testable without constructing a widget/provider.
String? validateHoursAllocated(int hours) {
  if (hours < 0) return 'Horas não podem ser negativas.';
  if (hours > ProjectResourceAllocation.maxHours) {
    return 'Valor de horas excede o limite permitido.';
  }
  return null;
}

String? validateBudgetAllocatedCents(int cents) {
  if (cents < 0) return 'Orçamento não pode ser negativo.';
  if (cents > ProjectResourceAllocation.maxBudgetAllocatedCents) {
    return 'Valor de orçamento excede o limite permitido.';
  }
  return null;
}

/// Converts a user-typed decimal money string (e.g. "1234.56" or
/// "1234,56") into exact integer cents — never via a double intermediate
/// for the final stored value, so a value like 10.10 cannot silently
/// become 1009 cents due to binary floating-point representation.
/// Returns null for anything that doesn't parse as a plain non-negative
/// decimal with at most 2 fraction digits, or that exceeds
/// [ProjectResourceAllocation.maxBudgetAllocatedCents].
///
/// Codex Gate 1 (mission 12, Phase B) P2 — this used to have no
/// application-level maximum: the whole-number group was an unbounded
/// `\d+`, so a pasted string with hundreds of digits would still reach
/// `int.parse`/`whole * 100 + cents` with no upper bound. The whole-number
/// group is now capped at 12 digits (already generous relative to
/// [ProjectResourceAllocation.maxBudgetAllocatedCents]'s own digit count)
/// so int.parse is never asked to parse an arbitrarily long string, and
/// the final value is checked against the same maximum before returning.
int? parseMoneyInputToCents(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return 0;
  final match = RegExp(r'^(\d{1,12})(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = match.group(2);
  final cents = fraction == null
      ? 0
      : int.parse(fraction.padRight(2, '0'));
  final total = whole * 100 + cents;
  if (total > ProjectResourceAllocation.maxBudgetAllocatedCents) return null;
  return total;
}
