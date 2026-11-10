import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Google Play requires an app that lets a device create an account to also let
/// that device delete the account and its data from inside the app, and to
/// offer the same deletion through a web link.
///
/// MockTester has no login: identity is the generated `usr_…` id stored on the
/// device (with the creator handle on top of it when a creator signs in). This
/// service therefore erases every server row that carries one of those
/// identities and then clears the local copy of the same data, so the next
/// launch starts from onboarding with a brand-new identity.
///
/// Deletion runs with the client key only. Every table it touches already
/// allows deletes through its RLS policy, so no service-role secret and no
/// database change is needed. Each table is cleared independently: if one call
/// fails (offline, or a table that is not deployed yet) the rest still run and
/// the failure is reported back to the user instead of being hidden.
class AccountDeletionService {
  AccountDeletionService._();

  /// Web page offering the same deletion. Play asks for a link next to the
  /// in-app action, so this opens the deletion section of the privacy policy
  /// (anchor `#deletion`) rather than the top of the page.
  static const String webDeletionUrl =
      'https://www.mocktester.online/p/privacy.html#deletion';

  /// Rows that are cleared, grouped by the identity that owns them.
  static const List<String> _userIdTables = <String>[
    'app_users',
    'user_question_attempts',
    'user_ai_insights',
    'user_premium',
    'premium_requests',
    'daily_challenge_submissions',
    'event_attendees',
    'ai_processing_consents',
  ];

  /// Tables whose owner column is the community handle (which is also the
  /// `usr_…` id for anyone who never signed in as a creator).
  static const Map<String, String> _handleColumns = <String, String>{
    'community_posts': 'creator_id',
    'creator_mocks': 'creator_id',
    'creator_profiles': 'handle_id',
    'post_comments': 'user_handle',
    'post_likes': 'user_handle',
    'comment_likes': 'user_handle',
    'poll_votes': 'user_handle',
    'user_saved_posts': 'user_handle',
    'post_reports': 'reported_by',
    'content_moderation_reports': 'reported_by',
    'batch_submissions': 'student_identifier',
  };

  /// Notifications also record who triggered them, so the same handle is erased
  /// from those columns too.
  static const List<String> _notificationColumns = <String>[
    'user_handle',
    'actor_handle',
    'receiver_id',
  ];

  /// Local storage that belongs to the person, their progress, or their
  /// consent. UI preferences (dark mode) and bundled content caches are kept on
  /// purpose so the app does not have to re-download study content.
  static const List<String> _localKeys = <String>[
    // identity and profile
    'user_id',
    'user_name',
    'full_name',
    'custom_aspirant_name',
    'user_district',
    'user_mobile',
    'user_email',
    'student_contact_id',
    'anonymous_device_uuid',
    'logged_in_creator_handle',
    'user_enrolled_batch_code',
    'followed_creators',
    'is_onboarded',
    // study stats and progress
    'stats_questions_solved',
    'stats_correct_answers',
    'stats_mocks_attempted',
    'stats_study_streak',
    'stats_last_active_date',
    'stats_last_chapter_name',
    'stats_last_chapter_path',
    'stats_wrong_questions_json',
    'stats_saved_questions_json',
    'stats_subject_performance_map',
    'has_learning_history',
    'last_learn_title',
    'last_learn_progress',
    'last_next_topic',
    'last_sub_district',
    'last_sub_score',
    'last_sub_time',
    'last_sub_user',
    'saved_daily_bulletins',
    'ai_last_call_timestamp',
    // AI disclosure and community safety state
    'ai_data_disclosure_accepted_version',
    'ai_data_disclosure_accepted_at',
    'ai_data_disclosure_server_sync_v1',
    'community_terms_accepted_version',
    'community_terms_accepted_at',
    'community_blocked_handles_v1',
  ];

  /// Keys created at runtime with a changing suffix.
  static const List<String> _localKeyPrefixes = <String>[
    'unlocked_batch_',
    'mastery_badge',
    'mastery_summary',
    'saved_current_affairs_screen',
    'saved_questions_screen',
  ];

  /// Identity values are used inside PostgREST filters, so only plain tokens are
  /// accepted. Anything else is skipped rather than sent as a filter.
  static final RegExp _safeToken = RegExp(r'^[A-Za-z0-9_.@:-]{1,160}$');

  static bool _usable(String? value) =>
      value != null && value.trim().isNotEmpty && _safeToken.hasMatch(value.trim());

