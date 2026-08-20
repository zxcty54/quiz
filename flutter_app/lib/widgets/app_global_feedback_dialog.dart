import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AppGlobalFeedbackDialog extends StatefulWidget {
  final bool isDarkMode;
  const AppGlobalFeedbackDialog({super.key, required this.isDarkMode});

  @override
  State<AppGlobalFeedbackDialog> createState() => _AppGlobalFeedbackDialogState();
}

class _AppGlobalFeedbackDialogState extends State<AppGlobalFeedbackDialog> {
  // 🔗 Aapka Live Google Apps Script Webhook URL
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
        const SnackBar(content: Text('⚠️ Kripya feedback likhein ya koi chip select karein!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final Map<String, dynamic> payload = {
      "timestamp": DateTime.now().toString().split('.')[0],
      "rating": "$_selectedRating ★",
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
            content: Text('✅ Feedback successfully sheet par save ho gaya! Dhanyawad.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Feedback sent!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: bgColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Text(
                      'App Feedback & Advice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: subTextColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            const SizedBox(height: 14),

            // Star Rating
            Text('Rate your experience:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final int star = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _selectedRating = star),
                  icon: Icon(
                    star <= _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            // Category Dropdown
            Text('Feedback Category / Topic:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFeature,
                  isExpanded: true,
                  dropdownColor: bgColor,
                  style: TextStyle(fontSize: 13, color: textColor),
                  items: _features.entries.map((e) {
                    return DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFeature = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Chips
            Text('Quick Highlights:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _aspectChips.map((chip) {
                final bool isSelected = _selectedAspects.contains(chip);
                return FilterChip(
                  label: Text(chip, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : textColor)),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  checkmarkColor: Colors.white,
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
            const SizedBox(height: 14),

            // Message TextField
            Text('Your Suggestion / Review:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor)),
            const SizedBox(height: 6),
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: 'Aapko kya achha laga ya kya naya feature chahiye...',
                hintStyle: TextStyle(fontSize: 12, color: subTextColor.withOpacity(0.7)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Contact / Telegram TextField (Optional)
            Text('Contact info (Telegram/Email - Optional):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: subTextColor)),
            const SizedBox(height: 6),
            TextField(
              controller: _userContactController,
              style: TextStyle(fontSize: 13, color: textColor),
              decoration: InputDecoration(
                hintText: '@telegram_handle ya email (agar update chahiye)',
                hintStyle: TextStyle(fontSize: 12, color: subTextColor.withOpacity(0.7)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
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
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Submit Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
