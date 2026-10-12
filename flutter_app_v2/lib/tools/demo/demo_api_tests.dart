import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mocktester_v2/core/bootstrap/app_bootstrap.dart';
import 'package:mocktester_v2/core/config/app_endpoints.dart';
import 'package:mocktester_v2/core/config/app_secrets.dart';
import 'package:mocktester_v2/core/config/remote_config_service.dart';
import 'package:mocktester_v2/core/network/json_fetcher.dart';
import 'package:mocktester_v2/core/network/local_cache.dart';
import 'package:mocktester_v2/features/ai/data/ai_explainer_service.dart';
import 'package:mocktester_v2/features/bihar_gk/data/bpsc_rotation_service.dart';
import 'package:mocktester_v2/features/challenge/data/challenge_service.dart';

/// One line of the smoke-test report.
class SmokeResult {
  const SmokeResult({
    required this.group,
    required this.name,
    required this.passed,
    required this.detail,
    required this.ms,
  });

  final String group;
  final String name;
  final bool passed;
  final String detail;
  final int ms;
}

/// End-to-end checks a tester can run on the phone before a release.
///
/// Each check exercises a **real** code path of the app (the shared fetcher,
/// live services, secrets, cache, bundled assets), so a green run means the
/// build can genuinely load content.
class DemoApiTests {
  DemoApiTests._();

