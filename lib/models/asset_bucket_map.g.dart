// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset_bucket_map.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAssetBucketMapCollection on Isar {
  IsarCollection<AssetBucketMap> get assetBucketMaps => this.collection();
}

const AssetBucketMapSchema = CollectionSchema(
  name: r'AssetBucketMap',
  id: 6951785895556233928,
  properties: {
    r'assetId': PropertySchema(
      id: 0,
      name: r'assetId',
      type: IsarType.long,
    ),
    r'assetSupabaseId': PropertySchema(
      id: 1,
      name: r'assetSupabaseId',
      type: IsarType.string,
    ),
    r'bucketId': PropertySchema(
      id: 2,
      name: r'bucketId',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'note': PropertySchema(
      id: 4,
      name: r'note',
      type: IsarType.string,
    ),
    r'planId': PropertySchema(
      id: 5,
      name: r'planId',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 6,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _assetBucketMapEstimateSize,
  serialize: _assetBucketMapSerialize,
  deserialize: _assetBucketMapDeserialize,
  deserializeProp: _assetBucketMapDeserializeProp,
  idName: r'id',
  indexes: {
    r'assetSupabaseId': IndexSchema(
      id: -577256045387587212,
      name: r'assetSupabaseId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'assetSupabaseId',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'assetId': IndexSchema(
      id: 174362542210192109,
      name: r'assetId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'assetId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'planId': IndexSchema(
      id: 7282644713036731817,
      name: r'planId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'planId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'bucketId': IndexSchema(
      id: -6654471401330852794,
      name: r'bucketId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'bucketId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _assetBucketMapGetId,
  getLinks: _assetBucketMapGetLinks,
  attach: _assetBucketMapAttach,
  version: '3.1.0+1',
);

int _assetBucketMapEstimateSize(
  AssetBucketMap object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.assetSupabaseId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _assetBucketMapSerialize(
  AssetBucketMap object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.assetId);
  writer.writeString(offsets[1], object.assetSupabaseId);
  writer.writeLong(offsets[2], object.bucketId);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeString(offsets[4], object.note);
  writer.writeLong(offsets[5], object.planId);
  writer.writeDateTime(offsets[6], object.updatedAt);
}

AssetBucketMap _assetBucketMapDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AssetBucketMap();
  object.assetId = reader.readLongOrNull(offsets[0]);
  object.assetSupabaseId = reader.readStringOrNull(offsets[1]);
  object.bucketId = reader.readLong(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.id = id;
  object.note = reader.readStringOrNull(offsets[4]);
  object.planId = reader.readLongOrNull(offsets[5]);
  object.updatedAt = reader.readDateTime(offsets[6]);
  return object;
}

P _assetBucketMapDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _assetBucketMapGetId(AssetBucketMap object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _assetBucketMapGetLinks(AssetBucketMap object) {
  return [];
}

void _assetBucketMapAttach(
    IsarCollection<dynamic> col, Id id, AssetBucketMap object) {
  object.id = id;
}

extension AssetBucketMapQueryWhereSort
    on QueryBuilder<AssetBucketMap, AssetBucketMap, QWhere> {
  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhere> anyAssetId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'assetId'),
      );
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhere> anyPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'planId'),
      );
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhere> anyBucketId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'bucketId'),
      );
    });
  }
}

