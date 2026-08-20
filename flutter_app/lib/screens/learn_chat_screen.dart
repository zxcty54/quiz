import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/learn_models.dart';
import '../utils/learn_effects.dart';
import '../widgets/learn_chat_widgets.dart';

class LearnChatScreen extends StatefulWidget {
  final String? jsonUrl;
  final String? chapterTitle;

  const LearnChatScreen({super.key, this.jsonUrl, this.chapterTitle});

  @override
  State<LearnChatScreen> createState() => _LearnChatScreenState();
}

class _LearnChatScreenState extends State<LearnChatScreen> {
  LearnChapterData? chapterData;
  int currentCardIndex = 0;
  int visibleMessageCount = 1;
  bool isTyping = false;
  bool isLoading = true;
  String? errorMessage;

  final List<int> _cardHistory = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchChapterJson();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 🧹 100% CRASH-PROOF SANITIZER (Auto Fixes Invalid LaTeX & Backslashes)
  String _sanitizeJsonString(String raw) {
    String clean = raw.trim();

    // 1. Remove UTF-8 BOM Marker
    if (clean.startsWith('\uFEFF')) {
      clean = clean.substring(1).trim();
    }

    // 2. Remove Markdown backticks
    clean = clean.replaceAll('```json', '').replaceAll('```', '').trim();

    // 3. Extract exact JSON boundaries
    int firstBrace = clean.indexOf('{');
    int firstBracket = clean.indexOf('[');
    int startIndex = -1;

    if (firstBrace != -1 && firstBracket != -1) {
      startIndex = firstBrace < firstBracket ? firstBrace : firstBracket;
    } else if (firstBrace != -1) {
      startIndex = firstBrace;
    } else if (firstBracket != -1) {
      startIndex = firstBracket;
    }

    int lastBrace = clean.lastIndexOf('}');
    int lastBracket = clean.lastIndexOf(']');
    int endIndex = -1;

    if (lastBrace != -1 && lastBracket != -1) {
      endIndex = lastBrace > lastBracket ? lastBrace : lastBracket;
    } else if (lastBrace != -1) {
      endIndex = lastBrace;
    } else if (lastBracket != -1) {
      endIndex = lastBracket;
    }

    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      clean = clean.substring(startIndex, endIndex + 1);
    }

    // 4. Remove zero-width & invisible spaces
    clean = clean.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

    // 🛡️ 5. AUTO-FIX LATEX BACKSLASHES (\text, \approx, \frac to \\text, \\approx)
    clean = clean.replaceAllMapped(
      RegExp(r'(?<!\\)\\(?!["\\/bfnrtu])'),
      (match) => r'\\',
    );

