import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dont_tap_blue/main.dart';

Finder _tileWithKind(String kind) {
  return find.byWidgetPredicate((Widget widget) {
    final Key? key = widget.key;
    return key is ValueKey<String> && key.value.endsWith('-$kind');
  }, skipOffstage: false);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('player can start and score on a safe tile', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const DontTapBlueApp());

    expect(find.text("Don't Tap Blue"), findsOneWidget);
    expect(find.text('Start Run'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('primary-action')));
    await tester.pump();

    expect(find.text('Find the warm tile'), findsOneWidget);
    expect(_tileWithKind('safe'), findsOneWidget);
    expect(_tileWithKind('trap'), findsOneWidget);
    expect(find.byKey(const ValueKey('pressure-bar')), findsOneWidget);

    await tester.tap(_tileWithKind('safe'));
    await tester.pump();

    expect(find.byKey(const ValueKey('score-pill-Score')), findsOneWidget);
    expect(find.text('1'), findsAtLeastNWidgets(1));
  });

  testWidgets('tapping blue ends the run and keeps best score visible', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const DontTapBlueApp());

    await tester.tap(find.byKey(const ValueKey('primary-action')));
    await tester.pump();

    await tester.tap(_tileWithKind('trap'));
    await tester.pump();

    expect(
      find.textContaining(RegExp('Blue got you|Too slow')),
      findsAtLeastNWidgets(1),
    );
    expect(find.text('Play Again'), findsOneWidget);
    expect(find.byKey(const ValueKey('score-pill-Best')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-rank')), findsOneWidget);
    expect(find.byKey(const ValueKey('result-cause')), findsOneWidget);
  });
}
