import 'package:flutter/material.dart';

class RevisionHeroBanner extends StatelessWidget {
  final bool isDark;
  final bool isLoading;

  const RevisionHeroBanner({
    super.key,
    required this.isDark,
    required this.isLoading,
  });

  void _showSourcesModal(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF475569);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Verified Academic Sources',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Revision Hub ke sabhi questions aur explanations standard government textbooks aur authentic benchmark books ke sath verified hain.',
                    style: TextStyle(fontSize: 12, color: subTextColor, height: 1.4),
                  ),
                  const Divider(height: 24),
                  _buildSourceTile('🔬 Physics, Chemistry & Biology', 'NCERT (Class 8–12), NCERT Exemplar & Previous Year State PCS Sets', textColor, subTextColor),
                  _buildSourceTile('🏛️ Indian Polity & Governance', 'M. Laxmikanth (Latest Edition) & NCERT Indian Constitution at Work', textColor, subTextColor),
                  _buildSourceTile('📜 History (Ancient, Medieval, Modern)', "Spectrum's Modern India (Rajiv Ahir), Satish Chandra & RS Sharma", textColor, subTextColor),
                  _buildSourceTile('🌍 Geography (Physical & Regional)', 'NCERT Geography (Class 6–12), Ghatna Chakra Purvavalokan & Oxford Atlas', textColor, subTextColor),
                  _buildSourceTile('📈 Indian Economy & Bihar Survey', 'NCERT Macroeconomics (Class 12), Ramesh Singh & Bihar Economic Survey', textColor, subTextColor),
                  _buildSourceTile('📐 Quantitative Aptitude', 'R.S. Aggarwal & Kiran SSC Mathematics Chapterwise PYQ Sets', textColor, subTextColor),
                  _buildSourceTile('🧩 Reasoning Ability', 'R.S. Aggarwal Verbal & Non-Verbal Reasoning & Previous Year State Tests', textColor, subTextColor),
                  _buildSourceTile('📰 Current Affairs & Schemes', 'Official Press Information Bureau (PIB) & Bihar State Gazette', textColor, subTextColor),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSourceTile(String title, String desc, Color textColor, Color subTextColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 11.5, color: subTextColor, height: 1.35)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('⚡ ', style: TextStyle(fontSize: 10)),
                        Text(
                          'SMART REVISION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'BPSC • BSSC • SSC • RLY',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isLoading) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '1 Question = Multiple Facts.\nHar Statement Ka Logic.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sirf sahi answer nahi — galat option ke peeche ka reason samjho aur 3x tezi se revise karo.',
                style: TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: () => _showSourcesModal(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mapped with NCERT (8-12), Laxmikanth & Standard PYQs',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
                Text(
                  'Sources ➔',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
