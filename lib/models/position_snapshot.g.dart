// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'position_snapshot.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPositionSnapshotCollection on Isar {
  IsarCollection<PositionSnapshot> get positionSnapshots => this.collection();
}

const PositionSnapshotSchema = CollectionSchema(
  name: r'PositionSnapshot',
  id: 4249771063589786325,
  properties: {
    r'assetSupabaseId': PropertySchema(
      id: 0,
      name: r'assetSupabaseId',
      type: IsarType.string,
    ),
    r'averageCost': PropertySchema(
      id: 1,
      name: r'averageCost',
      type: IsarType.double,
    ),
    r'costBasisCny': PropertySchema(
      id: 2,
      name: r'costBasisCny',
      type: IsarType.double,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'date': PropertySchema(
      id: 4,
      name: r'date',
      type: IsarType.dateTime,
    ),
    r'fxRateToCny': PropertySchema(
      id: 5,
      name: r'fxRateToCny',
      type: IsarType.double,
    ),
    r'supabaseId': PropertySchema(
      id: 6,
      name: r'supabaseId',
      type: IsarType.string,
    ),
    r'totalShares': PropertySchema(
      id: 7,
      name: r'totalShares',
      type: IsarType.double,
    ),
    r'updatedAt': PropertySchema(
      id: 8,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _positionSnapshotEstimateSize,
  serialize: _positionSnapshotSerialize,
  deserialize: _positionSnapshotDeserialize,
  deserializeProp: _positionSnapshotDeserializeProp,
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
          caseSensitive: true,
        )
      ],
    ),
    r'supabaseId': IndexSchema(
      id: 2753382765909358918,
      name: r'supabaseId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'supabaseId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _positionSnapshotGetId,
  getLinks: _positionSnapshotGetLinks,
  attach: _positionSnapshotAttach,
  version: '3.1.0+1',
);

int _positionSnapshotEstimateSize(
  PositionSnapshot object,
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
    final value = object.supabaseId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _positionSnapshotSerialize(
  PositionSnapshot object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.assetSupabaseId);
  writer.writeDouble(offsets[1], object.averageCost);
  writer.writeDouble(offsets[2], object.costBasisCny);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeDateTime(offsets[4], object.date);
  writer.writeDouble(offsets[5], object.fxRateToCny);
  writer.writeString(offsets[6], object.supabaseId);
  writer.writeDouble(offsets[7], object.totalShares);
  writer.writeDateTime(offsets[8], object.updatedAt);
}

PositionSnapshot _positionSnapshotDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PositionSnapshot();
  object.assetSupabaseId = reader.readStringOrNull(offsets[0]);
  object.averageCost = reader.readDouble(offsets[1]);
  object.costBasisCny = reader.readDoubleOrNull(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.date = reader.readDateTime(offsets[4]);
  object.fxRateToCny = reader.readDoubleOrNull(offsets[5]);
  object.id = id;
  object.supabaseId = reader.readStringOrNull(offsets[6]);
  object.totalShares = reader.readDouble(offsets[7]);
  object.updatedAt = reader.readDateTimeOrNull(offsets[8]);
  return object;
}

P _positionSnapshotDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readDoubleOrNull(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readDateTime(offset)) as P;
    case 5:
      return (reader.readDoubleOrNull(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _positionSnapshotGetId(PositionSnapshot object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _positionSnapshotGetLinks(PositionSnapshot object) {
  return [];
}

void _positionSnapshotAttach(
    IsarCollection<dynamic> col, Id id, PositionSnapshot object) {
  object.id = id;
}

extension PositionSnapshotByIndex on IsarCollection<PositionSnapshot> {
  Future<PositionSnapshot?> getBySupabaseId(String? supabaseId) {
    return getByIndex(r'supabaseId', [supabaseId]);
  }

  PositionSnapshot? getBySupabaseIdSync(String? supabaseId) {
    return getByIndexSync(r'supabaseId', [supabaseId]);
  }

  Future<bool> deleteBySupabaseId(String? supabaseId) {
    return deleteByIndex(r'supabaseId', [supabaseId]);
  }

  bool deleteBySupabaseIdSync(String? supabaseId) {
    return deleteByIndexSync(r'supabaseId', [supabaseId]);
  }

  Future<List<PositionSnapshot?>> getAllBySupabaseId(
      List<String?> supabaseIdValues) {
    final values = supabaseIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'supabaseId', values);
  }

  List<PositionSnapshot?> getAllBySupabaseIdSync(
      List<String?> supabaseIdValues) {
    final values = supabaseIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'supabaseId', values);
  }

  Future<int> deleteAllBySupabaseId(List<String?> supabaseIdValues) {
    final values = supabaseIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'supabaseId', values);
  }

  int deleteAllBySupabaseIdSync(List<String?> supabaseIdValues) {
    final values = supabaseIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'supabaseId', values);
  }

  Future<Id> putBySupabaseId(PositionSnapshot object) {
    return putByIndex(r'supabaseId', object);
  }

  Id putBySupabaseIdSync(PositionSnapshot object, {bool saveLinks = true}) {
    return putByIndexSync(r'supabaseId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySupabaseId(List<PositionSnapshot> objects) {
    return putAllByIndex(r'supabaseId', objects);
  }

  List<Id> putAllBySupabaseIdSync(List<PositionSnapshot> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'supabaseId', objects, saveLinks: saveLinks);
  }
}

extension PositionSnapshotQueryWhereSort
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QWhere> {
  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhere>
      anySupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'supabaseId'),
      );
    });
  }
}

