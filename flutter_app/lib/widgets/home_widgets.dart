import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
                  featuredData['title'] ?? 'BPSC & BSSC Inter Level 2026 Live Mocks',
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

// 3️⃣ WEB HUB CARD WIDGET
class WebHubCardWidget extends StatelessWidget {
  final List<Map<String, dynamic>> webLinks;
  final Function(String title, String url) onTapUrl;

  const WebHubCardWidget({super.key, required this.webLinks, required this.onTapUrl});

  @override
  Widget build(BuildContext context) {
    if (webLinks.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📚 Free Study Notes & Web Articles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                  child: const Text('OPEN IN CHROME 🌐', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                )
              ],
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: webLinks.length,
              separatorBuilder: (ctx, i) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final item = webLinks[index];
                final Color themeColor = Color(int.parse(item['color'] ?? '0xFF2563EB'));
                return InkWell(
                  onTap: () => onTapUrl(item['title']!, item['url']!),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(item['icon'] ?? '📝', style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(item['desc'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: themeColor),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 4️⃣ JOB ELIGIBILITY CHECKER BANNER
class EligibilityCheckerWidget extends StatelessWidget {
  final bool isDarkMode;
  final Function(String title, String url) onTapUrl;

  const EligibilityCheckerWidget({super.key, required this.isDarkMode, required this.onTapUrl});

  @override
  Widget build(BuildContext context) {
    const String eligibilityToolUrl = "https://www.mocktester.online/p/bihar-job-eligibility-checker.html";

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: isDarkMode
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFFEFF6FF), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('🎯', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text('Job Eligibility Checker', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(20)),
                  child: const Text('ONLINE TOOL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Apni DOB, Stream aur Height daal kar check karein aap Bihar ki kis-kis Sarkari Naukri ke liye eligible hain!',
              style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.3),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                _buildSmallBadge("✔ BPSC / BSSC Posts"),
                _buildSmallBadge("✔ Police & Height Check"),
                _buildSmallBadge("✔ TRE Teacher Course"),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => onTapUrl("Job Eligibility Checker", eligibilityToolUrl),
                icon: const Text('🚀', style: TextStyle(fontSize: 12)),
                label: const Text('Check My Eligibility On Website', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
    );
  }
}

// 5️⃣ TELEGRAM CREATOR FORM WIDGET
class TelegramCreatorWidget extends StatefulWidget {
  const TelegramCreatorWidget({super.key});

  @override
  State<TelegramCreatorWidget> createState() => _TelegramCreatorWidgetState();
}

class _TelegramCreatorWidgetState extends State<TelegramCreatorWidget> {
  bool _isExpanded = false;
  final _nameController = TextEditingController();
  final _subjectController = TextEditingController();

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
            const Text('Apna Name/Subject daal kar Telegram par Question Photo bhejein!', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF24A1DE), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (_nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Naam bharna zaroori hai!')));
                      return;
                    }
                    TelegramTracker.sendActivityAlert(screenName: "Creator Form Submitted", extraDetails: "Name: ${_nameController.text}");
                    final msg = "Bhai, main apna question photo attach kar rha hu.\n👤 Name: ${_nameController.text}\n📚 Subject: ${_subjectController.text}";
                    final uri = Uri.parse("https://t.me/MT_Masterhub_bot?text=${Uri.encodeComponent(msg)}");
                    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Text('🚀'),
                  label: const Text('Open Telegram & Send Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
