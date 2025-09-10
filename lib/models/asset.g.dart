// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'asset.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetAssetCollection on Isar {
  IsarCollection<Asset> get assets => this.collection();
}

const AssetSchema = CollectionSchema(
  name: r'Asset',
  id: -2933289051367723566,
  properties: {
    r'code': PropertySchema(
      id: 0,
      name: r'code',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 1,
      name: r'name',
      type: IsarType.string,
    ),
    r'trackingMethod': PropertySchema(
      id: 2,
      name: r'trackingMethod',
      type: IsarType.string,
      enumMap: _AssettrackingMethodEnumValueMap,
    )
  },
  estimateSize: _assetEstimateSize,
  serialize: _assetSerialize,
  deserialize: _assetDeserialize,
  deserializeProp: _assetDeserializeProp,
  idName: r'id',
  indexes: {
    r'name': IndexSchema(
      id: 879695947855722453,
      name: r'name',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'name',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {
    r'account': LinkSchema(
      id: 3892908787245791346,
      name: r'account',
      target: r'Account',
      single: true,
    ),
    r'snapshots': LinkSchema(
      id: -3094735826353787002,
      name: r'snapshots',
      target: r'PositionSnapshot',
      single: false,
      linkName: r'asset',
    ),
    r'transactions': LinkSchema(
      id: 2335268965389565597,
      name: r'transactions',
      target: r'Transaction',
      single: false,
      linkName: r'asset',
    )
  },
  embeddedSchemas: {},
  getId: _assetGetId,
  getLinks: _assetGetLinks,
  attach: _assetAttach,
  version: '3.1.0+1',
);

int _assetEstimateSize(
  Asset object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.code.length * 3;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.trackingMethod.name.length * 3;
  return bytesCount;
}

void _assetSerialize(
  Asset object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.code);
  writer.writeString(offsets[1], object.name);
  writer.writeString(offsets[2], object.trackingMethod.name);
}

Asset _assetDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Asset();
  object.code = reader.readString(offsets[0]);
  object.id = id;
  object.name = reader.readString(offsets[1]);
  object.trackingMethod =
      _AssettrackingMethodValueEnumMap[reader.readStringOrNull(offsets[2])] ??
          AssetTrackingMethod.valueBased;
  return object;
}

P _assetDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (_AssettrackingMethodValueEnumMap[
              reader.readStringOrNull(offset)] ??
          AssetTrackingMethod.valueBased) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _AssettrackingMethodEnumValueMap = {
  r'valueBased': r'valueBased',
  r'shareBased': r'shareBased',
};
const _AssettrackingMethodValueEnumMap = {
  r'valueBased': AssetTrackingMethod.valueBased,
  r'shareBased': AssetTrackingMethod.shareBased,
};

Id _assetGetId(Asset object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _assetGetLinks(Asset object) {
  return [object.account, object.snapshots, object.transactions];
}

void _assetAttach(IsarCollection<dynamic> col, Id id, Asset object) {
  object.id = id;
  object.account.attach(col, col.isar.collection<Account>(), r'account', id);
  object.snapshots
      .attach(col, col.isar.collection<PositionSnapshot>(), r'snapshots', id);
  object.transactions
      .attach(col, col.isar.collection<Transaction>(), r'transactions', id);
}

extension AssetQueryWhereSort on QueryBuilder<Asset, Asset, QWhere> {
  QueryBuilder<Asset, Asset, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhere> anyName() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'name'),
      );
    });
  }
}

extension AssetQueryWhere on QueryBuilder<Asset, Asset, QWhereClause> {
  QueryBuilder<Asset, Asset, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Asset, Asset, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> idBetween(
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

  QueryBuilder<Asset, Asset, QAfterWhereClause> nameEqualTo(String name) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'name',
        value: [name],
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> nameNotEqualTo(String name) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [],
              upper: [name],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [name],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [name],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'name',
              lower: [],
              upper: [name],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> nameGreaterThan(
    String name, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'name',
        lower: [name],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> nameLessThan(
    String name, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'name',
        lower: [],
        upper: [name],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> nameBetween(
    String lowerName,
    String upperName, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'name',
        lower: [lowerName],
        includeLower: includeLower,
        upper: [upperName],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> nameStartsWith(
      String NamePrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'name',
        lower: [NamePrefix],
        upper: ['$NamePrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'name',
        value: [''],
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterWhereClause> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'name',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'name',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'name',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'name',
              upper: [''],
            ));
      }
    });
  }
}

