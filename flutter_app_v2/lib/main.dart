import 'package:flutter/material.dart';

import 'package:mocktester_v2/app.dart';
import 'package:mocktester_v2/core/bootstrap/app_bootstrap.dart';
import 'package:mocktester_v2/tools/demo/demo_tool.dart';

/// True for demo/test builds: `flutter build apk --dart-define=DEMO_TOOL=true`.
///
/// The same source tree therefore produces either the normal app or the tester
/// build (widget gallery + screen directory + API smoke report), with no
/// branching inside the features themselves.
const bool kDemoBuild = bool.fromEnvironment('DEMO_TOOL', defaultValue: false);

void main() async {
  final BootstrapResult result = await AppBootstrap.run();

  runApp(kDemoBuild
      ? DemoApp(bootstrap: result)
      : MockTesterApp(isOnboarded: result.isOnboarded));
}
