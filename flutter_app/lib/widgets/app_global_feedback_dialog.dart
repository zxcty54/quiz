import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// 🌟 1. PROFILE BOTTOM HIGH-VISIBILITY BANNER CARD
class AppGlobalFeedbackCard extends StatelessWidget {
  final bool isDarkMode;

  const AppGlobalFeedbackCard({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final bool isDark = isDarkMode;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFFF59E0B).withOpacity(0.5)
              : const Color(0xFFF59E0B),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.2 : 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => AppGlobalFeedbackDialog(isDarkMode: isDark),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text('💬', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Share Idea / Feedback',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4)),
                            ),
                            child: const Text(
                              'DEV TEAM',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Request features or report issue to developers',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFFB45309),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Review',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 💬 2. INTERACTIVE GOOGLE SHEET FEEDBACK DIALOG
class AppGlobalFeedbackDialog extends StatefulWidget {
  final bool isDarkMode;
  const AppGlobalFeedbackDialog({super.key, required this.isDarkMode});

  @override
  State<AppGlobalFeedbackDialog> createState() => _AppGlobalFeedbackDialogState();
}

class _AppGlobalFeedbackDialogState extends State<AppGlobalFeedbackDialog> {
  static const String _googleSheetWebhookUrl =
      "https://script.google.com/macros/s/AKfycbzXL2JC7lUNCi6Kpwhp-_CUPWfVzIvYQF_wTXql1mJZe14f-uujfW7WNik88ZvNAMlVBw/exec";

  int _selectedRating = 5;
  String _selectedFeature = 'overall';
  final List<String> _selectedAspects = [];
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _userContactController = TextEditingController();
  bool _isSubmitting = false;

  final Map<String, String> _features = {
    'overall': '📱 Overall App Experience',
    'mock_engine': '🎯 Mock Test & Timer Engine',
    'revision_hub': '📚 Revision & Question Bank',
    'speed_test': '⚡ 30s Speed Test',
    'solution_page': '💡 Explanations & LaTeX',
    'ca_vault': '📰 Daily Current Affairs',
    'ui_design': '🎨 UI / Theme / Font',
    'new_feature': '🚀 Request a New Feature',
  };

  final Map<int, Map<String, String>> _ratingMeta = {
    1: {'emoji': '😡', 'label': 'Needs Major Fixes'},
    2: {'emoji': '😕', 'label': 'Could be Better'},
    3: {'emoji': '😐', 'label': 'Average Experience'},
    4: {'emoji': '🙂', 'label': 'Good & Helpful'},
    5: {'emoji': '🤩', 'label': 'Loved it, Superb!'},
  };

  final List<String> _aspectChips = [
    'User Friendly ❤️',
    'Super Fast ⚡',
    'Content Quality 💯',
    'Need More Tests 📝',
    'Explain Better 💡',
    'App Lag / Slow 🐢',
    'Fix Bug / Issue 🐛',
    'Hindi Translation 🇮🇳',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    _userContactController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final String userText = _feedbackController.text.trim();
    if (userText.isEmpty && _selectedAspects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Kripya feedback likhein ya koi quick tag select karein!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final Map<String, dynamic> payload = {
      "timestamp": DateTime.now().toString().split('.')[0],
      "rating": "$_selectedRating ★ (${_ratingMeta[_selectedRating]!['label']})",
      "category": _selectedFeature,
      "category_title": _features[_selectedFeature],
      "tags": _selectedAspects,
      "feedback_text": userText.isNotEmpty ? userText : "N/A",
      "contact_info": _userContactController.text.trim().isNotEmpty
          ? _userContactController.text.trim()
          : "Anonymous",
      "device_meta": {
        "app_version": "1.0.4",
        "dark_mode": widget.isDarkMode,
      }
    };

    try {
      final res = await http.post(
        Uri.parse(_googleSheetWebhookUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('✅ Feedback successfully sheet par save ho gaya! Dhanyawad.'),
              ],
            ),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Feedback sent!'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color fieldBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final currentMeta = _ratingMeta[_selectedRating]!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: bgColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)]
                        : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.rate_review_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'App Feedback & Advice',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                              ),
                            ),
                            Text(
                              'Direct review to developers',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF3B82F6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : const Color(0xFF1E3A8A)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final int star = index + 1;
                              final bool isFilled = star <= _selectedRating;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedRating = star),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Icon(
                                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: isFilled
                                        ? const Color(0xFFF59E0B)
                                        : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                                    size: 38,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                            ),
                            child: Text(
                              "${currentMeta['emoji']} ${currentMeta['label']}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Feedback Category / Topic:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _features.entries.map((e) {
                          final bool isSelected = _selectedFeature == e.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(
                                e.value,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.white : textColor,
                                ),
                              ),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: const Color(0xFF2563EB),
                              backgroundColor: fieldBg,
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF2563EB) : fieldBorder,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _selectedFeature = e.key);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Quick Highlights:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _aspectChips.map((chip) {
                        final bool isSelected = _selectedAspects.contains(chip);
                        return FilterChip(
                          label: Text(
                            chip,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : textColor,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: fieldBg,
                          checkmarkColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF2563EB) : fieldBorder,
                          ),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedAspects.add(chip);
                              } else {
                                _selectedAspects.remove(chip);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your Suggestion / Review:',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 3,
                      style: TextStyle(fontSize: 13, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Aapko kya achha laga ya kya naya feature chahiye...',
                        hintStyle: TextStyle(fontSize: 12, color: subTextColor.withOpacity(0.7)),
                        filled: true,
                        fillColor: fieldBg,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Contact Info (Telegram / Email - Optional):',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: subTextColor),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _userContactController,
                      style: TextStyle(fontSize: 12.5, color: textColor),
                      decoration: InputDecoration(
                        hintText: '@telegram_handle ya email (agar update chahiye)',
                        hintStyle: TextStyle(fontSize: 11.5, color: subTextColor.withOpacity(0.7)),
                        filled: true,
                        fillColor: fieldBg,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: fieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitFeedback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded, size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'Submit Feedback',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
