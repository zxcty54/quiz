import 'package:flutter/material.dart';

import '../services/community_safety_service.dart';

/// A direct, in-context reporting control for AI-generated output.
class ReportAiResponseButton extends StatelessWidget {
  final String response;
  final String source;
  final bool isDarkMode;

  const ReportAiResponseButton({
    super.key,
    required this.response,
    required this.source,
    this.isDarkMode = false,
  });

  Future<void> _report(BuildContext context) async {
    final reporter = await CommunitySafetyService.currentReporterHandle();
    if (!context.mounted) return;

    await CommunitySafetyService.promptAndQueueModerationReport(
      context,
      reporterHandle: reporter,
      targetType: 'ai_response',
      targetId: '$source:${DateTime.now().microsecondsSinceEpoch}',
      source: source,
      // Only a short excerpt of the generated response is retained for review;
      // the user's prompt and chat history are not included.
      contentExcerpt: response,
      successMessage: 'Thank you. The AI response was reported for review.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _report(context),
      icon: const Icon(Icons.flag_outlined, size: 15),
      label: const Text('Report AI response'),
      style: TextButton.styleFrom(
        foregroundColor: isDarkMode ? Colors.white70 : const Color(0xFF64748B),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
