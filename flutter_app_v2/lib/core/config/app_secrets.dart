/// Every credential the app needs in exactly one place.
///
/// Values can be rotated without touching code by passing them at build time:
///
/// ```
/// flutter build apk --release \
///   --dart-define=SUPABASE_URL=... \
///   --dart-define=SUPABASE_ANON_KEY=... \
///   --dart-define=TELEGRAM_ADMIN_BOT_TOKEN=... \
///   --dart-define=TELEGRAM_ADMIN_CHAT_ID=...
/// ```
///
/// The default values below are the ones the shipped v1 app used, so a plain
/// build keeps working exactly like before. CI injects the same names as
/// GitHub secrets (see `.github/workflows/build_apk_v2.yml`).
class AppSecrets {
  AppSecrets._();

  // ------------------------------------------------------------- supabase ---
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Supabase throws when initialised with an empty URL, so the bootstrap
  /// checks this flag first (fixes a v1 crash on secret-less builds).
  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  // ------------------------------------------------- admin bot (approvals) ---
  // `String.fromEnvironment` returns "" when the define exists but is empty,
  // so the helpers below fall back to the v1 values — a CI run without the
  // TELEGRAM_* secrets keeps the shipped behaviour instead of breaking alerts.
  static const String _envAdminBotToken =
      String.fromEnvironment('TELEGRAM_ADMIN_BOT_TOKEN');
  static const String _envAdminChatId =
      String.fromEnvironment('TELEGRAM_ADMIN_CHAT_ID');

  static String get telegramAdminBotToken => _envAdminBotToken.trim().isNotEmpty
      ? _envAdminBotToken.trim()
      : '1809778528:AAFlwdQMKgiezltaJYyAU5u6vNjblBiIPmo';

  static String get telegramAdminChatId => _envAdminChatId.trim().isNotEmpty
      ? _envAdminChatId.trim()
      : '785009742';

  // -------------------------------------- tracker bot (usage analytics) -----
  static const String _envTrackerBotToken =
      String.fromEnvironment('TELEGRAM_TRACKER_BOT_TOKEN');
  static const String _envTrackerChatId =
      String.fromEnvironment('TELEGRAM_TRACKER_CHAT_ID');

  static String get telegramTrackerBotToken =>
      _envTrackerBotToken.trim().isNotEmpty
          ? _envTrackerBotToken.trim()
          : '7953258129:AAH1J0eJ3rMmsxS_iM4Xm0LpXyOqE2A1pQ4';

  static String get telegramTrackerChatId =>
      _envTrackerChatId.trim().isNotEmpty
          ? _envTrackerChatId.trim()
          : '1138865181';

  // ------------------------------------------------------------------- ai ---
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY');
}
