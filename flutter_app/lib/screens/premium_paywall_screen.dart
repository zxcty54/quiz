import 'package:flutter/material.dart';

/// Safe destination for any older in-app route: premium study features are
/// free for this Google Play release and there is no checkout.
class PremiumPaywallScreen extends StatelessWidget {
  final bool isDarkMode;

  const PremiumPaywallScreen({super.key, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final background =
        isDarkMode ? const Color(0xFF0B1220) : const Color(0xFFF5F7FF);
    final surface = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final foreground = isDarkMode ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text('Free Study Access', style: TextStyle(color: foreground)),
        iconTheme: IconThemeData(color: foreground),
      ),
      body: Center(
        child: Card(
          color: surface,
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_open_rounded,
                  size: 48,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(height: 14),
                Text(
                  'All premium study features are free in this release.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'There is no payment or subscription flow in this Google Play build.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground.withOpacity(0.72),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Continue studying'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
