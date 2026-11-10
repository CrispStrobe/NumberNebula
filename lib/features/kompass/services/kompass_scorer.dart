import 'dart:math' as math;

import '../models/kompass_content.dart';

class KompassPartScore {
  final String partId;
  final List<String> competencyIds;
  final double awardedPoints;
  final double maxPoints;
  final bool correct;
  final bool pendingReview;
  final bool manual;
  final bool reviewed;
  final bool attempted;
  final bool carriedError;
  final String? errorCode;
  final Map<String, dynamic>? feedback;

  KompassPartScore({
    required this.partId,
    required List<String> competencyIds,
    required this.awardedPoints,
    required this.maxPoints,
    required this.correct,
    this.pendingReview = false,
    this.manual = false,
    this.reviewed = false,
    this.attempted = true,
    this.carriedError = false,
    this.errorCode,
    Map<String, dynamic>? feedback,
  })  : competencyIds = List.unmodifiable(competencyIds),
        feedback = feedback == null
            ? null
            : kompassFreezeJson(feedback) as Map<String, dynamic> {
    if (!awardedPoints.isFinite ||
        !maxPoints.isFinite ||
        maxPoints <= 0 ||
        awardedPoints < 0 ||
        awardedPoints > maxPoints ||
        (correct && awardedPoints != maxPoints) ||
        (pendingReview && (!manual || reviewed))) {
      throw const FormatException('Inconsistent part score.');
    }
  }

  Map<String, dynamic> toJson() => {
        'partId': partId,
        'competencyIds': competencyIds,
        'awardedPoints': awardedPoints,
        'maxPoints': maxPoints,
        'correct': correct,
        'pendingReview': pendingReview,
        'manual': manual,
        'reviewed': reviewed,
        'attempted': attempted,
        'carriedError': carriedError,
        if (errorCode != null) 'errorCode': errorCode,
        if (feedback != null) 'feedback': feedback,
      };

  factory KompassPartScore.fromJson(Map<String, dynamic> json) =>
      KompassPartScore(
        partId: json['partId'] as String,
        competencyIds: (json['competencyIds'] as List).cast<String>(),
        awardedPoints: (json['awardedPoints'] as num).toDouble(),
        maxPoints: (json['maxPoints'] as num).toDouble(),
        correct: json['correct'] as bool,
        pendingReview: json['pendingReview'] as bool? ?? false,
        manual: json['manual'] as bool? ?? false,
        reviewed: json['reviewed'] as bool? ?? false,
        attempted: json['attempted'] as bool? ?? true,
        carriedError: json['carriedError'] as bool? ?? false,
        errorCode: json['errorCode'] as String?,
        feedback:
            json['feedback'] == null ? null : kompassMap(json['feedback']),
      );
}

class KompassScore {
  final List<KompassPartScore> parts;
  KompassScore(List<KompassPartScore> parts) : parts = List.unmodifiable(parts);

  double get awardedPoints =>
      parts.fold<double>(0, (sum, part) => sum + part.awardedPoints);
  double get maxPoints =>
      parts.fold<double>(0, (sum, part) => sum + part.maxPoints);
  double get pendingPoints => parts
      .where((part) => part.pendingReview)
      .fold<double>(0, (sum, part) => sum + part.maxPoints);
  bool get pendingReview => parts.any((part) => part.pendingReview);
  bool get fullyCorrect => parts.isNotEmpty && parts.every((p) => p.correct);
  bool get attempted => parts.any((part) => part.attempted);

  KompassPartScore? partById(String id) {
    for (final part in parts) {
      if (part.partId == id) return part;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'parts': parts.map((part) => part.toJson()).toList(),
      };

  factory KompassScore.fromJson(Map<String, dynamic> json) => KompassScore([
        for (final part in json['parts'] as List)
          KompassPartScore.fromJson(kompassMap(part)),
      ]);
}

/// Explicit answer rules; free explanations are never graded by string matching.
class KompassScorer {
  static const _unitAliases = <String, List<String>>{
    '€': ['€', 'eur', 'euro', 'euros'],
    'ct': ['ct', 'cent', 'cents'],
    'cm': [
      'cm',
      'zentimeter',
      'centimeter',
      'centimeters',
      'centimetre',
      'centimetres'
    ],
    'mm': ['mm', 'millimeter', 'millimeters', 'millimetre', 'millimetres'],
    'm': ['m', 'meter', 'meters', 'metre', 'metres'],
    'km': ['km', 'kilometer', 'kilometers', 'kilometre', 'kilometres'],
    'g': ['g', 'gramm', 'gram', 'grams'],
    'kg': ['kg', 'kilogramm', 'kilogram', 'kilograms'],
    'l': ['l', 'liter', 'liters', 'litre', 'litres'],
    'ml': ['ml', 'milliliter', 'milliliters', 'millilitre', 'millilitres'],
    'min': ['min', 'minute', 'minuten', 'minutes'],
    'h': ['h', 'stunde', 'stunden', 'hour', 'hours'],
    's': ['s', 'sekunde', 'sekunden', 'second', 'seconds'],
    'cm²': ['cm²', 'cm2'],
    'm²': ['m²', 'm2'],
  };

