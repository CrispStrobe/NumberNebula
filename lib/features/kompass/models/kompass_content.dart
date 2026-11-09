/// Versioned, immutable mathematics content. This file has no Flutter imports.
const kompassDomains = ['numbers', 'geometry', 'measurement', 'data'];

/// Accepts localized maps as well as plain strings in optional authoring fields.
String kompassText(dynamic value, bool german) {
  if (value is String) return value;
  if (value is Map) {
    final preferred = value[german ? 'de' : 'en'];
    final fallback = value[german ? 'en' : 'de'];
    return (preferred ?? fallback ?? '').toString();
  }
  return '';
}

/// Snapshots JSON data so later UI edits cannot change saved first answers.
dynamic kompassFreezeJson(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(value.map(
        (key, child) => MapEntry(key.toString(), kompassFreezeJson(child))));
  }
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map(kompassFreezeJson));
  }
  if (value == null || value is String || value is bool || value is num) {
    if (value is num && !value.isFinite) {
      throw const FormatException('Non-finite JSON number.');
    }
    return value;
  }
  throw FormatException('Unsupported JSON value: ${value.runtimeType}.');
}

Map<String, dynamic> kompassMap(dynamic value, [String field = 'object']) {
  if (value is! Map) throw FormatException('Expected an object for $field.');
  return Map<String, dynamic>.from(value);
}

Map<String, dynamic> _localized(dynamic value, String field) {
  final map = kompassMap(value, field);
  if (map['de'] is! String || map['en'] is! String) {
    throw FormatException('$field requires German and English text.');
  }
  return kompassFreezeJson(map) as Map<String, dynamic>;
}

String _requiredString(Map<String, dynamic> map, String field) {
  final value = map[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $field.');
  }
  return value;
}