  static Future<List<SmokeResult>> runAll(
    void Function(SmokeResult result) onResult,
  ) async {
    final List<SmokeResult> results = <SmokeResult>[];

    Future<void> run(
      String group,
      String name,
      Future<String> Function() body,
    ) async {
      final Stopwatch watch = Stopwatch()..start();
      SmokeResult result;
      try {
        final String detail = await body();
        watch.stop();
        result = SmokeResult(
          group: group,
          name: name,
          passed: true,
          detail: detail,
          ms: watch.elapsedMilliseconds,
        );
      } catch (e) {
        watch.stop();
        result = SmokeResult(
          group: group,
          name: name,
          passed: false,
          detail: '$e',
          ms: watch.elapsedMilliseconds,
        );
      }
      results.add(result);
      onResult(result);
    }

    // ------------------------------------------------------------- runtime --
    await run('Runtime', 'Supabase', () async {
      if (!AppSecrets.hasSupabase) {
        return 'secrets missing → cloud features disabled (offline demo OK)';
      }
      if (!supabaseReadyNow) throw 'secrets present but client init failed';
      final List<dynamic> rows = await Supabase.instance.client
          .from('coachings')
          .select('id')
          .limit(3);
      return 'coachings answered with ${rows.length} row(s)';
    });

    await run('Runtime', 'Telegram admin bot', () async =>
        'bot @${await _telegramGetMe(AppSecrets.telegramAdminBotToken)} alive');

    await run('Runtime', 'Telegram tracker bot', () async =>
        'bot @${await _telegramGetMe(AppSecrets.telegramTrackerBotToken)} alive');

    // -------------------------------------------------------------- assets --
    for (final String file in <String>[
      'app_config.json',
      'home_data.json',
      'learn_data.json',
      'sectional_data.json',
      'subject_mapping.json',
    ]) {
      await run('Bundled assets', file, () async {
        final String raw = await rootBundle.loadString('assets/data/$file');
        jsonDecode(raw);
        return 'parsed ${raw.length} bytes';
      });
    }

    await run('Bundled assets', 'launcher icon', () async {
      final ByteData icon = await rootBundle.load('assets/images/app_icon.png');
      return 'app_icon.png = ${(icon.lengthInBytes / 1024).round()} KB';
    });

    // -------------------------------------------------------- local config --
    await run('Local config', 'cache-first bundle', () async {
      final RemoteConfigBundle bundle =
          await RemoteConfigService.instance.loadLocal();
      return 'app=${bundle.appConfig.length} keys • '
          'sectional=${bundle.sectionalData.length} exams • '
          'mapping=${bundle.subjectMapping.length} subjects';
    });

    await run('Local config', 'cache round-trip', () async {
      await LocalCache.saveJson('demo_cache_probe', <String, dynamic>{
        'ok': true,
        'at': DateTime.now().toIso8601String(),
      });
      final Map<String, dynamic>? back =
          await LocalCache.readMap('demo_cache_probe');
      await LocalCache.remove('demo_cache_probe');
      if (back == null || back['ok'] != true) {
        throw 'cache did not return the stored payload';
      }
      return 'write → read → remove OK';
    });

    await run('Local config', 'AI routing table', () async {
      final Map<String, dynamic>? cfg =
          await RemoteConfigService.instance.refreshAppConfig();
      if (cfg == null) throw 'app_config.json unreachable';
      return 'chain: ${AiExplainerService.activeModelHierarchy.join(" → ")}';
    });

    // ------------------------------------------------------- remote content --
    for (final String file in <String>[
      'sectional_data.json',
      'subject_mapping.json',
      'learn_data.json',
      'sarkarijob.json',
      'knowyourbihar/crops.json',
    ]) {
      await run('Remote JSON', file, () async {
        final dynamic data = await JsonFetcher.instance.fetchRobust(file);
        if (data == null) throw 'all mirrors failed';
        final String shape = data is List
            ? 'list(${data.length})'
            : 'map(${(data as Map).length} keys)';
        return 'core/network/json_fetcher → $shape';
      });
    }

    await run('Remote JSON', 'question bank (physics/light)',
        () async {
      final List<dynamic>? rows =
          await JsonFetcher.instance.fetchList('static/physics/light.json');
      if (rows == null || rows.isEmpty) throw 'empty question bank';
      return '${rows.length} questions • '
          '${(rows.first as Map).keys.length} fields in Q1';
    });

    await run('Remote JSON', 'current affairs (quiz repo)', () async {
      final dynamic data = await JsonFetcher.instance.fetchRobust(
        'current_affair/august_2026.json',
        repo: AppEndpoints.quizRepo,
      );
      if (data == null) throw 'unreachable';
      return data is List ? '${data.length} entries' : '${data.runtimeType}';
    });

    // --------------------------------------------------------- app services --
    await run('App services', 'challenge generator (10 files in parallel)',
        () async {
      final Map<String, dynamic> challenge =
          await ChallengeService.generateDailyChallenge();
      final List<dynamic> questions = challenge['questions'] as List<dynamic>;
      if (questions.isEmpty) throw 'no questions assembled';
      return 'code ${challenge['challenge_code']} • ${questions.length} Qs';
    });

    await run('App services', 'Know Your Bihar daily card', () async {
      final BpscDailyPayload payload =
          await BpscRotationService.fetchTodayPayload();
      return '${payload.config.domain} • ${payload.card.title}';
    });

    await run('App services', 'AI explainer (cloud worker)', () async {
      final String answer = await AiExplainerService.getExplanation(
        question: 'Which article of the Indian Constitution deals with the '
            'Right to Constitutional Remedies?',
        options: const <String>['Article 19', 'Article 21', 'Article 32', 'Article 44'],
        correctAnswer: 'Article 32',
      );
      if (answer.trim().isEmpty) throw 'empty answer';
      return answer.length > 150
          ? '${answer.substring(0, 150).replaceAll("\n", " ")}…'
          : answer.replaceAll('\n', ' ');
    });

    // ---------------------------------------------------------------- web ----
    await run('Website', 'mocktester.online', () async {
      final http.Response res = await http
          .get(Uri.parse(AppEndpoints.website))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 400) throw 'HTTP ${res.statusCode}';
      return 'HTTP ${res.statusCode} • ${res.bodyBytes.length} bytes';
    });

    return results;
  }

  static Future<String> _telegramGetMe(String token) async {
    final http.Response res = await http
        .get(Uri.parse('https://api.telegram.org/bot$token/getMe'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw 'HTTP ${res.statusCode}: ${res.body}';
    }
    final Map<String, dynamic> body =
        jsonDecode(res.body) as Map<String, dynamic>;
    return (body['result']?['username'] ?? 'unknown').toString();
  }
}
