import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/feature_flag.dart';
import '../data/services/feature_flag_service.dart';

export '../data/models/feature_flag.dart';

final featureFlagServiceProvider =
    Provider<FeatureFlagService>((_) => FeatureFlagService());

final featureFlagsProvider =
    FutureProvider.autoDispose<Map<String, bool>>((ref) {
  return ref.read(featureFlagServiceProvider).fetchAllEnabled();
});

final featureFlagProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, featureName) {
  return ref.read(featureFlagServiceProvider).isEnabled(featureName);
});

extension FlagMapX on Map<String, bool> {
  bool get advisorEnabled        => this[FeatureFlag.advisorEnabled]        ?? false;
  bool get businessMemoryEnabled => this[FeatureFlag.businessMemoryEnabled] ?? true;
  bool get ecosystemViewEnabled  => this[FeatureFlag.ecosystemViewEnabled]  ?? true;
  bool get opportunityLabEnabled => this[FeatureFlag.opportunityLabEnabled] ?? false;
  bool get actionEngineEnabled   => this[FeatureFlag.actionEngineEnabled]   ?? false;
  bool get copilotEnabled        => this[FeatureFlag.copilotEnabled]        ?? false;
}
