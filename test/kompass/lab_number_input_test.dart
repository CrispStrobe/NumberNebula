import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/features/kompass/labs/kompass_lab_round.dart';

void main() {
  test('length lab accepts millimetres and rejects other quantities', () {
    final round = generateKompassLabRound('supply_station', 3, 417);
    final millimetres = round.config['targetMm'] as int;

    for (final answer in [
      '$millimetres',
      '$millimetres mm',
      '$millimetres,0 mm',
      '$millimetres millimetres',
    ]) {
      expect(round.check({'millimetres': answer}).correct, isTrue,
          reason: 'A valid millimetre answer must be accepted: $answer');
    }
    for (final answer in [
      '$millimetres €',
      '$millimetres cm',
      '${millimetres ~/ 10} cm',
      '$millimetres mm €',
    ]) {
      expect(round.check({'millimetres': answer}).correct, isFalse,
          reason: 'The requested millimetres cannot be replaced by $answer');
    }
  });

  test('shopping lab accepts euros while preserving explicit unit checks', () {
    final round = generateKompassLabRound('supply_station', 0, 417);
    final totalCents = round.config['totalCents'] as int;
    final euros = (totalCents / 100).toStringAsFixed(2);
    var remainder = round.config['changeCents'] as int;
    final coins = <int>[];
    for (final denomination in labCoinValues) {
      coins.add(remainder ~/ denomination);
      remainder %= denomination;
    }

    for (final answer in [
      euros,
      '$euros €',
      '${euros.replaceAll('.', ',')} Euro',
    ]) {
      expect(round.check({'total': answer, 'coins': coins}).points, 2,
          reason: 'The correct receipt and change must earn both points');
    }
    for (final answer in ['$euros mm', '$euros ct', '$euros € €']) {
      expect(round.check({'total': answer, 'coins': coins}).points, 1,
          reason: 'Correct change must not hide a receipt in the wrong unit');
    }
  });

  test('neutral lab numbers reject currency and silently joined digits', () {
    expect(parseLabNumber(' 3,75 '), 3.75);
    expect(parseLabNumber(' 3,75 € ', unit: '€'), 3.75);
    for (final value in ['3,75 €', '3 75', '3€75', '375e-2', 'NaN']) {
      expect(parseLabNumber(value), isNull, reason: value);
    }
  });
}
