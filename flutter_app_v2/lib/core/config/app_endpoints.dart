/// Central registry of every remote endpoint the app talks to.
///
/// Before: 20+ `https://raw.githubusercontent.com/...` strings were copy-pasted
/// across 34 files. Now every URL is derived from this single file.
class AppEndpoints {
  AppEndpoints._();

  // --------------------------------------------------------------- repos ---
  /// Content repository (questions, mapping, bulletins, static/ folder).
  static const String contentRepo = 'zxcty54/content_base';

  /// This app's own repository (current affairs files, monthly MCQs).
  static const String quizRepo = 'zxcty54/quiz';

  /// Branch used for both repositories.
  static const String branch = 'main';

  // ------------------------------------------------------------ websites ---
  static const String website = 'https://www.mocktester.online';
  static const String privacyPolicy = '$website/p/privacy.html';
  static const String telegramChannel = 'https://t.me/MT_Masterhub_bot';
  static const String playStoreListing =
      'https://play.google.com/store/apps/details?id=com.mocktester.app';

  /// Deep link used when a student shares a challenge result.
  static const String challengeShareBase = 'https://mocktester.app/challenge';

  /// Google Apps Script Web-App endpoint that stores community "trick"
  /// submissions into the shared sheet.
  static const String communityWikiScriptUrl =
      'https://script.google.com/macros/s/AKfycbztbqpHH7H8LulJ36AsDBhSYmBVfmH-ONb6exJKCELIbqCbb6iptv43PrgO-y6-Jo8ULg/exec';

  /// QR image generator used by the donation card.
  static String qrCodeUrl(String encodedPayload) =>
      'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=$encodedPayload';

  // ------------------------------------------------------- AI + telemetry ---
  /// Cloudflare worker that fronts the LLM providers (keeps keys off-device).
  static const String aiProxyBaseUrl =
      'https://ai-proxy.nitesh-skyhigh.workers.dev';

  static const String groqApiBase = 'https://api.groq.com/openai/v1';

  /// Free IP geolocation providers used by [TelegramTracker].
  static const String ipApiCo = 'https://ipapi.co/json/';
  static const String ipApiCom = 'http://ip-api.com/json';

  // ----------------------------------------------------------- github api ---
  /// Raw file through the GitHub contents API (bypasses CDN edge caches).
  static String githubContentsApi(String repo, String path, {int? ts}) {
    final int stamp = ts ?? DateTime.now().millisecondsSinceEpoch;
    return 'https://api.github.com/repos/$repo/contents/$path?ref=$branch&t=$stamp';
  }

  /// CDN / mirror fallbacks, ordered fastest-first.
  static List<String> mirrorUrls(String repo, String path, {int? ts}) {
    final int stamp = ts ?? DateTime.now().millisecondsSinceEpoch;
    return <String>[
      'https://raw.githack.com/$repo/$branch/$path',
      'https://fastly.jsdelivr.net/gh/$repo@$branch/$path?t=$stamp',
      'https://cdn.statically.io/gh/$repo/$branch/$path',
      'https://cdn.jsdelivr.net/gh/$repo@$branch/$path?t=$stamp',
      'https://raw.githubusercontent.com/$repo/$branch/$path?t=$stamp',
    ];
  }

  /// Prefixes that may appear inside the remote JSON files themselves. They are
  /// stripped before a path is used again (see [JsonFetcher.cleanPath]).
  static List<String> get knownPrefixes => <String>[
        'https://cdn.jsdelivr.net/gh/$contentRepo@$branch/',
        'https://fastly.jsdelivr.net/gh/$contentRepo@$branch/',
        'https://raw.githubusercontent.com/$contentRepo/$branch/',
        'https://raw.githubusercontent.com/$contentRepo/refs/heads/$branch/',
        'https://cdn.statically.io/gh/$contentRepo/$branch/',
        'https://raw.githack.com/$contentRepo/$branch/',
        'https://cdn.jsdelivr.net/gh/$quizRepo@$branch/',
        'https://fastly.jsdelivr.net/gh/$quizRepo@$branch/',
        'https://raw.githubusercontent.com/$quizRepo/$branch/',
        'https://raw.githubusercontent.com/$quizRepo/refs/heads/$branch/',
        'https://cdn.statically.io/gh/$quizRepo/$branch/',
        'https://raw.githack.com/$quizRepo/$branch/',
      ];
}
