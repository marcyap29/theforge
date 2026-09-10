// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'forge_database.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _specVersionMeta = const VerificationMeta(
    'specVersion',
  );
  @override
  late final GeneratedColumn<String> specVersion = GeneratedColumn<String>(
    'spec_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastOpenedMeta = const VerificationMeta(
    'lastOpened',
  );
  @override
  late final GeneratedColumn<int> lastOpened = GeneratedColumn<int>(
    'last_opened',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    path,
    mode,
    phase,
    specVersion,
    lastOpened,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
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
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('spec_version')) {
      context.handle(
        _specVersionMeta,
        specVersion.isAcceptableOrUnknown(
          data['spec_version']!,
          _specVersionMeta,
        ),
      );
    }
    if (data.containsKey('last_opened')) {
      context.handle(
        _lastOpenedMeta,
        lastOpened.isAcceptableOrUnknown(data['last_opened']!, _lastOpenedMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      specVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}spec_version'],
      ),
      lastOpened: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_opened'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String name;
  final String path;
  final String mode;
  final String phase;
  final String? specVersion;
  final int? lastOpened;
  final int createdAt;
  const Project({
    required this.id,
    required this.name,
    required this.path,
    required this.mode,
    required this.phase,
    this.specVersion,
    this.lastOpened,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['path'] = Variable<String>(path);
    map['mode'] = Variable<String>(mode);
    map['phase'] = Variable<String>(phase);
    if (!nullToAbsent || specVersion != null) {
      map['spec_version'] = Variable<String>(specVersion);
    }
    if (!nullToAbsent || lastOpened != null) {
      map['last_opened'] = Variable<int>(lastOpened);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      path: Value(path),
      mode: Value(mode),
      phase: Value(phase),
      specVersion: specVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(specVersion),
      lastOpened: lastOpened == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpened),
      createdAt: Value(createdAt),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      path: serializer.fromJson<String>(json['path']),
      mode: serializer.fromJson<String>(json['mode']),
      phase: serializer.fromJson<String>(json['phase']),
      specVersion: serializer.fromJson<String?>(json['specVersion']),
      lastOpened: serializer.fromJson<int?>(json['lastOpened']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'path': serializer.toJson<String>(path),
      'mode': serializer.toJson<String>(mode),
      'phase': serializer.toJson<String>(phase),
      'specVersion': serializer.toJson<String?>(specVersion),
      'lastOpened': serializer.toJson<int?>(lastOpened),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    String? path,
    String? mode,
    String? phase,
    Value<String?> specVersion = const Value.absent(),
    Value<int?> lastOpened = const Value.absent(),
    int? createdAt,
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    path: path ?? this.path,
    mode: mode ?? this.mode,
    phase: phase ?? this.phase,
    specVersion: specVersion.present ? specVersion.value : this.specVersion,
    lastOpened: lastOpened.present ? lastOpened.value : this.lastOpened,
    createdAt: createdAt ?? this.createdAt,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      path: data.path.present ? data.path.value : this.path,
      mode: data.mode.present ? data.mode.value : this.mode,
      phase: data.phase.present ? data.phase.value : this.phase,
      specVersion: data.specVersion.present
          ? data.specVersion.value
          : this.specVersion,
      lastOpened: data.lastOpened.present
          ? data.lastOpened.value
          : this.lastOpened,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('path: $path, ')
          ..write('mode: $mode, ')
          ..write('phase: $phase, ')
          ..write('specVersion: $specVersion, ')
          ..write('lastOpened: $lastOpened, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    path,
    mode,
    phase,
    specVersion,
    lastOpened,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.path == this.path &&
          other.mode == this.mode &&
          other.phase == this.phase &&
          other.specVersion == this.specVersion &&
          other.lastOpened == this.lastOpened &&
          other.createdAt == this.createdAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> path;
  final Value<String> mode;
  final Value<String> phase;
  final Value<String?> specVersion;
  final Value<int?> lastOpened;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.path = const Value.absent(),
    this.mode = const Value.absent(),
    this.phase = const Value.absent(),
    this.specVersion = const Value.absent(),
    this.lastOpened = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    required String path,
    required String mode,
    required String phase,
    this.specVersion = const Value.absent(),
    this.lastOpened = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       path = Value(path),
       mode = Value(mode),
       phase = Value(phase),
       createdAt = Value(createdAt);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? path,
    Expression<String>? mode,
    Expression<String>? phase,
    Expression<String>? specVersion,
    Expression<int>? lastOpened,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (path != null) 'path': path,
      if (mode != null) 'mode': mode,
      if (phase != null) 'phase': phase,
      if (specVersion != null) 'spec_version': specVersion,
      if (lastOpened != null) 'last_opened': lastOpened,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? path,
    Value<String>? mode,
    Value<String>? phase,
    Value<String?>? specVersion,
    Value<int?>? lastOpened,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      specVersion: specVersion ?? this.specVersion,
      lastOpened: lastOpened ?? this.lastOpened,
      createdAt: createdAt ?? this.createdAt,
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
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (specVersion.present) {
      map['spec_version'] = Variable<String>(specVersion.value);
    }
    if (lastOpened.present) {
      map['last_opened'] = Variable<int>(lastOpened.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('path: $path, ')
          ..write('mode: $mode, ')
          ..write('phase: $phase, ')
          ..write('specVersion: $specVersion, ')
          ..write('lastOpened: $lastOpened, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FeaturesTable extends Features with TableInfo<$FeaturesTable, Feature> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeaturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetVersionMeta = const VerificationMeta(
    'targetVersion',
  );
  @override
  late final GeneratedColumn<String> targetVersion = GeneratedColumn<String>(
    'target_version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    title,
    description,
    status,
    priority,
    targetVersion,
    source,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'features';
  @override
  VerificationContext validateIntegrity(
    Insertable<Feature> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
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
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('target_version')) {
      context.handle(
        _targetVersionMeta,
        targetVersion.isAcceptableOrUnknown(
          data['target_version']!,
          _targetVersionMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Feature map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Feature(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      ),
      targetVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_version'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FeaturesTable createAlias(String alias) {
    return $FeaturesTable(attachedDatabase, alias);
  }
}

class Feature extends DataClass implements Insertable<Feature> {
  final String id;
  final String projectId;
  final String title;
  final String? description;

  /// One of FeatureStatus: idea | planned | in_progress | blocked | shipped | archived
  final String status;

  /// Lower = higher priority. Nullable when unranked.
  final int? priority;
  final String? targetVersion;

  /// Where the feature came from: manual | scan | spec
  final String source;
  final int createdAt;
  final int updatedAt;
  const Feature({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.status,
    this.priority,
    this.targetVersion,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || priority != null) {
      map['priority'] = Variable<int>(priority);
    }
    if (!nullToAbsent || targetVersion != null) {
      map['target_version'] = Variable<String>(targetVersion);
    }
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  FeaturesCompanion toCompanion(bool nullToAbsent) {
    return FeaturesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      status: Value(status),
      priority: priority == null && nullToAbsent
          ? const Value.absent()
          : Value(priority),
      targetVersion: targetVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(targetVersion),
      source: Value(source),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Feature.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Feature(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      status: serializer.fromJson<String>(json['status']),
      priority: serializer.fromJson<int?>(json['priority']),
      targetVersion: serializer.fromJson<String?>(json['targetVersion']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'status': serializer.toJson<String>(status),
      'priority': serializer.toJson<int?>(priority),
      'targetVersion': serializer.toJson<String?>(targetVersion),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Feature copyWith({
    String? id,
    String? projectId,
    String? title,
    Value<String?> description = const Value.absent(),
    String? status,
    Value<int?> priority = const Value.absent(),
    Value<String?> targetVersion = const Value.absent(),
    String? source,
    int? createdAt,
    int? updatedAt,
  }) => Feature(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    status: status ?? this.status,
    priority: priority.present ? priority.value : this.priority,
    targetVersion: targetVersion.present
        ? targetVersion.value
        : this.targetVersion,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Feature copyWithCompanion(FeaturesCompanion data) {
    return Feature(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      status: data.status.present ? data.status.value : this.status,
      priority: data.priority.present ? data.priority.value : this.priority,
      targetVersion: data.targetVersion.present
          ? data.targetVersion.value
          : this.targetVersion,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Feature(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('targetVersion: $targetVersion, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    title,
    description,
    status,
    priority,
    targetVersion,
    source,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Feature &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.title == this.title &&
          other.description == this.description &&
          other.status == this.status &&
          other.priority == this.priority &&
          other.targetVersion == this.targetVersion &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FeaturesCompanion extends UpdateCompanion<Feature> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> title;
  final Value<String?> description;
  final Value<String> status;
  final Value<int?> priority;
  final Value<String?> targetVersion;
  final Value<String> source;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const FeaturesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.status = const Value.absent(),
    this.priority = const Value.absent(),
    this.targetVersion = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeaturesCompanion.insert({
    required String id,
    required String projectId,
    required String title,
    this.description = const Value.absent(),
    required String status,
    this.priority = const Value.absent(),
    this.targetVersion = const Value.absent(),
    this.source = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       title = Value(title),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Feature> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? status,
    Expression<int>? priority,
    Expression<String>? targetVersion,
    Expression<String>? source,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (targetVersion != null) 'target_version': targetVersion,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeaturesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? title,
    Value<String?>? description,
    Value<String>? status,
    Value<int?>? priority,
    Value<String?>? targetVersion,
    Value<String>? source,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return FeaturesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      targetVersion: targetVersion ?? this.targetVersion,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (targetVersion.present) {
      map['target_version'] = Variable<String>(targetVersion.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeaturesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('status: $status, ')
          ..write('priority: $priority, ')
          ..write('targetVersion: $targetVersion, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectTrackingTable extends ProjectTracking
    with TableInfo<$ProjectTrackingTable, ProjectTrackingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectTrackingTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewCadenceDaysMeta = const VerificationMeta(
    'reviewCadenceDays',
  );
  @override
  late final GeneratedColumn<int> reviewCadenceDays = GeneratedColumn<int>(
    'review_cadence_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReviewedAtMeta = const VerificationMeta(
    'lastReviewedAt',
  );
  @override
  late final GeneratedColumn<int> lastReviewedAt = GeneratedColumn<int>(
    'last_reviewed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReviewHeadMeta = const VerificationMeta(
    'lastReviewHead',
  );
  @override
  late final GeneratedColumn<String> lastReviewHead = GeneratedColumn<String>(
    'last_review_head',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    projectId,
    status,
    summary,
    reviewCadenceDays,
    lastReviewedAt,
    lastReviewHead,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_tracking';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectTrackingData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('review_cadence_days')) {
      context.handle(
        _reviewCadenceDaysMeta,
        reviewCadenceDays.isAcceptableOrUnknown(
          data['review_cadence_days']!,
          _reviewCadenceDaysMeta,
        ),
      );
    }
    if (data.containsKey('last_reviewed_at')) {
      context.handle(
        _lastReviewedAtMeta,
        lastReviewedAt.isAcceptableOrUnknown(
          data['last_reviewed_at']!,
          _lastReviewedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_review_head')) {
      context.handle(
        _lastReviewHeadMeta,
        lastReviewHead.isAcceptableOrUnknown(
          data['last_review_head']!,
          _lastReviewHeadMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {projectId};
  @override
  ProjectTrackingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectTrackingData(
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      reviewCadenceDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}review_cadence_days'],
      ),
      lastReviewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_reviewed_at'],
      ),
      lastReviewHead: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_review_head'],
      ),
    );
  }

  @override
  $ProjectTrackingTable createAlias(String alias) {
    return $ProjectTrackingTable(attachedDatabase, alias);
  }
}

class ProjectTrackingData extends DataClass
    implements Insertable<ProjectTrackingData> {
  final String projectId;

  /// One of ProjectStatus: active | paused | shipped | archived
  final String status;
  final String? summary;

  /// Review cadence in days (e.g. 7). Null = no scheduled review.
  final int? reviewCadenceDays;
  final int? lastReviewedAt;

  /// Git HEAD SHA captured at the last review — powers staleness detection.
  final String? lastReviewHead;
  const ProjectTrackingData({
    required this.projectId,
    required this.status,
    this.summary,
    this.reviewCadenceDays,
    this.lastReviewedAt,
    this.lastReviewHead,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['project_id'] = Variable<String>(projectId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || reviewCadenceDays != null) {
      map['review_cadence_days'] = Variable<int>(reviewCadenceDays);
    }
    if (!nullToAbsent || lastReviewedAt != null) {
      map['last_reviewed_at'] = Variable<int>(lastReviewedAt);
    }
    if (!nullToAbsent || lastReviewHead != null) {
      map['last_review_head'] = Variable<String>(lastReviewHead);
    }
    return map;
  }

  ProjectTrackingCompanion toCompanion(bool nullToAbsent) {
    return ProjectTrackingCompanion(
      projectId: Value(projectId),
      status: Value(status),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      reviewCadenceDays: reviewCadenceDays == null && nullToAbsent
          ? const Value.absent()
          : Value(reviewCadenceDays),
      lastReviewedAt: lastReviewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewedAt),
      lastReviewHead: lastReviewHead == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewHead),
    );
  }

  factory ProjectTrackingData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectTrackingData(
      projectId: serializer.fromJson<String>(json['projectId']),
      status: serializer.fromJson<String>(json['status']),
      summary: serializer.fromJson<String?>(json['summary']),
      reviewCadenceDays: serializer.fromJson<int?>(json['reviewCadenceDays']),
      lastReviewedAt: serializer.fromJson<int?>(json['lastReviewedAt']),
      lastReviewHead: serializer.fromJson<String?>(json['lastReviewHead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'projectId': serializer.toJson<String>(projectId),
      'status': serializer.toJson<String>(status),
      'summary': serializer.toJson<String?>(summary),
      'reviewCadenceDays': serializer.toJson<int?>(reviewCadenceDays),
      'lastReviewedAt': serializer.toJson<int?>(lastReviewedAt),
      'lastReviewHead': serializer.toJson<String?>(lastReviewHead),
    };
  }

  ProjectTrackingData copyWith({
    String? projectId,
    String? status,
    Value<String?> summary = const Value.absent(),
    Value<int?> reviewCadenceDays = const Value.absent(),
    Value<int?> lastReviewedAt = const Value.absent(),
    Value<String?> lastReviewHead = const Value.absent(),
  }) => ProjectTrackingData(
    projectId: projectId ?? this.projectId,
    status: status ?? this.status,
    summary: summary.present ? summary.value : this.summary,
    reviewCadenceDays: reviewCadenceDays.present
        ? reviewCadenceDays.value
        : this.reviewCadenceDays,
    lastReviewedAt: lastReviewedAt.present
        ? lastReviewedAt.value
        : this.lastReviewedAt,
    lastReviewHead: lastReviewHead.present
        ? lastReviewHead.value
        : this.lastReviewHead,
  );
  ProjectTrackingData copyWithCompanion(ProjectTrackingCompanion data) {
    return ProjectTrackingData(
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      status: data.status.present ? data.status.value : this.status,
      summary: data.summary.present ? data.summary.value : this.summary,
      reviewCadenceDays: data.reviewCadenceDays.present
          ? data.reviewCadenceDays.value
          : this.reviewCadenceDays,
      lastReviewedAt: data.lastReviewedAt.present
          ? data.lastReviewedAt.value
          : this.lastReviewedAt,
      lastReviewHead: data.lastReviewHead.present
          ? data.lastReviewHead.value
          : this.lastReviewHead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectTrackingData(')
          ..write('projectId: $projectId, ')
          ..write('status: $status, ')
          ..write('summary: $summary, ')
          ..write('reviewCadenceDays: $reviewCadenceDays, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('lastReviewHead: $lastReviewHead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    projectId,
    status,
    summary,
    reviewCadenceDays,
    lastReviewedAt,
    lastReviewHead,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectTrackingData &&
          other.projectId == this.projectId &&
          other.status == this.status &&
          other.summary == this.summary &&
          other.reviewCadenceDays == this.reviewCadenceDays &&
          other.lastReviewedAt == this.lastReviewedAt &&
          other.lastReviewHead == this.lastReviewHead);
}

class ProjectTrackingCompanion extends UpdateCompanion<ProjectTrackingData> {
  final Value<String> projectId;
  final Value<String> status;
  final Value<String?> summary;
  final Value<int?> reviewCadenceDays;
  final Value<int?> lastReviewedAt;
  final Value<String?> lastReviewHead;
  final Value<int> rowid;
  const ProjectTrackingCompanion({
    this.projectId = const Value.absent(),
    this.status = const Value.absent(),
    this.summary = const Value.absent(),
    this.reviewCadenceDays = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.lastReviewHead = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectTrackingCompanion.insert({
    required String projectId,
    this.status = const Value.absent(),
    this.summary = const Value.absent(),
    this.reviewCadenceDays = const Value.absent(),
    this.lastReviewedAt = const Value.absent(),
    this.lastReviewHead = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : projectId = Value(projectId);
  static Insertable<ProjectTrackingData> custom({
    Expression<String>? projectId,
    Expression<String>? status,
    Expression<String>? summary,
    Expression<int>? reviewCadenceDays,
    Expression<int>? lastReviewedAt,
    Expression<String>? lastReviewHead,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (projectId != null) 'project_id': projectId,
      if (status != null) 'status': status,
      if (summary != null) 'summary': summary,
      if (reviewCadenceDays != null) 'review_cadence_days': reviewCadenceDays,
      if (lastReviewedAt != null) 'last_reviewed_at': lastReviewedAt,
      if (lastReviewHead != null) 'last_review_head': lastReviewHead,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectTrackingCompanion copyWith({
    Value<String>? projectId,
    Value<String>? status,
    Value<String?>? summary,
    Value<int?>? reviewCadenceDays,
    Value<int?>? lastReviewedAt,
    Value<String?>? lastReviewHead,
    Value<int>? rowid,
  }) {
    return ProjectTrackingCompanion(
      projectId: projectId ?? this.projectId,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      reviewCadenceDays: reviewCadenceDays ?? this.reviewCadenceDays,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      lastReviewHead: lastReviewHead ?? this.lastReviewHead,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (reviewCadenceDays.present) {
      map['review_cadence_days'] = Variable<int>(reviewCadenceDays.value);
    }
    if (lastReviewedAt.present) {
      map['last_reviewed_at'] = Variable<int>(lastReviewedAt.value);
    }
    if (lastReviewHead.present) {
      map['last_review_head'] = Variable<String>(lastReviewHead.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectTrackingCompanion(')
          ..write('projectId: $projectId, ')
          ..write('status: $status, ')
          ..write('summary: $summary, ')
          ..write('reviewCadenceDays: $reviewCadenceDays, ')
          ..write('lastReviewedAt: $lastReviewedAt, ')
          ..write('lastReviewHead: $lastReviewHead, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReleasesTable extends Releases with TableInfo<$ReleasesTable, Release> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReleasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('planned'),
  );
  static const VerificationMeta _releasedAtMeta = const VerificationMeta(
    'releasedAt',
  );
  @override
  late final GeneratedColumn<int> releasedAt = GeneratedColumn<int>(
    'released_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gitTagMeta = const VerificationMeta('gitTag');
  @override
  late final GeneratedColumn<String> gitTag = GeneratedColumn<String>(
    'git_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    version,
    status,
    releasedAt,
    notes,
    gitTag,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'releases';
  @override
  VerificationContext validateIntegrity(
    Insertable<Release> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('released_at')) {
      context.handle(
        _releasedAtMeta,
        releasedAt.isAcceptableOrUnknown(data['released_at']!, _releasedAtMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('git_tag')) {
      context.handle(
        _gitTagMeta,
        gitTag.isAcceptableOrUnknown(data['git_tag']!, _gitTagMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Release map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Release(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      releasedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}released_at'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      gitTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}git_tag'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReleasesTable createAlias(String alias) {
    return $ReleasesTable(attachedDatabase, alias);
  }
}

class Release extends DataClass implements Insertable<Release> {
  final String id;
  final String projectId;

  /// The version label features are grouped under (e.g. "v1", "1.2.0").
  final String version;

  /// One of: planned | released
  final String status;

  /// Epoch ms when the release was cut. Null while still planned.
  final int? releasedAt;

  /// Generated release notes (markdown). Null until cut.
  final String? notes;

  /// Git tag applied to the linked repo when cut, if any.
  final String? gitTag;
  final int createdAt;
  final int updatedAt;
  const Release({
    required this.id,
    required this.projectId,
    required this.version,
    required this.status,
    this.releasedAt,
    this.notes,
    this.gitTag,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['version'] = Variable<String>(version);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || releasedAt != null) {
      map['released_at'] = Variable<int>(releasedAt);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || gitTag != null) {
      map['git_tag'] = Variable<String>(gitTag);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  ReleasesCompanion toCompanion(bool nullToAbsent) {
    return ReleasesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      version: Value(version),
      status: Value(status),
      releasedAt: releasedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(releasedAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      gitTag: gitTag == null && nullToAbsent
          ? const Value.absent()
          : Value(gitTag),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Release.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Release(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      version: serializer.fromJson<String>(json['version']),
      status: serializer.fromJson<String>(json['status']),
      releasedAt: serializer.fromJson<int?>(json['releasedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      gitTag: serializer.fromJson<String?>(json['gitTag']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'version': serializer.toJson<String>(version),
      'status': serializer.toJson<String>(status),
      'releasedAt': serializer.toJson<int?>(releasedAt),
      'notes': serializer.toJson<String?>(notes),
      'gitTag': serializer.toJson<String?>(gitTag),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Release copyWith({
    String? id,
    String? projectId,
    String? version,
    String? status,
    Value<int?> releasedAt = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> gitTag = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => Release(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    version: version ?? this.version,
    status: status ?? this.status,
    releasedAt: releasedAt.present ? releasedAt.value : this.releasedAt,
    notes: notes.present ? notes.value : this.notes,
    gitTag: gitTag.present ? gitTag.value : this.gitTag,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Release copyWithCompanion(ReleasesCompanion data) {
    return Release(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      version: data.version.present ? data.version.value : this.version,
      status: data.status.present ? data.status.value : this.status,
      releasedAt: data.releasedAt.present
          ? data.releasedAt.value
          : this.releasedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      gitTag: data.gitTag.present ? data.gitTag.value : this.gitTag,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Release(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('version: $version, ')
          ..write('status: $status, ')
          ..write('releasedAt: $releasedAt, ')
          ..write('notes: $notes, ')
          ..write('gitTag: $gitTag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    version,
    status,
    releasedAt,
    notes,
    gitTag,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Release &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.version == this.version &&
          other.status == this.status &&
          other.releasedAt == this.releasedAt &&
          other.notes == this.notes &&
          other.gitTag == this.gitTag &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ReleasesCompanion extends UpdateCompanion<Release> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> version;
  final Value<String> status;
  final Value<int?> releasedAt;
  final Value<String?> notes;
  final Value<String?> gitTag;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const ReleasesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.version = const Value.absent(),
    this.status = const Value.absent(),
    this.releasedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.gitTag = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReleasesCompanion.insert({
    required String id,
    required String projectId,
    required String version,
    this.status = const Value.absent(),
    this.releasedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.gitTag = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Release> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? version,
    Expression<String>? status,
    Expression<int>? releasedAt,
    Expression<String>? notes,
    Expression<String>? gitTag,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (version != null) 'version': version,
      if (status != null) 'status': status,
      if (releasedAt != null) 'released_at': releasedAt,
      if (notes != null) 'notes': notes,
      if (gitTag != null) 'git_tag': gitTag,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReleasesCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? version,
    Value<String>? status,
    Value<int?>? releasedAt,
    Value<String?>? notes,
    Value<String?>? gitTag,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReleasesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      version: version ?? this.version,
      status: status ?? this.status,
      releasedAt: releasedAt ?? this.releasedAt,
      notes: notes ?? this.notes,
      gitTag: gitTag ?? this.gitTag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (releasedAt.present) {
      map['released_at'] = Variable<int>(releasedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (gitTag.present) {
      map['git_tag'] = Variable<String>(gitTag.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReleasesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('version: $version, ')
          ..write('status: $status, ')
          ..write('releasedAt: $releasedAt, ')
          ..write('notes: $notes, ')
          ..write('gitTag: $gitTag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ForgeDatabase extends GeneratedDatabase {
  _$ForgeDatabase(QueryExecutor e) : super(e);
  $ForgeDatabaseManager get managers => $ForgeDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $FeaturesTable features = $FeaturesTable(this);
  late final $ProjectTrackingTable projectTracking = $ProjectTrackingTable(
    this,
  );
  late final $ReleasesTable releases = $ReleasesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projects,
    features,
    projectTracking,
    releases,
  ];
}

typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String name,
      required String path,
      required String mode,
      required String phase,
      Value<String?> specVersion,
      Value<int?> lastOpened,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> path,
      Value<String> mode,
      Value<String> phase,
      Value<String?> specVersion,
      Value<int?> lastOpened,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$ProjectsTableFilterComposer
    extends Composer<_$ForgeDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
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

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get specVersion => $composableBuilder(
    column: $table.specVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastOpened => $composableBuilder(
    column: $table.lastOpened,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$ForgeDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
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

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get specVersion => $composableBuilder(
    column: $table.specVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOpened => $composableBuilder(
    column: $table.lastOpened,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$ForgeDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
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

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<String> get specVersion => $composableBuilder(
    column: $table.specVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastOpened => $composableBuilder(
    column: $table.lastOpened,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$ForgeDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, BaseReferences<_$ForgeDatabase, $ProjectsTable, Project>),
          Project,
          PrefetchHooks Function()
        > {
  $$ProjectsTableTableManager(_$ForgeDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<String?> specVersion = const Value.absent(),
                Value<int?> lastOpened = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                path: path,
                mode: mode,
                phase: phase,
                specVersion: specVersion,
                lastOpened: lastOpened,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String path,
                required String mode,
                required String phase,
                Value<String?> specVersion = const Value.absent(),
                Value<int?> lastOpened = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                path: path,
                mode: mode,
                phase: phase,
                specVersion: specVersion,
                lastOpened: lastOpened,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$ForgeDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, BaseReferences<_$ForgeDatabase, $ProjectsTable, Project>),
      Project,
      PrefetchHooks Function()
    >;
typedef $$FeaturesTableCreateCompanionBuilder =
    FeaturesCompanion Function({
      required String id,
      required String projectId,
      required String title,
      Value<String?> description,
      required String status,
      Value<int?> priority,
      Value<String?> targetVersion,
      Value<String> source,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$FeaturesTableUpdateCompanionBuilder =
    FeaturesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> title,
      Value<String?> description,
      Value<String> status,
      Value<int?> priority,
      Value<String?> targetVersion,
      Value<String> source,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$FeaturesTableFilterComposer
    extends Composer<_$ForgeDatabase, $FeaturesTable> {
  $$FeaturesTableFilterComposer({
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

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetVersion => $composableBuilder(
    column: $table.targetVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FeaturesTableOrderingComposer
    extends Composer<_$ForgeDatabase, $FeaturesTable> {
  $$FeaturesTableOrderingComposer({
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

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetVersion => $composableBuilder(
    column: $table.targetVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FeaturesTableAnnotationComposer
    extends Composer<_$ForgeDatabase, $FeaturesTable> {
  $$FeaturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get targetVersion => $composableBuilder(
    column: $table.targetVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FeaturesTableTableManager
    extends
        RootTableManager<
          _$ForgeDatabase,
          $FeaturesTable,
          Feature,
          $$FeaturesTableFilterComposer,
          $$FeaturesTableOrderingComposer,
          $$FeaturesTableAnnotationComposer,
          $$FeaturesTableCreateCompanionBuilder,
          $$FeaturesTableUpdateCompanionBuilder,
          (Feature, BaseReferences<_$ForgeDatabase, $FeaturesTable, Feature>),
          Feature,
          PrefetchHooks Function()
        > {
  $$FeaturesTableTableManager(_$ForgeDatabase db, $FeaturesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeaturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeaturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeaturesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> priority = const Value.absent(),
                Value<String?> targetVersion = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FeaturesCompanion(
                id: id,
                projectId: projectId,
                title: title,
                description: description,
                status: status,
                priority: priority,
                targetVersion: targetVersion,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String title,
                Value<String?> description = const Value.absent(),
                required String status,
                Value<int?> priority = const Value.absent(),
                Value<String?> targetVersion = const Value.absent(),
                Value<String> source = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FeaturesCompanion.insert(
                id: id,
                projectId: projectId,
                title: title,
                description: description,
                status: status,
                priority: priority,
                targetVersion: targetVersion,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FeaturesTableProcessedTableManager =
    ProcessedTableManager<
      _$ForgeDatabase,
      $FeaturesTable,
      Feature,
      $$FeaturesTableFilterComposer,
      $$FeaturesTableOrderingComposer,
      $$FeaturesTableAnnotationComposer,
      $$FeaturesTableCreateCompanionBuilder,
      $$FeaturesTableUpdateCompanionBuilder,
      (Feature, BaseReferences<_$ForgeDatabase, $FeaturesTable, Feature>),
      Feature,
      PrefetchHooks Function()
    >;
typedef $$ProjectTrackingTableCreateCompanionBuilder =
    ProjectTrackingCompanion Function({
      required String projectId,
      Value<String> status,
      Value<String?> summary,
      Value<int?> reviewCadenceDays,
      Value<int?> lastReviewedAt,
      Value<String?> lastReviewHead,
      Value<int> rowid,
    });
typedef $$ProjectTrackingTableUpdateCompanionBuilder =
    ProjectTrackingCompanion Function({
      Value<String> projectId,
      Value<String> status,
      Value<String?> summary,
      Value<int?> reviewCadenceDays,
      Value<int?> lastReviewedAt,
      Value<String?> lastReviewHead,
      Value<int> rowid,
    });

class $$ProjectTrackingTableFilterComposer
    extends Composer<_$ForgeDatabase, $ProjectTrackingTable> {
  $$ProjectTrackingTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reviewCadenceDays => $composableBuilder(
    column: $table.reviewCadenceDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReviewHead => $composableBuilder(
    column: $table.lastReviewHead,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectTrackingTableOrderingComposer
    extends Composer<_$ForgeDatabase, $ProjectTrackingTable> {
  $$ProjectTrackingTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reviewCadenceDays => $composableBuilder(
    column: $table.reviewCadenceDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReviewHead => $composableBuilder(
    column: $table.lastReviewHead,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectTrackingTableAnnotationComposer
    extends Composer<_$ForgeDatabase, $ProjectTrackingTable> {
  $$ProjectTrackingTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<int> get reviewCadenceDays => $composableBuilder(
    column: $table.reviewCadenceDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastReviewedAt => $composableBuilder(
    column: $table.lastReviewedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastReviewHead => $composableBuilder(
    column: $table.lastReviewHead,
    builder: (column) => column,
  );
}

class $$ProjectTrackingTableTableManager
    extends
        RootTableManager<
          _$ForgeDatabase,
          $ProjectTrackingTable,
          ProjectTrackingData,
          $$ProjectTrackingTableFilterComposer,
          $$ProjectTrackingTableOrderingComposer,
          $$ProjectTrackingTableAnnotationComposer,
          $$ProjectTrackingTableCreateCompanionBuilder,
          $$ProjectTrackingTableUpdateCompanionBuilder,
          (
            ProjectTrackingData,
            BaseReferences<
              _$ForgeDatabase,
              $ProjectTrackingTable,
              ProjectTrackingData
            >,
          ),
          ProjectTrackingData,
          PrefetchHooks Function()
        > {
  $$ProjectTrackingTableTableManager(
    _$ForgeDatabase db,
    $ProjectTrackingTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectTrackingTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectTrackingTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectTrackingTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> projectId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<int?> reviewCadenceDays = const Value.absent(),
                Value<int?> lastReviewedAt = const Value.absent(),
                Value<String?> lastReviewHead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectTrackingCompanion(
                projectId: projectId,
                status: status,
                summary: summary,
                reviewCadenceDays: reviewCadenceDays,
                lastReviewedAt: lastReviewedAt,
                lastReviewHead: lastReviewHead,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String projectId,
                Value<String> status = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<int?> reviewCadenceDays = const Value.absent(),
                Value<int?> lastReviewedAt = const Value.absent(),
                Value<String?> lastReviewHead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectTrackingCompanion.insert(
                projectId: projectId,
                status: status,
                summary: summary,
                reviewCadenceDays: reviewCadenceDays,
                lastReviewedAt: lastReviewedAt,
                lastReviewHead: lastReviewHead,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectTrackingTableProcessedTableManager =
    ProcessedTableManager<
      _$ForgeDatabase,
      $ProjectTrackingTable,
      ProjectTrackingData,
      $$ProjectTrackingTableFilterComposer,
      $$ProjectTrackingTableOrderingComposer,
      $$ProjectTrackingTableAnnotationComposer,
      $$ProjectTrackingTableCreateCompanionBuilder,
      $$ProjectTrackingTableUpdateCompanionBuilder,
      (
        ProjectTrackingData,
        BaseReferences<
          _$ForgeDatabase,
          $ProjectTrackingTable,
          ProjectTrackingData
        >,
      ),
      ProjectTrackingData,
      PrefetchHooks Function()
    >;
typedef $$ReleasesTableCreateCompanionBuilder =
    ReleasesCompanion Function({
      required String id,
      required String projectId,
      required String version,
      Value<String> status,
      Value<int?> releasedAt,
      Value<String?> notes,
      Value<String?> gitTag,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$ReleasesTableUpdateCompanionBuilder =
    ReleasesCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> version,
      Value<String> status,
      Value<int?> releasedAt,
      Value<String?> notes,
      Value<String?> gitTag,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$ReleasesTableFilterComposer
    extends Composer<_$ForgeDatabase, $ReleasesTable> {
  $$ReleasesTableFilterComposer({
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

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get releasedAt => $composableBuilder(
    column: $table.releasedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gitTag => $composableBuilder(
    column: $table.gitTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReleasesTableOrderingComposer
    extends Composer<_$ForgeDatabase, $ReleasesTable> {
  $$ReleasesTableOrderingComposer({
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

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get releasedAt => $composableBuilder(
    column: $table.releasedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gitTag => $composableBuilder(
    column: $table.gitTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReleasesTableAnnotationComposer
    extends Composer<_$ForgeDatabase, $ReleasesTable> {
  $$ReleasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get releasedAt => $composableBuilder(
    column: $table.releasedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get gitTag =>
      $composableBuilder(column: $table.gitTag, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReleasesTableTableManager
    extends
        RootTableManager<
          _$ForgeDatabase,
          $ReleasesTable,
          Release,
          $$ReleasesTableFilterComposer,
          $$ReleasesTableOrderingComposer,
          $$ReleasesTableAnnotationComposer,
          $$ReleasesTableCreateCompanionBuilder,
          $$ReleasesTableUpdateCompanionBuilder,
          (Release, BaseReferences<_$ForgeDatabase, $ReleasesTable, Release>),
          Release,
          PrefetchHooks Function()
        > {
  $$ReleasesTableTableManager(_$ForgeDatabase db, $ReleasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReleasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReleasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReleasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> releasedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> gitTag = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReleasesCompanion(
                id: id,
                projectId: projectId,
                version: version,
                status: status,
                releasedAt: releasedAt,
                notes: notes,
                gitTag: gitTag,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String version,
                Value<String> status = const Value.absent(),
                Value<int?> releasedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> gitTag = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReleasesCompanion.insert(
                id: id,
                projectId: projectId,
                version: version,
                status: status,
                releasedAt: releasedAt,
                notes: notes,
                gitTag: gitTag,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReleasesTableProcessedTableManager =
    ProcessedTableManager<
      _$ForgeDatabase,
      $ReleasesTable,
      Release,
      $$ReleasesTableFilterComposer,
      $$ReleasesTableOrderingComposer,
      $$ReleasesTableAnnotationComposer,
      $$ReleasesTableCreateCompanionBuilder,
      $$ReleasesTableUpdateCompanionBuilder,
      (Release, BaseReferences<_$ForgeDatabase, $ReleasesTable, Release>),
      Release,
      PrefetchHooks Function()
    >;

class $ForgeDatabaseManager {
  final _$ForgeDatabase _db;
  $ForgeDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$FeaturesTableTableManager get features =>
      $$FeaturesTableTableManager(_db, _db.features);
  $$ProjectTrackingTableTableManager get projectTracking =>
      $$ProjectTrackingTableTableManager(_db, _db.projectTracking);
  $$ReleasesTableTableManager get releases =>
      $$ReleasesTableTableManager(_db, _db.releases);
}
