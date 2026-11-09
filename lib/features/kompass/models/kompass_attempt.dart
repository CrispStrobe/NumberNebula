import '../services/kompass_scorer.dart';
import 'kompass_content.dart';

enum KompassMode { practice, check, rehearsal, lab }

/// A submission's first evidence is immutable; later corrections are separate.
class KompassAttempt {
  final String id;
  final String sessionId;
  final String taskId;
  final String taskVersion;
  final String packVersion;
  final String familyId;
  final String domain;
  final KompassMode mode;

  /// The content's authored split is retained independently of the UI mode.
  final String contentUse;
  final Map<String, dynamic> firstResponses;
  final Map<String, dynamic> responses;
  final int hintsUsed;
  final int hintsBeforeFirstResponse;
  final int activeSeconds;
  final DateTime at;
  final DateTime updatedAt;

  /// Persisted edit generation, so an old editor cannot replace newer work.
  final int revision;
  final bool completed;
  final bool solutionSeenBeforeFirstResponse;
  final bool solutionSeen;
  final bool isNovel;
  final KompassScore firstScore;
  final KompassScore score;

  KompassAttempt._({
    required this.id,
    required this.sessionId,
    required this.taskId,
    required this.taskVersion,
    required this.packVersion,
    required this.familyId,
    required this.domain,
    required this.mode,
    required this.contentUse,
    required Map<String, dynamic> firstResponses,
    required Map<String, dynamic> responses,
    required this.hintsUsed,
    required this.hintsBeforeFirstResponse,
    required this.activeSeconds,
    required this.at,
    required this.updatedAt,
    required this.revision,
    required this.completed,
    required this.solutionSeenBeforeFirstResponse,
    required this.solutionSeen,
    required this.isNovel,
    required this.firstScore,
    required this.score,
  })  : firstResponses =
            kompassFreezeJson(firstResponses) as Map<String, dynamic>,
        responses = kompassFreezeJson(responses) as Map<String, dynamic> {
    if (id.isEmpty ||
        taskId.isEmpty ||
        familyId.isEmpty ||
        hintsUsed < 0 ||
        hintsBeforeFirstResponse < 0 ||
        hintsUsed < hintsBeforeFirstResponse ||
        activeSeconds < 0 ||
        revision < 0 ||
        (solutionSeenBeforeFirstResponse && !solutionSeen)) {
      throw const FormatException('Invalid attempt evidence.');
    }
  }

  /// Eligible evidence; success is evaluated separately for each scored part.
  bool get verified =>
      (mode == KompassMode.check || mode == KompassMode.rehearsal) &&
      contentUse == mode.name &&
      completed &&
      isNovel &&
      hintsBeforeFirstResponse == 0 &&
      !solutionSeenBeforeFirstResponse &&
      firstScore.parts.any((part) => !part.manual && part.attempted);

  bool get assisted => hintsUsed > 0 || solutionSeen;
  bool get pendingReview => score.pendingReview;
  List<String> get competencyIds => List.unmodifiable(
        firstScore.parts.expand((part) => part.competencyIds).toSet(),
      );

