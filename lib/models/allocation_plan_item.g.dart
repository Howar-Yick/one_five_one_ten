// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'allocation_plan_item.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAllocationPlanItemCollection on Isar {
  IsarCollection<AllocationPlanItem> get allocationPlanItems =>
      this.collection();
}

const AllocationPlanItemSchema = CollectionSchema(
  name: r'AllocationPlanItem',
  id: -877900730360211676,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'includeRule': PropertySchema(
      id: 1,
      name: r'includeRule',
      type: IsarType.string,
    ),
    r'label': PropertySchema(
      id: 2,
      name: r'label',
      type: IsarType.string,
    ),
    r'note': PropertySchema(
      id: 3,
      name: r'note',
      type: IsarType.string,
    ),
    r'planId': PropertySchema(
      id: 4,
      name: r'planId',
      type: IsarType.long,
    ),
    r'sortOrder': PropertySchema(
      id: 5,
      name: r'sortOrder',
      type: IsarType.long,
    ),
    r'targetPercent': PropertySchema(
      id: 6,
      name: r'targetPercent',
      type: IsarType.double,
    ),
    r'updatedAt': PropertySchema(
      id: 7,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _allocationPlanItemEstimateSize,
  serialize: _allocationPlanItemSerialize,
  deserialize: _allocationPlanItemDeserialize,
  deserializeProp: _allocationPlanItemDeserializeProp,
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
    r'label': IndexSchema(
      id: 6902807635198700142,
      name: r'label',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'label',
          type: IndexType.hash,
          caseSensitive: false,
        )
      ],
    ),
    r'targetPercent': IndexSchema(
      id: -6672626738722574290,
      name: r'targetPercent',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'targetPercent',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    ),
    r'sortOrder': IndexSchema(
      id: -1119549396205841918,
      name: r'sortOrder',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sortOrder',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _allocationPlanItemGetId,
  getLinks: _allocationPlanItemGetLinks,
  attach: _allocationPlanItemAttach,
  version: '3.1.0+1',
);

int _allocationPlanItemEstimateSize(
  AllocationPlanItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.includeRule;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.label.length * 3;
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _allocationPlanItemSerialize(
  AllocationPlanItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeString(offsets[1], object.includeRule);
  writer.writeString(offsets[2], object.label);
  writer.writeString(offsets[3], object.note);
  writer.writeLong(offsets[4], object.planId);
  writer.writeLong(offsets[5], object.sortOrder);
  writer.writeDouble(offsets[6], object.targetPercent);
  writer.writeDateTime(offsets[7], object.updatedAt);
}

AllocationPlanItem _allocationPlanItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AllocationPlanItem();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.includeRule = reader.readStringOrNull(offsets[1]);
  object.label = reader.readString(offsets[2]);
  object.note = reader.readStringOrNull(offsets[3]);
  object.planId = reader.readLong(offsets[4]);
  object.sortOrder = reader.readLong(offsets[5]);
  object.targetPercent = reader.readDouble(offsets[6]);
  object.updatedAt = reader.readDateTime(offsets[7]);
  return object;
}

P _allocationPlanItemDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readDouble(offset)) as P;
    case 7:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _allocationPlanItemGetId(AllocationPlanItem object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _allocationPlanItemGetLinks(
    AllocationPlanItem object) {
  return [];
}

void _allocationPlanItemAttach(
    IsarCollection<dynamic> col, Id id, AllocationPlanItem object) {
  object.id = id;
}

extension AllocationPlanItemQueryWhereSort
    on QueryBuilder<AllocationPlanItem, AllocationPlanItem, QWhere> {
  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhere>
      anyPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'planId'),
      );
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhere>
      anyTargetPercent() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'targetPercent'),
      );
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhere>
      anySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'sortOrder'),
      );
    });
  }
}