  /// Bare values use the unit displayed by the part. Written units must agree.
  /// Decimal commas and decimal points are accepted, grouping/exponents are not.
  /// `acceptCents` lets a euro part also read "345 ct" or "3 € 45 ct"; it is
  /// set only where the task's rubric accepts cent amounts.
  static double? parseNumber(dynamic value,
      {String unit = '',
      bool acceptCents = false,
      List<String> aliases = const []}) {
    if (value is num) return value.isFinite ? value.toDouble() : null;
    if (value is! String) return null;
    var text = value
        .trim()
        .replaceAll('\u2212', '-')
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202f', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return null;
    final expectedUnit = unit.trim().toLowerCase();
    if (expectedUnit == '€' && acceptCents) {
      // "345 ct" and "3 € 45 ct" are unambiguous euro amounts.
      final cents = RegExp(r'^(?:(\d+)\s*(?:€|euro)\s*)?(\d+)\s*(?:ct|cent)$',
              caseSensitive: false)
          .firstMatch(text);
      if (cents != null) {
        return int.parse(cents.group(1) ?? '0') +
            int.parse(cents.group(2)!) / 100;
      }
    }
    if (expectedUnit.isNotEmpty) {
      // A part may also name further count words ("Quadrate" beside
      // "Quadraten"); only those words, never an arbitrary suffix.
      final suffixes = [
        ...?_unitAliases[expectedUnit],
        expectedUnit,
        for (final alias in aliases) alias.trim().toLowerCase(),
      ]..sort((a, b) => b.length.compareTo(a.length));
      final lower = text.toLowerCase();
      for (final alias in suffixes) {
        if (lower.endsWith(alias)) {
          text = text.substring(0, text.length - alias.length).trim();
          break;
        }
      }
    }
    if (!RegExp(r'^[+-]?(?:\d+(?:[.,]\d+)?|[.,]\d+)$').hasMatch(text)) {
      return null;
    }
    final result = double.tryParse(text.replaceAll(',', '.'));
    return result != null && result.isFinite ? result : null;
  }

  static bool isAnswered(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    return true;
  }

