import 'package:flutter/material.dart';

/// Small, dependency-free UI helpers shared by every feature.
///
/// v1 repeated `showDialog(... CircularProgressIndicator ...)` +
/// `Navigator.pop(context)` in at least a dozen screens, and each one had to
/// remember the "is this widget still mounted" guard by hand.
class UiHelper {
  UiHelper._();

  /// Shows a blocking spinner. Always pair it with [hideLoading].
  static void showLoading(BuildContext context, {String? message}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(ctx).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                if (message != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(message, style: const TextStyle(fontSize: 12.5)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Closes the dialog opened by [showLoading] (safe if it is already gone).
  static void hideLoading(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  static void snack(
    BuildContext context,
    String message, {
    Color? background,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        duration: duration,
      ),
    );
  }

  /// Standard bottom-sheet container used by the editor sheets.
  static Future<T?> showAppSheet<T>(
    BuildContext context, {
    required Widget child,
    bool isScrollControlled = true,
    Color? background,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: background ?? Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(child: child),
    );
  }
}
