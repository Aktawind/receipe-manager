// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RecipesTable extends Recipes with TableInfo<$RecipesTable, RecipeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tipsMeta = const VerificationMeta('tips');
  @override
  late final GeneratedColumn<String> tips = GeneratedColumn<String>(
    'tips',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _servingsMeta = const VerificationMeta(
    'servings',
  );
  @override
  late final GeneratedColumn<int> servings = GeneratedColumn<int>(
    'servings',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingsUnitMeta = const VerificationMeta(
    'servingsUnit',
  );
  @override
  late final GeneratedColumn<String> servingsUnit = GeneratedColumn<String>(
    'servings_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _prepMinutesMeta = const VerificationMeta(
    'prepMinutes',
  );
  @override
  late final GeneratedColumn<int> prepMinutes = GeneratedColumn<int>(
    'prep_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cookMinutesMeta = const VerificationMeta(
    'cookMinutes',
  );
  @override
  late final GeneratedColumn<int> cookMinutes = GeneratedColumn<int>(
    'cook_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restMinutesMeta = const VerificationMeta(
    'restMinutes',
  );
  @override
  late final GeneratedColumn<int> restMinutes = GeneratedColumn<int>(
    'rest_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timesCookedMeta = const VerificationMeta(
    'timesCooked',
  );
  @override
  late final GeneratedColumn<int> timesCooked = GeneratedColumn<int>(
    'times_cooked',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mainPhotoMeta = const VerificationMeta(
    'mainPhoto',
  );
  @override
  late final GeneratedColumn<String> mainPhoto = GeneratedColumn<String>(
    'main_photo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _courseMeta = const VerificationMeta('course');
  @override
  late final GeneratedColumn<String> course = GeneratedColumn<String>(
    'course',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _collectionsMeta = const VerificationMeta(
    'collections',
  );
  @override
  late final GeneratedColumn<String> collections = GeneratedColumn<String>(
    'collections',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _equipmentMeta = const VerificationMeta(
    'equipment',
  );
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
    'equipment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _videoLinksMeta = const VerificationMeta(
    'videoLinks',
  );
  @override
  late final GeneratedColumn<String> videoLinks = GeneratedColumn<String>(
    'video_links',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    source,
    notes,
    tips,
    servings,
    servingsUnit,
    prepMinutes,
    cookMinutes,
    restMinutes,
    timesCooked,
    mainPhoto,
    isFavorite,
    rating,
    status,
    course,
    category,
    collections,
    equipment,
    videoLinks,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipes';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('tips')) {
      context.handle(
        _tipsMeta,
        tips.isAcceptableOrUnknown(data['tips']!, _tipsMeta),
      );
    }
    if (data.containsKey('servings')) {
      context.handle(
        _servingsMeta,
        servings.isAcceptableOrUnknown(data['servings']!, _servingsMeta),
      );
    }
    if (data.containsKey('servings_unit')) {
      context.handle(
        _servingsUnitMeta,
        servingsUnit.isAcceptableOrUnknown(
          data['servings_unit']!,
          _servingsUnitMeta,
        ),
      );
    }
    if (data.containsKey('prep_minutes')) {
      context.handle(
        _prepMinutesMeta,
        prepMinutes.isAcceptableOrUnknown(
          data['prep_minutes']!,
          _prepMinutesMeta,
        ),
      );
    }
    if (data.containsKey('cook_minutes')) {
      context.handle(
        _cookMinutesMeta,
        cookMinutes.isAcceptableOrUnknown(
          data['cook_minutes']!,
          _cookMinutesMeta,
        ),
      );
    }
    if (data.containsKey('rest_minutes')) {
      context.handle(
        _restMinutesMeta,
        restMinutes.isAcceptableOrUnknown(
          data['rest_minutes']!,
          _restMinutesMeta,
        ),
      );
    }
    if (data.containsKey('times_cooked')) {
      context.handle(
        _timesCookedMeta,
        timesCooked.isAcceptableOrUnknown(
          data['times_cooked']!,
          _timesCookedMeta,
        ),
      );
    }
    if (data.containsKey('main_photo')) {
      context.handle(
        _mainPhotoMeta,
        mainPhoto.isAcceptableOrUnknown(data['main_photo']!, _mainPhotoMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('course')) {
      context.handle(
        _courseMeta,
        course.isAcceptableOrUnknown(data['course']!, _courseMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('collections')) {
      context.handle(
        _collectionsMeta,
        collections.isAcceptableOrUnknown(
          data['collections']!,
          _collectionsMeta,
        ),
      );
    }
    if (data.containsKey('equipment')) {
      context.handle(
        _equipmentMeta,
        equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta),
      );
    }
    if (data.containsKey('video_links')) {
      context.handle(
        _videoLinksMeta,
        videoLinks.isAcceptableOrUnknown(data['video_links']!, _videoLinksMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecipeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      tips: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tips'],
      )!,
      servings: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}servings'],
      ),
      servingsUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}servings_unit'],
      )!,
      prepMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}prep_minutes'],
      ),
      cookMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cook_minutes'],
      ),
      restMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_minutes'],
      ),
      timesCooked: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}times_cooked'],
      )!,
      mainPhoto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}main_photo'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      course: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      collections: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collections'],
      )!,
      equipment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment'],
      )!,
      videoLinks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_links'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $RecipesTable createAlias(String alias) {
    return $RecipesTable(attachedDatabase, alias);
  }
}

class RecipeRow extends DataClass implements Insertable<RecipeRow> {
  final String id;
  final String title;
  final String description;
  final String source;
  final String notes;

  /// Ancien champ « Astuces », fusionné dans [notes] par la migration v2.
  /// Toujours vide : la colonne reste pour ne pas reconstruire la table.
  final String tips;
  final int? servings;

  /// « blinis », « ramequins »… ; vide = des personnes. Ajouté en v4.
  final String servingsUnit;
  final int? prepMinutes;
  final int? cookMinutes;
  final int? restMinutes;
  final int timesCooked;
  final String? mainPhoto;

  /// Favori ; ajouté en v3.
  final bool isFavorite;

  /// Note de 1 à 5, `null` si non notée ; ajouté en v3.
  final int? rating;

  /// `toTest`, `validated`, `toImprove` ou `null` ; ajouté en v3.
  final String? status;

  /// Type de plat, catégorie et collections (une par ligne) en texte libre
  /// en attendant le classement complet de la 0.3 ; ajoutés en v3.
  final String course;
  final String category;
  final String collections;

