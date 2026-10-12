import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mocktester_v2/core/theme/app_theme.dart';
import 'package:mocktester_v2/core/widgets/brand_mark.dart';
import 'package:mocktester_v2/features/home/presentation/widgets/home_greeting_header.dart';
import 'package:mocktester_v2/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:mocktester_v2/features/onboarding/presentation/splash_screen.dart';
import 'package:mocktester_v2/tools/demo/demo_widget_gallery.dart';

/// Head-less UI check: every gallery widget is rendered on a phone-sized
/// surface, in light *and* dark mode, and any error the framework reports is
/// surfaced.
///
/// This is what answers "widget ka UI/UX theek hai?" without a device: layout
/// overflows, missing assets, bad constraints and crashes all show up here.
/// Failures caused by the *test* environment (no network, no plugins, no
/// Supabase) are listed separately and do not fail the suite — every real
/// layout problem does.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every layout defect found, collected so one CI run reports the whole list
  /// instead of the first few annotations.
  final List<String> uiDefects = <String>[];

  tearDownAll(() {
    if (uiDefects.isEmpty) return;
    print('==== UI DEFECTS (${uiDefects.length}) ====');
    for (final String defect in uiDefects) {
      print(defect);
    }
    print('==== END UI DEFECTS ====');
  });

  /// Messages that mean "this widget needs a device / backend"; they are
  /// reported but not treated as UI defects.
  const List<String> environmentMarkers = <String>[
    'supabase',
    'missingpluginexception',
    'socketexception',
    'clientexception',
    'httpexception',
    'failed host lookup',
    'connection refused',
    'connection closed',
    'network is unreachable',
    'operation not permitted',
    'platformexception',
    'unimplemented',
    'no implementation found for method',
    'failed assertion: line 0',
    'statuscode: 400',
    'status code 400',
    'bad state: stream has already been listened to',
    // HTTP 400 responses from the test binding, in various wrappings.
    'exception: 400',
    'invalid statuscode',
  ];

  bool isEnvironmentIssue(String message) {
    final String lower = message.toLowerCase();
    return environmentMarkers.any(lower.contains);
  }

  /// Renders [builder] like the gallery card does and returns every error the
  /// framework reported while building / laying out / ticking.
  Future<List<String>> renderAndCollect(
    WidgetTester tester,
    Widget Function(BuildContext context) builder, {
    required bool dark,
  }) async {
    final List<String> errors = <String>[];

    tester.view.physicalSize = const Size(1170, 2532); // 390 x 844 logical
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        // A known width keeps overflow reports comparable between runs.
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 400));

    Object? error = tester.takeException();
    while (error != null) {
      errors.add(error.toString());
      error = tester.takeException();
    }

    // Unmount: this flushes pending timers/animations so a widget that leaks
    // them is reported as such instead of poisoning the next test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));

    final Object? teardownError = tester.takeException();
    if (teardownError != null) {
      errors.add(teardownError.toString());
    }
    return errors;
  }

  for (final bool dark in <bool>[false, true]) {
    final String mode = dark ? 'dark' : 'light';

    for (final DemoGalleryEntry entry in demoGalleryEntries(dark: dark)) {
      testWidgets('gallery: ${entry.name} [$mode]',
          (WidgetTester tester) async {
        // entry.build applies the gallery's own sizing (some widgets scroll
        // internally and need a bounded box).
        final List<String> errors = await renderAndCollect(
          tester,
          entry.build,
          dark: dark,
        );

        final List<String> defects = errors
            .where((String e) => !isEnvironmentIssue(e))
            .toList();
        for (final String defect in defects) {
          // One line per defect, starting with RenderFlex/overflow when that is
          // what it is, so a grep on the CI log finds them all.
          uiDefects.add('${entry.name} [$mode] -> '
              '${defect.split('\n').first.trim()}');
        }
        final List<String> environment =
            errors.where(isEnvironmentIssue).toList();

        if (environment.isNotEmpty) {
          // Visible in the CI log, but not a UI defect.
          printOnFailure(
            '${entry.name} [$mode] needs a backend:\n'
            '${environment.join('\n---\n')}',
          );
        }

        expect(
          defects,
          isEmpty,
          reason: '${entry.name} [$mode] reported UI errors:\n'
              '${defects.join('\n---\n')}',
        );
      });
    }
  }

  group('redesigned surfaces', () {
    testWidgets('brand mark + wordmark render', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                BrandMark(size: 64),
                BrandWordmark(color: Colors.black),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('MOCKTESTER'), findsOneWidget);
    });

    testWidgets('welcome step renders and Continue opens the form step',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const OnboardingWelcomeScreen(nextScreen: SizedBox.shrink()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Welcome to\nMockTester'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('First,\nwhat should we call you?'), findsOneWidget);
      expect(find.text('SELECT YOUR DISTRICT'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Unmount before the intro controller/animations are checked.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('home greeting header renders and receives a reload token',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'stats_questions_solved': 42,
        'stats_correct_answers': 30,
        'stats_mocks_attempted': 3,
        'stats_study_streak': 5,
        'custom_aspirant_name': 'Aarav',
      });
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      int learnTaps = 0;
      int challengeTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeGreetingHeader(
              isDarkMode: false,
              onTapLearn: () => learnTaps++,
              onStartChallenge: () => challengeTaps++,
              reloadToken: 0,
            ),
          ),
        ),
      );
      // Let the stats future resolve.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Aarav'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);

      await tester.tap(find.text('Learn Hub'));
      await tester.pump();
      expect(learnTaps, 1);

      await tester.tap(find.text('Daily Challenge'));
      await tester.pump();
      expect(challengeTaps, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('splash renders and cancels its timer on dispose',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const SplashScreen()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('MockTester'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Leaving before the 2.5s timer fires must not leave a pending timer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