List<String> _strings(dynamic value, String field) {
  if (value is! List || value.any((v) => v is! String)) {
    throw FormatException('$field must be a list of strings.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

Map<String, dynamic>? _figure(dynamic value) {
  if (value == null) return null;
  final map = kompassMap(value, 'figure');
  _requiredString(map, 'kind');
  kompassMap(map['data'], 'figure.data');
  _localized(map['alt'], 'figure.alt');
  return kompassFreezeJson(map) as Map<String, dynamic>;
}

class KompassCompetency {
  final String id;
  final String domain;
  final Map<String, dynamic> title;
  final Map<String, dynamic> goal;
  final String evidence;
  final String curriculumUrl;
  final List<String> gameKeys;
  final Map<String, dynamic> _json;

  KompassCompetency._(this.id, this.domain, this.title, this.goal,
      this.evidence, this.curriculumUrl, this.gameKeys, this._json);

  factory KompassCompetency.fromJson(Map<String, dynamic> json) {
    final domain = _requiredString(json, 'domain');
    if (!kompassDomains.contains(domain)) {
      throw FormatException('Unknown competency domain: $domain.');
    }
    final evidence = _requiredString(json, 'evidence');
    if (!['published2025', 'curriculum'].contains(evidence)) {
      throw FormatException('Unknown evidence type: $evidence.');
    }
    return KompassCompetency._(
      _requiredString(json, 'id'),
      domain,
      _localized(json['title'], 'title'),
      _localized(json['goal'], 'goal'),
      evidence,
      _requiredString(json, 'curriculumUrl'),
      _strings(json['gameKeys'] ?? [], 'gameKeys'),
      kompassFreezeJson(json) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() => _json;
}

class KompassPart {
  final String id;
  final String kind;
  final Map<String, dynamic> prompt;
  final List<String> competencyIds;
  final double maxPoints;
  final Map<String, dynamic> answer;
  final String unit;
  final List<Map<String, dynamic>> options;
  final Map<String, dynamic>? figure;
  final List<Map<String, dynamic>> rubric;
  final String? carryFrom;
  final double? carryOffset;
  final List<Map<String, dynamic>> errors;
  final Map<String, dynamic> _json;

  KompassPart._({
    required this.id,
    required this.kind,
    required this.prompt,
    required this.competencyIds,
    required this.maxPoints,
    required this.answer,
    required this.unit,
    required this.options,
    required this.figure,
    required this.rubric,
    required this.carryFrom,
    required this.carryOffset,
    required this.errors,
    required Map<String, dynamic> json,
  }) : _json = json;

  bool get isManual => answer['type'] == 'manual';

  factory KompassPart.fromJson(Map<String, dynamic> json) {
    final kind = _requiredString(json, 'kind');
    if (!['number', 'choice', 'multiChoice', 'text', 'cells', 'order']
        .contains(kind)) {
      throw FormatException('Unknown response kind: $kind.');
    }
    final answer = kompassMap(json['answer'], 'answer');
    final type = answer['type'];
    if (!['number', 'choice', 'set', 'sequence', 'manual'].contains(type)) {
      throw FormatException('Unknown answer type: $type.');
    }
    if (type == 'number' &&
        (answer['value'] is! num || !(answer['value'] as num).isFinite)) {
      throw const FormatException('Numeric answers require a finite value.');
    }
    if (type == 'choice' && answer['value'] is! String) {
      throw const FormatException('Choice answers require an option ID.');
    }
    if (type == 'set' || type == 'sequence') {
      _strings(answer['values'], 'answer.values');
    }
    if (type == 'manual') _localized(answer['criteria'], 'answer.criteria');
    if (answer['tolerance'] != null &&
        (answer['tolerance'] is! num ||
            !(answer['tolerance'] as num).isFinite ||
            (answer['tolerance'] as num) < 0)) {
      throw const FormatException('Tolerance must be finite and nonnegative.');
    }
    final points = json['maxPoints'];
    if (points is! num || !points.isFinite || points <= 0) {
      throw const FormatException('Every part needs positive finite points.');
    }
    final skills = _strings(json['competencyIds'], 'competencyIds');
    if (skills.isEmpty || skills.toSet().length != skills.length) {
      throw const FormatException('Each part needs distinct competency IDs.');
    }
    final options = <Map<String, dynamic>>[];
    final optionIds = <String>{};
    for (final item in json['options'] as List? ?? const []) {
      final option = kompassMap(item, 'option');
      final id = _requiredString(option, 'id');
      if (!optionIds.add(id)) {
        throw FormatException('Duplicate option ID: $id.');
      }
      _localized(option['label'], 'option.label');
      options.add(kompassFreezeJson(option) as Map<String, dynamic>);
    }
    if (kind == 'choice' &&
        (options.isEmpty || !optionIds.contains(answer['value']))) {
      throw const FormatException(
          'Choice answer must name a displayed option.');
    }
    final carryFrom = json['carryFrom'] as String?;
    final offset = json['carryOffset'];
    if (carryFrom != null &&
        (type != 'number' || offset is! num || !offset.isFinite)) {
      throw const FormatException(
          'Carry rules need a numeric answer and offset.');
    }
    final errors = <Map<String, dynamic>>[];
    for (final item in json['errors'] as List? ?? const []) {
      final error = kompassMap(item, 'error');
      _requiredString(error, 'code');
      _localized(error['feedback'], 'error.feedback');
      errors.add(kompassFreezeJson(error) as Map<String, dynamic>);
    }
    return KompassPart._(
      id: _requiredString(json, 'id'),
      kind: kind,
      prompt: _localized(json['prompt'], 'part.prompt'),
      competencyIds: skills,
      maxPoints: points.toDouble(),
      answer: kompassFreezeJson(answer) as Map<String, dynamic>,
      unit: json['unit'] as String? ?? '',
      options: List.unmodifiable(options),
      figure: _figure(json['figure']),
      rubric: List.unmodifiable([
        for (final row in json['rubric'] as List? ?? const [])
          _localized(row, 'rubric'),
      ]),
      carryFrom: carryFrom,
      carryOffset: (offset as num?)?.toDouble(),
      errors: List.unmodifiable(errors),
      json: kompassFreezeJson(json) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() => _json;
}

class KompassTask {
  final String id;
  final String familyId;
  final String domain;
  final Map<String, dynamic> title;
  final Map<String, dynamic> prompt;
  final int level;
  final String use;
  final List<KompassPart> parts;
  final List<Map<String, dynamic>> hints;
  final Map<String, dynamic> solution;
  final Map<String, dynamic> source;
  final Map<String, dynamic>? figure;
  final int estimatedSeconds;
  final Map<String, dynamic> _json;

  KompassTask._({
    required this.id,
    required this.familyId,
    required this.domain,
    required this.title,
    required this.prompt,
    required this.level,
    required this.use,
    required this.parts,
    required this.hints,
    required this.solution,
    required this.source,
    required this.figure,
    required this.estimatedSeconds,
    required Map<String, dynamic> json,
  }) : _json = json;

  double get maxPoints =>
      parts.fold<double>(0, (total, part) => total + part.maxPoints);
  List<String> get competencyIds =>
      List.unmodifiable(parts.expand((p) => p.competencyIds).toSet());
  bool get hasManualParts => parts.any((part) => part.isManual);

  factory KompassTask.fromJson(Map<String, dynamic> json) {
    final domain = _requiredString(json, 'domain');
    final use = _requiredString(json, 'use');
    final level = json['level'];
    if (!kompassDomains.contains(domain)) {
      throw FormatException('Unknown task domain: $domain.');
    }
    if (!['practice', 'check', 'rehearsal'].contains(use)) {
      throw FormatException('Unknown task use: $use.');
    }
    if (level is! int || level < 1 || level > 3) {
      throw const FormatException('Task level must be 1, 2 or 3.');
    }
    if (json['parts'] is! List || (json['parts'] as List).isEmpty) {
      throw const FormatException('A task needs at least one response part.');
    }
    final parts = [
      for (final p in json['parts'] as List)
        KompassPart.fromJson(kompassMap(p, 'part')),
    ];
    final previousParts = <String, KompassPart>{};
    for (final part in parts) {
      if (previousParts.containsKey(part.id)) {
        throw FormatException('Duplicate part ID: ${part.id}.');
      }
      if (part.carryFrom != null &&
          previousParts[part.carryFrom]?.answer['type'] != 'number') {
        throw const FormatException(
            'Carry source must be an earlier numeric part.');
      }
      previousParts[part.id] = part;
    }
    final seconds = json['estimatedSeconds'] ?? 120;
    if (seconds is! num || !seconds.isFinite || seconds <= 0) {
      throw const FormatException('Estimated duration must be positive.');
    }
    return KompassTask._(
      id: _requiredString(json, 'id'),
      familyId: _requiredString(json, 'familyId'),
      domain: domain,
      title: _localized(json['title'], 'title'),
      prompt: _localized(json['prompt'], 'prompt'),
      level: level,
      use: use,
      parts: List.unmodifiable(parts),
      hints: List.unmodifiable([
        for (final h in json['hints'] as List? ?? const [])
          _localized(h, 'hint'),
      ]),
      solution: _localized(json['solution'], 'solution'),
      source: kompassFreezeJson(kompassMap(json['source'], 'source'))
          as Map<String, dynamic>,
      figure: _figure(json['figure']),
      estimatedSeconds: seconds.round(),
      json: kompassFreezeJson(json) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() => _json;
}

class KompassPack {
  final int schemaVersion;
  final String id;
  final String version;
  final Map<String, dynamic> source;
  final List<KompassCompetency> competencies;
  final List<KompassTask> tasks;
  final Map<String, KompassTask> _taskIndex;
  final Map<String, KompassCompetency> _competencyIndex;
  final Map<String, Set<String>> _compatibleTaskIds;

  KompassPack._(this.schemaVersion, this.id, this.version, this.source,
      this.competencies, this.tasks, this._taskIndex, this._competencyIndex,
      this._compatibleTaskIds);

  factory KompassPack.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 2) {
      throw const FormatException('Unsupported KOMPASS content schema.');
    }
    final competencies = [
      for (final c in json['competencies'] as List)
        KompassCompetency.fromJson(kompassMap(c)),
    ];
    final tasks = [
      for (final t in json['tasks'] as List)
        KompassTask.fromJson(kompassMap(t)),
    ];
    if (competencies.isEmpty || tasks.isEmpty) {
      throw const FormatException('A content pack cannot be empty.');
    }
    final competencyIndex = {for (final c in competencies) c.id: c};
    final taskIndex = {for (final t in tasks) t.id: t};
    if (competencyIndex.length != competencies.length ||
        taskIndex.length != tasks.length) {
      throw const FormatException('Content IDs must be unique.');
    }
    final familyUses = <String, String>{};
    for (final task in tasks) {
      if (task.competencyIds.any((id) => !competencyIndex.containsKey(id))) {
        throw FormatException('Unknown competency in ${task.id}.');
      }
      final previous = familyUses[task.familyId];
      if (previous != null && previous != task.use) {
        throw FormatException(
            'Family ${task.familyId} crosses practice/check sets.');
      }
      familyUses[task.familyId] = task.use;
    }
    final version = json['version']?.toString();
    if (version == null || version.isEmpty) {
      throw const FormatException('A pack requires a version.');
    }
    final compatible = <String, Set<String>>{};
    for (final entry in kompassMap(json['compatibleTaskIds'] ?? const {},
        'compatibleTaskIds').entries) {
      final ids = _strings(entry.value, 'compatibleTaskIds.${entry.key}');
      if (entry.key.isEmpty || entry.key == version ||
          ids.toSet().length != ids.length ||
          ids.any((id) => !taskIndex.containsKey(id))) {
        throw const FormatException('Invalid historical task compatibility.');
      }
      compatible[entry.key] = Set.unmodifiable(ids);
    }
    return KompassPack._(
      2,
      _requiredString(json, 'id'),
      version,
      kompassFreezeJson(kompassMap(json['source'], 'source'))
          as Map<String, dynamic>,
      List.unmodifiable(competencies),
      List.unmodifiable(tasks),
      Map.unmodifiable(taskIndex),
      Map.unmodifiable(competencyIndex),
      Map.unmodifiable(compatible),
    );
  }

  KompassTask? taskById(String id) => _taskIndex[id];
  KompassCompetency? competencyById(String id) => _competencyIndex[id];

  /// The build verifies whole task objects against an immutable prior pack.
  /// Unknown or changed task versions never inherit a current answer key.
  bool isTaskCompatible(String taskId, String? savedPackVersion) =>
      _taskIndex.containsKey(taskId) &&
      (savedPackVersion == version ||
          (_compatibleTaskIds[savedPackVersion]?.contains(taskId) ?? false));

  bool isSessionCompatible(String? savedPackVersion, Iterable<String> taskIds) {
    final ids = taskIds.toList();
    return ids.isNotEmpty && ids.toSet().length == ids.length &&
        ids.every((id) => isTaskCompatible(id, savedPackVersion));
  }
}