  factory KompassAttempt.forTask({
    required String id,
    required String sessionId,
    required KompassTask task,
    required String packVersion,
    required KompassMode mode,
    required Map<String, dynamic> firstResponses,
    Map<String, dynamic>? responses,
    int hintsUsed = 0,
    int? hintsBeforeFirstResponse,
    int activeSeconds = 0,
    DateTime? at,
    Map<String, double> manualPoints = const {},
    bool completed = true,
    bool solutionSeenBeforeFirstResponse = false,
    bool solutionSeen = false,
    bool isNovel = true,
  }) {
    final submittedAt = (at ?? DateTime.now()).toUtc();
    final currentResponses = responses ?? firstResponses;
    return KompassAttempt._(
      id: id,
      sessionId: sessionId,
      taskId: task.id,
      taskVersion: (task.toJson()['version'] ?? packVersion).toString(),
      packVersion: packVersion,
      familyId: task.familyId,
      domain: task.domain,
      mode: mode,
      contentUse: task.use,
      firstResponses: firstResponses,
      responses: currentResponses,
      hintsUsed: hintsUsed,
      hintsBeforeFirstResponse: hintsBeforeFirstResponse ?? hintsUsed,
      activeSeconds: activeSeconds,
      at: submittedAt,
      updatedAt: submittedAt,
      revision: 0,
      completed: completed,
      solutionSeenBeforeFirstResponse: solutionSeenBeforeFirstResponse,
      solutionSeen: solutionSeen || solutionSeenBeforeFirstResponse,
      isNovel: isNovel,
      firstScore: KompassScorer.score(task, firstResponses),
      score: KompassScorer.score(
        task,
        currentResponses,
        manualPoints: manualPoints,
      ),
    );
  }

  /// Lab outcomes are practice exposure even when solved without any hints.
  factory KompassAttempt.forLab({
    required String id,
    required Map<String, dynamic> result,
    required String packVersion,
    DateTime? at,
  }) {
    final labId = result['labId'] as String;
    final max = (result['maxPoints'] as num? ?? 1).toDouble();
    final awarded = (result['awardedPoints'] as num? ??
            (result['firstCorrect'] == true ? max : 0))
        .toDouble();
    final firstCorrect = result['firstCorrect'] == true;
    final skills = (result['skillIds'] as List).cast<String>();
    final submittedAt = (at ?? DateTime.now()).toUtc();
    final completedCorrect = result['completedCorrect'] == true;
    final hintsUsed = (result['hintsUsed'] as num? ?? 0).toInt();
    final hintsBeforeFirstResponse =
        (result['hintsBeforeFirstResponse'] as num? ?? hintsUsed).toInt();
    final first = KompassScore([
      KompassPartScore(
        partId: 'lab',
        competencyIds: skills,
        awardedPoints: awarded,
        maxPoints: max,
        correct: firstCorrect,
      ),
    ]);
    return KompassAttempt._(
      id: id,
      sessionId: 'lab:$labId',
      taskId: 'lab:$labId',
      taskVersion: packVersion,
      packVersion: packVersion,
      familyId: 'lab:$labId:${result['roundId']}',
      domain: const {
            'number_dock': 'numbers',
            'supply_station': 'measurement',
            'data_observatory': 'data',
            'geometry_workshop': 'geometry',
            'reasoning_workshop': 'numbers',
            'journey_planner': 'measurement',
            'area_studio': 'geometry',
            'chance_detective': 'data',
          }[labId] ??
          '',
      mode: KompassMode.lab,
      contentUse: 'practice',
      firstResponses: {'lab': result['firstResponse'] ?? result['response']},
      responses: {'lab': result['finalResponse'] ?? result['response']},
      hintsUsed: hintsUsed,
      hintsBeforeFirstResponse: hintsBeforeFirstResponse,
      activeSeconds: (result['activeSeconds'] as num? ?? 0).toInt(),
      at: submittedAt,
      updatedAt: submittedAt,
      revision: 0,
      completed: true,
      solutionSeenBeforeFirstResponse: false,
      solutionSeen: result['solutionSeen'] == true,
      isNovel: false,
      firstScore: first,
      score: KompassScore([
        KompassPartScore(
          partId: 'lab',
          competencyIds: skills,
          awardedPoints: completedCorrect ? max : awarded,
          maxPoints: max,
          correct: completedCorrect || awarded == max,
        ),
      ]),
    );
  }