  static KompassScore score(KompassTask task, Map<String, dynamic> responses,
      {Map<String, double> manualPoints = const {}}) {
    final scores = <KompassPartScore>[];
    final byId = {for (final part in task.parts) part.id: part};
    for (final part in task.parts) {
      final response = responses[part.id];
      final type = part.answer['type'];
      final attempted = type == 'set'
          ? responses.containsKey(part.id) && response is List
          : isAnswered(response);
      var correct = false;
      var pending = false;
      var reviewed = false;
      var carried = false;
      var points = 0.0;
      String? errorCode;
      Map<String, dynamic>? feedback;
      if (!attempted) {
        errorCode = 'unanswered';
      } else {
        switch (type) {
          case 'number':
            final number = parseNumber(response,
                unit: part.unit,
                acceptCents: part.answer['acceptCents'] == true,
                aliases: _unitAliasesOf(part));
            final expected = (part.answer['value'] as num).toDouble();
            final tolerance =
                (part.answer['tolerance'] as num?)?.toDouble() ?? 1e-9;
            final accepted = <double>[
              expected,
              for (final value in part.answer['accepted'] as List? ?? const [])
                if (value is num && value.isFinite) value.toDouble(),
            ];
            correct = number != null &&
                accepted.any((value) => (number - value).abs() <= tolerance);
            if (correct) {
              points = part.maxPoints;
            } else if (number != null && part.carryFrom != null) {
              final source = byId[part.carryFrom]!;
              final previous = parseNumber(responses[source.id],
                  unit: source.unit, aliases: _unitAliasesOf(source));
              final previousExpected =
                  (source.answer['value'] as num).toDouble();
              // A whole-euro canonical answer can follow a valid cents error.
              // Counting tasks still require whole numbers; cash amounts must
              // be expressible in cents, never fractions of a cent.
              final validGranularity = part.unit == '€'
                  ? (number * 100 - (number * 100).roundToDouble()).abs() <=
                      1e-7
                  : expected != expected.roundToDouble() ||
                      number == number.roundToDouble();
              if (previous != null &&
                  (previous - previousExpected).abs() > tolerance &&
                  number >= 0 &&
                  validGranularity &&
                  (number - (previous + part.carryOffset!)).abs() <=
                      tolerance) {
                carried = true;
                points = part.maxPoints;
                errorCode = 'carried_error';
                feedback = const {
                  'de':
                      'Dieser Rechenschritt passt zu deinem vorherigen Ergebnis. Prüfe den vorherigen Schritt noch einmal.',
                  'en':
                      'This step follows your earlier result correctly. Check that earlier step again.',
                };
              }
            }
            if (number == null) {
              errorCode = 'number_format_or_unit';
              feedback = {
                'de': part.unit.isEmpty
                    ? 'Schreibe eine Zahl ohne Tausendertrennzeichen. Ein Komma als Dezimalzeichen ist möglich.'
                    : 'Schreibe die Zahl in ${part.unit}, ohne Tausendertrennzeichen. Achte auf die gefragte Einheit.',
                'en': part.unit.isEmpty
                    ? 'Enter a number without thousands separators. A decimal comma or point is accepted.'
                    : 'Enter the value in ${part.unit}, without thousands separators. Check the requested unit.',
              };
            }
          case 'choice':
            correct = response is String && response == part.answer['value'];
            if (correct) points = part.maxPoints;
          case 'set':
            final given = _stringList(response);
            final expected = (part.answer['values'] as List).cast<String>();
            final alternatives = <List<String>>[
              expected,
              for (final other
                  in part.answer['alternatives'] as List? ?? const [])
                (other as List).cast<String>(),
            ];
            correct = given != null &&
                given.toSet().length == given.length &&
                alternatives.any((answer) =>
                    given.length == answer.toSet().length &&
                    given.toSet().containsAll(answer));
            if (correct) {
              points = part.maxPoints;
            } else if (given != null && part.answer['partialCredit'] == true) {
              final target = expected.toSet();
              final unique = given.toSet();
              final right = unique.intersection(target).length;
              final wrong = unique.difference(target).length;
              if (target.isNotEmpty) {
                points =
                    part.maxPoints * math.max(0, right - wrong) / target.length;
              }
            }
          case 'sequence':
            final given = _stringList(response);
            final expected = (part.answer['values'] as List).cast<String>();
            correct = given != null &&
                given.length == expected.length &&
                List.generate(expected.length, (i) => given[i] == expected[i])
                    .every((equal) => equal);
            if (correct) points = part.maxPoints;
          case 'text':
            String normal(Object? value) {
              // Spacing between numbers and units and a closing full stop do
              // not change a short answer: "1m50cm" equals "1 m 50 cm.".
              var text = value
                  .toString()
                  .replaceAll(
                      RegExp(r'(?<=\d)(?=\p{L})|(?<=\p{L})(?=\d)',
                          unicode: true),
                      ' ')
                  .trim()
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .replaceAll(RegExp(r'[.!]+$'), '')
                  .trim();
              if (part.answer['caseSensitive'] != true) {
                text = text.toLowerCase();
              }
              return text;
            }
            final accepted =
                (part.answer['values'] as List).map(normal).toSet();
            correct = accepted.contains(normal(response));
            if (correct) {
              points = part.maxPoints;
            } else if (part.answer['reviewOnMismatch'] == true) {
              // Another wording may be right: a person decides, never a
              // fuzzy string match.
              final review = _reviewPoints(part, manualPoints);
              if (review != null) {
                points = review;
                reviewed = true;
                correct = review == part.maxPoints;
              } else {
                pending = true;
              }
            }
          case 'manual':
            final review = _reviewPoints(part, manualPoints);
            if (review != null) {
              points = review;
              reviewed = true;
              correct = review == part.maxPoints;
            } else {
              pending = true;
            }
        }
        // A rubric may credit a correct continuation of a wrong earlier step.
        // That needs a person: the wrong answer goes to review, not to zero.
        final followOn = part.answer['followOnFrom'];
        if (!correct && !pending && !carried && followOn is String) {
          final source = scores.where((s) => s.partId == followOn).firstOrNull;
          if (source != null &&
              source.attempted &&
              !source.correct &&
              !source.pendingReview) {
            final review = _reviewPoints(part, manualPoints);
            if (review != null) {
              points = review;
              reviewed = true;
              correct = review == part.maxPoints;
            } else {
              pending = true;
              feedback = const {
                'de':
                    'Dein vorheriges Ergebnis war nicht richtig. Ob du damit richtig weitergerechnet hast, wird am Ende mit den Kriterien geprüft.',
                'en':
                    'Your earlier result was not right. Whether you continued correctly from it is reviewed against the criteria at the end.',
              };
            }
          }
        }
        if (!correct && !pending && !carried) {
          for (final error in part.errors) {
            final target = error['value'];
            final matches = type == 'number'
                ? _sameNumber(response, target, part.unit)
                : response.toString().trim() == target.toString().trim();
            if (matches) {
              errorCode = error['code'] as String;
              feedback = kompassMap(error['feedback']);
              break;
            }
          }
        }
      }
      scores.add(KompassPartScore(
        partId: part.id,
        competencyIds: part.competencyIds,
        awardedPoints: points,
        maxPoints: part.maxPoints,
        correct: correct,
        pendingReview: pending,
        manual: type == 'manual' || pending || reviewed,
        reviewed: reviewed,
        attempted: attempted,
        carriedError: carried,
        errorCode: errorCode ?? (!correct && !pending ? 'incorrect' : null),
        feedback: feedback,
      ));
    }
    return KompassScore(scores);
  }

