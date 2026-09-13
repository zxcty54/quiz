import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RevisionTrickSubmitBox extends StatefulWidget {
  final String testTitle;
  final int qIndex;
  final String questionSnippet;

  const RevisionTrickSubmitBox({
    super.key,
    required this.testTitle,
    required this.qIndex,
    required this.questionSnippet,
  });

  @override
  State<RevisionTrickSubmitBox> createState() => _RevisionTrickSubmitBoxState();
}

class _RevisionTrickSubmitBoxState extends State<RevisionTrickSubmitBox> {
  final TextEditingController _trickController = TextEditingController();

  bool _isSubmitting = false;
  bool _isSubmitted = false;
  bool _isOpen = false;

  static const String _botToken = "1809778528:AAFlwdQMKgiezltaJYyAU5u6vNjblBiIPmo";
  static const String _chatId = "785009742";

  Future<void> _submitTrickToTelegram() async {
    final trickText = _trickController.text.trim();

    if (trickText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('⚠️ Please write your trick or data first!'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final cleanSnippet = widget.questionSnippet.length > 70
        ? "${widget.questionSnippet.substring(0, 70)}..."
        : widget.questionSnippet;

    final telegramMsg = """
💡 *NEW TRICK / DATA SUBMITTED!*
━━━━━━━━━━━━━━━━━━━━━
📁 *Chapter:* ${widget.testTitle}
❓ *Q#: * Q${widget.qIndex + 1}
📝 *Snippet:* $cleanSnippet
━━━━━━━━━━━━━━━━━━━━━
✨ *User Trick/Logic:*
$trickText
""";

    try {
      final res = await http.post(
        Uri.parse("https://api.telegram.org/bot$_botToken/sendMessage"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "chat_id": _chatId,
          "text": telegramMsg,
          "parse_mode": "Markdown",
        }),
      );

      if (res.statusCode == 200 && mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmitted = true;
        });
      } else {
        if (mounted) setState(() => _isSubmitting = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _trickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isSubmitted) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF052E16) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '✅ Thank you! Trick/Data Telegram par bhej diya gaya hai.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A),
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isDark ? const Color(0xFF29364D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _isOpen = !_isOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Text('💡 ', style: TextStyle(fontSize: 13)),
                        Flexible(
                          child: Text(
                            'Got a short-trick or better logic?',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOpen ? 'Close ▲' : 'Share ➜',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isOpen) ...[
            const SizedBox(height: 9),
            TextField(
              controller: _trickController,
              maxLines: 3,
              minLines: 2,
              textInputAction: TextInputAction.newline,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Apni trick, mnemonic code ya logic yahan likhein...',
                hintStyle: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey),
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF172033) : Colors.white,
                contentPadding: const EdgeInsets.all(11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(color: Color(0xFF24A1DE), width: 1.3),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF24A1DE),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: _isSubmitting ? null : _submitTrickToTelegram,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 14),
                  label: Text(
                    _isSubmitting ? 'Sending...' : 'Send to Telegram',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
