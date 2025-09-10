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
    r'averageCost': PropertySchema(
      id: 0,
      name: r'averageCost',
      type: IsarType.double,
    ),
    r'date': PropertySchema(
      id: 1,
      name: r'date',
      type: IsarType.dateTime,
    ),
    r'totalShares': PropertySchema(
      id: 2,
      name: r'totalShares',
      type: IsarType.double,
    )
  },
  estimateSize: _positionSnapshotEstimateSize,
  serialize: _positionSnapshotSerialize,
  deserialize: _positionSnapshotDeserialize,
  deserializeProp: _positionSnapshotDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {
    r'asset': LinkSchema(
      id: -7541019565681147517,
      name: r'asset',
      target: r'Asset',
      single: true,
    )
  },
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
  return bytesCount;
}

void _positionSnapshotSerialize(
  PositionSnapshot object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDouble(offsets[0], object.averageCost);
  writer.writeDateTime(offsets[1], object.date);
  writer.writeDouble(offsets[2], object.totalShares);
}

PositionSnapshot _positionSnapshotDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PositionSnapshot();
  object.averageCost = reader.readDouble(offsets[0]);
  object.date = reader.readDateTime(offsets[1]);
  object.id = id;
  object.totalShares = reader.readDouble(offsets[2]);
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
      return (reader.readDouble(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _positionSnapshotGetId(PositionSnapshot object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _positionSnapshotGetLinks(PositionSnapshot object) {
  return [object.asset];
}

void _positionSnapshotAttach(
    IsarCollection<dynamic> col, Id id, PositionSnapshot object) {
  object.id = id;
  object.asset.attach(col, col.isar.collection<Asset>(), r'asset', id);
}

extension PositionSnapshotQueryWhereSort
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QWhere> {
  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
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
}

extension PositionSnapshotQueryFilter
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QFilterCondition> {
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
}

extension PositionSnapshotQueryObject
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QFilterCondition> {}

extension PositionSnapshotQueryLinks
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QFilterCondition> {
  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition> asset(
      FilterQuery<Asset> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'asset');
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QAfterFilterCondition>
      assetIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'asset', 0, true, 0, true);
    });
  }
}

extension PositionSnapshotQuerySortBy
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QSortBy> {
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
}

extension PositionSnapshotQuerySortThenBy
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QSortThenBy> {
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
}

extension PositionSnapshotQueryWhereDistinct
    on QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct> {
  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct>
      distinctByAverageCost() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'averageCost');
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct> distinctByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date');
    });
  }

  QueryBuilder<PositionSnapshot, PositionSnapshot, QDistinct>
      distinctByTotalShares() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalShares');
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

  QueryBuilder<PositionSnapshot, double, QQueryOperations>
      averageCostProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'averageCost');
    });
  }

  QueryBuilder<PositionSnapshot, DateTime, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<PositionSnapshot, double, QQueryOperations>
      totalSharesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalShares');
    });
  }
}