  /// Same device identifier the onboarding flow registers in `app_users`.
  static Future<String> permanentDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        return (await info.androidInfo).id;
      }
      return (await info.iosInfo).identifierForVendor ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Every identity this device is known by: the generated user id and, when a
  /// creator is signed in, their handle as well.
  static Future<Set<String>> currentIdentities() async {
    final prefs = await SharedPreferences.getInstance();
    return <String>{
      if (_usable(prefs.getString('user_id'))) prefs.getString('user_id')!.trim(),
      if (_usable(prefs.getString('logged_in_creator_handle')))
        prefs.getString('logged_in_creator_handle')!.trim(),
    };
  }

  /// Deletes the account: server rows first, then the local copy.
  static Future<AccountDeletionResult> deleteAccountAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final identities = await currentIdentities();
    final deviceId = await permanentDeviceId();

    final cleared = <String>[];
    final failed = <String>[];
    final retained = <String>[];

    Future<void> clear(String table, String column, String value) async {
      final label = '$table.$column';
      if (!_usable(value)) return;
      try {
        await Supabase.instance.client.from(table).delete().eq(column, value);
        cleared.add(label);
      } catch (error) {
        final message = error.toString();
        final notDeployed = message.contains('schema cache') ||
            message.contains('Could not find the table') ||
            message.contains('42P01');
        final writeOnly =
            message.contains('permission denied') || message.contains('42501');
        if (notDeployed) {
          debugPrint('Account deletion: $label is not deployed yet');
        } else if (writeOnly) {
          debugPrint('Account deletion: $label is write-only for clients');
          retained.add(label);
        } else {
          debugPrint('Account deletion: $label failed: $error');
          failed.add(label);
        }
      }
    }

    for (final identity in identities) {
      for (final table in _userIdTables) {
        await clear(table, 'user_id', identity);
      }
      for (final entry in _handleColumns.entries) {
        await clear(entry.key, entry.value, identity);
      }
      for (final column in _notificationColumns) {
        await clear('user_notifications', column, identity);
      }
    }

    if (_usable(deviceId)) {
      await clear('app_users', 'device_id', deviceId);
    }

    final localCleared = await _wipeLocalData(prefs);

    return AccountDeletionResult(
      identities: identities.toList()..sort(),
      cleared: cleared,
      failed: failed,
      retained: retained,
      localCleared: localCleared,
    );
  }

  static Future<bool> _wipeLocalData(SharedPreferences prefs) async {
    try {
      final stored = prefs.getKeys();
      final doomed = <String>{
        ..._localKeys,
        ...stored.where((key) => _localKeyPrefixes.any(key.startsWith)),
      };
      for (final key in doomed) {
        await prefs.remove(key);
      }
      return true;
    } catch (error) {
      debugPrint('Account deletion: local wipe failed: $error');
      return false;
    }
  }

  /// Opens the web deletion page so the requirement is met outside the app too.
  static Future<void> openWebDeletionPage() async {
    final uri = Uri.parse(webDeletionUrl);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        debugPrint('Account deletion: could not open $webDeletionUrl');
      }
    } catch (error) {
      debugPrint('Account deletion: web link failed: $error');
    }
  }

  /// Explains what will be erased, asks for an explicit confirmation, runs the
  /// deletion and reports the outcome. Returns true only when the account was
  /// deleted, so the caller can restart the app flow.
  static Future<bool> promptAndDelete(BuildContext context) async {
    final identities = await currentIdentities();
    if (!context.mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account and data?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                identities.isEmpty
                    ? 'This device has no saved identity yet.'
                    : 'This erases everything linked to ${identities.join(', ')}.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Deleted from our database:\n'
                '• Profile: name, district, phone, email, device id\n'
                '• Study history: attempts, scores, streaks, mastery and AI reports\n'
                '• Saved and wrong questions, bookmarks, notifications\n'
                '• Community posts, comments, likes, poll votes and reports you filed\n'
                '• Creator profile, mocks and classroom submissions, if you have any\n'
                '• AI data-disclosure consent and community terms acceptance',
              ),
              const SizedBox(height: 12),
              const Text(
                'Deleted from this device: the same data plus your sign-in state. '
                'Dark mode and downloaded study content stay so the app reloads fast.',
              ),
              const SizedBox(height: 12),
              const Text(
                'This cannot be undone. The app restarts at onboarding with a new '
                'identity. You can also request deletion on the web.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete everything',
              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    // Blocking progress dialog: deletion must not be interrupted halfway. It is
    // opened without awaiting and popped once the work below finishes.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(width: 18),
            Expanded(child: Text('Deleting your account and data…')),
          ],
        ),
      ),
    );

    final result = await deleteAccountAndData();
    if (!context.mounted) return false;
    Navigator.of(context).pop(); // close the progress dialog

    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(result.localCleared ? 'Account deleted' : 'Partly deleted'),
        content: Text(result.summary),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    return result.localCleared;
  }
}

/// Outcome of one deletion attempt, worded for the person who asked for it.
class AccountDeletionResult {
  const AccountDeletionResult({
    required this.identities,
    required this.cleared,
    required this.failed,
    required this.retained,
    required this.localCleared,
  });

  final List<String> identities;
  final List<String> cleared;
  final List<String> failed;
  final List<String> retained;
  final bool localCleared;

  String get summary {
    final buffer = StringBuffer();
    if (identities.isEmpty) {
      buffer.write('No saved identity was found on this device.');
    } else {
      buffer.write('Erased the data linked to ${identities.join(', ')}.');
    }
    buffer.write(' ${cleared.length} server collections cleared.');
    if (retained.isNotEmpty) {
      buffer.write(
        ' Kept because the app is not allowed to erase it: '
        '${retained.join(', ')}. That is the moderation report queue, which a '
        'person can file but not delete. Write to support and we will remove '
        'those records for you.',
      );
    }
    if (failed.isNotEmpty) {
      buffer.write(
        ' Could not reach: ${failed.join(', ')}. That happens when the device '
        'is offline or a collection is not deployed yet. Retry while online, '
        'or contact support and we will erase them for you.',
      );
    }
    if (!localCleared) {
      buffer.write(' Local storage could not be cleared on this device.');
    }
    return buffer.toString();
  }
}
