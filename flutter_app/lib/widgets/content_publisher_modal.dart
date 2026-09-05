import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_telegram_alert.dart'; // 👈 Yahan adjust ho gaya

class ContentPublisherModal {
  static void openPublishSheet({
    required BuildContext context,
    required String type,
    required String creatorHandle,
    required String? coachingName,
    required String? profileName,
    required bool isDarkMode,
    required VoidCallback onPublished,
  }) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    final opCtrl1 = TextEditingController();
    final opCtrl2 = TextEditingController();
    final opCtrl3 = TextEditingController();
    final opCtrl4 = TextEditingController();
    final expCtrl = TextEditingController();
    int correctIdx = 0;

    bool isSubmitting = false;

    String sheetTitle = '📢 Share Notice & Update';
    String tag = 'Announcement 📢';
    if (type == 'pdf') {
      sheetTitle = '📚 Share PDF Notes & Handouts';
      tag = 'Study Material 📚';
    } else if (type == 'quiz') {
      sheetTitle = '🎯 Publish Daily Rapid Quiz';
      tag = 'Daily Quiz ⚡';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sheetTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 10),

                if (type == 'pdf') ...[
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'PDF Title / Chapter Name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: linkCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Google Drive / Telegram PDF Link',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.link_rounded, color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                TextField(
                  controller: contentCtrl,
                  maxLines: type == 'quiz' ? 2 : 4,
                  decoration: InputDecoration(
                    labelText: type == 'quiz' ? 'Question Statement' : 'Description / Message',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                if (type == 'quiz') ...[
                  const Text('Options & Correct Answer (Tap letter to set correct):',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  ...List.generate(4, (idx) {
                    final controllers = [opCtrl1, opCtrl2, opCtrl3, opCtrl4];
                    final isCorrect = correctIdx == idx;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setModalState(() => correctIdx = idx),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: isCorrect ? const Color(0xFF16A34A) : Colors.grey.withOpacity(0.3),
                              child: Text(
                                String.fromCharCode(65 + idx),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isCorrect ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controllers[idx],
                              decoration: InputDecoration(
                                hintText: 'Option ${String.fromCharCode(65 + idx)}',
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  TextField(
                    controller: expCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Explanation (Optional)', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final rawContent = contentCtrl.text.trim();
                            if (rawContent.isEmpty) return;

                            setModalState(() => isSubmitting = true);

                            String finalContent = rawContent;
                            if (type == 'pdf') {
                              final pTitle = titleCtrl.text.trim();
                              final pLink = linkCtrl.text.trim();
                              finalContent =
                                  '${pTitle.isNotEmpty ? "📑 **$pTitle**\n\n" : ""}$rawContent${pLink.isNotEmpty ? "\n\n🔗 Download Link: $pLink" : ""}';
                            }

                            Map<String, dynamic>? pollJson;
                            if (type == 'quiz') {
                              final rawOptions = [
                                opCtrl1.text.trim(),
                                opCtrl2.text.trim(),
                                opCtrl3.text.trim(),
                                opCtrl4.text.trim()
                              ].where((o) => o.isNotEmpty).toList();
                              if (rawOptions.length >= 2) {
                                pollJson = {
                                  'options': rawOptions,
                                  'correct_idx': correctIdx < rawOptions.length ? correctIdx : 0,
                                  'votes': List.filled(rawOptions.length, 0),
                                  'exp': expCtrl.text.trim().isNotEmpty
                                      ? expCtrl.text.trim()
                                      : 'Provided by @$creatorHandle',
                                };
                              }
                            }

                            try {
                              final authorName = coachingName ?? profileName ?? creatorHandle;

                              final inserted = await Supabase.instance.client
                                  .from('community_posts')
                                  .insert({
                                'creator_id': creatorHandle,
                                'author_name': authorName,
                                'content': finalContent,
                                'tag': tag,
                                'poll_data': pollJson,
                                'views_count': 1,
                                'is_approved': true,
                                'upvotes': 0,
                                'downvotes': 0,
                                'shares_count': 0,
                                'bookmarks_count': 0,
                              }).select().single();

                              AdminTelegramAlert.sendForInteractiveApproval(
                                postId: inserted['id'] ?? 0,
                                authorName: authorName,
                                authorHandle: creatorHandle,
                                tag: tag,
                                content: finalContent,
                                hasPoll: type == 'quiz',
                              ).catchError((_) => false);

                              if (ctx.mounted) Navigator.pop(ctx);
                              onPublished();
                            } catch (_) {
                              setModalState(() => isSubmitting = false);
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Publish to Community & Profile 🚀',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
