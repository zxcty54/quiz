import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class DonationWidget extends StatefulWidget {
  final bool isDarkMode;
  const DonationWidget({super.key, required this.isDarkMode});

  @override
  State<DonationWidget> createState() => _DonationWidgetState();
}

class _DonationWidgetState extends State<DonationWidget> {
  // 📌 APNI UPI ID YAHAN CHANGE KAREIN
  static const String upiId = "me.nitesh47@okhdfcbank"; 
  static const String payeeName = "MockTester Student Fund";

  int _selectedAmount = 30; // Default ₹30
  bool _isCustom = false;
  final TextEditingController _customAmountController = TextEditingController();

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  // 🚀 UPI PAYMENT TRIGGER (Deep-Link to GPay/PhonePe/Paytm)
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

  // 🖼️ QR CODE DIALOG FOR ALTERNATIVE PAYMENT
  void _showQrCodeDialog(int amount) {
    final String upiUri =
        "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent('MockTester Community Fund')}";
    final String qrApiUrl =
        "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(upiUri)}";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Text(
              'Scan & Pay ₹$amount 📲',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'GPay, PhonePe, Paytm ya BHIM se scan karein',
              style: TextStyle(
                fontSize: 11.5,
                color: widget.isDarkMode ? Colors.white60 : Colors.grey.shade600,
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
                border: Border.all(color: Colors.grey.shade300),
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
                color: widget.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF818CF8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'UPI: $upiId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? Colors.white : const Color(0xFF0F172A),
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
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Copy',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
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

    final cardBg = widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final titleColor = widget.isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final descColor = widget.isDarkMode ? Colors.white70 : const Color(0xFF475569);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏷️ BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.25)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: Color(0xFF4F46E5)),
                SizedBox(width: 6),
                Text(
                  'COMMUNITY FUNDED PLATFORM',
                  style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 🎯 TITLE & DESC
          Text(
            'Help Us Keep MockTester 100% Free ❤️',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hum education par ₹499/yr paywalls nahi lagate. Apna contribution choose karein aur Bihar ke rural aspirants ke liye high-quality tests free rakhne mein madad karein.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: descColor,
            ),
          ),
          const SizedBox(height: 14),

          // 📊 METER CARD
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Server Fund Goal',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const Text(
                      '₹420 / ₹1,500',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // PROGRESS BAR
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: 0.42, // 42%
                    minHeight: 7,
                    backgroundColor: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                  ),
                ),
                const SizedBox(height: 6),

                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('42% Funded This Month', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('58% Remaining', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 💰 PRESET CHIPS (₹30, ₹50, ₹100, Custom)
          Text(
            'Select Contribution Amount:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: titleColor,
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

          // CUSTOM INPUT FIELD
          if (_isCustom) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customAmountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: titleColor, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter Custom Amount in ₹',
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 14),

          // 💳 DONATE CTA BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _processUpiPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.volunteer_activism_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Donate ₹$currentAmount via UPI',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                ],
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
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4F46E5)
                  : (widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : (widget.isDarkMode ? Colors.white70 : const Color(0xFF334155)),
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
            color: _isCustom
                ? const Color(0xFF4F46E5)
                : (widget.isDarkMode ? const Color(0xFF0F172A) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isCustom
                  ? const Color(0xFF4F46E5)
                  : (widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Text(
            'Custom',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _isCustom ? Colors.white : (widget.isDarkMode ? Colors.white70 : const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }
}