    return clean.trim();
  }

  // 🌐 MULTI-CDN LIVE FETCHER (Direct GitHub Raw Included)
  Future<void> _fetchChapterJson() async {
    String rawPath = widget.jsonUrl ?? '';
    
    if (rawPath.isEmpty) {
      rawPath = 'learn/biology/cell.json';
    }

    String cleanPath = rawPath
        .replaceAll('https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/', '')
        .replaceAll('https://fastly.jsdelivr.net/gh/zxcty54/quiz@main/', '')
        .replaceAll('https://raw.githubusercontent.com/zxcty54/quiz/main/', '')
        .replaceAll('https://raw.githubusercontent.com/zxcty54/quiz/refs/heads/main/', '')
        .replaceAll('https://cdn.statically.io/gh/zxcty54/quiz/main/', '')
        .replaceAll('https://raw.githack.com/zxcty54/quiz/main/', '');
    
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
    if (cleanPath.contains('?')) cleanPath = cleanPath.split('?').first;

    final int ts = DateTime.now().millisecondsSinceEpoch;
    String encodedPath = Uri.encodeFull(cleanPath);

    // 🚀 Robust Multi-CDN Fallback Order
    List<String> mirrorUrls = [
      // 1. Direct Raw GitHub with Cache Buster (100% Guaranteed Source)
      "https://raw.githubusercontent.com/zxcty54/quiz/main/$encodedPath?t=$ts",
      // 2. GitHack Cloudflare Dev Gateway
      "https://raw.githack.com/zxcty54/quiz/main/$encodedPath",
      // 3. Statically CDN
      "https://cdn.statically.io/gh/zxcty54/quiz/main/$encodedPath",
      // 4. Fastly CDN
      "https://fastly.jsdelivr.net/gh/zxcty54/quiz@main/$encodedPath?t=$ts",
    ];

    for (String url in mirrorUrls) {
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
            'Expires': '0',
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          String rawBody = utf8.decode(response.bodyBytes);
          String cleanJson = _sanitizeJsonString(rawBody);

          if (cleanJson.startsWith('<') || cleanJson.startsWith('<!DOCTYPE')) {
            continue;
          }

          Map<String, dynamic> parsedJson = json.decode(cleanJson);
          LearnChapterData data = LearnChapterData.fromJson(parsedJson);

          final prefs = await SharedPreferences.getInstance();
          int savedIdx = prefs.getInt('progress_idx_${data.id}') ?? 0;
          if (savedIdx >= data.cardsList.length) savedIdx = 0;

          if (mounted) {
            setState(() {
              chapterData = data;
              currentCardIndex = savedIdx;
              visibleMessageCount = 1;
              _cardHistory.clear();
              isLoading = false;
              errorMessage = null;
            });
            _saveProgress(savedIdx);
            return;
          }
        }
      } catch (e) {
        debugPrint("Mirror $url failed: $e");
        continue;
      }
    }

    if (mounted) {
      setState(() {
        errorMessage = "Data load nahi ho saka. Internet ya JSON syntax check karein.";
        isLoading = false;
      });
    }
  }

  Future<void> _saveProgress(int index) async {
    if (chapterData == null || chapterData!.cardsList.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt('progress_idx_${chapterData!.id}', index);

    double progress = (index + 1) / chapterData!.cardsList.length;
    
    String nextTopic = "Continue Interactive Story";
    if (index + 1 < chapterData!.cardsList.length) {
      final nextCard = chapterData!.cardsList[index + 1];
      
      if (nextCard.messages != null && nextCard.messages!.isNotEmpty) {
        final firstMsg = nextCard.messages!.first.text;
        nextTopic = firstMsg.length > 30 ? "Next: ${firstMsg.substring(0, 30)}..." : "Next: $firstMsg";
      } else if (nextCard.cardSlug.isNotEmpty) {
        nextTopic = "Next: ${nextCard.cardSlug}";
      }
    } else {
      nextTopic = "Chapter Completed 🎉";
    }

    await prefs.setString('last_learn_title', chapterData!.title);
    await prefs.setDouble('last_learn_progress', progress);
    await prefs.setString('last_next_topic', nextTopic);
    await prefs.setBool('has_learning_history', true);
  }

  void _goToPreviousCard() {
    if (_cardHistory.isEmpty || isTyping) return;
    LearnEffects.playTap();

    final prevIndex = _cardHistory.removeLast();
    if (prevIndex >= 0 && prevIndex < chapterData!.cardsList.length) {
      _saveProgress(prevIndex);
      setState(() {
        currentCardIndex = prevIndex;
        final prevCard = chapterData!.cardsList[prevIndex];
        visibleMessageCount = prevCard.messages?.length ?? 1;
        isTyping = false;
      });
    }
  }

  void _goToFirstCard() {
    if (currentCardIndex == 0 || isTyping) return;
    LearnEffects.playTap();

    _saveProgress(0);
    setState(() {
      _cardHistory.clear();
      currentCardIndex = 0;
      visibleMessageCount = 1;
      isTyping = false;
    });
  }

  void _handleNextTap(LearnCardModel currentCard) {
    if (isTyping) return;
    
    LearnEffects.playTap();

    if (currentCard.type == 'chat') {
      int totalMsgs = currentCard.messages?.length ?? 0;
      if (visibleMessageCount < totalMsgs) {
        setState(() {
          isTyping = true;
        });

        _scrollToBottom();

        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              isTyping = false;
              visibleMessageCount++;
            });
            LearnEffects.playMessagePop();
            _scrollToBottom();
          }
        });
        return;
      }
    }

    int targetIndex = -1;
    final String? nextTarget = currentCard.nextSlug;

    if (nextTarget != null && nextTarget != "FINISH" && nextTarget.isNotEmpty) {
      targetIndex = chapterData!.cardsList.indexWhere((c) =>
          c.cardId == nextTarget || c.cardSlug == nextTarget);
    }

    if (targetIndex == -1 && currentCardIndex < chapterData!.cardsList.length - 1) {
      targetIndex = currentCardIndex + 1;
    }

    if (targetIndex != -1 && targetIndex < chapterData!.cardsList.length) {
      _cardHistory.add(currentCardIndex);

      _saveProgress(targetIndex);
      setState(() {
        currentCardIndex = targetIndex;
        visibleMessageCount = 1;
        isTyping = false;
      });
    } else {
      _saveProgress(chapterData!.cardsList.length - 1);
      LearnEffects.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Chapter Completed! Excellent Job!')),
      );
      Navigator.pop(context);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(widget.chapterTitle ?? 'Loading Chapter...', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFF4F46E5),
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF4F46E5)),
              SizedBox(height: 14),
              Text("Preparing Interactive Session...", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null || chapterData == null || chapterData!.cardsList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error'), backgroundColor: const Color(0xFF4F46E5)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("⚠️", style: TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                Text(errorMessage ?? "Could not load chapter data", textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                      errorMessage = null;
                    });
                    _fetchChapterJson();
                  },
                  child: const Text("Retry", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        ),
      );
    }

    LearnCardModel currentCard = chapterData!.cardsList[currentCardIndex];

    if (currentCard.type == 'milestone') {
      return Scaffold(
        body: SafeArea(
          child: MilestoneCardWidget(
            payload: currentCard.milestonePayload ?? {},
            onContinue: () => _handleNextTap(currentCard),
          ),
        ),
      );
    }

    int totalMsgs = currentCard.messages?.length ?? 0;
    bool isAllMessagesRevealed = (visibleMessageCount >= totalMsgs && !isTyping) || currentCard.type != 'chat';

    String buttonLabel = 'Tap to Read Next 💬';

    if (currentCard.type == 'intro') {
      buttonLabel = currentCard.buttonText ?? 'Start Chapter 🚀';
    } else if (isTyping) {
      buttonLabel = 'Aman Sir is typing...';
    } else if (isAllMessagesRevealed) {
      buttonLabel = currentCard.buttonText ?? 'Next Card ➔';
    } else if (currentCard.messages != null && visibleMessageCount < totalMsgs) {
      final nextMsg = currentCard.messages![visibleMessageCount];
      final char = chapterData!.characters[nextMsg.speaker];
      if (char != null && char.role == 'student') {
        buttonLabel = '💬 "${nextMsg.text}"';
      }
    }

    final bool canGoPrevious = _cardHistory.isNotEmpty;
    final bool canRestart = currentCardIndex > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4F46E5),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chapterData!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (currentCardIndex + 1) / chapterData!.cardsList.length,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                minHeight: 5,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${currentCardIndex + 1}/${chapterData!.cardsList.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          if (canGoPrevious || canRestart)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                border: Border(bottom: BorderSide(color: Color(0xFFC7D2FE), width: 0.8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: canGoPrevious ? _goToPreviousCard : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: canGoPrevious ? Colors.white : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: canGoPrevious ? const Color(0xFF818CF8) : Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            size: 15,
                            color: canGoPrevious ? const Color(0xFF4F46E5) : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Previous Card',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: canGoPrevious ? const Color(0xFF4F46E5) : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (canRestart)
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            title: const Text('Go to First Card?'),
                            content: const Text('Kya aap wapas Chapter ke First Card (Intro) par jana chahte hain?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _goToFirstCard();
                                },
                                child: const Text('Yes, Go to Start 🔄'),
                              ),
                            ],
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restart_alt_rounded, size: 15, color: Color(0xFF4F46E5)),
                            SizedBox(width: 4),
                            Text(
                              'First Card',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: () => _handleNextTap(currentCard),
              behavior: HitTestBehavior.opaque,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(currentCardIndex),
                  child: LearnCardRenderer(
                    card: currentCard,
                    characters: chapterData!.characters,
                    visibleCount: visibleMessageCount,
                    isTyping: isTyping,
                    scrollController: _scrollController,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (currentCard.type == 'intro' || isAllMessagesRevealed) 
                      ? const Color(0xFF4F46E5) 
                      : const Color(0xFF2563EB),
                  minimumSize: const Size.fromHeight(52),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _handleNextTap(currentCard),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        buttonLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      (currentCard.type == 'intro' || isAllMessagesRevealed) 
                          ? Icons.arrow_forward_rounded 
                          : Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
