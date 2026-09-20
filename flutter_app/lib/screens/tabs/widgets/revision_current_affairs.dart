import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../models/question_model.dart';
import '../../revision_practice_screen.dart';

class MonthAffairConfig {
  final String label;
  final String fileName;

  const MonthAffairConfig({required this.label, required this.fileName});
}

class RevisionCurrentAffairsCard extends StatefulWidget {
  final bool isDark;

  const RevisionCurrentAffairsCard({super.key, required this.isDark});

  @override
  State<RevisionCurrentAffairsCard> createState() =>
      _RevisionCurrentAffairsCardState();
}

class _RevisionCurrentAffairsCardState extends State<RevisionCurrentAffairsCard> {
  // Python script ke generated files ke anusaar months
  final List<MonthAffairConfig> _months = const [
    MonthAffairConfig(label: "September 2026", fileName: "september_2026.json"),
    MonthAffairConfig(label: "August 2026", fileName: "august_2026.json"),
    MonthAffairConfig(label: "July 2026", fileName: "july_2026.json"),
    MonthAffairConfig(label: "June 2026", fileName: "june_2026.json"),
  ];

  late MonthAffairConfig _selectedMonth;
  bool _isLoadingCounts = true;
  int _nationalCount = 0;
  int _biharCount = 0;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _months.first;
    _fetchMonthCounts(_selectedMonth);
  }

  // Real-time Counts: Python metadata (national_total, bihar_total) ko direct read karta hai
  Future<void> _fetchMonthCounts(MonthAffairConfig month) async {
    setState(() {
      _isLoadingCounts = true;
      _nationalCount = 0;
      _biharCount = 0;
    });

    try {
      final String url =
          'https://raw.githubusercontent.com/zxcty54/content_base/main/current_affair/${month.fileName}?t=${DateTime.now().millisecondsSinceEpoch}';

      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && mounted) {
        String body = utf8.decode(res.bodyBytes).trim();
        if (body.startsWith('\uFEFF')) body = body.substring(1).trim();

        final Map<String, dynamic> data = jsonDecode(body);

        setState(() {
          // Metadata counts pehle check karein, fallback me list length
          _nationalCount = data['national_total'] ??
              (data['national_questions'] as List?)?.length ??
              0;
          _biharCount = data['bihar_total'] ??
              (data['bihar_questions'] as List?)?.length ??
              0;
          _isLoadingCounts = false;
        });
        return;
      }
    } catch (e) {
      debugPrint("Error loading counts for ${month.fileName}: $e");
    }

    if (mounted) {
      setState(() {
        _isLoadingCounts = false;
      });
    }
  }

  Future<void> _openCurrentAffairsSection(
    BuildContext context, {
    required bool isBihar,
    required String title,
    required String jsonPath,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2.5),
                SizedBox(width: 16),
                Text('Current Affairs लोड हो रहा है...',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final String fetchUrl = jsonPath.startsWith('http')
          ? '$jsonPath?t=${DateTime.now().millisecondsSinceEpoch}'
          : 'https://raw.githubusercontent.com/zxcty54/content_base/main/$jsonPath?t=${DateTime.now().millisecondsSinceEpoch}';

      final res = await http.get(Uri.parse(fetchUrl)).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200 && context.mounted) {
        String body = utf8.decode(res.bodyBytes).trim();
        if (body.startsWith('\uFEFF')) body = body.substring(1).trim();

        final Map<String, dynamic> data = jsonDecode(body);
        final List<dynamic> rawList = isBihar
            ? (data['bihar_questions'] ?? [])
            : (data['national_questions'] ?? []);

        final List<Question> qs = rawList
            .map<Question>(
                (item) => Question.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        Navigator.pop(context);

        if (qs.isNotEmpty) {
          final String monthClean =
              _selectedMonth.fileName.replaceAll('.json', '');
          final String dynamicStorageKey =
              isBihar ? "ca_bihar_$monthClean" : "ca_national_$monthClean";

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => RevisionPracticeScreen(
                testTitle: title,
                questions: qs,
                storageKey: dynamicStorageKey,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('⚠️ इस महीने में कोई प्रश्न नहीं मिला!')));
        }
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('⚠️ लोड करने में त्रुटि: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandPurple = Color(0xFF7C3AED);
    final isDark = widget.isDark;
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color itemBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color itemBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Card(
      color: cardBg,
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? brandPurple.withValues(alpha: 0.4) : brandPurple.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: brandPurple,
        collapsedIconColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        leading: const Text('📰', style: TextStyle(fontSize: 22)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Current Affairs Vault',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15, color: brandPurple)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                  ),
                  child: const Text('2026 EDITION',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A))),
                )
              ],
            ),
            const SizedBox(height: 2),
            Text('Monthly curated MCQs with trap logic & fact breakdown',
                style: TextStyle(
                    fontSize: 11, color: subTextColor, fontWeight: FontWeight.w500)),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          const Divider(height: 16),

          // 🗓️ Month Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Month:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: itemBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: itemBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<MonthAffairConfig>(
                    value: _selectedMonth,
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: _months.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(m.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedMonth) {
                        setState(() => _selectedMonth = val);
                        _fetchMonthCounts(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 🌐 National & Global Row
          _buildRow(
            context,
            icon: '🌐',
            title: 'National & Global Affairs',
            subtitle: 'Awards, Sports, Govt Schemes, Summits',
            count: _isLoadingCounts ? '...' : '$_nationalCount Qs',
            color: const Color(0xFF2563EB),
            itemBg: itemBg,
            itemBorder: itemBorder,
            textColor: textColor,
            subTextColor: subTextColor,
            onTap: () {
              _openCurrentAffairsSection(
                context,
                isBihar: false,
                title: "🌐 National & Global (${_selectedMonth.label})",
                jsonPath: "current_affair/${_selectedMonth.fileName}",
              );
            },
          ),
          const SizedBox(height: 8),

          // 📍 Bihar Special Row
          _buildRow(
            context,
            icon: '📍',
            title: 'Bihar Special Current Affairs',
            subtitle: 'BPSC, Bihar Budget, Schemes & State News',
            count: _isLoadingCounts ? '...' : '$_biharCount Qs',
            color: const Color(0xFF059669),
            itemBg: itemBg,
            itemBorder: itemBorder,
            textColor: textColor,
            subTextColor: subTextColor,
            onTap: () {
              _openCurrentAffairsSection(
                context,
                isBihar: true,
                title: "🇮🇳 Bihar Special (${_selectedMonth.label})",
                jsonPath: "current_affair/${_selectedMonth.fileName}",
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required String count,
    required Color color,
    required Color itemBg,
    required Color itemBorder,
    required Color textColor,
    required Color subTextColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: itemBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: itemBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: subTextColor)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                count,
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