  /// Applies one new review without migrating other historical review values.
  /// Untouched values outside a declared step set remain recorded until the
  /// learner explicitly reviews those parts again.
  static KompassScore reviewPart(
    KompassTask task,
    Map<String, dynamic> responses, {
    required KompassScore previousScore,
    required String partId,
    required double points,
  }) {
    final parts = {for (final part in task.parts) part.id: part};
    final part = parts[partId];
    if (part == null ||
        (!part.isManual && previousScore.partById(partId)?.manual != true)) {
      throw ArgumentError.value(partId, 'partId', 'Part is not under review.');
    }
    _reviewPoints(part, {partId: points});
    final manual = <String, double>{partId: points};
    final historical = <String, KompassPartScore>{};
    for (final previous in previousScore.parts) {
      if (previous.partId == partId || !previous.manual || !previous.reviewed) {
        continue;
      }
      final previousPart = parts[previous.partId];
      if (previousPart == null) continue;
      if (previousPart.acceptsManualPoints(previous.awardedPoints)) {
        manual[previous.partId] = previous.awardedPoints;
      } else if (previousPart.answer.containsKey('creditSteps') &&
          previous.maxPoints == previousPart.maxPoints &&
          previous.awardedPoints.isFinite &&
          previous.awardedPoints >= 0 &&
          previous.awardedPoints <= previousPart.maxPoints) {
        historical[previous.partId] = previous;
      } else {
        throw ArgumentError.value(previous.awardedPoints, 'manualPoints',
            'Historical review does not match the current rubric scale.');
      }
    }
    final updated = score(task, responses, manualPoints: manual);
    return KompassScore([
      for (final result in updated.parts) historical[result.partId] ?? result,
    ]);
  }

  static double? _reviewPoints(
      KompassPart part, Map<String, double> manualPoints) {
    final review = manualPoints[part.id];
    if (review != null && !part.acceptsManualPoints(review)) {
      throw ArgumentError.value(
          review,
          'manualPoints',
          part.answer.containsKey('creditSteps')
              ? 'Review points must match a declared rubric step.'
              : 'Review points must be between zero and the part maximum.');
    }
    return review;
  }

  static List<String> _unitAliasesOf(KompassPart part) => [
        for (final alias in part.answer['unitAliases'] as List? ?? const [])
          if (alias is String) alias,
      ];

  static List<String>? _stringList(dynamic value) {
    if (value is! List || value.any((item) => item is! String)) return null;
    return value.cast<String>();
  }

  static bool _sameNumber(dynamic left, dynamic right, String unit) {
    final a = parseNumber(left, unit: unit);
    final b = parseNumber(right, unit: unit);
    return a != null && b != null && (a - b).abs() < 1e-9;
  }
}