  /// Callers score the revised response explicitly or use [reviseTask].
  KompassAttempt copyWith({
    Map<String, dynamic>? responses,
    KompassScore? score,
    int? hintsUsed,
    int? activeSeconds,
    bool? completed,
    bool? solutionSeen,
    bool? isNovel,
    DateTime? updatedAt,
    int? revision,
  }) {
    if (responses != null && score == null) {
      throw ArgumentError(
        'Changed responses need an explicitly revised score.',
      );
    }
    return KompassAttempt._(
      id: id,
      sessionId: sessionId,
      taskId: taskId,
      taskVersion: taskVersion,
      packVersion: packVersion,
      familyId: familyId,
      domain: domain,
      mode: mode,
      contentUse: contentUse,
      firstResponses: firstResponses,
      responses: responses ?? this.responses,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      hintsBeforeFirstResponse: hintsBeforeFirstResponse,
      activeSeconds: activeSeconds ?? this.activeSeconds,
      at: at,
      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
      revision: revision ?? this.revision + 1,
      completed: completed ?? this.completed,
      solutionSeenBeforeFirstResponse: solutionSeenBeforeFirstResponse,
      solutionSeen: solutionSeen ?? this.solutionSeen,
      isNovel: isNovel ?? this.isNovel,
      firstScore: firstScore,
      score: score ?? this.score,
    );
  }

  KompassAttempt reviseTask({
    required KompassTask task,
    required Map<String, dynamic> responses,
    Map<String, double> manualPoints = const {},
    int? hintsUsed,
    int? activeSeconds,
    bool? completed,
    bool? solutionSeen,
  }) {
    if (task.id != taskId || task.familyId != familyId) {
      throw ArgumentError('A revision must use the original task.');
    }
    return copyWith(
      responses: responses,
      score: KompassScorer.score(task, responses, manualPoints: manualPoints),
      hintsUsed: hintsUsed,
      activeSeconds: activeSeconds,
      completed: completed,
      solutionSeen: solutionSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'id': id,
        'sessionId': sessionId,
        'taskId': taskId,
        'taskVersion': taskVersion,
        'packVersion': packVersion,
        'familyId': familyId,
        'domain': domain,
        'mode': mode.name,
        'contentUse': contentUse,
        'firstResponses': firstResponses,
        'responses': responses,
        'hintsUsed': hintsUsed,
        'hintsBeforeFirstResponse': hintsBeforeFirstResponse,
        'activeSeconds': activeSeconds,
        'at': at.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'revision': revision,
        'completed': completed,
        'solutionSeenBeforeFirstResponse': solutionSeenBeforeFirstResponse,
        'solutionSeen': solutionSeen,
        'isNovel': isNovel,
        'firstScore': firstScore.toJson(),
        'score': score.toJson(),
      };

  factory KompassAttempt.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported attempt schema.');
    }
    return KompassAttempt._(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      taskId: json['taskId'] as String,
      taskVersion: json['taskVersion'] as String,
      packVersion: json['packVersion'] as String,
      familyId: json['familyId'] as String,
      domain: json['domain'] as String,
      mode: KompassMode.values.byName(json['mode'] as String),
      // Records from before authored splits were retained cannot prove novelty.
      contentUse: json['contentUse'] as String? ?? 'unknown',
      firstResponses: kompassMap(json['firstResponses']),
      responses: kompassMap(json['responses']),
      hintsUsed: json['hintsUsed'] as int,
      hintsBeforeFirstResponse: json['hintsBeforeFirstResponse'] as int,
      activeSeconds: json['activeSeconds'] as int,
      at: DateTime.parse(json['at'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      revision: json['revision'] as int? ?? 0,
      completed: json['completed'] as bool,
      solutionSeenBeforeFirstResponse:
          json['solutionSeenBeforeFirstResponse'] as bool,
      solutionSeen: json['solutionSeen'] as bool? ??
          json['solutionSeenBeforeFirstResponse'] as bool,
      isNovel: json['isNovel'] as bool,
      firstScore: KompassScore.fromJson(kompassMap(json['firstScore'])),
      score: KompassScore.fromJson(kompassMap(json['score'])),
    );
  }
}
