import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

void main() {
  group('SVGAEasyPlayer Playback Modes Tests', () {
    testWidgets('SVGAEasyPlayer builds with default infinite loop',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SVGAEasyPlayer(
              assetsName: "assets/sample.svga",
              // loops: null is default (infinite)
            ),
          ),
        ),
      );

      expect(find.byType(SVGAEasyPlayer), findsOneWidget);
    });

    testWidgets('SVGAEasyPlayer builds with loops set to 0 (play once)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SVGAEasyPlayer(
              assetsName: "assets/sample.svga",
              loops: 0,
              onFinished: () {
                // Callback verified to be settable
              },
            ),
          ),
        ),
      );

      expect(find.byType(SVGAEasyPlayer), findsOneWidget);
      // Note: callback won't be called in test without actual animation
      // This just verifies the widget builds correctly
    });

    testWidgets('SVGAEasyPlayer builds with loops set to 3 (repeat 3 times)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SVGAEasyPlayer(
              assetsName: "assets/sample.svga",
              loops: 3,
              onFinished: () {
                // Callback verified to be settable
              },
            ),
          ),
        ),
      );

      expect(find.byType(SVGAEasyPlayer), findsOneWidget);
    });

    testWidgets('SVGAEasyPlayer accepts both resUrl and assetsName',
        (WidgetTester tester) async {
      // Test with assetsName
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SVGAEasyPlayer(
              assetsName: "assets/sample.svga",
              loops: 0,
            ),
          ),
        ),
      );

      expect(find.byType(SVGAEasyPlayer), findsOneWidget);

      // Test with resUrl
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SVGAEasyPlayer(
              resUrl: "https://example.com/animation.svga",
              loops: 1,
            ),
          ),
        ),
      );

      expect(find.byType(SVGAEasyPlayer), findsOneWidget);
    });

    testWidgets('SVGAEasyPlayer can be created without onFinished callback',
        (WidgetTester tester) async {
      // Should work fine without callback
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SVGAEasyPlayer(
              assetsName: "assets/sample.svga",
              loops: 0,
              // No onFinished callback
            ),
          ),
        ),
      );

      expect(find.byType(SVGAEasyPlayer), findsOneWidget);
    });

    testWidgets('SVGAEasyPlayer accepts different BoxFit values',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SVGAEasyPlayer(
              assetsName: "assets/sample.svga",
              fit: BoxFit.cover,
              loops: 0,
            ),
          ),
        ),
      );

      expect(find.byType(SVGAEasyPlayer), findsOneWidget);
    });

    test('Verify loops parameter accepts null, 0, and positive integers', () {
      // These should all be valid
      const player1 = SVGAEasyPlayer(
        assetsName: "assets/sample.svga",
        loops: null, // infinite
      );

      const player2 = SVGAEasyPlayer(
        assetsName: "assets/sample.svga",
        loops: 0, // play once
      );

      const player3 = SVGAEasyPlayer(
        assetsName: "assets/sample.svga",
        loops: 5, // repeat 5 times
      );

      expect(player1.loops, isNull);
      expect(player2.loops, equals(0));
      expect(player3.loops, equals(5));
    });

    test('onFinished callback is optional', () {
      // Should compile without callback
      const player = SVGAEasyPlayer(
        assetsName: "assets/sample.svga",
        loops: 0,
      );

      expect(player.onFinished, isNull);
    });

    test('onFinished callback can be provided', () {
      void callback() {}

      final player = SVGAEasyPlayer(
        assetsName: "assets/sample.svga",
        loops: 0,
        onFinished: callback,
      );

      expect(player.onFinished, isNotNull);
      expect(player.onFinished, equals(callback));
    });
  });
}
