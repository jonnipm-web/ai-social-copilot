import '../../core/utils/date_parser.dart';

// ── Asset Type ────────────────────────────────────────────────────────────────

enum AssetType {
  product,
  service,
  book,
  series,
  website,
  app,
  course,
  contentProperty,
  brand,
  module,
  market,
  niche,
  technology,
  intellectualProperty,
  other;

  String get dbValue => switch (this) {
    AssetType.contentProperty    => 'content_property',
    AssetType.intellectualProperty => 'intellectual_property',
    _ => name,
  };

  static AssetType fromDb(String? value) => switch (value) {
    'content_property'     => AssetType.contentProperty,
    'intellectual_property' => AssetType.intellectualProperty,
    'product'              => AssetType.product,
    'service'              => AssetType.service,
    'book'                 => AssetType.book,
    'series'               => AssetType.series,
    'website'              => AssetType.website,
    'app'                  => AssetType.app,
    'course'               => AssetType.course,
    'brand'                => AssetType.brand,
    'module'               => AssetType.module,
    'market'               => AssetType.market,
    'niche'                => AssetType.niche,
    'technology'           => AssetType.technology,
    _                      => AssetType.other,
  };
}

// ── Asset Status ──────────────────────────────────────────────────────────────

enum AssetStatus {
  idea,
  research,
  validation,
  planned,
  active,
  paused,
  completed,
  archived;

  String get dbValue => name;

  static AssetStatus fromDb(String? value) => switch (value) {
    'idea'       => AssetStatus.idea,
    'research'   => AssetStatus.research,
    'validation' => AssetStatus.validation,
    'planned'    => AssetStatus.planned,
    'active'     => AssetStatus.active,
    'paused'     => AssetStatus.paused,
    'completed'  => AssetStatus.completed,
    'archived'   => AssetStatus.archived,
    _            => AssetStatus.idea,
  };
}

// ── Asset Model ───────────────────────────────────────────────────────────────

class Asset {
  final String  id;
  final String  userId;
  final String  projectId;
  final String? parentAssetId;

  final String  name;
  final AssetType type;
  final String? subtype;
  final String? description;

  final AssetStatus status;
  final String? category;
  final String? niche;

  final String? targetMarket;
  final String? targetAudience;

  final String? businessModel;
  final String? revenueModel;

  final String? lifecycleStage;
  final int?    strategicPriority;

  final Map<String, dynamic> metadata;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Asset({
    required this.id,
    required this.userId,
    required this.projectId,
    this.parentAssetId,
    required this.name,
    required this.type,
    this.subtype,
    this.description,
    this.status = AssetStatus.idea,
    this.category,
    this.niche,
    this.targetMarket,
    this.targetAudience,
    this.businessModel,
    this.revenueModel,
    this.lifecycleStage,
    this.strategicPriority,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id:                map['id'] as String,
      userId:            map['user_id'] as String,
      projectId:         map['project_id'] as String,
      parentAssetId:     map['parent_asset_id'] as String?,
      name:              map['name'] as String,
      type:              AssetType.fromDb(map['type'] as String?),
      subtype:           map['subtype'] as String?,
      description:       map['description'] as String?,
      status:            AssetStatus.fromDb(map['status'] as String?),
      category:          map['category'] as String?,
      niche:             map['niche'] as String?,
      targetMarket:      map['target_market'] as String?,
      targetAudience:    map['target_audience'] as String?,
      businessModel:     map['business_model'] as String?,
      revenueModel:      map['revenue_model'] as String?,
      lifecycleStage:    map['lifecycle_stage'] as String?,
      strategicPriority: map['strategic_priority'] as int?,
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : {},
      createdAt: DateParser.parse(map['created_at']),
      updatedAt: DateParser.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'user_id':             userId,
    'project_id':          projectId,
    if (parentAssetId != null) 'parent_asset_id': parentAssetId,
    'name':                name,
    'type':                type.dbValue,
    if (subtype != null)   'subtype': subtype,
    if (description != null) 'description': description,
    'status':              status.dbValue,
    if (category != null)  'category': category,
    if (niche != null)     'niche': niche,
    if (targetMarket != null)   'target_market': targetMarket,
    if (targetAudience != null) 'target_audience': targetAudience,
    if (businessModel != null)  'business_model': businessModel,
    if (revenueModel != null)   'revenue_model': revenueModel,
    if (lifecycleStage != null) 'lifecycle_stage': lifecycleStage,
    if (strategicPriority != null) 'strategic_priority': strategicPriority,
    'metadata':            metadata,
  };

  Map<String, dynamic> toUpdateMap() => {
    'name':                name,
    'type':                type.dbValue,
    if (subtype != null)   'subtype': subtype,
    if (description != null) 'description': description,
    'status':              status.dbValue,
    if (category != null)  'category': category,
    if (niche != null)     'niche': niche,
    if (targetMarket != null)   'target_market': targetMarket,
    if (targetAudience != null) 'target_audience': targetAudience,
    if (businessModel != null)  'business_model': businessModel,
    if (revenueModel != null)   'revenue_model': revenueModel,
    if (lifecycleStage != null) 'lifecycle_stage': lifecycleStage,
    if (strategicPriority != null) 'strategic_priority': strategicPriority,
    'metadata':            metadata,
  };

  Asset copyWith({
    String?             id,
    String?             userId,
    String?             projectId,
    String?             parentAssetId,
    bool                clearParent = false,
    String?             name,
    AssetType?          type,
    String?             subtype,
    String?             description,
    AssetStatus?        status,
    String?             category,
    String?             niche,
    String?             targetMarket,
    String?             targetAudience,
    String?             businessModel,
    String?             revenueModel,
    String?             lifecycleStage,
    int?                strategicPriority,
    Map<String, dynamic>? metadata,
    DateTime?           createdAt,
    DateTime?           updatedAt,
  }) {
    return Asset(
      id:                id               ?? this.id,
      userId:            userId           ?? this.userId,
      projectId:         projectId        ?? this.projectId,
      parentAssetId:     clearParent ? null : (parentAssetId ?? this.parentAssetId),
      name:              name             ?? this.name,
      type:              type             ?? this.type,
      subtype:           subtype          ?? this.subtype,
      description:       description      ?? this.description,
      status:            status           ?? this.status,
      category:          category         ?? this.category,
      niche:             niche            ?? this.niche,
      targetMarket:      targetMarket     ?? this.targetMarket,
      targetAudience:    targetAudience   ?? this.targetAudience,
      businessModel:     businessModel    ?? this.businessModel,
      revenueModel:      revenueModel     ?? this.revenueModel,
      lifecycleStage:    lifecycleStage   ?? this.lifecycleStage,
      strategicPriority: strategicPriority ?? this.strategicPriority,
      metadata:          metadata         ?? this.metadata,
      createdAt:         createdAt        ?? this.createdAt,
      updatedAt:         updatedAt        ?? this.updatedAt,
    );
  }
}
