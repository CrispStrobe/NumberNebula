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
        feedback: json['feedback'] == null ? null : kompassMap(json['feedback']),
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
    'cm': ['cm', 'zentimeter', 'centimeter', 'centimeters', 'centimetre', 'centimetres'],
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
  static double? parseNumber(dynamic value, {String unit = ''}) {
    if (value is num) return value.isFinite ? value.toDouble() : null;
    if (value is! String) return null;
    var text = value
        .trim()
        .replaceAll('\u2212', '-')
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202f', ' ');
    if (text.isEmpty) return null;
    final expectedUnit = unit.trim().toLowerCase();
    if (expectedUnit.isNotEmpty) {
      final aliases = [...?_unitAliases[expectedUnit], expectedUnit]
        ..sort((a, b) => b.length.compareTo(a.length));
      final lower = text.toLowerCase();
      for (final alias in aliases) {
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
      final attempted = isAnswered(response);
      final type = part.answer['type'];
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
            final number = parseNumber(response, unit: part.unit);
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
              final previous =
                  parseNumber(responses[source.id], unit: source.unit);
              final previousExpected = (source.answer['value'] as num).toDouble();
              if (previous != null &&
                  (previous - previousExpected).abs() > tolerance &&
                  number >= 0 &&
                  (number - (previous + part.carryOffset!)).abs() <= tolerance) {
                carried = true;
                points = part.maxPoints;
                errorCode = 'carried_error';
                feedback = const {
                  'de': 'Dieser Rechenschritt passt zu deinem vorherigen Ergebnis. Prüfe den vorherigen Schritt noch einmal.',
                  'en': 'This step follows your earlier result correctly. Check that earlier step again.',
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
              for (final other in part.answer['alternatives'] as List? ?? const [])
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
                points = part.maxPoints *
                    math.max(0, right - wrong) / target.length;
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
          case 'manual':
            final review = manualPoints[part.id];
            if (review != null) {
              if (!review.isFinite || review < 0 || review > part.maxPoints) {
                throw ArgumentError.value(review, 'manualPoints',
                    'Review points must be between zero and the part maximum.');
              }
              points = review;
              reviewed = true;
              correct = review == part.maxPoints;
            } else {
              pending = true;
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
        manual: type == 'manual',
        reviewed: reviewed,
        attempted: attempted,
        carriedError: carried,
        errorCode: errorCode ?? (!correct && !pending ? 'incorrect' : null),
        feedback: feedback,
      ));
    }
    return KompassScore(scores);
  }

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
