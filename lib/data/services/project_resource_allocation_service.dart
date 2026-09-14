import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_resource_allocation.dart';

const _table = 'project_resource_allocations';

/// IVE-COMMERCIAL-EXPERIENCE-12 (Phase B) — thin Supabase-backed service
/// for the persisted per-project Resource Allocation. RLS (see the
/// migration) is the sole authorization boundary; this class never
/// second-guesses ownership client-side, exactly like every other
/// service in this codebase.
class ProjectResourceAllocationService {
  ProjectResourceAllocationService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Returns the saved allocation for [projectId], or a zero-valued
  /// [ProjectResourceAllocation.empty] if the project has never saved
  /// one — RLS makes "not mine" and "doesn't exist" indistinguishable at
  /// this layer, which is the correct fail-safe (never leaks existence).
  Future<ProjectResourceAllocation> fetch(String projectId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('project_id', projectId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return ProjectResourceAllocation.empty(projectId);
    return ProjectResourceAllocation.fromMap(list.first as Map<String, dynamic>);
  }

  /// Upserts the current allocation for one project. `onConflict:
  /// 'project_id'` requires the UNIQUE(project_id) constraint from the
  /// migration to already exist in the target environment — same
  /// deploy-ordering rule as the Stability-08 migration.
  Future<ProjectResourceAllocation> save(ProjectResourceAllocation allocation) async {
    final row = await _client
        .from(_table)
        .upsert(allocation.toUpsertMap(), onConflict: 'project_id')
        .select()
        .single();
    return ProjectResourceAllocation.fromMap(row);
  }
}
