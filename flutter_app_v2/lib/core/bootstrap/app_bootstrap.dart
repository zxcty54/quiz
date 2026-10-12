import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mocktester_v2/core/config/app_secrets.dart';
import 'package:mocktester_v2/core/config/remote_config_service.dart';
import 'package:mocktester_v2/core/services/notifications/notification_service.dart';
import 'package:mocktester_v2/core/theme/theme_controller.dart';

/// Result of the start-up sequence.
class BootstrapResult {
  const BootstrapResult({
    required this.isOnboarded,
    required this.firebaseReady,
    required this.supabaseReady,
  });

  final bool isOnboarded;
  final bool firebaseReady;
  final bool supabaseReady;
}

/// One shared boot sequence for both the real app and the demo tool.
///
/// Order matters:
///   1. Firebase   (optional — the app is fully usable without it)
///   2. Supabase   (optional — v1 crashed when the secret was missing)
///   3. theme + onboarding flags from disk
///   4. remote config warm-up (fire and forget, never blocks first paint)
class AppBootstrap {
  AppBootstrap._();

  static Future<BootstrapResult> run() async {
    WidgetsFlutterBinding.ensureInitialized();

    final bool firebaseReady = await _initFirebase();
    final bool supabaseReady = await _initSupabase();

    await ThemeController.load();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isOnboarded = prefs.getBool('is_onboarded') ?? false;

    unawaited(_warmUpRemoteConfig());

    return BootstrapResult(
      isOnboarded: isOnboarded,
      firebaseReady: firebaseReady,
      supabaseReady: supabaseReady,
    );
  }

  /// Firebase must never stop the app from booting: a missing or stale
  /// `google-services.json` is a very common local-build situation.
  static Future<bool> _initFirebase() async {
    try {
      await Firebase.initializeApp();
      await NotificationService.initialize();
      return true;
    } catch (e) {
      debugPrint('Bootstrap: Firebase skipped ($e)');
      return false;
    }
  }

  /// Supabase throws an assertion on an empty URL — guard it, then
  /// `Supabase.instance` is only touched when a client really exists.
  static Future<bool> _initSupabase() async {
    if (!AppSecrets.hasSupabase) {
      debugPrint('Bootstrap: Supabase secrets missing — cloud sync disabled.');
      return false;
    }
    try {
      await Supabase.initialize(
        url: AppSecrets.supabaseUrl,
        anonKey: AppSecrets.supabaseAnonKey,
      );
      return true;
    } catch (e) {
      debugPrint('Bootstrap: Supabase failed ($e)');
      return false;
    }
  }

  /// Pulls the latest remote config in the background. `RemoteConfigService`
  /// forwards the AI routing table to `AiExplainerService` on the way.
  static Future<void> _warmUpRemoteConfig() async {
    try {
      await RemoteConfigService.instance.refreshAll();
    } catch (e) {
      debugPrint('Bootstrap: remote config warm-up failed ($e)');
    }
  }
}

/// True when a Supabase client was successfully created.
bool get supabaseReadyNow {
  try {
    Supabase.instance.client;
    return true;
  } catch (_) {
    return false;
  }
}