extension AssetQueryFilter on QueryBuilder<Asset, Asset, QFilterCondition> {
  QueryBuilder<Asset, Asset, QAfterFilterCondition> codeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> codeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> codeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> codeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'code',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> codeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> codeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> codeContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'code',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> codeMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'code',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> codeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'code',
        value: '',
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> codeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'code',
        value: '',
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Asset, Asset, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Asset, Asset, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Asset, Asset, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> nameContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> nameMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> trackingMethodEqualTo(
    AssetTrackingMethod value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'trackingMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> trackingMethodGreaterThan(
    AssetTrackingMethod value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'trackingMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> trackingMethodLessThan(
    AssetTrackingMethod value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'trackingMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> trackingMethodBetween(
    AssetTrackingMethod lower,
    AssetTrackingMethod upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'trackingMethod',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> trackingMethodStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'trackingMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> trackingMethodEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'trackingMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> trackingMethodContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'trackingMethod',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> trackingMethodMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'trackingMethod',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> trackingMethodIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'trackingMethod',
        value: '',
      ));
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> trackingMethodIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'trackingMethod',
        value: '',
      ));
    });
  }
}

extension AssetQueryObject on QueryBuilder<Asset, Asset, QFilterCondition> {}

extension AssetQueryLinks on QueryBuilder<Asset, Asset, QFilterCondition> {
  QueryBuilder<Asset, Asset, QAfterFilterCondition> account(
      FilterQuery<Account> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'account');
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> accountIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'account', 0, true, 0, true);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> snapshots(
      FilterQuery<PositionSnapshot> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'snapshots');
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> snapshotsLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'snapshots', length, true, length, true);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> snapshotsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'snapshots', 0, true, 0, true);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> snapshotsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'snapshots', 0, false, 999999, true);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> snapshotsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'snapshots', 0, true, length, include);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> snapshotsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'snapshots', length, include, 999999, true);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> snapshotsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
          r'snapshots', lower, includeLower, upper, includeUpper);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> transactions(
      FilterQuery<Transaction> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'transactions');
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> transactionsLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'transactions', length, true, length, true);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> transactionsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'transactions', 0, true, 0, true);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> transactionsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'transactions', 0, false, 999999, true);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> transactionsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'transactions', 0, true, length, include);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition>
      transactionsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'transactions', length, include, 999999, true);
    });
  }

  QueryBuilder<Asset, Asset, QAfterFilterCondition> transactionsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
          r'transactions', lower, includeLower, upper, includeUpper);
    });
  }
}

extension AssetQuerySortBy on QueryBuilder<Asset, Asset, QSortBy> {
  QueryBuilder<Asset, Asset, QAfterSortBy> sortByCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByTrackingMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackingMethod', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> sortByTrackingMethodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackingMethod', Sort.desc);
    });
  }
}

extension AssetQuerySortThenBy on QueryBuilder<Asset, Asset, QSortThenBy> {
  QueryBuilder<Asset, Asset, QAfterSortBy> thenByCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'code', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByTrackingMethod() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackingMethod', Sort.asc);
    });
  }

  QueryBuilder<Asset, Asset, QAfterSortBy> thenByTrackingMethodDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackingMethod', Sort.desc);
    });
  }
}

extension AssetQueryWhereDistinct on QueryBuilder<Asset, Asset, QDistinct> {
  QueryBuilder<Asset, Asset, QDistinct> distinctByCode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'code', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Asset, Asset, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Asset, Asset, QDistinct> distinctByTrackingMethod(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trackingMethod',
          caseSensitive: caseSensitive);
    });
  }
}

extension AssetQueryProperty on QueryBuilder<Asset, Asset, QQueryProperty> {
  QueryBuilder<Asset, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Asset, String, QQueryOperations> codeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'code');
    });
  }

  QueryBuilder<Asset, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<Asset, AssetTrackingMethod, QQueryOperations>
      trackingMethodProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trackingMethod');
    });
  }
}
