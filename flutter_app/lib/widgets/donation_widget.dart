import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class DonationWidget extends StatefulWidget {
  final bool isDarkMode;
  const DonationWidget({super.key, required this.isDarkMode});

  @override
  State<DonationWidget> createState() => _DonationWidgetState();
}

class _DonationWidgetState extends State<DonationWidget>
    with SingleTickerProviderStateMixin {
  // 📌 APNI UPI ID YAHAN CHANGE KAREIN
  static const String upiId = "me.nitesh47@okhdfcbank";
  static const String payeeName = "MockTester Student Fund";

  int _selectedAmount = 30; // Default ₹30
  bool _isCustom = false;
  final TextEditingController _customAmountController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // 🌟 SUBTLE PULSE ANIMATION FOR CTA BUTTON
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _customAmountController.dispose();
    super.dispose();
  }

  // 🚀 UPI PAYMENT TRIGGER
  Future<void> _processUpiPayment() async {
    final int amount = _isCustom
        ? (int.tryParse(_customAmountController.text) ?? 10)
        : _selectedAmount;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount!')),
      );
      return;
    }

    final String upiUri =
        "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent('MockTester Community Fund')}";

    final Uri uri = Uri.parse(upiUri);

    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        _showQrCodeDialog(amount);
      }
    } catch (_) {
      _showQrCodeDialog(amount);
    }
  }

  // 🖼️ QR CODE DIALOG
  void _showQrCodeDialog(int amount) {
    final String upiUri =
        "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent('MockTester Community Fund')}";
    final String qrApiUrl =
        "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(upiUri)}";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Text(
              'Scan & Pay ₹$amount 📲',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'GPay, PhonePe, Paytm ya BHIM se scan karein',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFFE0E7FF),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.network(
                qrApiUrl,
                width: 180,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Column(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.grey),
                    Text('QR Code unavailable', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF312E81),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF4338CA)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'UPI: $upiId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: upiId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UPI ID copied to clipboard!')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Copy',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFFE0E7FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int currentAmount = _isCustom
        ? (int.tryParse(_customAmountController.text) ?? 0)
        : _selectedAmount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // 🔮 HIGH-CONTRAST DEEP INDIGO TO ROYAL BLUE GRADIENT
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏷️ NEON AMBER BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3.5, backgroundColor: Color(0xFFF59E0B)),
                SizedBox(width: 6),
                Text(
                  'COMMUNITY FUNDED PLATFORM',
                  style: TextStyle(
                    color: Color(0xFFFBF3D5),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 🎯 CRISP WHITE TITLE & SUBTITLE
          const Text(
            'Help Us Keep MockTester 100% Free ❤️',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hum education par ₹499/yr paywalls nahi lagate. Apna contribution choose karein aur Bihar ke rural aspirants ke liye high-quality tests free rakhne mein madad karein.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFFE0E7FF),
            ),
          ),
          const SizedBox(height: 16),

          // 📊 SERVER FUND METER CARD
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Server Fund Goal',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '₹420 / ₹1,500',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ⚡ ELECTRIC GREEN PROGRESS BAR
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    value: 0.42, // 42%
                    minHeight: 8,
                    backgroundColor: Color(0xFF1E293B),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 6),

                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('42% Funded This Month',
                        style: TextStyle(fontSize: 10, color: Color(0xFFA7F3D0), fontWeight: FontWeight.bold)),
                    Text('⚡ ₹1,080 Remaining',
                        style: TextStyle(fontSize: 10, color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 💰 PRESET CHIPS
          const Text(
            'Select Contribution Amount:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE0E7FF),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildAmountChip(30, '₹30'),
              const SizedBox(width: 6),
              _buildAmountChip(50, '₹50'),
              const SizedBox(width: 6),
              _buildAmountChip(100, '₹100'),
              const SizedBox(width: 6),
              _buildCustomChip(),
            ],
          ),

          if (_isCustom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customAmountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter Custom Amount in ₹',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),

          // 💳 VIBRANT AMBER/GOLD CTA WITH SUBTLE PULSE ANIMATION
          ScaleTransition(
            scale: _scaleAnimation,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processUpiPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B), // Vibrant Amber Gold
                  foregroundColor: const Color(0xFF0F172A), // Dark High Contrast Text
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.volunteer_activism_rounded, size: 18, color: Color(0xFF0F172A)),
                    const SizedBox(width: 8),
                    Text(
                      'Donate ₹$currentAmount via UPI',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountChip(int amount, String label) {
    final bool isSelected = !_isCustom && _selectedAmount == amount;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedAmount = amount;
            _isCustom = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFF59E0B) : Colors.white.withOpacity(0.15),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomChip() {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _isCustom = true;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isCustom ? const Color(0xFFF59E0B) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isCustom ? const Color(0xFFF59E0B) : Colors.white.withOpacity(0.15),
            ),
          ),
          child: Text(
            'Custom',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _isCustom ? const Color(0xFF0F172A) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