  /// Liens vidéo, un par ligne ; ajouté en v5. [equipment] (matériel en texte,
  /// v5) est vidé par la migration v6 : le matériel est dans [RecipeEquipment].
  final String equipment;
  final String videoLinks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const RecipeRow({
    required this.id,
    required this.title,
    required this.description,
    required this.source,
    required this.notes,
    required this.tips,
    this.servings,
    required this.servingsUnit,
    this.prepMinutes,
    this.cookMinutes,
    this.restMinutes,
    required this.timesCooked,
    this.mainPhoto,
    required this.isFavorite,
    this.rating,
    this.status,
    required this.course,
    required this.category,
    required this.collections,
    required this.equipment,
    required this.videoLinks,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['source'] = Variable<String>(source);
    map['notes'] = Variable<String>(notes);
    map['tips'] = Variable<String>(tips);
    if (!nullToAbsent || servings != null) {
      map['servings'] = Variable<int>(servings);
    }
    map['servings_unit'] = Variable<String>(servingsUnit);
    if (!nullToAbsent || prepMinutes != null) {
      map['prep_minutes'] = Variable<int>(prepMinutes);
    }
    if (!nullToAbsent || cookMinutes != null) {
      map['cook_minutes'] = Variable<int>(cookMinutes);
    }
    if (!nullToAbsent || restMinutes != null) {
      map['rest_minutes'] = Variable<int>(restMinutes);
    }
    map['times_cooked'] = Variable<int>(timesCooked);
    if (!nullToAbsent || mainPhoto != null) {
      map['main_photo'] = Variable<String>(mainPhoto);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<int>(rating);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    map['course'] = Variable<String>(course);
    map['category'] = Variable<String>(category);
    map['collections'] = Variable<String>(collections);
    map['equipment'] = Variable<String>(equipment);
    map['video_links'] = Variable<String>(videoLinks);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  RecipesCompanion toCompanion(bool nullToAbsent) {
    return RecipesCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      source: Value(source),
      notes: Value(notes),
      tips: Value(tips),
      servings: servings == null && nullToAbsent
          ? const Value.absent()
          : Value(servings),
      servingsUnit: Value(servingsUnit),
      prepMinutes: prepMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(prepMinutes),
      cookMinutes: cookMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(cookMinutes),
      restMinutes: restMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(restMinutes),
      timesCooked: Value(timesCooked),
      mainPhoto: mainPhoto == null && nullToAbsent
          ? const Value.absent()
          : Value(mainPhoto),
      isFavorite: Value(isFavorite),
      rating: rating == null && nullToAbsent
          ? const Value.absent()
          : Value(rating),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      course: Value(course),
      category: Value(category),
      collections: Value(collections),
      equipment: Value(equipment),
      videoLinks: Value(videoLinks),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory RecipeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      source: serializer.fromJson<String>(json['source']),
      notes: serializer.fromJson<String>(json['notes']),
      tips: serializer.fromJson<String>(json['tips']),
      servings: serializer.fromJson<int?>(json['servings']),
      servingsUnit: serializer.fromJson<String>(json['servingsUnit']),
      prepMinutes: serializer.fromJson<int?>(json['prepMinutes']),
      cookMinutes: serializer.fromJson<int?>(json['cookMinutes']),
      restMinutes: serializer.fromJson<int?>(json['restMinutes']),
      timesCooked: serializer.fromJson<int>(json['timesCooked']),
      mainPhoto: serializer.fromJson<String?>(json['mainPhoto']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      rating: serializer.fromJson<int?>(json['rating']),
      status: serializer.fromJson<String?>(json['status']),
      course: serializer.fromJson<String>(json['course']),
      category: serializer.fromJson<String>(json['category']),
      collections: serializer.fromJson<String>(json['collections']),
      equipment: serializer.fromJson<String>(json['equipment']),
      videoLinks: serializer.fromJson<String>(json['videoLinks']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'source': serializer.toJson<String>(source),
      'notes': serializer.toJson<String>(notes),
      'tips': serializer.toJson<String>(tips),
      'servings': serializer.toJson<int?>(servings),
      'servingsUnit': serializer.toJson<String>(servingsUnit),
      'prepMinutes': serializer.toJson<int?>(prepMinutes),
      'cookMinutes': serializer.toJson<int?>(cookMinutes),
      'restMinutes': serializer.toJson<int?>(restMinutes),
      'timesCooked': serializer.toJson<int>(timesCooked),
      'mainPhoto': serializer.toJson<String?>(mainPhoto),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'rating': serializer.toJson<int?>(rating),
      'status': serializer.toJson<String?>(status),
      'course': serializer.toJson<String>(course),
      'category': serializer.toJson<String>(category),
      'collections': serializer.toJson<String>(collections),
      'equipment': serializer.toJson<String>(equipment),
      'videoLinks': serializer.toJson<String>(videoLinks),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  RecipeRow copyWith({
    String? id,
    String? title,
    String? description,
    String? source,
    String? notes,
    String? tips,
    Value<int?> servings = const Value.absent(),
    String? servingsUnit,
    Value<int?> prepMinutes = const Value.absent(),
    Value<int?> cookMinutes = const Value.absent(),
    Value<int?> restMinutes = const Value.absent(),
    int? timesCooked,
    Value<String?> mainPhoto = const Value.absent(),
    bool? isFavorite,
    Value<int?> rating = const Value.absent(),
    Value<String?> status = const Value.absent(),
    String? course,
    String? category,
    String? collections,
    String? equipment,
    String? videoLinks,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => RecipeRow(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    source: source ?? this.source,
    notes: notes ?? this.notes,
    tips: tips ?? this.tips,
    servings: servings.present ? servings.value : this.servings,
    servingsUnit: servingsUnit ?? this.servingsUnit,
    prepMinutes: prepMinutes.present ? prepMinutes.value : this.prepMinutes,
    cookMinutes: cookMinutes.present ? cookMinutes.value : this.cookMinutes,
    restMinutes: restMinutes.present ? restMinutes.value : this.restMinutes,
    timesCooked: timesCooked ?? this.timesCooked,
    mainPhoto: mainPhoto.present ? mainPhoto.value : this.mainPhoto,
    isFavorite: isFavorite ?? this.isFavorite,
    rating: rating.present ? rating.value : this.rating,
    status: status.present ? status.value : this.status,
    course: course ?? this.course,
    category: category ?? this.category,
    collections: collections ?? this.collections,
    equipment: equipment ?? this.equipment,
    videoLinks: videoLinks ?? this.videoLinks,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  RecipeRow copyWithCompanion(RecipesCompanion data) {
    return RecipeRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      source: data.source.present ? data.source.value : this.source,
      notes: data.notes.present ? data.notes.value : this.notes,
      tips: data.tips.present ? data.tips.value : this.tips,
      servings: data.servings.present ? data.servings.value : this.servings,
      servingsUnit: data.servingsUnit.present
          ? data.servingsUnit.value
          : this.servingsUnit,
      prepMinutes: data.prepMinutes.present
          ? data.prepMinutes.value
          : this.prepMinutes,
      cookMinutes: data.cookMinutes.present
          ? data.cookMinutes.value
          : this.cookMinutes,
      restMinutes: data.restMinutes.present
          ? data.restMinutes.value
          : this.restMinutes,
      timesCooked: data.timesCooked.present
          ? data.timesCooked.value
          : this.timesCooked,
      mainPhoto: data.mainPhoto.present ? data.mainPhoto.value : this.mainPhoto,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      rating: data.rating.present ? data.rating.value : this.rating,
      status: data.status.present ? data.status.value : this.status,
      course: data.course.present ? data.course.value : this.course,
      category: data.category.present ? data.category.value : this.category,
      collections: data.collections.present
          ? data.collections.value
          : this.collections,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      videoLinks: data.videoLinks.present
          ? data.videoLinks.value
          : this.videoLinks,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('source: $source, ')
          ..write('notes: $notes, ')
          ..write('tips: $tips, ')
          ..write('servings: $servings, ')
          ..write('servingsUnit: $servingsUnit, ')
          ..write('prepMinutes: $prepMinutes, ')
          ..write('cookMinutes: $cookMinutes, ')
          ..write('restMinutes: $restMinutes, ')
          ..write('timesCooked: $timesCooked, ')
          ..write('mainPhoto: $mainPhoto, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('rating: $rating, ')
          ..write('status: $status, ')
          ..write('course: $course, ')
          ..write('category: $category, ')
          ..write('collections: $collections, ')
          ..write('equipment: $equipment, ')
          ..write('videoLinks: $videoLinks, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    description,
    source,
    notes,
    tips,
    servings,
    servingsUnit,
    prepMinutes,
    cookMinutes,
    restMinutes,
    timesCooked,
    mainPhoto,
    isFavorite,
    rating,
    status,
    course,
    category,
    collections,
    equipment,
    videoLinks,
    createdAt,
    updatedAt,
    deletedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.source == this.source &&
          other.notes == this.notes &&
          other.tips == this.tips &&
          other.servings == this.servings &&
          other.servingsUnit == this.servingsUnit &&
          other.prepMinutes == this.prepMinutes &&
          other.cookMinutes == this.cookMinutes &&
          other.restMinutes == this.restMinutes &&
          other.timesCooked == this.timesCooked &&
          other.mainPhoto == this.mainPhoto &&
          other.isFavorite == this.isFavorite &&
          other.rating == this.rating &&
          other.status == this.status &&
          other.course == this.course &&
          other.category == this.category &&
          other.collections == this.collections &&
          other.equipment == this.equipment &&
          other.videoLinks == this.videoLinks &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class RecipesCompanion extends UpdateCompanion<RecipeRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String> source;
  final Value<String> notes;
  final Value<String> tips;
  final Value<int?> servings;
  final Value<String> servingsUnit;
  final Value<int?> prepMinutes;
  final Value<int?> cookMinutes;
  final Value<int?> restMinutes;
  final Value<int> timesCooked;
  final Value<String?> mainPhoto;
  final Value<bool> isFavorite;
  final Value<int?> rating;
  final Value<String?> status;
  final Value<String> course;
  final Value<String> category;
  final Value<String> collections;
  final Value<String> equipment;
  final Value<String> videoLinks;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const RecipesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.source = const Value.absent(),
    this.notes = const Value.absent(),
    this.tips = const Value.absent(),
    this.servings = const Value.absent(),
    this.servingsUnit = const Value.absent(),
    this.prepMinutes = const Value.absent(),
    this.cookMinutes = const Value.absent(),
    this.restMinutes = const Value.absent(),
    this.timesCooked = const Value.absent(),
    this.mainPhoto = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.rating = const Value.absent(),
    this.status = const Value.absent(),
    this.course = const Value.absent(),
    this.category = const Value.absent(),
    this.collections = const Value.absent(),
    this.equipment = const Value.absent(),
    this.videoLinks = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipesCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.source = const Value.absent(),
    this.notes = const Value.absent(),
    this.tips = const Value.absent(),
    this.servings = const Value.absent(),
    this.servingsUnit = const Value.absent(),
    this.prepMinutes = const Value.absent(),
    this.cookMinutes = const Value.absent(),
    this.restMinutes = const Value.absent(),
    this.timesCooked = const Value.absent(),
    this.mainPhoto = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.rating = const Value.absent(),
    this.status = const Value.absent(),
    this.course = const Value.absent(),
    this.category = const Value.absent(),
    this.collections = const Value.absent(),
    this.equipment = const Value.absent(),
    this.videoLinks = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RecipeRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? source,
    Expression<String>? notes,
    Expression<String>? tips,
    Expression<int>? servings,
    Expression<String>? servingsUnit,
    Expression<int>? prepMinutes,
    Expression<int>? cookMinutes,
    Expression<int>? restMinutes,
    Expression<int>? timesCooked,
    Expression<String>? mainPhoto,
    Expression<bool>? isFavorite,
    Expression<int>? rating,
    Expression<String>? status,
    Expression<String>? course,
    Expression<String>? category,
    Expression<String>? collections,
    Expression<String>? equipment,
    Expression<String>? videoLinks,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (source != null) 'source': source,
      if (notes != null) 'notes': notes,
      if (tips != null) 'tips': tips,
      if (servings != null) 'servings': servings,
      if (servingsUnit != null) 'servings_unit': servingsUnit,
      if (prepMinutes != null) 'prep_minutes': prepMinutes,
      if (cookMinutes != null) 'cook_minutes': cookMinutes,
      if (restMinutes != null) 'rest_minutes': restMinutes,
      if (timesCooked != null) 'times_cooked': timesCooked,
      if (mainPhoto != null) 'main_photo': mainPhoto,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (rating != null) 'rating': rating,
      if (status != null) 'status': status,
      if (course != null) 'course': course,
      if (category != null) 'category': category,
      if (collections != null) 'collections': collections,
      if (equipment != null) 'equipment': equipment,
      if (videoLinks != null) 'video_links': videoLinks,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? description,
    Value<String>? source,
    Value<String>? notes,
    Value<String>? tips,
    Value<int?>? servings,
    Value<String>? servingsUnit,
    Value<int?>? prepMinutes,
    Value<int?>? cookMinutes,
    Value<int?>? restMinutes,
    Value<int>? timesCooked,
    Value<String?>? mainPhoto,
    Value<bool>? isFavorite,
    Value<int?>? rating,
    Value<String?>? status,
    Value<String>? course,
    Value<String>? category,
    Value<String>? collections,
    Value<String>? equipment,
    Value<String>? videoLinks,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return RecipesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      tips: tips ?? this.tips,
      servings: servings ?? this.servings,
      servingsUnit: servingsUnit ?? this.servingsUnit,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      cookMinutes: cookMinutes ?? this.cookMinutes,
      restMinutes: restMinutes ?? this.restMinutes,
      timesCooked: timesCooked ?? this.timesCooked,
      mainPhoto: mainPhoto ?? this.mainPhoto,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      course: course ?? this.course,
      category: category ?? this.category,
      collections: collections ?? this.collections,
      equipment: equipment ?? this.equipment,
      videoLinks: videoLinks ?? this.videoLinks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (tips.present) {
      map['tips'] = Variable<String>(tips.value);
    }
    if (servings.present) {
      map['servings'] = Variable<int>(servings.value);
    }
    if (servingsUnit.present) {
      map['servings_unit'] = Variable<String>(servingsUnit.value);
    }
    if (prepMinutes.present) {
      map['prep_minutes'] = Variable<int>(prepMinutes.value);
    }
    if (cookMinutes.present) {
      map['cook_minutes'] = Variable<int>(cookMinutes.value);
    }
    if (restMinutes.present) {
      map['rest_minutes'] = Variable<int>(restMinutes.value);
    }
    if (timesCooked.present) {
      map['times_cooked'] = Variable<int>(timesCooked.value);
    }
    if (mainPhoto.present) {
      map['main_photo'] = Variable<String>(mainPhoto.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (course.present) {
      map['course'] = Variable<String>(course.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (collections.present) {
      map['collections'] = Variable<String>(collections.value);
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (videoLinks.present) {
      map['video_links'] = Variable<String>(videoLinks.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('source: $source, ')
          ..write('notes: $notes, ')
          ..write('tips: $tips, ')
          ..write('servings: $servings, ')
          ..write('servingsUnit: $servingsUnit, ')
          ..write('prepMinutes: $prepMinutes, ')
          ..write('cookMinutes: $cookMinutes, ')
          ..write('restMinutes: $restMinutes, ')
          ..write('timesCooked: $timesCooked, ')
          ..write('mainPhoto: $mainPhoto, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('rating: $rating, ')
          ..write('status: $status, ')
          ..write('course: $course, ')
          ..write('category: $category, ')
          ..write('collections: $collections, ')
          ..write('equipment: $equipment, ')
          ..write('videoLinks: $videoLinks, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IngredientsTable extends Ingredients
    with TableInfo<$IngredientsTable, IngredientRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
    'recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSectionMeta = const VerificationMeta(
    'isSection',
  );
  @override
  late final GeneratedColumn<bool> isSection = GeneratedColumn<bool>(
    'is_section',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_section" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _optionalMeta = const VerificationMeta(
    'optional',
  );
  @override
  late final GeneratedColumn<bool> optional = GeneratedColumn<bool>(
    'optional',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("optional" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _substitutesMeta = const VerificationMeta(
    'substitutes',
  );
  @override
  late final GeneratedColumn<String> substitutes = GeneratedColumn<String>(
    'substitutes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _linkedRecipeIdMeta = const VerificationMeta(
    'linkedRecipeId',
  );
  @override
  late final GeneratedColumn<String> linkedRecipeId = GeneratedColumn<String>(
    'linked_recipe_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recipeId,
    position,
    isSection,
    name,
    quantity,
    unit,
    note,
    optional,
    substitutes,
    linkedRecipeId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ingredients';
  @override
  VerificationContext validateIntegrity(
    Insertable<IngredientRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('is_section')) {
      context.handle(
        _isSectionMeta,
        isSection.isAcceptableOrUnknown(data['is_section']!, _isSectionMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('optional')) {
      context.handle(
        _optionalMeta,
        optional.isAcceptableOrUnknown(data['optional']!, _optionalMeta),
      );
    }
    if (data.containsKey('substitutes')) {
      context.handle(
        _substitutesMeta,
        substitutes.isAcceptableOrUnknown(
          data['substitutes']!,
          _substitutesMeta,
        ),
      );
    }
    if (data.containsKey('linked_recipe_id')) {
      context.handle(
        _linkedRecipeIdMeta,
        linkedRecipeId.isAcceptableOrUnknown(
          data['linked_recipe_id']!,
          _linkedRecipeIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IngredientRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IngredientRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      isSection: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_section'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      optional: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}optional'],
      )!,
      substitutes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}substitutes'],
      )!,
      linkedRecipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_recipe_id'],
      ),
    );
  }

  @override
  $IngredientsTable createAlias(String alias) {
    return $IngredientsTable(attachedDatabase, alias);
  }
}

class IngredientRow extends DataClass implements Insertable<IngredientRow> {
  final String id;
  final String recipeId;
  final int position;
  final bool isSection;
  final String name;
  final double? quantity;
  final String unit;
  final String note;
  final bool optional;

  /// Remplaçants possibles de l'ingrédient ; ajouté en v5.
  final String substitutes;

  /// Recette qu'est cet ingrédient (pâte, sauce) ; ajouté en v6.
  final String? linkedRecipeId;
  const IngredientRow({
    required this.id,
    required this.recipeId,
    required this.position,
    required this.isSection,
    required this.name,
    this.quantity,
    required this.unit,
    required this.note,
    required this.optional,
    required this.substitutes,
    this.linkedRecipeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['recipe_id'] = Variable<String>(recipeId);
    map['position'] = Variable<int>(position);
    map['is_section'] = Variable<bool>(isSection);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<double>(quantity);
    }
    map['unit'] = Variable<String>(unit);
    map['note'] = Variable<String>(note);
    map['optional'] = Variable<bool>(optional);
    map['substitutes'] = Variable<String>(substitutes);
    if (!nullToAbsent || linkedRecipeId != null) {
      map['linked_recipe_id'] = Variable<String>(linkedRecipeId);
    }
    return map;
  }

  IngredientsCompanion toCompanion(bool nullToAbsent) {
    return IngredientsCompanion(
      id: Value(id),
      recipeId: Value(recipeId),
      position: Value(position),
      isSection: Value(isSection),
      name: Value(name),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      unit: Value(unit),
      note: Value(note),
      optional: Value(optional),
      substitutes: Value(substitutes),
      linkedRecipeId: linkedRecipeId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedRecipeId),
    );
  }

  factory IngredientRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IngredientRow(
      id: serializer.fromJson<String>(json['id']),
      recipeId: serializer.fromJson<String>(json['recipeId']),
      position: serializer.fromJson<int>(json['position']),
      isSection: serializer.fromJson<bool>(json['isSection']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<double?>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
      note: serializer.fromJson<String>(json['note']),
      optional: serializer.fromJson<bool>(json['optional']),
      substitutes: serializer.fromJson<String>(json['substitutes']),
      linkedRecipeId: serializer.fromJson<String?>(json['linkedRecipeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recipeId': serializer.toJson<String>(recipeId),
      'position': serializer.toJson<int>(position),
      'isSection': serializer.toJson<bool>(isSection),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<double?>(quantity),
      'unit': serializer.toJson<String>(unit),
      'note': serializer.toJson<String>(note),
      'optional': serializer.toJson<bool>(optional),
      'substitutes': serializer.toJson<String>(substitutes),
      'linkedRecipeId': serializer.toJson<String?>(linkedRecipeId),
    };
  }

  IngredientRow copyWith({
    String? id,
    String? recipeId,
    int? position,
    bool? isSection,
    String? name,
    Value<double?> quantity = const Value.absent(),
    String? unit,
    String? note,
    bool? optional,
    String? substitutes,
    Value<String?> linkedRecipeId = const Value.absent(),
  }) => IngredientRow(
    id: id ?? this.id,
    recipeId: recipeId ?? this.recipeId,
    position: position ?? this.position,
    isSection: isSection ?? this.isSection,
    name: name ?? this.name,
    quantity: quantity.present ? quantity.value : this.quantity,
    unit: unit ?? this.unit,
    note: note ?? this.note,
    optional: optional ?? this.optional,
    substitutes: substitutes ?? this.substitutes,
    linkedRecipeId: linkedRecipeId.present
        ? linkedRecipeId.value
        : this.linkedRecipeId,
  );
  IngredientRow copyWithCompanion(IngredientsCompanion data) {
    return IngredientRow(
      id: data.id.present ? data.id.value : this.id,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      position: data.position.present ? data.position.value : this.position,
      isSection: data.isSection.present ? data.isSection.value : this.isSection,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      note: data.note.present ? data.note.value : this.note,
      optional: data.optional.present ? data.optional.value : this.optional,
      substitutes: data.substitutes.present
          ? data.substitutes.value
          : this.substitutes,
      linkedRecipeId: data.linkedRecipeId.present
          ? data.linkedRecipeId.value
          : this.linkedRecipeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IngredientRow(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('position: $position, ')
          ..write('isSection: $isSection, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('note: $note, ')
          ..write('optional: $optional, ')
          ..write('substitutes: $substitutes, ')
          ..write('linkedRecipeId: $linkedRecipeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recipeId,
    position,
    isSection,
    name,
    quantity,
    unit,
    note,
    optional,
    substitutes,
    linkedRecipeId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IngredientRow &&
          other.id == this.id &&
          other.recipeId == this.recipeId &&
          other.position == this.position &&
          other.isSection == this.isSection &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.note == this.note &&
          other.optional == this.optional &&
          other.substitutes == this.substitutes &&
          other.linkedRecipeId == this.linkedRecipeId);
}

class IngredientsCompanion extends UpdateCompanion<IngredientRow> {
  final Value<String> id;
  final Value<String> recipeId;
  final Value<int> position;
  final Value<bool> isSection;
  final Value<String> name;
  final Value<double?> quantity;
  final Value<String> unit;
  final Value<String> note;
  final Value<bool> optional;
  final Value<String> substitutes;
  final Value<String?> linkedRecipeId;
  final Value<int> rowid;
  const IngredientsCompanion({
    this.id = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.position = const Value.absent(),
    this.isSection = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.note = const Value.absent(),
    this.optional = const Value.absent(),
    this.substitutes = const Value.absent(),
    this.linkedRecipeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IngredientsCompanion.insert({
    required String id,
    required String recipeId,
    required int position,
    this.isSection = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.note = const Value.absent(),
    this.optional = const Value.absent(),
    this.substitutes = const Value.absent(),
    this.linkedRecipeId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recipeId = Value(recipeId),
       position = Value(position);
  static Insertable<IngredientRow> custom({
    Expression<String>? id,
    Expression<String>? recipeId,
    Expression<int>? position,
    Expression<bool>? isSection,
    Expression<String>? name,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<String>? note,
    Expression<bool>? optional,
    Expression<String>? substitutes,
    Expression<String>? linkedRecipeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipeId != null) 'recipe_id': recipeId,
      if (position != null) 'position': position,
      if (isSection != null) 'is_section': isSection,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (note != null) 'note': note,
      if (optional != null) 'optional': optional,
      if (substitutes != null) 'substitutes': substitutes,
      if (linkedRecipeId != null) 'linked_recipe_id': linkedRecipeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IngredientsCompanion copyWith({
    Value<String>? id,
    Value<String>? recipeId,
    Value<int>? position,
    Value<bool>? isSection,
    Value<String>? name,
    Value<double?>? quantity,
    Value<String>? unit,
    Value<String>? note,
    Value<bool>? optional,
    Value<String>? substitutes,
    Value<String?>? linkedRecipeId,
    Value<int>? rowid,
  }) {
    return IngredientsCompanion(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      position: position ?? this.position,
      isSection: isSection ?? this.isSection,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      note: note ?? this.note,
      optional: optional ?? this.optional,
      substitutes: substitutes ?? this.substitutes,
      linkedRecipeId: linkedRecipeId ?? this.linkedRecipeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (isSection.present) {
      map['is_section'] = Variable<bool>(isSection.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (optional.present) {
      map['optional'] = Variable<bool>(optional.value);
    }
    if (substitutes.present) {
      map['substitutes'] = Variable<String>(substitutes.value);
    }
    if (linkedRecipeId.present) {
      map['linked_recipe_id'] = Variable<String>(linkedRecipeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngredientsCompanion(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('position: $position, ')
          ..write('isSection: $isSection, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('note: $note, ')
          ..write('optional: $optional, ')
          ..write('substitutes: $substitutes, ')
          ..write('linkedRecipeId: $linkedRecipeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipeStepsTable extends RecipeSteps
    with TableInfo<$RecipeStepsTable, StepRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeStepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
    'recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, recipeId, position, title, body];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_steps';
  @override
  VerificationContext validateIntegrity(
    Insertable<StepRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StepRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StepRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
    );
  }

  @override
  $RecipeStepsTable createAlias(String alias) {
    return $RecipeStepsTable(attachedDatabase, alias);
  }
}

class StepRow extends DataClass implements Insertable<StepRow> {
  final String id;
  final String recipeId;
  final int position;

  /// Titre optionnel de la partie (« Biscuit ») ; ajouté en v2.
  final String title;
  final String body;
  const StepRow({
    required this.id,
    required this.recipeId,
    required this.position,
    required this.title,
    required this.body,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['recipe_id'] = Variable<String>(recipeId);
    map['position'] = Variable<int>(position);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    return map;
  }

  RecipeStepsCompanion toCompanion(bool nullToAbsent) {
    return RecipeStepsCompanion(
      id: Value(id),
      recipeId: Value(recipeId),
      position: Value(position),
      title: Value(title),
      body: Value(body),
    );
  }

  factory StepRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StepRow(
      id: serializer.fromJson<String>(json['id']),
      recipeId: serializer.fromJson<String>(json['recipeId']),
      position: serializer.fromJson<int>(json['position']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recipeId': serializer.toJson<String>(recipeId),
      'position': serializer.toJson<int>(position),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
    };
  }

  StepRow copyWith({
    String? id,
    String? recipeId,
    int? position,
    String? title,
    String? body,
  }) => StepRow(
    id: id ?? this.id,
    recipeId: recipeId ?? this.recipeId,
    position: position ?? this.position,
    title: title ?? this.title,
    body: body ?? this.body,
  );
  StepRow copyWithCompanion(RecipeStepsCompanion data) {
    return StepRow(
      id: data.id.present ? data.id.value : this.id,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      position: data.position.present ? data.position.value : this.position,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StepRow(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('position: $position, ')
          ..write('title: $title, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recipeId, position, title, body);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StepRow &&
          other.id == this.id &&
          other.recipeId == this.recipeId &&
          other.position == this.position &&
          other.title == this.title &&
          other.body == this.body);
}

class RecipeStepsCompanion extends UpdateCompanion<StepRow> {
  final Value<String> id;
  final Value<String> recipeId;
  final Value<int> position;
  final Value<String> title;
  final Value<String> body;
  final Value<int> rowid;
  const RecipeStepsCompanion({
    this.id = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.position = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipeStepsCompanion.insert({
    required String id,
    required String recipeId,
    required int position,
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recipeId = Value(recipeId),
       position = Value(position);
  static Insertable<StepRow> custom({
    Expression<String>? id,
    Expression<String>? recipeId,
    Expression<int>? position,
    Expression<String>? title,
    Expression<String>? body,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipeId != null) 'recipe_id': recipeId,
      if (position != null) 'position': position,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipeStepsCompanion copyWith({
    Value<String>? id,
    Value<String>? recipeId,
    Value<int>? position,
    Value<String>? title,
    Value<String>? body,
    Value<int>? rowid,
  }) {
    return RecipeStepsCompanion(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      position: position ?? this.position,
      title: title ?? this.title,
      body: body ?? this.body,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeStepsCompanion(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('position: $position, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipePhotosTable extends RecipePhotos
    with TableInfo<$RecipePhotosTable, ExtraPhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipePhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
    'recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileMeta = const VerificationMeta('file');
  @override
  late final GeneratedColumn<String> file = GeneratedColumn<String>(
    'file',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [recipeId, position, file];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtraPhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('file')) {
      context.handle(
        _fileMeta,
        file.isAcceptableOrUnknown(data['file']!, _fileMeta),
      );
    } else if (isInserting) {
      context.missing(_fileMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recipeId, position};
  @override
  ExtraPhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtraPhotoRow(
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      file: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file'],
      )!,
    );
  }

  @override
  $RecipePhotosTable createAlias(String alias) {
    return $RecipePhotosTable(attachedDatabase, alias);
  }
}

class ExtraPhotoRow extends DataClass implements Insertable<ExtraPhotoRow> {
  final String recipeId;
  final int position;
  final String file;
  const ExtraPhotoRow({
    required this.recipeId,
    required this.position,
    required this.file,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recipe_id'] = Variable<String>(recipeId);
    map['position'] = Variable<int>(position);
    map['file'] = Variable<String>(file);
    return map;
  }

  RecipePhotosCompanion toCompanion(bool nullToAbsent) {
    return RecipePhotosCompanion(
      recipeId: Value(recipeId),
      position: Value(position),
      file: Value(file),
    );
  }

  factory ExtraPhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtraPhotoRow(
      recipeId: serializer.fromJson<String>(json['recipeId']),
      position: serializer.fromJson<int>(json['position']),
      file: serializer.fromJson<String>(json['file']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recipeId': serializer.toJson<String>(recipeId),
      'position': serializer.toJson<int>(position),
      'file': serializer.toJson<String>(file),
    };
  }

  ExtraPhotoRow copyWith({String? recipeId, int? position, String? file}) =>
      ExtraPhotoRow(
        recipeId: recipeId ?? this.recipeId,
        position: position ?? this.position,
        file: file ?? this.file,
      );
  ExtraPhotoRow copyWithCompanion(RecipePhotosCompanion data) {
    return ExtraPhotoRow(
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      position: data.position.present ? data.position.value : this.position,
      file: data.file.present ? data.file.value : this.file,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtraPhotoRow(')
          ..write('recipeId: $recipeId, ')
          ..write('position: $position, ')
          ..write('file: $file')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recipeId, position, file);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtraPhotoRow &&
          other.recipeId == this.recipeId &&
          other.position == this.position &&
          other.file == this.file);
}

class RecipePhotosCompanion extends UpdateCompanion<ExtraPhotoRow> {
  final Value<String> recipeId;
  final Value<int> position;
  final Value<String> file;
  final Value<int> rowid;
  const RecipePhotosCompanion({
    this.recipeId = const Value.absent(),
    this.position = const Value.absent(),
    this.file = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipePhotosCompanion.insert({
    required String recipeId,
    required int position,
    required String file,
    this.rowid = const Value.absent(),
  }) : recipeId = Value(recipeId),
       position = Value(position),
       file = Value(file);
  static Insertable<ExtraPhotoRow> custom({
    Expression<String>? recipeId,
    Expression<int>? position,
    Expression<String>? file,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recipeId != null) 'recipe_id': recipeId,
      if (position != null) 'position': position,
      if (file != null) 'file': file,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipePhotosCompanion copyWith({
    Value<String>? recipeId,
    Value<int>? position,
    Value<String>? file,
    Value<int>? rowid,
  }) {
    return RecipePhotosCompanion(
      recipeId: recipeId ?? this.recipeId,
      position: position ?? this.position,
      file: file ?? this.file,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (file.present) {
      map['file'] = Variable<String>(file.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipePhotosCompanion(')
          ..write('recipeId: $recipeId, ')
          ..write('position: $position, ')
          ..write('file: $file, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EquipmentItemsTable extends EquipmentItems
    with TableInfo<$EquipmentItemsTable, EquipmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipmentItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<EquipmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EquipmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquipmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $EquipmentItemsTable createAlias(String alias) {
    return $EquipmentItemsTable(attachedDatabase, alias);
  }
}

class EquipmentRow extends DataClass implements Insertable<EquipmentRow> {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const EquipmentRow({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  EquipmentItemsCompanion toCompanion(bool nullToAbsent) {
    return EquipmentItemsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory EquipmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquipmentRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  EquipmentRow copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => EquipmentRow(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  EquipmentRow copyWithCompanion(EquipmentItemsCompanion data) {
    return EquipmentRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquipmentRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class EquipmentItemsCompanion extends UpdateCompanion<EquipmentRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const EquipmentItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EquipmentItemsCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<EquipmentRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EquipmentItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return EquipmentItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipeEquipmentTable extends RecipeEquipment
    with TableInfo<$RecipeEquipmentTable, RecipeEquipmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeEquipmentTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
    'recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equipmentIdMeta = const VerificationMeta(
    'equipmentId',
  );
  @override
  late final GeneratedColumn<String> equipmentId = GeneratedColumn<String>(
    'equipment_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [recipeId, position, equipmentId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_equipment';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipeEquipmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('equipment_id')) {
      context.handle(
        _equipmentIdMeta,
        equipmentId.isAcceptableOrUnknown(
          data['equipment_id']!,
          _equipmentIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_equipmentIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recipeId, position};
  @override
  RecipeEquipmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeEquipmentRow(
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      equipmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment_id'],
      )!,
    );
  }

  @override
  $RecipeEquipmentTable createAlias(String alias) {
    return $RecipeEquipmentTable(attachedDatabase, alias);
  }
}

class RecipeEquipmentRow extends DataClass
    implements Insertable<RecipeEquipmentRow> {
  final String recipeId;
  final int position;
  final String equipmentId;
  const RecipeEquipmentRow({
    required this.recipeId,
    required this.position,
    required this.equipmentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recipe_id'] = Variable<String>(recipeId);
    map['position'] = Variable<int>(position);
    map['equipment_id'] = Variable<String>(equipmentId);
    return map;
  }

  RecipeEquipmentCompanion toCompanion(bool nullToAbsent) {
    return RecipeEquipmentCompanion(
      recipeId: Value(recipeId),
      position: Value(position),
      equipmentId: Value(equipmentId),
    );
  }

  factory RecipeEquipmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeEquipmentRow(
      recipeId: serializer.fromJson<String>(json['recipeId']),
      position: serializer.fromJson<int>(json['position']),
      equipmentId: serializer.fromJson<String>(json['equipmentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recipeId': serializer.toJson<String>(recipeId),
      'position': serializer.toJson<int>(position),
      'equipmentId': serializer.toJson<String>(equipmentId),
    };
  }

  RecipeEquipmentRow copyWith({
    String? recipeId,
    int? position,
    String? equipmentId,
  }) => RecipeEquipmentRow(
    recipeId: recipeId ?? this.recipeId,
    position: position ?? this.position,
    equipmentId: equipmentId ?? this.equipmentId,
  );
  RecipeEquipmentRow copyWithCompanion(RecipeEquipmentCompanion data) {
    return RecipeEquipmentRow(
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      position: data.position.present ? data.position.value : this.position,
      equipmentId: data.equipmentId.present
          ? data.equipmentId.value
          : this.equipmentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeEquipmentRow(')
          ..write('recipeId: $recipeId, ')
          ..write('position: $position, ')
          ..write('equipmentId: $equipmentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recipeId, position, equipmentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeEquipmentRow &&
          other.recipeId == this.recipeId &&
          other.position == this.position &&
          other.equipmentId == this.equipmentId);
}

class RecipeEquipmentCompanion extends UpdateCompanion<RecipeEquipmentRow> {
  final Value<String> recipeId;
  final Value<int> position;
  final Value<String> equipmentId;
  final Value<int> rowid;
  const RecipeEquipmentCompanion({
    this.recipeId = const Value.absent(),
    this.position = const Value.absent(),
    this.equipmentId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipeEquipmentCompanion.insert({
    required String recipeId,
    required int position,
    required String equipmentId,
    this.rowid = const Value.absent(),
  }) : recipeId = Value(recipeId),
       position = Value(position),
       equipmentId = Value(equipmentId);
  static Insertable<RecipeEquipmentRow> custom({
    Expression<String>? recipeId,
    Expression<int>? position,
    Expression<String>? equipmentId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recipeId != null) 'recipe_id': recipeId,
      if (position != null) 'position': position,
      if (equipmentId != null) 'equipment_id': equipmentId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipeEquipmentCompanion copyWith({
    Value<String>? recipeId,
    Value<int>? position,
    Value<String>? equipmentId,
    Value<int>? rowid,
  }) {
    return RecipeEquipmentCompanion(
      recipeId: recipeId ?? this.recipeId,
      position: position ?? this.position,
      equipmentId: equipmentId ?? this.equipmentId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (equipmentId.present) {
      map['equipment_id'] = Variable<String>(equipmentId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeEquipmentCompanion(')
          ..write('recipeId: $recipeId, ')
          ..write('position: $position, ')
          ..write('equipmentId: $equipmentId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RecipesTable recipes = $RecipesTable(this);
  late final $IngredientsTable ingredients = $IngredientsTable(this);
  late final $RecipeStepsTable recipeSteps = $RecipeStepsTable(this);
  late final $RecipePhotosTable recipePhotos = $RecipePhotosTable(this);
  late final $EquipmentItemsTable equipmentItems = $EquipmentItemsTable(this);
  late final $RecipeEquipmentTable recipeEquipment = $RecipeEquipmentTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    recipes,
    ingredients,
    recipeSteps,
    recipePhotos,
    equipmentItems,
    recipeEquipment,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recipes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ingredients', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recipes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recipe_steps', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recipes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recipe_photos', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recipes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recipe_equipment', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$RecipesTableCreateCompanionBuilder = RecipesCompanion Function({
  required String id,
  Value<String> title,
  Value<String> description,
  Value<String> source,
  Value<String> notes,
  Value<String> tips,
  Value<int?> servings,
  Value<String> servingsUnit,
  Value<int?> prepMinutes,
  Value<int?> cookMinutes,
  Value<int?> restMinutes,
  Value<int> timesCooked,
  Value<String?> mainPhoto,
  Value<bool> isFavorite,
  Value<int?> rating,
  Value<String?> status,
  Value<String> course,
  Value<String> category,
  Value<String> collections,
  Value<String> equipment,
  Value<String> videoLinks,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$RecipesTableUpdateCompanionBuilder = RecipesCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> description,
  Value<String> source,
  Value<String> notes,
  Value<String> tips,
  Value<int?> servings,
  Value<String> servingsUnit,
  Value<int?> prepMinutes,
  Value<int?> cookMinutes,
  Value<int?> restMinutes,
  Value<int> timesCooked,
  Value<String?> mainPhoto,
  Value<bool> isFavorite,
  Value<int?> rating,
  Value<String?> status,
  Value<String> course,
  Value<String> category,
  Value<String> collections,
  Value<String> equipment,
  Value<String> videoLinks,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$RecipesTableReferences
    extends BaseReferences<_$AppDatabase, $RecipesTable, RecipeRow> {
  $$RecipesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$IngredientsTable, List<IngredientRow>>
  _ingredientsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.ingredients,
    aliasName: 'recipes__id__ingredients__recipe_id',
  );

  $$IngredientsTableProcessedTableManager get ingredientsRefs {
    final manager = $$IngredientsTableTableManager(
      $_db,
      $_db.ingredients,
    ).filter((f) => f.recipeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_ingredientsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecipeStepsTable, List<StepRow>>
  _recipeStepsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recipeSteps,
    aliasName: 'recipes__id__recipe_steps__recipe_id',
  );

  $$RecipeStepsTableProcessedTableManager get recipeStepsRefs {
    final manager = $$RecipeStepsTableTableManager(
      $_db,
      $_db.recipeSteps,
    ).filter((f) => f.recipeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recipeStepsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecipePhotosTable, List<ExtraPhotoRow>>
  _recipePhotosRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recipePhotos,
    aliasName: 'recipes__id__recipe_photos__recipe_id',
  );

  $$RecipePhotosTableProcessedTableManager get recipePhotosRefs {
    final manager = $$RecipePhotosTableTableManager(
      $_db,
      $_db.recipePhotos,
    ).filter((f) => f.recipeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recipePhotosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecipeEquipmentTable, List<RecipeEquipmentRow>>
  _recipeEquipmentRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recipeEquipment,
    aliasName: 'recipes__id__recipe_equipment__recipe_id',
  );

  $$RecipeEquipmentTableProcessedTableManager get recipeEquipmentRefs {
    final manager = $$RecipeEquipmentTableTableManager(
      $_db,
      $_db.recipeEquipment,
    ).filter((f) => f.recipeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _recipeEquipmentRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecipesTableFilterComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tips => $composableBuilder(
    column: $table.tips,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get servings => $composableBuilder(
    column: $table.servings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servingsUnit => $composableBuilder(
    column: $table.servingsUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get prepMinutes => $composableBuilder(
    column: $table.prepMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cookMinutes => $composableBuilder(
    column: $table.cookMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restMinutes => $composableBuilder(
    column: $table.restMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timesCooked => $composableBuilder(
    column: $table.timesCooked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mainPhoto => $composableBuilder(
    column: $table.mainPhoto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get course => $composableBuilder(
    column: $table.course,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collections => $composableBuilder(
    column: $table.collections,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoLinks => $composableBuilder(
    column: $table.videoLinks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> ingredientsRefs(
    Expression<bool> Function($$IngredientsTableFilterComposer f) f,
  ) {
    final $$IngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableFilterComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recipeStepsRefs(
    Expression<bool> Function($$RecipeStepsTableFilterComposer f) f,
  ) {
    final $$RecipeStepsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeSteps,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeStepsTableFilterComposer(
            $db: $db,
            $table: $db.recipeSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recipePhotosRefs(
    Expression<bool> Function($$RecipePhotosTableFilterComposer f) f,
  ) {
    final $$RecipePhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipePhotos,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipePhotosTableFilterComposer(
            $db: $db,
            $table: $db.recipePhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recipeEquipmentRefs(
    Expression<bool> Function($$RecipeEquipmentTableFilterComposer f) f,
  ) {
    final $$RecipeEquipmentTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeEquipment,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeEquipmentTableFilterComposer(
            $db: $db,
            $table: $db.recipeEquipment,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tips => $composableBuilder(
    column: $table.tips,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get servings => $composableBuilder(
    column: $table.servings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servingsUnit => $composableBuilder(
    column: $table.servingsUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get prepMinutes => $composableBuilder(
    column: $table.prepMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cookMinutes => $composableBuilder(
    column: $table.cookMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restMinutes => $composableBuilder(
    column: $table.restMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timesCooked => $composableBuilder(
    column: $table.timesCooked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mainPhoto => $composableBuilder(
    column: $table.mainPhoto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get course => $composableBuilder(
    column: $table.course,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collections => $composableBuilder(
    column: $table.collections,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipment => $composableBuilder(
    column: $table.equipment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoLinks => $composableBuilder(
    column: $table.videoLinks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get tips =>
      $composableBuilder(column: $table.tips, builder: (column) => column);

  GeneratedColumn<int> get servings =>
      $composableBuilder(column: $table.servings, builder: (column) => column);

  GeneratedColumn<String> get servingsUnit => $composableBuilder(
    column: $table.servingsUnit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get prepMinutes => $composableBuilder(
    column: $table.prepMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cookMinutes => $composableBuilder(
    column: $table.cookMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restMinutes => $composableBuilder(
    column: $table.restMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timesCooked => $composableBuilder(
    column: $table.timesCooked,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mainPhoto =>
      $composableBuilder(column: $table.mainPhoto, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get course =>
      $composableBuilder(column: $table.course, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get collections => $composableBuilder(
    column: $table.collections,
    builder: (column) => column,
  );

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<String> get videoLinks => $composableBuilder(
    column: $table.videoLinks,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> ingredientsRefs<T extends Object>(
    Expression<T> Function($$IngredientsTableAnnotationComposer a) f,
  ) {
    final $$IngredientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableAnnotationComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recipeStepsRefs<T extends Object>(
    Expression<T> Function($$RecipeStepsTableAnnotationComposer a) f,
  ) {
    final $$RecipeStepsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeSteps,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeStepsTableAnnotationComposer(
            $db: $db,
            $table: $db.recipeSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recipePhotosRefs<T extends Object>(
    Expression<T> Function($$RecipePhotosTableAnnotationComposer a) f,
  ) {
    final $$RecipePhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipePhotos,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipePhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.recipePhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recipeEquipmentRefs<T extends Object>(
    Expression<T> Function($$RecipeEquipmentTableAnnotationComposer a) f,
  ) {
    final $$RecipeEquipmentTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeEquipment,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeEquipmentTableAnnotationComposer(
            $db: $db,
            $table: $db.recipeEquipment,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecipesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipesTable,
          RecipeRow,
          $$RecipesTableFilterComposer,
          $$RecipesTableOrderingComposer,
          $$RecipesTableAnnotationComposer,
          $$RecipesTableCreateCompanionBuilder,
          $$RecipesTableUpdateCompanionBuilder,
          (RecipeRow, $$RecipesTableReferences),
          RecipeRow,
          PrefetchHooks Function({
            bool ingredientsRefs,
            bool recipeStepsRefs,
            bool recipePhotosRefs,
            bool recipeEquipmentRefs,
          })
        > {
  $$RecipesTableTableManager(_$AppDatabase db, $RecipesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> tips = const Value.absent(),
                Value<int?> servings = const Value.absent(),
                Value<String> servingsUnit = const Value.absent(),
                Value<int?> prepMinutes = const Value.absent(),
                Value<int?> cookMinutes = const Value.absent(),
                Value<int?> restMinutes = const Value.absent(),
                Value<int> timesCooked = const Value.absent(),
                Value<String?> mainPhoto = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String> course = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> collections = const Value.absent(),
                Value<String> equipment = const Value.absent(),
                Value<String> videoLinks = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipesCompanion(
                id: id,
                title: title,
                description: description,
                source: source,
                notes: notes,
                tips: tips,
                servings: servings,
                servingsUnit: servingsUnit,
                prepMinutes: prepMinutes,
                cookMinutes: cookMinutes,
                restMinutes: restMinutes,
                timesCooked: timesCooked,
                mainPhoto: mainPhoto,
                isFavorite: isFavorite,
                rating: rating,
                status: status,
                course: course,
                category: category,
                collections: collections,
                equipment: equipment,
                videoLinks: videoLinks,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> tips = const Value.absent(),
                Value<int?> servings = const Value.absent(),
                Value<String> servingsUnit = const Value.absent(),
                Value<int?> prepMinutes = const Value.absent(),
                Value<int?> cookMinutes = const Value.absent(),
                Value<int?> restMinutes = const Value.absent(),
                Value<int> timesCooked = const Value.absent(),
                Value<String?> mainPhoto = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int?> rating = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String> course = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> collections = const Value.absent(),
                Value<String> equipment = const Value.absent(),
                Value<String> videoLinks = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipesCompanion.insert(
                id: id,
                title: title,
                description: description,
                source: source,
                notes: notes,
                tips: tips,
                servings: servings,
                servingsUnit: servingsUnit,
                prepMinutes: prepMinutes,
                cookMinutes: cookMinutes,
                restMinutes: restMinutes,
                timesCooked: timesCooked,
                mainPhoto: mainPhoto,
                isFavorite: isFavorite,
                rating: rating,
                status: status,
                course: course,
                category: category,
                collections: collections,
                equipment: equipment,
                videoLinks: videoLinks,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecipesTable, RecipeRow>(table),
                  $$RecipesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                ingredientsRefs = false,
                recipeStepsRefs = false,
                recipePhotosRefs = false,
                recipeEquipmentRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (ingredientsRefs) db.ingredients,
                    if (recipeStepsRefs) db.recipeSteps,
                    if (recipePhotosRefs) db.recipePhotos,
                    if (recipeEquipmentRefs) db.recipeEquipment,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (ingredientsRefs)
                        await $_getPrefetchedDataByColumns<
                          RecipeRow,
                          $RecipesTable,
                          IngredientRow,
                          $IngredientsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RecipesTableReferences
                              ._ingredientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).ingredientsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'recipe_id',
                          typedResults: items,
                        ),
                      if (recipeStepsRefs)
                        await $_getPrefetchedDataByColumns<
                          RecipeRow,
                          $RecipesTable,
                          StepRow,
                          $RecipeStepsTable
                        >(
                          currentTable: table,
                          referencedTable: $$RecipesTableReferences
                              ._recipeStepsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).recipeStepsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'recipe_id',
                          typedResults: items,
                        ),
                      if (recipePhotosRefs)
                        await $_getPrefetchedDataByColumns<
                          RecipeRow,
                          $RecipesTable,
                          ExtraPhotoRow,
                          $RecipePhotosTable
                        >(
                          currentTable: table,
                          referencedTable: $$RecipesTableReferences
                              ._recipePhotosRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).recipePhotosRefs,
                          currentColumn: 'id',
                          referencedColumn: 'recipe_id',
                          typedResults: items,
                        ),
                      if (recipeEquipmentRefs)
                        await $_getPrefetchedDataByColumns<
                          RecipeRow,
                          $RecipesTable,
                          RecipeEquipmentRow,
                          $RecipeEquipmentTable
                        >(
                          currentTable: table,
                          referencedTable: $$RecipesTableReferences
                              ._recipeEquipmentRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).recipeEquipmentRefs,
                          currentColumn: 'id',
                          referencedColumn: 'recipe_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RecipesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipesTable,
      RecipeRow,
      $$RecipesTableFilterComposer,
      $$RecipesTableOrderingComposer,
      $$RecipesTableAnnotationComposer,
      $$RecipesTableCreateCompanionBuilder,
      $$RecipesTableUpdateCompanionBuilder,
      (RecipeRow, $$RecipesTableReferences),
      RecipeRow,
      PrefetchHooks Function({
        bool ingredientsRefs,
        bool recipeStepsRefs,
        bool recipePhotosRefs,
        bool recipeEquipmentRefs,
      })
    >;
typedef $$IngredientsTableCreateCompanionBuilder =
    IngredientsCompanion Function({
      required String id,
      required String recipeId,
      required int position,
      Value<bool> isSection,
      Value<String> name,
      Value<double?> quantity,
      Value<String> unit,
      Value<String> note,
      Value<bool> optional,
      Value<String> substitutes,
      Value<String?> linkedRecipeId,
      Value<int> rowid,
    });
typedef $$IngredientsTableUpdateCompanionBuilder =
    IngredientsCompanion Function({
      Value<String> id,
      Value<String> recipeId,
      Value<int> position,
      Value<bool> isSection,
      Value<String> name,
      Value<double?> quantity,
      Value<String> unit,
      Value<String> note,
      Value<bool> optional,
      Value<String> substitutes,
      Value<String?> linkedRecipeId,
      Value<int> rowid,
    });

final class $$IngredientsTableReferences
    extends BaseReferences<_$AppDatabase, $IngredientsTable, IngredientRow> {
  $$IngredientsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias('ingredients__recipe_id__recipes__id');

  $$RecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<String>('recipe_id')!;

    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$IngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSection => $composableBuilder(
    column: $table.isSection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get optional => $composableBuilder(
    column: $table.optional,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get substitutes => $composableBuilder(
    column: $table.substitutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedRecipeId => $composableBuilder(
    column: $table.linkedRecipeId,
    builder: (column) => ColumnFilters(column),
  );

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSection => $composableBuilder(
    column: $table.isSection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get optional => $composableBuilder(
    column: $table.optional,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get substitutes => $composableBuilder(
    column: $table.substitutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedRecipeId => $composableBuilder(
    column: $table.linkedRecipeId,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get isSection =>
      $composableBuilder(column: $table.isSection, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get optional =>
      $composableBuilder(column: $table.optional, builder: (column) => column);

  GeneratedColumn<String> get substitutes => $composableBuilder(
    column: $table.substitutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedRecipeId => $composableBuilder(
    column: $table.linkedRecipeId,
    builder: (column) => column,
  );

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IngredientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IngredientsTable,
          IngredientRow,
          $$IngredientsTableFilterComposer,
          $$IngredientsTableOrderingComposer,
          $$IngredientsTableAnnotationComposer,
          $$IngredientsTableCreateCompanionBuilder,
          $$IngredientsTableUpdateCompanionBuilder,
          (IngredientRow, $$IngredientsTableReferences),
          IngredientRow,
          PrefetchHooks Function({bool recipeId})
        > {
  $$IngredientsTableTableManager(_$AppDatabase db, $IngredientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IngredientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IngredientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recipeId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<bool> isSection = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<bool> optional = const Value.absent(),
                Value<String> substitutes = const Value.absent(),
                Value<String?> linkedRecipeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IngredientsCompanion(
                id: id,
                recipeId: recipeId,
                position: position,
                isSection: isSection,
                name: name,
                quantity: quantity,
                unit: unit,
                note: note,
                optional: optional,
                substitutes: substitutes,
                linkedRecipeId: linkedRecipeId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recipeId,
                required int position,
                Value<bool> isSection = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<bool> optional = const Value.absent(),
                Value<String> substitutes = const Value.absent(),
                Value<String?> linkedRecipeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IngredientsCompanion.insert(
                id: id,
                recipeId: recipeId,
                position: position,
                isSection: isSection,
                name: name,
                quantity: quantity,
                unit: unit,
                note: note,
                optional: optional,
                substitutes: substitutes,
                linkedRecipeId: linkedRecipeId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IngredientsTable, IngredientRow>(table),
                  $$IngredientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recipeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recipeId,
                        referencedTable: $$IngredientsTableReferences
                            ._recipeIdTable(db),
                        referencedColumn: $$IngredientsTableReferences
                            ._recipeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$IngredientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IngredientsTable,
      IngredientRow,
      $$IngredientsTableFilterComposer,
      $$IngredientsTableOrderingComposer,
      $$IngredientsTableAnnotationComposer,
      $$IngredientsTableCreateCompanionBuilder,
      $$IngredientsTableUpdateCompanionBuilder,
      (IngredientRow, $$IngredientsTableReferences),
      IngredientRow,
      PrefetchHooks Function({bool recipeId})
    >;
typedef $$RecipeStepsTableCreateCompanionBuilder =
    RecipeStepsCompanion Function({
      required String id,
      required String recipeId,
      required int position,
      Value<String> title,
      Value<String> body,
      Value<int> rowid,
    });
typedef $$RecipeStepsTableUpdateCompanionBuilder =
    RecipeStepsCompanion Function({
      Value<String> id,
      Value<String> recipeId,
      Value<int> position,
      Value<String> title,
      Value<String> body,
      Value<int> rowid,
    });

final class $$RecipeStepsTableReferences
    extends BaseReferences<_$AppDatabase, $RecipeStepsTable, StepRow> {
  $$RecipeStepsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias('recipe_steps__recipe_id__recipes__id');

  $$RecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<String>('recipe_id')!;

    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipeStepsTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeStepsTable> {
  $$RecipeStepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeStepsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeStepsTable> {
  $$RecipeStepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeStepsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeStepsTable> {
  $$RecipeStepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeStepsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipeStepsTable,
          StepRow,
          $$RecipeStepsTableFilterComposer,
          $$RecipeStepsTableOrderingComposer,
          $$RecipeStepsTableAnnotationComposer,
          $$RecipeStepsTableCreateCompanionBuilder,
          $$RecipeStepsTableUpdateCompanionBuilder,
          (StepRow, $$RecipeStepsTableReferences),
          StepRow,
          PrefetchHooks Function({bool recipeId})
        > {
  $$RecipeStepsTableTableManager(_$AppDatabase db, $RecipeStepsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeStepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeStepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeStepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recipeId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipeStepsCompanion(
                id: id,
                recipeId: recipeId,
                position: position,
                title: title,
                body: body,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recipeId,
                required int position,
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipeStepsCompanion.insert(
                id: id,
                recipeId: recipeId,
                position: position,
                title: title,
                body: body,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecipeStepsTable, StepRow>(table),
                  $$RecipeStepsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recipeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recipeId,
                        referencedTable: $$RecipeStepsTableReferences
                            ._recipeIdTable(db),
                        referencedColumn: $$RecipeStepsTableReferences
                            ._recipeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecipeStepsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipeStepsTable,
      StepRow,
      $$RecipeStepsTableFilterComposer,
      $$RecipeStepsTableOrderingComposer,
      $$RecipeStepsTableAnnotationComposer,
      $$RecipeStepsTableCreateCompanionBuilder,
      $$RecipeStepsTableUpdateCompanionBuilder,
      (StepRow, $$RecipeStepsTableReferences),
      StepRow,
      PrefetchHooks Function({bool recipeId})
    >;
typedef $$RecipePhotosTableCreateCompanionBuilder =
    RecipePhotosCompanion Function({
      required String recipeId,
      required int position,
      required String file,
      Value<int> rowid,
    });
typedef $$RecipePhotosTableUpdateCompanionBuilder =
    RecipePhotosCompanion Function({
      Value<String> recipeId,
      Value<int> position,
      Value<String> file,
      Value<int> rowid,
    });

final class $$RecipePhotosTableReferences
    extends BaseReferences<_$AppDatabase, $RecipePhotosTable, ExtraPhotoRow> {
  $$RecipePhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias('recipe_photos__recipe_id__recipes__id');

  $$RecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<String>('recipe_id')!;

    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipePhotosTableFilterComposer
    extends Composer<_$AppDatabase, $RecipePhotosTable> {
  $$RecipePhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get file => $composableBuilder(
    column: $table.file,
    builder: (column) => ColumnFilters(column),
  );

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipePhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipePhotosTable> {
  $$RecipePhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get file => $composableBuilder(
    column: $table.file,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipePhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipePhotosTable> {
  $$RecipePhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get file =>
      $composableBuilder(column: $table.file, builder: (column) => column);

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipePhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipePhotosTable,
          ExtraPhotoRow,
          $$RecipePhotosTableFilterComposer,
          $$RecipePhotosTableOrderingComposer,
          $$RecipePhotosTableAnnotationComposer,
          $$RecipePhotosTableCreateCompanionBuilder,
          $$RecipePhotosTableUpdateCompanionBuilder,
          (ExtraPhotoRow, $$RecipePhotosTableReferences),
          ExtraPhotoRow,
          PrefetchHooks Function({bool recipeId})
        > {
  $$RecipePhotosTableTableManager(_$AppDatabase db, $RecipePhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipePhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipePhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipePhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recipeId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> file = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipePhotosCompanion(
                recipeId: recipeId,
                position: position,
                file: file,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recipeId,
                required int position,
                required String file,
                Value<int> rowid = const Value.absent(),
              }) => RecipePhotosCompanion.insert(
                recipeId: recipeId,
                position: position,
                file: file,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecipePhotosTable, ExtraPhotoRow>(table),
                  $$RecipePhotosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recipeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recipeId,
                        referencedTable: $$RecipePhotosTableReferences
                            ._recipeIdTable(db),
                        referencedColumn: $$RecipePhotosTableReferences
                            ._recipeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecipePhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipePhotosTable,
      ExtraPhotoRow,
      $$RecipePhotosTableFilterComposer,
      $$RecipePhotosTableOrderingComposer,
      $$RecipePhotosTableAnnotationComposer,
      $$RecipePhotosTableCreateCompanionBuilder,
      $$RecipePhotosTableUpdateCompanionBuilder,
      (ExtraPhotoRow, $$RecipePhotosTableReferences),
      ExtraPhotoRow,
      PrefetchHooks Function({bool recipeId})
    >;
typedef $$EquipmentItemsTableCreateCompanionBuilder =
    EquipmentItemsCompanion Function({
      required String id,
      required String name,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$EquipmentItemsTableUpdateCompanionBuilder =
    EquipmentItemsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$EquipmentItemsTableFilterComposer
    extends Composer<_$AppDatabase, $EquipmentItemsTable> {
  $$EquipmentItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EquipmentItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $EquipmentItemsTable> {
  $$EquipmentItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EquipmentItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EquipmentItemsTable> {
  $$EquipmentItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$EquipmentItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EquipmentItemsTable,
          EquipmentRow,
          $$EquipmentItemsTableFilterComposer,
          $$EquipmentItemsTableOrderingComposer,
          $$EquipmentItemsTableAnnotationComposer,
          $$EquipmentItemsTableCreateCompanionBuilder,
          $$EquipmentItemsTableUpdateCompanionBuilder,
          (
            EquipmentRow,
            BaseReferences<_$AppDatabase, $EquipmentItemsTable, EquipmentRow>,
          ),
          EquipmentRow,
          PrefetchHooks Function()
        > {
  $$EquipmentItemsTableTableManager(
    _$AppDatabase db,
    $EquipmentItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EquipmentItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EquipmentItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EquipmentItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EquipmentItemsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EquipmentItemsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EquipmentItemsTable, EquipmentRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EquipmentItemsTable,
                    EquipmentRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EquipmentItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EquipmentItemsTable,
      EquipmentRow,
      $$EquipmentItemsTableFilterComposer,
      $$EquipmentItemsTableOrderingComposer,
      $$EquipmentItemsTableAnnotationComposer,
      $$EquipmentItemsTableCreateCompanionBuilder,
      $$EquipmentItemsTableUpdateCompanionBuilder,
      (
        EquipmentRow,
        BaseReferences<_$AppDatabase, $EquipmentItemsTable, EquipmentRow>,
      ),
      EquipmentRow,
      PrefetchHooks Function()
    >;
typedef $$RecipeEquipmentTableCreateCompanionBuilder =
    RecipeEquipmentCompanion Function({
      required String recipeId,
      required int position,
      required String equipmentId,
      Value<int> rowid,
    });
typedef $$RecipeEquipmentTableUpdateCompanionBuilder =
    RecipeEquipmentCompanion Function({
      Value<String> recipeId,
      Value<int> position,
      Value<String> equipmentId,
      Value<int> rowid,
    });

final class $$RecipeEquipmentTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RecipeEquipmentTable,
          RecipeEquipmentRow
        > {
  $$RecipeEquipmentTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias('recipe_equipment__recipe_id__recipes__id');

  $$RecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<String>('recipe_id')!;

    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipeEquipmentTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeEquipmentTable> {
  $$RecipeEquipmentTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipmentId => $composableBuilder(
    column: $table.equipmentId,
    builder: (column) => ColumnFilters(column),
  );

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeEquipmentTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeEquipmentTable> {
  $$RecipeEquipmentTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipmentId => $composableBuilder(
    column: $table.equipmentId,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeEquipmentTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeEquipmentTable> {
  $$RecipeEquipmentTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get equipmentId => $composableBuilder(
    column: $table.equipmentId,
    builder: (column) => column,
  );

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeEquipmentTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipeEquipmentTable,
          RecipeEquipmentRow,
          $$RecipeEquipmentTableFilterComposer,
          $$RecipeEquipmentTableOrderingComposer,
          $$RecipeEquipmentTableAnnotationComposer,
          $$RecipeEquipmentTableCreateCompanionBuilder,
          $$RecipeEquipmentTableUpdateCompanionBuilder,
          (RecipeEquipmentRow, $$RecipeEquipmentTableReferences),
          RecipeEquipmentRow,
          PrefetchHooks Function({bool recipeId})
        > {
  $$RecipeEquipmentTableTableManager(
    _$AppDatabase db,
    $RecipeEquipmentTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeEquipmentTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeEquipmentTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeEquipmentTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recipeId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> equipmentId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipeEquipmentCompanion(
                recipeId: recipeId,
                position: position,
                equipmentId: equipmentId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recipeId,
                required int position,
                required String equipmentId,
                Value<int> rowid = const Value.absent(),
              }) => RecipeEquipmentCompanion.insert(
                recipeId: recipeId,
                position: position,
                equipmentId: equipmentId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecipeEquipmentTable, RecipeEquipmentRow>(table),
                  $$RecipeEquipmentTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recipeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.recipeId,
                        referencedTable: $$RecipeEquipmentTableReferences
                            ._recipeIdTable(db),
                        referencedColumn: $$RecipeEquipmentTableReferences
                            ._recipeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecipeEquipmentTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipeEquipmentTable,
      RecipeEquipmentRow,
      $$RecipeEquipmentTableFilterComposer,
      $$RecipeEquipmentTableOrderingComposer,
      $$RecipeEquipmentTableAnnotationComposer,
      $$RecipeEquipmentTableCreateCompanionBuilder,
      $$RecipeEquipmentTableUpdateCompanionBuilder,
      (RecipeEquipmentRow, $$RecipeEquipmentTableReferences),
      RecipeEquipmentRow,
      PrefetchHooks Function({bool recipeId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RecipesTableTableManager get recipes =>
      $$RecipesTableTableManager(_db, _db.recipes);
  $$IngredientsTableTableManager get ingredients =>
      $$IngredientsTableTableManager(_db, _db.ingredients);
  $$RecipeStepsTableTableManager get recipeSteps =>
      $$RecipeStepsTableTableManager(_db, _db.recipeSteps);
  $$RecipePhotosTableTableManager get recipePhotos =>
      $$RecipePhotosTableTableManager(_db, _db.recipePhotos);
  $$EquipmentItemsTableTableManager get equipmentItems =>
      $$EquipmentItemsTableTableManager(_db, _db.equipmentItems);
  $$RecipeEquipmentTableTableManager get recipeEquipment =>
      $$RecipeEquipmentTableTableManager(_db, _db.recipeEquipment);
}