extension PositionSnapshotQueryWhere
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QWhereClause> {
  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause> idBetween(
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      assetSupabaseIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetSupabaseId',
        value: [null],
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      assetSupabaseIdEqualTo(String? assetSupabaseId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'assetSupabaseId',
        value: [assetSupabaseId],
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      supabaseIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'supabaseId',
        value: [null],
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      supabaseIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'supabaseId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      supabaseIdEqualTo(String? supabaseId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'supabaseId',
        value: [supabaseId],
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      supabaseIdNotEqualTo(String? supabaseId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'supabaseId',
              lower: [],
              upper: [supabaseId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'supabaseId',
              lower: [supabaseId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'supabaseId',
              lower: [supabaseId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'supabaseId',
              lower: [],
              upper: [supabaseId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      supabaseIdGreaterThan(
    String? supabaseId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'supabaseId',
        lower: [supabaseId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      supabaseIdLessThan(
    String? supabaseId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'supabaseId',
        lower: [],
        upper: [supabaseId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      supabaseIdBetween(
    String? lowerSupabaseId,
    String? upperSupabaseId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'supabaseId',
        lower: [lowerSupabaseId],
        includeLower: includeLower,
        upper: [upperSupabaseId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      supabaseIdStartsWith(String SupabaseIdPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'supabaseId',
        lower: [SupabaseIdPrefix],
        upper: ['$SupabaseIdPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      supabaseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'supabaseId',
        value: [''],
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhereClause>
      supabaseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'supabaseId',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'supabaseId',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'supabaseId',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'supabaseId',
              upper: [''],
            ));
      }
    });
  }
}

extension PositionSnapshotQueryFilter
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QFilterCondition> {
  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      assetSupabaseIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'assetSupabaseId',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      assetSupabaseIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'assetSupabaseId',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      assetSupabaseIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'assetSupabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      assetSupabaseIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'assetSupabaseId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      assetSupabaseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'assetSupabaseId',
        value: '',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      assetSupabaseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'assetSupabaseId',
        value: '',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      averageCostEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'averageCost',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      averageCostGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'averageCost',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      averageCostLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'averageCost',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      averageCostBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'averageCost',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      costBasisCnyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'costBasisCny',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      costBasisCnyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'costBasisCny',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      costBasisCnyEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'costBasisCny',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      costBasisCnyGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'costBasisCny',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      costBasisCnyLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'costBasisCny',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      costBasisCnyBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'costBasisCny',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      dateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      dateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      dateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'date',
        value: value,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      dateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'date',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      fxRateToCnyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'fxRateToCny',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      fxRateToCnyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'fxRateToCny',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      fxRateToCnyEqualTo(
    double? value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fxRateToCny',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      fxRateToCnyGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fxRateToCny',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      fxRateToCnyLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fxRateToCny',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      fxRateToCnyBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fxRateToCny',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'supabaseId',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'supabaseId',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'supabaseId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'supabaseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'supabaseId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'supabaseId',
        value: '',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      supabaseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'supabaseId',
        value: '',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      totalSharesEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalShares',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      totalSharesGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalShares',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      totalSharesLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalShares',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      totalSharesBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalShares',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      updatedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      updatedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'updatedAt',
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      updatedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime? value, {
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime? value, {
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

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      updatedAtBetween(
    DateTime? lower,
    DateTime? upper, {
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

extension PositionSnapshotQueryObject
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QFilterCondition> {}

extension PositionSnapshotQueryLinks
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QFilterCondition> {}

extension PositionSnapshotQuerySortBy
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QSortBy> {
  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByAssetSupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetSupabaseId', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByAssetSupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetSupabaseId', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByAverageCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'averageCost', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByAverageCostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'averageCost', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByCostBasisCny() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costBasisCny', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByCostBasisCnyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costBasisCny', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByFxRateToCny() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fxRateToCny', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByFxRateToCnyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fxRateToCny', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortBySupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortBySupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByTotalShares() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalShares', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByTotalSharesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalShares', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension PositionSnapshotQuerySortThenBy
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QSortThenBy> {
  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByAssetSupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetSupabaseId', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByAssetSupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'assetSupabaseId', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByAverageCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'averageCost', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByAverageCostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'averageCost', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByCostBasisCny() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costBasisCny', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByCostBasisCnyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'costBasisCny', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByFxRateToCny() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fxRateToCny', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByFxRateToCnyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fxRateToCny', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenBySupabaseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenBySupabaseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'supabaseId', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByTotalShares() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalShares', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByTotalSharesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalShares', Sort.desc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension PositionSnapshotQueryWhereDistinct
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct> {
  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct>
      distinctByAssetSupabaseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'assetSupabaseId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct>
      distinctByAverageCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'averageCost');
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct>
      distinctByCostBasisCny() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'costBasisCny');
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct> distinctByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date');
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct>
      distinctByFxRateToCny() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fxRateToCny');
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct>
      distinctBySupabaseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'supabaseId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct>
      distinctByTotalShares() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalShares');
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension PositionSnapshotQueryProperty
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QQueryProperty> {
  QueryBuilder<PositionSnapshot, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PositionSnapshot, String?, QQueryOperations>
      assetSupabaseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'assetSupabaseId');
    });
  }

  QueryBuilder<PositionSnapshot, double, QQueryOperations>
      averageCostProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'averageCost');
    });
  }

  QueryBuilder<PositionSnapshot, double?, QQueryOperations>
      costBasisCnyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'costBasisCny');
    });
  }

  QueryBuilder<PositionSnapshot, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<PositionSnapshot, DateTime, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<PositionSnapshot, double?, QQueryOperations>
      fxRateToCnyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fxRateToCny');
    });
  }

  QueryBuilder<PositionSnapshot, String?, QQueryOperations>
      supabaseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'supabaseId');
    });
  }

  QueryBuilder<PositionSnapshot, double, QQueryOperations>
      totalSharesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalShares');
    });
  }

  QueryBuilder<PositionSnapshot, DateTime?, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