extension AllocationPlanItemQueryWhere
    on QueryBuilder<AllocationPlanItem, AllocationPlanItem, QWhereClause> {
  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      planIdEqualTo(int planId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'planId',
        value: [planId],
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      labelEqualTo(String label) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'label',
        value: [label],
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      labelNotEqualTo(String label) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'label',
              lower: [],
              upper: [label],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'label',
              lower: [label],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'label',
              lower: [label],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'label',
              lower: [],
              upper: [label],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      targetPercentEqualTo(double targetPercent) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'targetPercent',
        value: [targetPercent],
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      targetPercentNotEqualTo(double targetPercent) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetPercent',
              lower: [],
              upper: [targetPercent],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetPercent',
              lower: [targetPercent],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetPercent',
              lower: [targetPercent],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetPercent',
              lower: [],
              upper: [targetPercent],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      targetPercentGreaterThan(
    double targetPercent, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'targetPercent',
        lower: [targetPercent],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      targetPercentLessThan(
    double targetPercent, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'targetPercent',
        lower: [],
        upper: [targetPercent],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      targetPercentBetween(
    double lowerTargetPercent,
    double upperTargetPercent, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'targetPercent',
        lower: [lowerTargetPercent],
        includeLower: includeLower,
        upper: [upperTargetPercent],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      sortOrderEqualTo(int sortOrder) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sortOrder',
        value: [sortOrder],
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      sortOrderNotEqualTo(int sortOrder) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sortOrder',
              lower: [],
              upper: [sortOrder],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sortOrder',
              lower: [sortOrder],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sortOrder',
              lower: [sortOrder],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sortOrder',
              lower: [],
              upper: [sortOrder],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      sortOrderGreaterThan(
    int sortOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sortOrder',
        lower: [sortOrder],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      sortOrderLessThan(
    int sortOrder, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sortOrder',
        lower: [],
        upper: [sortOrder],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterWhereClause>
      sortOrderBetween(
    int lowerSortOrder,
    int upperSortOrder, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sortOrder',
        lower: [lowerSortOrder],
        includeLower: includeLower,
        upper: [upperSortOrder],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AllocationPlanItemQueryFilter
    on QueryBuilder<AllocationPlanItem, AllocationPlanItem, QFilterCondition> {
  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'includeRule',
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'includeRule',
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'includeRule',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'includeRule',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'includeRule',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'includeRule',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'includeRule',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'includeRule',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'includeRule',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'includeRule',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'includeRule',
        value: '',
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      includeRuleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'includeRule',
        value: '',
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      labelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      labelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      labelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      labelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'label',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      labelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      labelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      labelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      labelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'label',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      labelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'label',
        value: '',
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      labelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'label',
        value: '',
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'note',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      planIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'planId',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      planIdGreaterThan(
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      planIdLessThan(
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      planIdBetween(
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      sortOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sortOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      sortOrderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sortOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      sortOrderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sortOrder',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      sortOrderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sortOrder',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      targetPercentEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetPercent',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      targetPercentGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetPercent',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      targetPercentLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetPercent',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      targetPercentBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetPercent',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterFilterCondition>
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

extension AllocationPlanItemQueryObject
    on QueryBuilder<AllocationPlanItem, AllocationPlanItem, QFilterCondition> {}

extension AllocationPlanItemQueryLinks
    on QueryBuilder<AllocationPlanItem, AllocationPlanItem, QFilterCondition> {}

extension AllocationPlanItemQuerySortBy
    on QueryBuilder<AllocationPlanItem, AllocationPlanItem, QSortBy> {
  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByIncludeRule() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'includeRule', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByIncludeRuleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'includeRule', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByPlanIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByTargetPercent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPercent', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByTargetPercentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPercent', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension AllocationPlanItemQuerySortThenBy
    on QueryBuilder<AllocationPlanItem, AllocationPlanItem, QSortThenBy> {
  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByIncludeRule() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'includeRule', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByIncludeRuleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'includeRule', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByPlanIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'planId', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sortOrder', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByTargetPercent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPercent', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByTargetPercentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetPercent', Sort.desc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension AllocationPlanItemQueryWhereDistinct
    on QueryBuilder<AllocationPlanItem, AllocationPlanItem, QDistinct> {
  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QDistinct>
      distinctByIncludeRule({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'includeRule', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QDistinct>
      distinctByLabel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'label', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QDistinct>
      distinctByNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QDistinct>
      distinctByPlanId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'planId');
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QDistinct>
      distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sortOrder');
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QDistinct>
      distinctByTargetPercent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetPercent');
    });
  }

  QueryBuilder<AllocationPlanItem, AllocationPlanItem, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension AllocationPlanItemQueryProperty
    on QueryBuilder<AllocationPlanItem, AllocationPlanItem, QQueryProperty> {
  QueryBuilder<AllocationPlanItem, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AllocationPlanItem, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<AllocationPlanItem, String?, QQueryOperations>
      includeRuleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'includeRule');
    });
  }

  QueryBuilder<AllocationPlanItem, String, QQueryOperations> labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'label');
    });
  }

  QueryBuilder<AllocationPlanItem, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<AllocationPlanItem, int, QQueryOperations> planIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'planId');
    });
  }

  QueryBuilder<AllocationPlanItem, int, QQueryOperations> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sortOrder');
    });
  }

  QueryBuilder<AllocationPlanItem, double, QQueryOperations>
      targetPercentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetPercent');
    });
  }

  QueryBuilder<AllocationPlanItem, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
