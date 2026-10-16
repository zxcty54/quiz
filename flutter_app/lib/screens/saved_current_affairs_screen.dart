import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SavedCurrentAffairsScreen extends StatefulWidget {
  final bool isDarkMode;
  const SavedCurrentAffairsScreen({super.key, this.isDarkMode = false});

  @override
  State<SavedCurrentAffairsScreen> createState() => _SavedCurrentAffairsScreenState();
}

class _SavedCurrentAffairsScreenState extends State<SavedCurrentAffairsScreen> {
  List<dynamic> _savedNewsList = [];
  bool _isLoading = true;
  bool _isHindi = true;
  bool _isGeneratingPdf = false;

  // Filter selection: 'ALL', 'BIHAR', 'NATIONAL'
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('saved_daily_bulletins');
    if (savedJson != null) {
      try {
        if (mounted) {
          setState(() {
            _savedNewsList = jsonDecode(savedJson);
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint("Error loading saved news: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🗑️ CLEAR ALL SAVED CURRENT AFFAIRS
  Future<void> _clearAllSavedNews() async {
    if (_savedNewsList.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_daily_bulletins');
    setState(() {
      _savedNewsList.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cleared all Saved Current Affairs!")),
      );
    }
  }

  // 🗑️ DELETE SINGLE CA ITEM
  Future<void> _removeSavedNews(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedNewsList.removeAt(index);
    });
    await prefs.setString('saved_daily_bulletins', jsonEncode(_savedNewsList));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Removed from Saved Current Affairs"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // 📄 EXPORT TO BRANDED PDF (mocktester.online On Every Page)
  Future<void> _downloadBrandedPdf(List<dynamic> newsToExport) async {
    if (newsToExport.isEmpty) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final doc = pw.Document();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          // 🏷️ 1. TOP HEADER ON EVERY PAGE
          header: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue700, width: 1.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'MockTester • Saved Current Affairs Magazine',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                  pw.Text(
                    '🌐 mocktester.online',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                  ),
                ],
              ),
            );
          },
          // 📌 2. FOOTER WITH PAGE NUMBER ON EVERY PAGE
          footer: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 10),
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'For BPSC, BSSC & State Exams • www.mocktester.online',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                ],
              ),
            );
          },
          // 📋 3. NEWS CONTENT
          build: (pw.Context context) {
            return [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                margin: const pw.EdgeInsets.only(bottom: 14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '📌 SAVED CURRENT AFFAIRS DIGEST',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Total Items: ${newsToExport.length} • Powered by MockTester (mocktester.online)',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue800),
                    ),
                  ],
                ),
              ),
              ...newsToExport.map((news) {
                final String title = news['title'] ?? 'Current Affairs Update';
                final String tag = news['exam_tag'] ?? 'General Update';
                final List bullets = (news['bullets'] as List?) ?? [];

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.amber100,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          tag,
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        title,
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 6),
                      ...bullets.map((b) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 3),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                                pw.Expanded(
                                  child: pw.Text(
                                    b.toString(),
                                    style: const pw.TextStyle(fontSize: 9.5, height: 1.25, color: PdfColors.grey900),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      );

      // Open System Print / Download / Share Sheet
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'MockTester_Saved_CA_Digest.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ PDF generation failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // 📍 BIHAR vs NATIONAL DETECTOR
  bool _isBiharNews(Map<String, dynamic> item) {
    final String tag = (item['exam_tag'] ?? '').toString().toLowerCase();
    final String title = (item['title'] ?? '').toString().toLowerCase();
    final String cat = (item['category'] ?? '').toString().toLowerCase();

    return tag.contains('bihar') ||
        tag.contains('bpsc') ||
        tag.contains('bssc') ||
        title.contains('bihar') ||
        title.contains('patna') ||
        cat.contains('bihar');
  }

  @override
  Widget build(BuildContext context) {
    // Profile se mode mile to wo, warna app ke theme se pehchano
    final bool isDark = widget.isDarkMode || Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
          title: Text('Saved Current Affairs Vault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    if (_savedNewsList.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
          title: Text('📌 Saved Current Affairs Vault', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📌', style: TextStyle(fontSize: 50)),
              const SizedBox(height: 10),
              Text('Vault Empty!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text('Home Tab se daily bulletins ko bookmark karke yahan revise karein.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final filteredList = _savedNewsList.where((item) {
      bool isBihar = _isBiharNews(item);
      if (_selectedFilter == 'BIHAR') return isBihar;
      if (_selectedFilter == 'NATIONAL') return !isBihar;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text('📌 Saved CA (${_savedNewsList.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        actions: [
          // 📄 DOWNLOAD BRANDED PDF BUTTON
          IconButton(
            icon: _isGeneratingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)))
                : const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2563EB)),
            tooltip: "Download PDF",
            onPressed: _isGeneratingPdf ? null : () => _downloadBrandedPdf(filteredList),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: "Clear All",
            onPressed: _clearAllSavedNews,
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2563EB)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isHindi ? 'हिंदी' : 'ENG',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ),
            onPressed: () => setState(() => _isHindi = !_isHindi),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🏷️ 1. FILTER CHIPS
          Row(
            children: [
              _filterChip('ALL', 'All (${_savedNewsList.length})', isDark),
              const SizedBox(width: 8),
              _filterChip('BIHAR', '📍 Bihar CA', isDark),
              const SizedBox(width: 8),
              _filterChip('NATIONAL', '🇮🇳 National CA', isDark),
            ],
          ),
          const SizedBox(height: 14),

          // 📋 2. BULLETIN CARDS LIST
          ...List.generate(filteredList.length, (index) {
            final news = filteredList[index];
            final List bullets = (news['bullets'] as List?) ?? [];
            bool isBihar = _isBiharNews(news);

            return Card(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isBihar
                                ? (isDark ? const Color(0xFFF59E0B).withOpacity(0.18) : const Color(0xFFFEF3C7))
                                : (isDark ? const Color(0xFF2563EB).withOpacity(0.22) : const Color(0xFFE0E7FF)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            news['exam_tag'] ?? (isBihar ? '📍 Bihar CA' : '🇮🇳 National CA'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isBihar
                                  ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E))
                                  : (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF3730A3)),
                            ),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                          onPressed: () => _removeSavedNews(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      news['title'] ?? '',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87, height: 1.3),
                    ),
                    const SizedBox(height: 8),

                    ...bullets.map((bullet) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.arrow_right_rounded, size: 16, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  bullet.toString(),
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.grey.shade800, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _filterChip(String filterKey, String label, bool isDark) {
    bool isSelected = _selectedFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF475569) : Colors.grey.shade300)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}
