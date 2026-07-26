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

  Future<void> _fetchChapterJson() async {
    // 🚀 jsDelivr CDN URL: Fast, reliable, and never blocked by Jio/Airtel
    String targetUrl = widget.jsonUrl ?? '';
    
    if (targetUrl.isEmpty) {
      targetUrl = 'https://cdn.jsdelivr.net/gh/zxcty54/quiz@main/learn/biology/cell.json';
    } else if (targetUrl.contains('raw.githubusercontent.com')) {
      // Automatic GitHub Raw to jsDelivr CDN URL Convertor
      targetUrl = targetUrl
          .replaceAll('https://raw.githubusercontent.com/', 'https://cdn.jsdelivr.net/gh/')
          .replaceAll('/refs/heads/main/', '@main/')
          .replaceAll('/main/', '@main/');
    }

    try {
      final response = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        Map<String, dynamic> parsedJson = json.decode(utf8.decode(response.bodyBytes));
        LearnChapterData data = LearnChapterData.fromJson(parsedJson);

        final prefs = await SharedPreferences.getInstance();
        int savedIdx = prefs.getInt('progress_idx_${data.id}') ?? 0;
        if (savedIdx >= data.cardsList.length) savedIdx = 0;

        if (mounted) {
          setState(() {
            chapterData = data;
            currentCardIndex = savedIdx;
            visibleMessageCount = 1;
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = "Error ${response.statusCode}: Data load nahi ho saka.";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Exact error details print hongi for debugging
          errorMessage = "Data Fetch Error: $e\n\nURL: $targetUrl";
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProgress(int index) async {
    if (chapterData == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('progress_idx_${chapterData!.id}', index);
  }

  void _handleNextTap(LearnCardModel currentCard) {
    if (isTyping) return;
    
    LearnEffects.playTap();

    // 1. Chat cards ke liye progressive message reveal
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

    // 2. Next Card Target Navigation
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
      _saveProgress(targetIndex);
      setState(() {
        currentCardIndex = targetIndex;
        visibleMessageCount = 1;
        isTyping = false;
      });
    } else {
      _saveProgress(0);
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

    // 🌟 SMART BUTTON LABEL LOGIC FOR INTRO VS CHAT CARDS
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
      body: GestureDetector(
        onTap: () => _handleNextTap(currentCard),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Expanded(
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
      ),
    );
  }
}
