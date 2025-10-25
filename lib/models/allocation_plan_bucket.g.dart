// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'allocation_plan_bucket.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAllocationPlanBucketCollection on Isar {
  IsarCollection<AllocationPlanBucket> get allocationPlanBuckets =>
      this.collection();
}

const AllocationPlanBucketSchema = CollectionSchema(
  name: r'AllocationPlanBucket',
  id: -4874483677012763390,
  properties: {
    r'bucketId': PropertySchema(
      id: 0,
      name: r'bucketId',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'planId': PropertySchema(
      id: 2,
      name: r'planId',
      type: IsarType.long,
    ),
    r'targetWeightOverride': PropertySchema(
      id: 3,
      name: r'targetWeightOverride',
      type: IsarType.double,
    ),
    r'updatedAt': PropertySchema(
      id: 4,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _allocationPlanBucketEstimateSize,
  serialize: _allocationPlanBucketSerialize,
  deserialize: _allocationPlanBucketDeserialize,
  deserializeProp: _allocationPlanBucketDeserializeProp,
  idName: r'id',
  indexes: {
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
  getId: _allocationPlanBucketGetId,
  getLinks: _allocationPlanBucketGetLinks,
  attach: _allocationPlanBucketAttach,
  version: '3.1.0+1',
);

int _allocationPlanBucketEstimateSize(
  AllocationPlanBucket object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _allocationPlanBucketSerialize(
  AllocationPlanBucket object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.bucketId);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeLong(offsets[2], object.planId);
  writer.writeDouble(offsets[3], object.targetWeightOverride);
  writer.writeDateTime(offsets[4], object.updatedAt);
}

AllocationPlanBucket _allocationPlanBucketDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AllocationPlanBucket();
  object.bucketId = reader.readLong(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.id = id;
  object.planId = reader.readLong(offsets[2]);
  object.targetWeightOverride = reader.readDoubleOrNull(offsets[3]);
  object.updatedAt = reader.readDateTime(offsets[4]);
  return object;
}

P _allocationPlanBucketDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _allocationPlanBucketGetId(AllocationPlanBucket object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _allocationPlanBucketGetLinks(
    AllocationPlanBucket object) {
  return [];
}

void _allocationPlanBucketAttach(
    IsarCollection<dynamic> col, Id id, AllocationPlanBucket object) {
  object.id = id;
}

extension AllocationPlanBucketQueryWhereSort
    on QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QWhere> {
  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhere>
      anyPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'planId'),
      );
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhere>
      anyBucketId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'bucketId'),
      );
    });
  }
}

extension AllocationPlanBucketQueryWhere
    on QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QWhereClause> {
  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      idNotEqualTo(Id id) {
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      idBetween(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      planIdEqualTo(int planId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'planId',
        value: [planId],
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      planIdNotEqualTo(int planId) {
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      planIdGreaterThan(
    int planId, {
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      planIdLessThan(
    int planId, {
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      planIdBetween(
    int lowerPlanId,
    int upperPlanId, {
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
      bucketIdEqualTo(int bucketId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'bucketId',
        value: [bucketId],
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterWhereClause>
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

extension AllocationPlanBucketQueryFilter on QueryBuilder<AllocationPlanBucket,
    AllocationPlanBucket, QFilterCondition> {
  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> bucketIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bucketId',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> bucketIdGreaterThan(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> bucketIdLessThan(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> bucketIdBetween(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> createdAtGreaterThan(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> createdAtLessThan(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> createdAtBetween(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> idLessThan(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> idBetween(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> planIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'planId',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> planIdGreaterThan(
    int value, {
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> planIdLessThan(
    int value, {
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> planIdBetween(
    int lower,
    int upper, {
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> targetWeightOverrideIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'targetWeightOverride',
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> targetWeightOverrideIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'targetWeightOverride',
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> targetWeightOverrideEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetWeightOverride',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> targetWeightOverrideGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetWeightOverride',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> targetWeightOverrideLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetWeightOverride',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> targetWeightOverrideBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetWeightOverride',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> updatedAtGreaterThan(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> updatedAtLessThan(
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

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket,
      QAfterFilterCondition> updatedAtBetween(
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

extension AllocationPlanBucketQueryObject on QueryBuilder<AllocationPlanBucket,
    AllocationPlanBucket, QFilterCondition> {}

extension AllocationPlanBucketQueryLinks on QueryBuilder<AllocationPlanBucket,
    AllocationPlanBucket, QFilterCondition> {}

extension AllocationPlanBucketQuerySortBy
    on QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QSortBy> {
  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      sortByBucketId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bucketId', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      sortByBucketIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bucketId', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      sortByPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      sortByPlanIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      sortByTargetWeightOverride() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetWeightOverride', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      sortByTargetWeightOverrideDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetWeightOverride', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension AllocationPlanBucketQuerySortThenBy
    on QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QSortThenBy> {
  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByBucketId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bucketId', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByBucketIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bucketId', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByPlanIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByTargetWeightOverride() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetWeightOverride', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByTargetWeightOverrideDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetWeightOverride', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension AllocationPlanBucketQueryWhereDistinct
    on QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QDistinct> {
  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QDistinct>
      distinctByBucketId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bucketId');
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QDistinct>
      distinctByPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'planId');
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QDistinct>
      distinctByTargetWeightOverride() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetWeightOverride');
    });
  }

  QueryBuilder<AllocationPlanBucket, AllocationPlanBucket, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension AllocationPlanBucketQueryProperty on QueryBuilder<
    AllocationPlanBucket, AllocationPlanBucket, QQueryProperty> {
  QueryBuilder<AllocationPlanBucket, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AllocationPlanBucket, int, QQueryOperations> bucketIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bucketId');
    });
  }

  QueryBuilder<AllocationPlanBucket, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<AllocationPlanBucket, int, QQueryOperations> planIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'planId');
    });
  }

  QueryBuilder<AllocationPlanBucket, double?, QQueryOperations>
      targetWeightOverrideProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetWeightOverride');
    });
  }

  QueryBuilder<AllocationPlanBucket, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
