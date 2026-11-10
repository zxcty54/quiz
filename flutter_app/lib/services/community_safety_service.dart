import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app UGC safeguards. The app intentionally uses a device-based identity,
/// so consent and blocked handles are stored locally on that device.
class CommunitySafetyService {
  CommunitySafetyService._();

  static const String termsVersion = '2026-10-12-v1';
  static const String _termsVersionKey = 'community_terms_accepted_version';
  static const String _termsAcceptedAtKey = 'community_terms_accepted_at';
  static const String _blockedHandlesKey = 'community_blocked_handles_v1';

  static const List<String> reportReasons = [
    'Harassment or bullying',
    'Hate or abusive content',
    'Sexual or violent content',
    'Spam or scam',
    'False or misleading content',
    'Other safety concern',
  ];

  /// Shows the current community rules before the first post/comment on a
  /// device, and whenever the rules version changes. Posting is blocked unless
  /// the user explicitly accepts.
  static Future<bool> requirePostingTerms(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_termsVersionKey) == termsVersion) return true;
    if (!context.mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Community Terms & Safety'),
        content: const SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Text(
              'Posting is public and optional. By choosing “Agree and continue”, you confirm that you have the right to share your post, image, quiz, or comment.\n\n'
              'Do not post harassment, hate, threats, sexual or violent content, scams, spam, illegal material, or anyone’s private information. Be respectful and keep content relevant to learning.\n\n'
              'Other users can report content or block its author. Moderators may review and remove content or restrict repeat offenders. Your device-based user ID, display name, and submitted content may be stored with our service providers to operate the community and review reports.\n\n'
              'You can read the Privacy Policy from Support → Privacy Policy in the app.',
              style: TextStyle(height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Agree and continue'),
          ),
        ],
      ),
    );

    if (accepted != true) return false;
    await prefs.setString(_termsVersionKey, termsVersion);
    await prefs.setString(
      _termsAcceptedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    return true;
  }

  static String normalizeHandle(String handle) => handle.trim().toLowerCase();

  static Future<String> currentReporterHandle() async {
    final prefs = await SharedPreferences.getInstance();
    final creatorHandle = prefs.getString('logged_in_creator_handle')?.trim();
    if (creatorHandle != null && creatorHandle.isNotEmpty) return creatorHandle;
    final userId = prefs.getString('user_id')?.trim();
    if (userId != null && userId.isNotEmpty) return userId;
    return 'usr_guest';
  }

  static Future<Set<String>> loadBlockedHandles() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_blockedHandlesKey) ?? const <String>[])
        .map(normalizeHandle)
        .where((handle) => handle.isNotEmpty)
        .toSet();
  }

  static Future<void> blockUser(String handle) async {
    final normalized = normalizeHandle(handle);
    if (normalized.isEmpty || normalized == 'user') return;

    final prefs = await SharedPreferences.getInstance();
    final blocked = await loadBlockedHandles();
    blocked.add(normalized);
    await prefs.setStringList(_blockedHandlesKey, blocked.toList()..sort());
  }

  static Future<void> unblockUser(String handle) async {
    final normalized = normalizeHandle(handle);
    final prefs = await SharedPreferences.getInstance();
    final blocked = await loadBlockedHandles();
    blocked.remove(normalized);
    await prefs.setStringList(_blockedHandlesKey, blocked.toList()..sort());
  }

  /// Local blocks apply consistently across the feed and comment threads on
  /// this device. The callback lets the visible screen refresh immediately.
  static Future<void> showBlockedUsersDialog(
    BuildContext context, {
    ValueChanged<Set<String>>? onChanged,
  }) async {
    final blocked = await loadBlockedHandles();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final handles = blocked.toList()..sort();
          return AlertDialog(
            title: const Text('Blocked users'),
            content: SizedBox(
              width: 360,
              child: handles.isEmpty
                  ? const Text('You have not blocked anyone on this device.')
                  : SizedBox(
                      height: 300,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: handles.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final handle = handles[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(handle),
                            trailing: IconButton(
                              tooltip: 'Unblock $handle',
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              onPressed: () async {
                                await unblockUser(handle);
                                blocked.remove(handle);
                                if (!dialogContext.mounted) return;
                                setDialogState(() {});
                                onChanged?.call(Set<String>.unmodifiable(blocked));
                              },
                            ),
                          );
                        },
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<String?> chooseReportReason(BuildContext context) async {
    var selectedReason = reportReasons.first;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Report content or user'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedReason,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: reportReasons
                .map((reason) => DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) setDialogState(() => selectedReason = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selectedReason),
              child: const Text('Send report'),
            ),
          ],
        ),
      ),
    );
  }

  /// Queue a report without returning report data to the client. The
  /// moderation migration intentionally grants clients INSERT only.
  static Future<void> queueModerationReport({
    required String reporterHandle,
    required String targetType,
    required String targetId,
    required String reason,
    String? targetHandle,
    int? postId,
    String? source,
    String? contentExcerpt,
  }) async {
    final safeTargetId = targetId.trim();
    if (safeTargetId.isEmpty) throw ArgumentError('A report target is required.');

    final row = <String, dynamic>{
      'reported_by': reporterHandle.trim().isEmpty ? 'usr_guest' : reporterHandle.trim(),
      'target_type': targetType,
      'target_id': safeTargetId.length > 200 ? safeTargetId.substring(0, 200) : safeTargetId,
      'reason': reason.trim().isEmpty ? 'Other safety concern' : reason.trim(),
      if (targetHandle != null && targetHandle.trim().isNotEmpty)
        'target_handle': targetHandle.trim(),
      if (postId != null) 'post_id': postId,
      if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
      if (contentExcerpt != null && contentExcerpt.trim().isNotEmpty)
        'content_excerpt': contentExcerpt.trim().length > 600
            ? contentExcerpt.trim().substring(0, 600)
            : contentExcerpt.trim(),
    };

    await Supabase.instance.client
        .from('content_moderation_reports')
        .insert(row);
  }

  static Future<bool> promptAndQueueModerationReport(
    BuildContext context, {
    required String reporterHandle,
    required String targetType,
    required String targetId,
    required String successMessage,
    String? targetHandle,
    int? postId,
    String? source,
    String? contentExcerpt,
  }) async {
    final reason = await chooseReportReason(context);
    if (reason == null || !context.mounted) return false;

    try {
      await queueModerationReport(
        reporterHandle: reporterHandle,
        targetType: targetType,
        targetId: targetId,
        reason: reason,
        targetHandle: targetHandle,
        postId: postId,
        source: source,
        contentExcerpt: contentExcerpt,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report could not be sent. Please try again later.'),
          ),
        );
      }
      return false;
    }
  }

  static Future<bool> reportQuestionError({
    required String fileName,
    required int questionIndex,
    required String issueType,
    required String questionSnippet,
  }) async {
    try {
      final reporter = await currentReporterHandle();
      await queueModerationReport(
        reporterHandle: reporter,
        targetType: 'question_error',
        targetId: '$fileName:${questionIndex + 1}',
        reason: issueType,
        source: 'question_report',
        contentExcerpt: questionSnippet,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
