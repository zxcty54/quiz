import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AppGlobalFeedbackDialog extends StatefulWidget {
  final bool isDarkMode;

  const AppGlobalFeedbackDialog({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<AppGlobalFeedbackDialog> createState() => _AppGlobalFeedbackDialogState();
}

class _AppGlobalFeedbackDialogState extends State<AppGlobalFeedbackDialog> {
  int _selectedRating = 5;
  String _selectedFeature = 'general';
  final List<String> _selectedAspects = [];
  final TextEditingController _feedbackController = TextEditingController();
  final TextEditingController _userContactController = TextEditingController();
  bool _isSubmitting = false;

  // 🔑 GitHub Repository & PAT Token Config
  static const String _repoOwner = "zxcty54";
  static const String _repoName = "quiz";
  static const String _filePath = "app_feedback.json";
  
  // ⚠️ Base64 encoded token taaki basic bot scrapers se bacha rahe
  // Replace with your fine-grained PAT (Contents: Read & Write)
  static const String _tokenBase64 = "Z2hwX1lPVVJfR0lUSFVCX1BBVF9UT0tFTl9IRVJF"; 
  String get _githubToken => utf8.decode(base64.decode(_tokenBase64));

  final Map<String, String> _features = {
    'general': '📱 Overall App Experience',
    'cbt_mock': '💻 Mock Test & CBT Engine',
    'revision_mode': '⚡ Revision & Practice Centre',
    'sarkari_jobs': '📢 Sarkari Job & Alerts',
    'current_affairs': '📰 Current Affairs & News',
    'ui_design': '🎨 UI / Theme / Dark Mode',
    'feature_request': '💡 Suggest New Feature / Idea',
    'performance': '🚀 App Speed / Bugs / Crashes',
  };

  final List<String> _quickAspects = [
    'User Friendly ❤️',
    'Super Fast ⚡',
    'Content Quality 💯',
    'Need More Tests 📚',
    'UI Needs Polish ✨',
    'Offline Mode Chahiye 📶',
    'Font Size Issue 🔤',
    'Great Explanations 💡',
  ];

  // 🚀 Direct Push to GitHub JSON File
  Future<void> _submitFeedbackToGitHub() async {
    final String userText = _feedbackController.text.trim();
    if (userText.isEmpty && _selectedAspects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Kripya feedback text ya koi tag select karein!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final int ts = DateTime.now().millisecondsSinceEpoch;

    // 1️⃣ Naya Structured Feedback Object
    final Map<String, dynamic> newEntry = {
      "feedback_id": "REV_$ts",
      "timestamp": DateTime.now().toIso8601String(),
      "rating": _selectedRating,
      "category": _selectedFeature,
      "category_title": _features[_selectedFeature],
      "tags": _selectedAspects,
      "feedback_text": userText.isNotEmpty ? userText : "N/A",
      "contact_info": _userContactController.text.trim().isNotEmpty
          ? _userContactController.text.trim()
          : "Anonymous",
      "device_meta": {
        "app_name": "MockTester Pro",
        "app_version": "1.0.4",
        "dark_mode": widget.isDarkMode,
      }
    };

    final Uri apiUrl = Uri.parse("https://api.github.com/repos/$_repoOwner/$_repoName/contents/$_filePath");

    try {
      // 2️⃣ Existing File aur SHA Fetch karein
      final getRes = await http.get(
        apiUrl,
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 5));

      String? fileSha;
      List<dynamic> feedbackList = [];

      if (getRes.statusCode == 200) {
        final Map<String, dynamic> fileData = jsonDecode(getRes.body);
        fileSha = fileData['sha'];
        String existingContent = utf8.decode(base64.decode((fileData['content'] as String).replaceAll('\n', '')));
        
        final decodedJson = jsonDecode(existingContent);
        if (decodedJson is List) {
          feedbackList = decodedJson;
        } else if (decodedJson is Map && decodedJson.containsKey('feedbacks')) {
          feedbackList = decodedJson['feedbacks'] as List;
        }
      }

      // 3️⃣ Naya feedback list ke top par add karein
      feedbackList.insert(0, newEntry);

      // 4️⃣ Format karke Base64 encode karein
      final String updatedJsonString = const JsonEncoder.withIndent('  ').convert({
        "total_feedbacks": feedbackList.length,
        "last_updated": DateTime.now().toIso8601String(),
        "feedbacks": feedbackList,
      });

      final String base64Content = base64.encode(utf8.encode(updatedJsonString));

      // 5️⃣ GitHub par Commit Push karein
      final putBody = {
        "message": "📝 User Review: [${_features[_selectedFeature]}] - $_selectedRating★ (ID: REV_$ts)",
        "content": base64Content,
        if (fileSha != null) "sha": fileSha,
      };

      final putRes = await http.put(
        apiUrl,
        headers: {
          'Authorization': 'token $_githubToken',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(putBody),
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (putRes.statusCode == 200 || putRes.statusCode == 201) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Feedback GitHub par successfully save ho gaya!'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('⚠️ GitHub push error: ${putRes.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Network timeout. Kripya punah prayas karein.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: bgColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.rate_review_rounded, size: 20, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'App Feedback & Advice',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Apna anubhav share karein ya kisi bhi feature par advice dein.',
                style: TextStyle(fontSize: 12, color: subTextColor),
              ),
              const Divider(height: 20),

              // ⭐ Rating
              Center(
                child: Column(
                  children: [
                    Text(
                      'Rate Overall Experience',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return IconButton(
                          iconSize: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          icon: Icon(
                            index < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                          onPressed: () => setState(() => _selectedRating = index + 1),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 📂 Feature Selection
              Text(
                'Feature Category',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: Border.all(color: cardBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFeature,
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor),
                    items: _features.entries.map((e) {
                      return DropdownMenuItem(value: e.key, child: Text(e.value));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedFeature = val ?? _selectedFeature),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 🏷️ Quick Aspects
              Text(
                'Quick Highlights',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickAspects.map((aspect) {
                  final isSelected = _selectedAspects.contains(aspect);
                  return FilterChip(
                    label: Text(
                      aspect,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    checkmarkColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : cardBorder),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedAspects.add(aspect);
                        } else {
                          _selectedAspects.remove(aspect);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // 💬 Review / Advice Field
              Text(
                'Your Review, Advice or Idea',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _feedbackController,
                maxLines: 3,
                style: TextStyle(fontSize: 12.5, color: textColor),
                decoration: InputDecoration(
                  hintText: 'App me kya pasand aaya ya kya naya hona chahiye? Detail me likhein...',
                  hintStyle: TextStyle(fontSize: 11.5, color: isDark ? Colors.white38 : Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 📱 Optional Contact
              TextField(
                controller: _userContactController,
                style: TextStyle(fontSize: 12, color: textColor),
                decoration: InputDecoration(
                  hintText: 'Email / Telegram handle (Optional)',
                  hintStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                  prefixIcon: const Icon(Icons.alternate_email_rounded, size: 16, color: Color(0xFF2563EB)),
                  isDense: true,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 🚀 Submit Action
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSubmitting ? null : _submitFeedbackToGitHub,
                  icon: _isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: Text(
                    _isSubmitting ? 'Saving to GitHub...' : 'Save Feedback (GitHub) 🚀',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
