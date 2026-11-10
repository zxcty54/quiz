import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Explicit, versioned notice shown before user-submitted text or study context
/// is sent to the server-side AI proxy.
class AiDataDisclosureService {
  AiDataDisclosureService._();

  static const String _disclosureVersion = '2026-10-12-v1';
  static const String _acceptedVersionKey = 'ai_data_disclosure_accepted_version';
  static const String _acceptedAtKey = 'ai_data_disclosure_accepted_at';
  static const String _serverSyncKey = 'ai_data_disclosure_server_sync_v1';

  static const String _notice =
      'To generate an answer, explanation, or parsed mock, the text you submit '
      'and relevant study material (such as the question and your selected '
      'answer) are sent to MockTester’s server-side AI service. The service '
      'may forward that information to AI providers to produce a response. '
      'AI mastery summaries may also use your recorded question attempts.\n\n'
      'Do not include passwords, contact details, or other sensitive personal '
      'information. AI responses can be wrong; verify important facts. If you '
      'report an AI response, its short excerpt and your report reason are '
      'sent to our moderation queue.\n\n'
      'You can decline and continue using other app features. See Support → '
      'Privacy Policy for more information.';

  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_acceptedVersionKey) == _disclosureVersion;
  }

  static Future<bool> requireConsent(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_acceptedVersionKey) == _disclosureVersion) {
      await _syncServerConsent(prefs);
      return true;
    }
    if (!context.mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('How AI features use your data'),
        content: const SingleChildScrollView(
          child: Text(_notice, style: TextStyle(height: 1.4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue to AI'),
          ),
        ],
      ),
    );

    if (accepted != true) return false;
    await prefs.setString(_acceptedVersionKey, _disclosureVersion);
    await prefs.setString(
      _acceptedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    await prefs.setBool(_serverSyncKey, false);
    await _syncServerConsent(prefs);
    return true;
  }

  /// Shows the AI-data setting in Support and lets the device user revoke.
  /// Local AI requests stop immediately; a successful server deletion also
  /// opts the device user out of future scheduled mastery analysis.
  static Future<void> showSettings(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isAccepted =
        prefs.getString(_acceptedVersionKey) == _disclosureVersion;
    if (!isAccepted) {
      if (!context.mounted) return;
      await requireConsent(context);
      return;
    }
    if (!context.mounted) return;

    final revoke = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('AI data processing'),
        content: const SingleChildScrollView(
          child: Text(
            'AI processing is enabled on this device. Your submitted prompts, '
            'relevant study material, and (for mastery summaries) recorded '
            'question attempts may be processed by our server-side AI service.\n\n'
            'Choose “Revoke” to stop future AI requests from this device and '
            'remove its opt-in for scheduled mastery analysis. Previously '
            'submitted reports or data already processed may remain subject '
            'to the Privacy Policy.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep enabled'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (revoke != true) return;
    final serverRevoked = await revokeConsent();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          serverRevoked
              ? 'AI processing consent revoked for this device.'
              : 'AI requests are disabled here, but server opt-out could not be confirmed. Please retry when online.',
        ),
      ),
    );
  }

  static Future<bool> revokeConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _deviceUserId(prefs);
    var serverRevoked = userId == null;

    if (userId != null) {
      try {
        await Supabase.instance.client
            .from('ai_processing_consents')
            .delete()
            .eq('user_id', userId);
        serverRevoked = true;
      } catch (_) {
        serverRevoked = false;
      }
    }

    await prefs.remove(_acceptedVersionKey);
    await prefs.remove(_acceptedAtKey);
    await prefs.remove(_serverSyncKey);
    return serverRevoked;
  }

  static String? _deviceUserId(SharedPreferences prefs) {
    final userId = prefs.getString('user_id')?.trim();
    if (userId == null || userId.isEmpty || userId == 'usr_guest') return null;
    return userId;
  }

  static Future<void> _syncServerConsent(SharedPreferences prefs) async {
    if (prefs.getBool(_serverSyncKey) == true) return;
    final userId = _deviceUserId(prefs);
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('ai_processing_consents').upsert(
        {
          'user_id': userId,
          'consent_version': _disclosureVersion,
          'consented_at': prefs.getString(_acceptedAtKey) ??
              DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id',
      );
      await prefs.setBool(_serverSyncKey, true);
    } catch (_) {
      // Keep interactive consent local, but the Worker will not analyze this
      // user's stored attempts unless it can see an opt-in row server-side.
    }
  }
}
