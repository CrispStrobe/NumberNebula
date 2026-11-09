import 'dart:math' as math;

import '../models/kompass_attempt.dart';
import '../models/kompass_content.dart';

enum KompassProgressState {
  unassessed,
  practising,
  supported,
  independent,
  reviewDue,
}

/// Observed learning evidence, never an official level or readiness estimate.
class KompassCompetencyProgress {
  final String competencyId;
  final KompassProgressState state;
  final int attempts;
  final int assistedAttempts;
  final int independentAttempts;
  final int independentCorrect;
  final int manualReviews;
  final int pendingReviews;
  final DateTime? lastPractised;
  final DateTime? lastIndependentAt;
  final DateTime? dueAt;

  const KompassCompetencyProgress({
    required this.competencyId,
    required this.state,
    required this.attempts,
    required this.assistedAttempts,
    required this.independentAttempts,
    required this.independentCorrect,
    required this.manualReviews,
    required this.pendingReviews,
    this.lastPractised,
    this.lastIndependentAt,
    this.dueAt,
  });

  String label(bool german) => switch (state) {
        KompassProgressState.unassessed =>
          german ? 'Noch nicht ausreichend geprüft' : 'Not enough evidence yet',
        KompassProgressState.practising =>
          german ? 'Weiter üben' : 'Keep practising',
        KompassProgressState.supported =>
          german ? 'Mit Unterstützung gelöst' : 'Solved with support',
        KompassProgressState.independent =>
          german ? 'Ohne Hilfe gelöst' : 'Solved independently',
        KompassProgressState.reviewDue =>
          german ? 'Zeit für eine Wiederholung' : 'Time to revisit',
      };
}

class _SkillEvidence {
  int attempts = 0;
  int assistedAttempts = 0;
  int independentAttempts = 0;
  int independentCorrect = 0;
  int manualReviews = 0;
  int pendingReviews = 0;
  DateTime? lastPractised;
  DateTime? lastIndependentAt;
  bool lastSupportedSuccess = false;
  final List<bool> independentResults = [];
}

class KompassPlanner {
  /// Two distinct independent families provide an observation of success.
  /// A later error returns that skill to practice; manual reviews remain separate.
  static Map<String, KompassCompetencyProgress> progress(
    KompassPack pack,
    List<KompassAttempt> attempts, {
    DateTime? now,
  }) {
    final reference = (now ?? DateTime.now()).toUtc();
    final evidence = {
      for (final competency in pack.competencies)
        competency.id: _SkillEvidence(),
    };
    final unique = <String, KompassAttempt>{};
    for (final attempt in attempts) {
      final previous = unique[attempt.id];
      if (previous == null ||
          attempt.revision > previous.revision ||
          (attempt.revision == previous.revision &&
              attempt.updatedAt.isAfter(previous.updatedAt))) {
        unique[attempt.id] = attempt;
      }
    }
    final ordered = unique.values.toList()
      ..sort((a, b) {
        final order = a.at.compareTo(b.at);
        return order != 0 ? order : a.id.compareTo(b.id);
      });
    final seenFamilies = <String>{};
    for (final attempt in ordered) {
      if (attempt.at.isAfter(reference)) continue;
      final fresh = seenFamilies.add(attempt.familyId);
      for (final competencyId in attempt.competencyIds) {
        final skill = evidence[competencyId];
        if (skill == null) continue;
        final firstParts = attempt.firstScore.parts
            .where((part) => part.competencyIds.contains(competencyId))
            .toList();
        final latestParts = attempt.score.parts
            .where((part) => part.competencyIds.contains(competencyId))
            .toList();
        if (!firstParts.any((p) => p.attempted) &&
            !latestParts.any((p) => p.attempted)) {
          continue;
        }
        skill.attempts++;
        skill.lastPractised = attempt.at;
        if (attempt.assisted) skill.assistedAttempts++;
        skill.manualReviews +=
            latestParts.where((p) => p.manual && p.reviewed).length;
        skill.pendingReviews +=
            latestParts.where((p) => p.pendingReview).length;
        skill.lastSupportedSuccess = attempt.assisted &&
            latestParts.isNotEmpty &&
            latestParts.every((p) => p.correct);
        final automated = firstParts.where((p) => !p.manual).toList();
        // A required explanation cannot be silently omitted from the evidence
        // for that skill or promoted through a self-reviewed rubric score.
        if (fresh &&
            attempt.verified &&
            automated.length == firstParts.length &&
            automated.any((p) => p.attempted)) {
          skill.independentAttempts++;
          skill.lastIndependentAt = attempt.at;
          final correct = automated.every((p) => p.correct && !p.carriedError);
          skill.independentResults.add(correct);
          if (correct) skill.independentCorrect++;
        }
      }
    }
    return Map.unmodifiable({
      for (final entry in evidence.entries)
        entry.key: _summarize(entry.key, entry.value, reference),
    });
  }

