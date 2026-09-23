// A disabled primary button has to stay visible on the dark background.
// Material's default disabled grey all but vanished, so a child saw no
// button at all until they had picked an answer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:space_math_academy/core/theme/space_theme.dart';

void main() {
  test('disabled primary buttons keep a visible, dimmed orange', () {
    const disabled = {WidgetState.disabled};
    final bg = SpaceTheme.primaryButtonStyle.backgroundColor!.resolve(disabled)!;
    final fg = SpaceTheme.primaryButtonStyle.foregroundColor!.resolve(disabled)!;

    expect(bg.r, closeTo(SpaceTheme.planetOrange.r, 0.01));
    expect(bg.a, greaterThanOrEqualTo(0.25));
    expect(fg.a, greaterThanOrEqualTo(0.5));
  });
}
