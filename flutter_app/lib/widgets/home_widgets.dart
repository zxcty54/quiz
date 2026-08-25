import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart'; // 👈 Added for attaching File/Image
import '../services/telegram_tracker.dart';

// 1️⃣ TODAY UPDATE TICKER WIDGET
class TodayUpdateTickerWidget extends StatelessWidget {
  final Map<String, dynamic> updateData;
  final Function(String title, String url) onTapUrl;

  const TodayUpdateTickerWidget({
    super.key,
    required this.updateData,
    required this.onTapUrl,
  });

  @override
  Widget build(BuildContext context) {
    final String title = updateData['title'] ?? "🔥 Daily Bulletin Update";
    final String url = updateData['url'] ?? "https://www.mocktester.online";

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF78350F)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => onTapUrl("Today Update", url),
            child: const Text('Read Now 🚀', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// 2️⃣ PREMIUM HERO HEADER WIDGET
class HeroHeaderWidget extends StatelessWidget {
  final Map<String, dynamic> featuredData;

  const HeroHeaderWidget({super.key, required this.featuredData});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔥', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text('MASTER CBT PATTERN MOCKS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  featuredData['title'] ?? 'BPSC & BSSC Inter Level Live Mocks',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, height: 1.2),
                ),
                const SizedBox(height: 6),
                Text(
                  featuredData['subtitle'] ?? 'Real TCS Simulation • High Yield Qs • Detailed Solution',
                  style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildValueBadge('🎯', 'REAL CBT\nINTERFACE'),
                const SizedBox(height: 10),
                _buildValueBadge('📋', 'TOP PYQ\nCOLLECTION'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueBadge(String emoji, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 9, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

// 3️⃣ ALAG-ALAG DISTINCT 3-BOX WEB HUB CARD WIDGET
class WebHubCardWidget extends StatelessWidget {
  final List<dynamic> webHubSections;
  final Function(String title, String url) onTapUrl;

  const WebHubCardWidget({
    super.key,
    required this.webHubSections,
    required this.onTapUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (webHubSections.isEmpty) {
      return Card(
        color: const Color(0xFFFEF2F2),
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text('⚠️', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Notice: 'web_hub' data missing or empty in assets/data/home_data.json",
                  style: TextStyle(
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: webHubSections.map((rawSection) {
        final Map<String, dynamic> section = Map<String, dynamic>.from(rawSection as Map);

        final String title = section['title'] ?? '📚 Category';
        final String buttonText = section['button_text'] ?? 'View All →';
        final String buttonUrl = section['button_url'] ?? 'https://www.mocktester.online';
        
        Color themeColor = const Color(0xFF2563EB);
        try {
          if (section['color'] != null) {
            themeColor = Color(int.parse(section['color'].toString()));
          }
        } catch (_) {}

        final List<dynamic> items = section['items'] ?? [];

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: themeColor.withOpacity(0.35), width: 1.3),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: themeColor.withOpacity(0.2), height: 1),
                const SizedBox(height: 10),

                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.toString(),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => onTapUrl(title, buttonUrl),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: themeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        buttonText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// 4️⃣ PREMIUM HIGH-CONVERTING JOB ELIGIBILITY CHECKER BANNER
class EligibilityCheckerWidget extends StatelessWidget {
  final bool isDarkMode;
  final Function(String title, String url) onTapUrl;

  const EligibilityCheckerWidget({
    super.key,
    required this.isDarkMode,
    required this.onTapUrl,
  });

  @override
  Widget build(BuildContext context) {
    const String eligibilityToolUrl = "https://www.mocktester.online/p/bihar-job-eligibility-checker.html";

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF3B82F6).withOpacity(0.4) : const Color(0xFF60A5FA),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(isDarkMode ? 0.2 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Tag + Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🎯', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sarkari Eligibility Radar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: isDarkMode ? Colors.white : const Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '100% FREE TOOL',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Callout Text
          Text(
            'Kaun-kaun si Sarkari Naukri aap bhar sakte hain?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bas apni Date of Birth (DOB) aur Stream (10th/12th/Graduation) chuniye — Smart tool turant bata dega aapki eligible posts!',
            style: TextStyle(
              fontSize: 11.5,
              color: isDarkMode ? Colors.white70 : const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          // Visual 3-Step Action Flow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF0F172A).withOpacity(0.6) : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.white12 : const Color(0xFFBFDBFE),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStepBadge('1', '📅 DOB', isDarkMode),
                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey),
                _buildStepBadge('2', '🎓 Stream', isDarkMode),
                const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey),
                _buildStepBadge('3', '📋 All Posts', isDarkMode, isHighlight: true),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Badges Supported Exams
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildSmallBadge("✔ BPSC & BSSC", isDarkMode),
              _buildSmallBadge("✔ Bihar Police / SI", isDarkMode),
              _buildSmallBadge("✔ Railway & SSC", isDarkMode),
            ],
          ),
          const SizedBox(height: 14),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
              ),
              onPressed: () => onTapUrl("Job Eligibility Checker", eligibilityToolUrl),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Check My Eligibility Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBadge(String num, String label, bool isDark, {bool isHighlight = false}) {
    return Row(
      children: [
        Container(
          width: 17,
          height: 17,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isHighlight ? const Color(0xFF10B981) : const Color(0xFF2563EB),
            shape: BoxShape.circle,
          ),
          child: Text(
            num,
            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isHighlight
                ? const Color(0xFF10B981)
                : (isDark ? Colors.white : const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
        ),
      ),
    );
  }
}

// 5️⃣ TELEGRAM CREATOR FORM WIDGET (WITH DIRECT FILE PICKER ATTACH)
class TelegramCreatorWidget extends StatefulWidget {
  const TelegramCreatorWidget({super.key});

  @override
  State<TelegramCreatorWidget> createState() => _TelegramCreatorWidgetState();
}

class _TelegramCreatorWidgetState extends State<TelegramCreatorWidget> {
  bool _isExpanded = false;
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();
  File? _attachedFile;

  // 📂 Direct File Attachment Picker
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _attachedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ File select error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🤝 Bano MockTester Ke Creator!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Apna Name/Subject daal kar Question Photo attach karein!', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                icon: Text(_isExpanded ? '✕' : '📸', style: const TextStyle(fontSize: 12)),
                label: Text(_isExpanded ? 'Close Form' : 'Bhejein Apna Question', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 10),
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Aapka Naam', isDense: true)),
              const SizedBox(height: 8),
              TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Exam / Subject', isDense: true)),
              const SizedBox(height: 10),

              // 📎 Attach File Option Inside Form
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file_rounded, size: 16, color: Color(0xFF10B981)),
                    label: const Text('Attach Photo/PDF', style: TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_attachedFile != null)
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _attachedFile!.path.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _attachedFile = null),
                            child: const Icon(Icons.close, size: 16, color: Colors.red),
                          )
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF24A1DE), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (_nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Naam bharna zaroori hai!')));
                      return;
                    }
                    TelegramTracker.logActivity("Creator Form Submitted - Name: ${_nameController.text}");

                    String fileNameText = _attachedFile != null ? "\n📎 Attached: ${_attachedFile!.path.split('/').last}" : "";
                    final msg = "Bhai, main apna question submit kar raha hu.\n👤 Name: ${_nameController.text}\n📚 Subject: ${_subjectController.text}$fileNameText";
                    final uri = Uri.parse("https://t.me/MT_Masterhub_bot?text=${Uri.encodeComponent(msg)}");
                    
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Text('🚀'),
                  label: const Text('Open Telegram & Send', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