  static KompassCompetencyProgress _summarize(
    String id,
    _SkillEvidence evidence,
    DateTime now,
  ) {
    final latest = evidence.independentResults;
    final independentlySolved = latest.length >= 2 &&
        latest[latest.length - 1] &&
        latest[latest.length - 2];
    DateTime? dueAt;
    if (independentlySolved && evidence.lastIndependentAt != null) {
      dueAt = evidence.lastIndependentAt!.add(const Duration(days: 7));
    } else if (evidence.lastPractised != null) {
      dueAt = evidence.lastPractised!.add(const Duration(days: 2));
    }
    final state = independentlySolved
        ? dueAt != null && !now.isBefore(dueAt)
            ? KompassProgressState.reviewDue
            : KompassProgressState.independent
        : evidence.lastSupportedSuccess
            ? KompassProgressState.supported
            : evidence.attempts > 0
                ? KompassProgressState.practising
                : KompassProgressState.unassessed;
    return KompassCompetencyProgress(
      competencyId: id,
      state: state,
      attempts: evidence.attempts,
      assistedAttempts: evidence.assistedAttempts,
      independentAttempts: evidence.independentAttempts,
      independentCorrect: evidence.independentCorrect,
      manualReviews: evidence.manualReviews,
      pendingReviews: evidence.pendingReviews,
      lastPractised: evidence.lastPractised,
      lastIndependentAt: evidence.lastIndependentAt,
      dueAt: dueAt,
    );
  }

