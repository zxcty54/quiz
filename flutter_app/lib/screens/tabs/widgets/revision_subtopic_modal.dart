import 'package:flutter/material.dart';

class RevisionSubTopicModal {
  static void show({
    required BuildContext context,
    required String chapterTitle,
    required Map<String, dynamic> subTypes,
    required bool isDark,
    required Color themeColor,
    required Function(BuildContext, String, String) onLaunchPractice,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.folder_open_rounded, color: themeColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chapterTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Select topic / type to practice',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
                const Divider(height: 24),
                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: subTypes.entries.map((entry) {
                    return ActionChip(
                      elevation: 1,
                      backgroundColor: isDark ? themeColor.withOpacity(0.2) : const Color(0xFFEEF2FF),
                      side: BorderSide(color: themeColor.withOpacity(0.4)),
                      label: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : themeColor,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onLaunchPractice(
                          context,
                          "$chapterTitle: ${entry.key}",
                          entry.value.toString(),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
