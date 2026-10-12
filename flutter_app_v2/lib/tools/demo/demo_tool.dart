import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mocktester_v2/app.dart';
import 'package:mocktester_v2/core/bootstrap/app_bootstrap.dart';
import 'package:mocktester_v2/core/config/app_endpoints.dart';
import 'package:mocktester_v2/core/config/app_secrets.dart';
import 'package:mocktester_v2/core/theme/theme_controller.dart';
import 'package:mocktester_v2/features/shell/presentation/home_shell_screen.dart';

import 'package:mocktester_v2/tools/demo/demo_api_tests.dart';
import 'package:mocktester_v2/tools/demo/demo_screen_directory.dart';
import 'package:mocktester_v2/tools/demo/demo_widget_gallery.dart';

/// Demo build entry point.
///
/// Two ways to build it:
///   1. `flutter build apk -t lib/tools/demo/demo_tool.dart`   (this file)
///   2. `flutter build apk --dart-define=DEMO_TOOL=true`       (lib/main.dart)
///
/// It reuses the production bootstrap, theme and every feature screen, but
/// starts on a launcher that opens the widget gallery, the screen directory and
/// the API smoke report.
void main() async {
  final BootstrapResult result = await AppBootstrap.run();
  runApp(DemoApp(bootstrap: result));
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key, required this.bootstrap});

  final BootstrapResult bootstrap;

  /// The demo build reuses [MockTesterApp] so theming, routing and the theme
  /// controller stay identical to production. Bootstrap results are already
  /// folded into preferences by [AppBootstrap.run], hence the single flag.
  @override
  Widget build(BuildContext context) =>
      MockTesterApp(isOnboarded: bootstrap.isOnboarded);
}

/// Landing screen of the demo build.
class DemoLauncherScreen extends StatefulWidget {
  const DemoLauncherScreen({super.key, required this.bootstrap});

  final BootstrapResult bootstrap;

  @override
  State<DemoLauncherScreen> createState() => _DemoLauncherScreenState();
}

class _DemoLauncherScreenState extends State<DemoLauncherScreen> {
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _loadOnboardFlag();
  }

  Future<void> _loadOnboardFlag() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _onboarded = prefs.getBool('is_onboarded') ?? false);
    }
  }

  Future<void> _toggleOnboarding() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool next = !_onboarded;
    await prefs.setBool('is_onboarded', next);
    setState(() => _onboarded = next);
    _snack(next
        ? 'Onboarding marked complete — restart shows the app directly.'
        : 'Onboarding reset — restart shows the welcome flow.');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MockTester v2 — Demo Build'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Toggle theme',
            icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ThemeController.toggle(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFF2563EB), Color(0xFF1E40AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '🧪 DEMO BUILD — TEST BEFORE RELEASE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Everything from v1 is here,\nre-laid out per feature.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${_statusLine('Firebase', widget.bootstrap.firebaseReady)} • '
                  '${_statusLine('Supabase', widget.bootstrap.supabaseReady)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          _primaryAction(
            icon: Icons.palette_outlined,
            title: '🎨 Widget Gallery',
            subtitle: 'All 45+ widgets rendered with fixture data',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DemoWidgetGalleryScreen(),
              ),
            ),
          ),
          _primaryAction(
            icon: Icons.phone_android_outlined,
            title: '📱 Screen Directory',
            subtitle: 'Open every screen (34 routes) with fixtures',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DemoScreenDirectoryScreen(),
              ),
            ),
          ),
          _primaryAction(
            icon: Icons.health_and_safety_outlined,
            title: '🩺 API & Data Smoke Test',
            subtitle: 'Live check: assets, CDN mirrors, Supabase, AI, Telegram',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DemoSmokeTestScreen(),
              ),
            ),
          ),
          _primaryAction(
            icon: Icons.rocket_launch_outlined,
            title: '🚀 Launch the real app',
            subtitle: 'Starts HomeShellScreen exactly like production',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const DemoEmbeddedAppScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _SectionTitle('TESTER CONTROLS'),
          SwitchListTile(
            title: const Text('Onboarding completed'),
            subtitle: const Text(
              'Off = next launch shows the welcome flow (name + district)',
              style: TextStyle(fontSize: 11.5),
            ),
            value: _onboarded,
            onChanged: (bool _) => _toggleOnboarding(),
          ),
          const SizedBox(height: 8),
          const _SectionTitle('ENVIRONMENT'),
          _infoTile('Content repo', AppEndpoints.contentRepo),
          _infoTile('Quiz repo', AppEndpoints.quizRepo),
          _infoTile('AI worker', AppEndpoints.aiProxyBaseUrl),
          _infoTile(
            'Supabase secrets',
            AppSecrets.hasSupabase ? 'present' : 'missing (offline-safe)',
          ),
          _infoTile('GROQ_API_KEY', AppSecrets.groqApiKey.isEmpty ? 'missing' : 'present'),
          _infoTile('Admin bot', _maskToken(AppSecrets.telegramAdminBotToken)),
          _infoTile('Tracker bot', _maskToken(AppSecrets.telegramTrackerBotToken)),
          const SizedBox(height: 24),
          Text(
            'Build the production APK with:\n'
            'flutter build apk --release',
            style: TextStyle(
              fontSize: 11.5,
              color: theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _statusLine(String label, bool ready) =>
      '$label ${ready ? "✅" : "⚪ (optional)"}';

  String _maskToken(String token) {
    if (token.length < 12) return 'missing';
    return '${token.substring(0, 8)}…${token.substring(token.length - 4)}';
  }

  Widget _primaryAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(icon, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}

/// Streams the smoke-test report so the tester sees results as they land.
class DemoSmokeTestScreen extends StatefulWidget {
  const DemoSmokeTestScreen({super.key});

  @override
  State<DemoSmokeTestScreen> createState() => _DemoSmokeTestScreenState();
}

class _DemoSmokeTestScreenState extends State<DemoSmokeTestScreen> {
  final List<SmokeResult> _results = <SmokeResult>[];
  bool _running = false;

  Future<void> _run() async {
    setState(() {
      _results.clear();
      _running = true;
    });
    await DemoApiTests.runAll((SmokeResult result) {
      if (mounted) setState(() => _results.add(result));
    });
    if (mounted) setState(() => _running = false);
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final int passed = _results.where((SmokeResult r) => r.passed).length;
    final int failed = _results.length - passed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API & Data Smoke Test'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Run again',
            icon: const Icon(Icons.refresh),
            onPressed: _running ? null : _run,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: failed == 0 && !_running
                ? const Color(0xFF16A34A).withValues(alpha: 0.12)
                : const Color(0xFFD97706).withValues(alpha: 0.12),
            child: Row(
              children: <Widget>[
                if (_running)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    failed == 0 ? Icons.verified : Icons.warning_amber_rounded,
                    color: failed == 0
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFD97706),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _running
                        ? 'Running ${_results.length} checks…'
                        : '$passed passed • $failed failed • ${_results.length} total',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _results.length,
              itemBuilder: (BuildContext context, int index) {
                final SmokeResult r = _results[index];
                final bool newGroup = index == 0 ||
                    _results[index - 1].group != r.group;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (newGroup) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Text(
                          r.group.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          r.passed
                              ? Icons.check_circle
                              : Icons.cancel_outlined,
                          color: r.passed
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          size: 20,
                        ),
                        title: Text(
                          r.name,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          r.detail,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          '${r.ms} ms',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Embeds the production shell so the tester can use the real app inside the
/// demo build (same widget the release build shows after onboarding).
class DemoEmbeddedAppScreen extends StatelessWidget {
  const DemoEmbeddedAppScreen({super.key});

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