  static KompassTask? nextPractice(
    KompassPack pack,
    List<KompassAttempt> attempts, {
    String? domain,
    String? competencyId,
    DateTime? now,
    Set<String> exposedFamilies = const {},
  }) {
    final reference = (now ?? DateTime.now()).toUtc();
    final statuses = progress(pack, attempts, now: reference);
    final candidates = pack.tasks
        .where(
          (task) =>
              task.use == 'practice' &&
              (domain == null || task.domain == domain) &&
              (competencyId == null ||
                  task.competencyIds.contains(competencyId)),
        )
        .toList();
    _sortPractice(candidates, statuses, attempts, reference);
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Selects held-out families for independent work; never silently recycles them.
  /// Domain weights describe this practice package, not an official blueprint.
  static List<KompassTask> selectSession(
    KompassPack pack,
    List<KompassAttempt> attempts, {
    required KompassMode mode,
    int count = 20,
    String? domain,
    DateTime? now,
    Set<String> exposedFamilies = const {},
  }) {
    if (count <= 0 || mode == KompassMode.lab) return const [];
    final reference = (now ?? DateTime.now()).toUtc();
    final seen = {
      ...exposedFamilies,
      for (final attempt in attempts) attempt.familyId,
    };
    final statuses = progress(pack, attempts, now: reference);
    final candidates = pack.tasks
        .where(
          (task) =>
              task.use == mode.name &&
              (domain == null || task.domain == domain) &&
              (mode == KompassMode.practice || !seen.contains(task.familyId)),
        )
        .toList();
    _sortPractice(candidates, statuses, attempts, reference);
    if (domain != null) {
      return List.unmodifiable(_distinctFamilies(candidates, count));
    }

    const weights = <String, int>{
      'numbers': 8,
      'geometry': 5,
      'measurement': 4,
      'data': 3,
    };
    final quotas = <String, int>{};
    final remainder = <String, double>{};
    var allocated = 0;
    for (final domain in kompassDomains) {
      final exact = count * weights[domain]! / 20;
      quotas[domain] = exact.floor();
      remainder[domain] = exact - exact.floor();
      allocated += exact.floor();
    }
    final rankedRemainders = kompassDomains.toList()
      ..sort((a, b) {
        final order = remainder[b]!.compareTo(remainder[a]!);
        return order != 0
            ? order
            : kompassDomains.indexOf(a).compareTo(kompassDomains.indexOf(b));
      });
    for (var i = 0; allocated < count; i++, allocated++) {
      final domain = rankedRemainders[i % rankedRemainders.length];
      quotas[domain] = quotas[domain]! + 1;
    }
    final groups = {
      for (final domain in kompassDomains)
        domain: _distinctFamilies(
          candidates.where((task) => task.domain == domain),
          quotas[domain]!,
        ),
    };
    final selected = <KompassTask>[];
    var changed = true;
    while (changed && selected.length < count) {
      changed = false;
      for (final domain in kompassDomains) {
        if (groups[domain]!.isEmpty || selected.length >= count) continue;
        selected.add(groups[domain]!.removeAt(0));
        changed = true;
      }
    }
    // If a domain has run out, return honest available coverage with other
    // unseen families; the UI shows the actual domains/tasks in the session.
    final selectedFamilies = selected.map((t) => t.familyId).toSet();
    for (final task in candidates) {
      if (selected.length >= count) break;
      if (selectedFamilies.add(task.familyId)) selected.add(task);
    }
    return List.unmodifiable(selected);
  }

  static List<KompassTask> _distinctFamilies(
    Iterable<KompassTask> tasks,
    int limit,
  ) {
    final result = <KompassTask>[];
    final families = <String>{};
    for (final task in tasks) {
      if (result.length >= limit) break;
      if (families.add(task.familyId)) result.add(task);
    }
    return result;
  }

  static void _sortPractice(
    List<KompassTask> candidates,
    Map<String, KompassCompetencyProgress> statuses,
    List<KompassAttempt> attempts,
    DateTime now,
  ) {
    final lastPlayed = <String, DateTime>{};
    for (final attempt in attempts) {
      final previous = lastPlayed[attempt.taskId];
      if (previous == null || attempt.at.isAfter(previous)) {
        lastPlayed[attempt.taskId] = attempt.at;
      }
    }
    double priority(KompassTask task) {
      var highest = 0.0;
      for (final id in task.competencyIds) {
        final status = statuses[id];
        if (status == null) continue;
        var score = switch (status.state) {
          KompassProgressState.reviewDue => 100.0,
          KompassProgressState.supported => 85.0,
          KompassProgressState.practising =>
            status.independentAttempts > status.independentCorrect
                ? 95.0
                : 65.0,
          KompassProgressState.unassessed => 75.0,
          KompassProgressState.independent => 20.0,
        };
        if (status.dueAt != null && !now.isBefore(status.dueAt!)) score += 20;
        highest = math.max(highest, score);
      }
      final previous = lastPlayed[task.id];
      if (previous == null) {
        highest += 25;
      } else {
        final hours = now.difference(previous).inHours.clamp(0, 168);
        highest += hours / 12 - 20;
      }
      return highest - (task.level - 1) * 4;
    }

    candidates.sort((a, b) {
      final order = priority(b).compareTo(priority(a));
      return order != 0 ? order : a.id.compareTo(b.id);
    });
  }
}
