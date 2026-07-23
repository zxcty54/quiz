import 'package:flutter/material.dart';
import '../services/telegram_service.dart';

class ReportErrorDialog extends StatefulWidget {
  final String fileName;
  final int questionIndex;
  final String questionSnippet;

  const ReportErrorDialog({
    super.key,
    required this.fileName,
    required this.questionIndex,
    required this.questionSnippet,
  });

  @override
  State<ReportErrorDialog> createState() => _ReportErrorDialogState();
}

class _ReportErrorDialogState extends State<ReportErrorDialog> {
  String _selectedIssue = 'Wrong Answer/Option';
  bool _isSending = false;

  final List<String> _issues = [
    'Wrong Answer/Option',
    'Typo / Translation Error',
    'Missing Statement / Question',
    'Explanation Incorrect',
    'Other Issue'
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🚩 Report Question Error'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q#${widget.questionIndex + 1} (${widget.fileName})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text('Select Issue Type:'),
          DropdownButton<String>(
            isExpanded: true,
            value: _selectedIssue,
            items: _issues.map((String issue) {
              return DropdownMenuItem<String>(
                value: issue,
                child: Text(issue),
              );
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() => _selectedIssue = newValue);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: _isSending
              ? null
              : () async {
                  setState(() => _isSending = true);
                  bool success = await TelegramService.reportError(
                    fileName: widget.fileName,
                    questionIndex: widget.questionIndex,
                    issueType: _selectedIssue,
                    questionSnippet: widget.questionSnippet,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? '✅ Error reported to team via Telegram!'
                              : '❌ Failed to report error. Try again.',
                        ),
                      ),
                    );
                  }
                },
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Report', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