extension AssetBucketMapQueryWhere
    on QueryBuilder<AssetBucketMap, AssetBucketMap, QWhereClause> {
  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetSupabaseIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetSupabaseId',
        value: [null],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetSupabaseIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetSupabaseId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetSupabaseIdEqualTo(String? assetSupabaseId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetSupabaseId',
        value: [assetSupabaseId],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetSupabaseIdNotEqualTo(String? assetSupabaseId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetSupabaseId',
              lower: [],
              upper: [assetSupabaseId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetSupabaseId',
              lower: [assetSupabaseId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetSupabaseId',
              lower: [assetSupabaseId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetSupabaseId',
              lower: [],
              upper: [assetSupabaseId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetId',
        value: [null],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetIdEqualTo(int? assetId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetId',
        value: [assetId],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetIdNotEqualTo(int? assetId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetId',
              lower: [],
              upper: [assetId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetId',
              lower: [assetId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetId',
              lower: [assetId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'assetId',
              lower: [],
              upper: [assetId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetIdGreaterThan(
    int? assetId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetId',
        lower: [assetId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetIdLessThan(
    int? assetId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetId',
        lower: [],
        upper: [assetId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      assetIdBetween(
    int? lowerAssetId,
    int? upperAssetId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'assetId',
        lower: [lowerAssetId],
        includeLower: includeLower,
        upper: [upperAssetId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      planIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'planId',
        value: [null],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      planIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'planId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause> planIdEqualTo(
      int? planId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'planId',
        value: [planId],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      planIdNotEqualTo(int? planId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'planId',
              lower: [],
              upper: [planId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'planId',
              lower: [planId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'planId',
              lower: [planId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'planId',
              lower: [],
              upper: [planId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      planIdGreaterThan(
    int? planId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'planId',
        lower: [planId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      planIdLessThan(
    int? planId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'planId',
        lower: [],
        upper: [planId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause> planIdBetween(
    int? lowerPlanId,
    int? upperPlanId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'planId',
        lower: [lowerPlanId],
        includeLower: includeLower,
        upper: [upperPlanId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      bucketIdEqualTo(int bucketId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'bucketId',
        value: [bucketId],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      bucketIdNotEqualTo(int bucketId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bucketId',
              lower: [],
              upper: [bucketId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bucketId',
              lower: [bucketId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bucketId',
              lower: [bucketId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'bucketId',
              lower: [],
              upper: [bucketId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      bucketIdGreaterThan(
    int bucketId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bucketId',
        lower: [bucketId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      bucketIdLessThan(
    int bucketId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bucketId',
        lower: [],
        upper: [bucketId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterWhereClause>
      bucketIdBetween(
    int lowerBucketId,
    int upperBucketId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'bucketId',
        lower: [lowerBucketId],
        includeLower: includeLower,
        upper: [upperBucketId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AssetBucketMapQueryFilter
    on QueryBuilder<AssetBucketMap, AssetBucketMap, QFilterCondition> {
  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetId',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetId',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetId',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetId',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetId',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetSupabaseId',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetSupabaseId',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetSupabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'assetSupabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'assetSupabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'assetSupabaseId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'assetSupabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'assetSupabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetSupabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetSupabaseId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetSupabaseId',
        value: '',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      assetSupabaseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetSupabaseId',
        value: '',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      bucketIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bucketId',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      bucketIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bucketId',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      bucketIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bucketId',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      bucketIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bucketId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'note',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'note',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      planIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'planId',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      planIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'planId',
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      planIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'planId',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      planIdGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'planId',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      planIdLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'planId',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      planIdBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'planId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AssetBucketMapQueryObject
    on QueryBuilder<AssetBucketMap, AssetBucketMap, QFilterCondition> {}

extension AssetBucketMapQueryLinks
    on QueryBuilder<AssetBucketMap, AssetBucketMap, QFilterCondition> {}

extension AssetBucketMapQuerySortBy
    on QueryBuilder<AssetBucketMap, AssetBucketMap, QSortBy> {
  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> sortByAssetId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetId', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      sortByAssetIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetId', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      sortByAssetSupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetSupabaseId', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      sortByAssetSupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetSupabaseId', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> sortByBucketId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bucketId', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      sortByBucketIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bucketId', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> sortByPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      sortByPlanIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension AssetBucketMapQuerySortThenBy
    on QueryBuilder<AssetBucketMap, AssetBucketMap, QSortThenBy> {
  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> thenByAssetId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetId', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      thenByAssetIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetId', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      thenByAssetSupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetSupabaseId', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      thenByAssetSupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetSupabaseId', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> thenByBucketId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bucketId', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      thenByBucketIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bucketId', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> thenByPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      thenByPlanIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.desc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension AssetBucketMapQueryWhereDistinct
    on QueryBuilder<AssetBucketMap, AssetBucketMap, QDistinct> {
  QueryBuilder<AssetBucketMap, AssetBucketMap, QDistinct> distinctByAssetId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetId');
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QDistinct>
      distinctByAssetSupabaseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetSupabaseId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QDistinct> distinctByBucketId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bucketId');
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QDistinct> distinctByNote(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QDistinct> distinctByPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'planId');
    });
  }

  QueryBuilder<AssetBucketMap, AssetBucketMap, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension AssetBucketMapQueryProperty
    on QueryBuilder<AssetBucketMap, AssetBucketMap, QQueryProperty> {
  QueryBuilder<AssetBucketMap, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AssetBucketMap, int?, QQueryOperations> assetIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetId');
    });
  }

  QueryBuilder<AssetBucketMap, String?, QQueryOperations>
      assetSupabaseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetSupabaseId');
    });
  }

  QueryBuilder<AssetBucketMap, int, QQueryOperations> bucketIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bucketId');
    });
  }

  QueryBuilder<AssetBucketMap, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<AssetBucketMap, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<AssetBucketMap, int?, QQueryOperations> planIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'planId');
    });
  }

  QueryBuilder<AssetBucketMap, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
