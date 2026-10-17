import 'dart:async';
import 'package:flutter/material.dart';

import '../services/premium_service.dart';
import 'premium_paywall_screen.dart';

/// sectional_data.json se bana ek section group (jaise "Reasoning Sets").
/// Sets hamesha JSON ke count se auto-generate hote hain — kuch hardcoded nahi.
class SectionalExamGroup {
  final String title;
  final int sets;
  final int upcomingSets;
  final String upcomingText;
  final String pathPrefix; // set file path = '$pathPrefix$n.json'

  const SectionalExamGroup({
    required this.title,
    required this.sets,
    required this.upcomingSets,
    required this.upcomingText,
    required this.pathPrefix,
  });

  String launchTitle(int setNum) => '$title Set $setNum';
  String launchPath(int setNum) => '$pathPrefix$setNum.json';
}

/// Sectional Mocks 2.0 — ek exam ke saare sets ki list,
/// CbtProgressService ke saved data se Done / In-Progress / Score ke saath.
class SectionalExamScreen extends StatefulWidget {
  final String examTitle;
  final String badge;
  final String icon;
  final Color color;
  final bool isDarkMode;
  final List<SectionalExamGroup> groups;
  final Future<Map<String, Map<String, dynamic>>> Function() progressLoader;
  final Function(BuildContext, String, String) onLaunchCbtMock;
  final void Function(String setTitle, String notice) onShowUpcoming;

  const SectionalExamScreen({
    super.key,
    required this.examTitle,
    required this.badge,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.groups,
    required this.progressLoader,
    required this.onLaunchCbtMock,
    required this.onShowUpcoming,
  });

  @override
  State<SectionalExamScreen> createState() => _SectionalExamScreenState();
}

class _SectionalExamScreenState extends State<SectionalExamScreen> {
  Map<String, Map<String, dynamic>> _progress = {};
  String _filter = 'all'; // all | left | done
  Timer? _refreshTimer;
  bool _refreshPending = false;
  bool _isPremium = false;
  bool _isOwner = false;
  DateTime? _premiumUntil;

  @override
  void initState() {
    super.initState();
    _reloadProgress();
    _loadPremium();
    // Test khatm karke wapas aane par rows auto-refresh ho jayein
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      if (_refreshPending && (ModalRoute.of(context)?.isCurrent ?? false)) {
        _refreshPending = false;
        _reloadProgress();
        _loadPremium();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _reloadProgress() async {
    final data = await widget.progressLoader();
    if (mounted) setState(() => _progress = data);
  }

  Future<void> _loadPremium() async {
    final until = await PremiumService.fetchPremiumUntil();
    final owner = await PremiumService.isOwnerMode();
    if (!mounted) return;
    setState(() {
      _premiumUntil = until;
      _isOwner = owner;
      _isPremium =
          owner || (until != null && until.isAfter(DateTime.now()));
    });
  }

  bool _isSetLocked(int setNum) => setNum > 1 && !_isPremium;

  Future<void> _openPaywall() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumPaywallScreen(isDarkMode: widget.isDarkMode),
      ),
    );
    await _loadPremium();
  }

  void _launch(SectionalExamGroup group, int setNum) {
    // Set 01 free, baki Premium — seedha ghusne par bhi rok yahi lagegi
    if (_isSetLocked(setNum)) {
      _openPaywall();
      return;
    }
    _refreshPending = true;
    widget.onLaunchCbtMock(
      context,
      group.launchTitle(setNum),
      group.launchPath(setNum),
    );
  }

  int get _totalSets => widget.groups.fold<int>(0, (s, g) => s + g.sets);

  int get _doneSets {
    int done = 0;
    for (final g in widget.groups) {
      for (int n = 1; n <= g.sets; n++) {
        if (_progress[g.launchTitle(n)]?['status'] == 'COMPLETED') done++;
      }
    }
    return done;
  }

  String _fmtScore(dynamic raw) {
    final double d = (raw is num) ? raw.toDouble() : 0;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = widget.isDarkMode;
    final Color bg = isDark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FF);
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    final int total = _totalSets;
    final int done = _doneSets;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          widget.examTitle,
          style: TextStyle(color: textColor, fontSize: 16.5, fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF1F7)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header band
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(widget.color, Colors.black, 0.25)!,
                  widget.color,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.35)),
                      ),
                      child: Center(child: Text(widget.icon, style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.examTitle,
                            style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w900, height: 1.2),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${widget.badge} • Real CBT Pattern',
                            style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$done / $total sets complete',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: _openPaywall,
                  child: Text(
                    _isOwner
                        ? '🛠 Owner Mode ON • Sab Set unlock (band karne ke liye dabao)'
                        : (_isPremium
                            ? '👑 Premium Active • ${_premiumUntil!.difference(DateTime.now()).inDays + 1} din baki — saare Set khule hai'
                            : '🔓 Set 01 Free • Baki Set Premium (₹49/month)'),
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filters
          Row(
            children: [
              _filterChip('all', 'All Sets', isDark),
              const SizedBox(width: 7),
              _filterChip('left', 'Bache Hue', isDark),
              const SizedBox(width: 7),
              _filterChip('done', 'Done ✓', isDark),
            ],
          ),
          const SizedBox(height: 14),

          if (widget.groups.isEmpty)
            _emptyBox(isDark, 'Is exam me abhi koi set add nahi hua hai.')
          else
            ...widget.groups.map((g) => _groupCard(g, isDark, textColor)),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label, bool isDark) {
    final bool selected = _filter == key;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          color: selected ? Colors.white : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
        ),
      ),
      selectedColor: widget.color,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      side: BorderSide(
        color: selected ? widget.color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      onSelected: (v) {
        if (v) setState(() => _filter = key);
      },
    );
  }

  Widget _emptyBox(bool isDark, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      ),
    );
  }

  Widget _groupCard(SectionalExamGroup group, bool isDark, Color textColor) {
    final List<Widget> rows = [];
    for (int n = 1; n <= group.sets; n++) {
      final status = _progress[group.launchTitle(n)]?['status']?.toString();
      final bool isDone = status == 'COMPLETED';
      final bool isInProgress = status == 'IN_PROGRESS';
      if (_filter == 'left' && isDone) continue;
      if (_filter == 'done' && !isDone) continue;
      rows.add(_setRow(group, n, isDark, textColor, isDone, isInProgress));
    }
    // Upcoming (locked) sets sirf "All" filter me
    if (_filter == 'all') {
      for (int u = 1; u <= group.upcomingSets; u++) {
        final int n = group.sets + u;
        rows.add(_lockedRow(group, n, isDark, textColor));
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                ),
              ),
              if (group.upcomingSets > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '🔥 +${group.upcomingSets} Upcoming',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF92400E)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Is filter me koi set nahi hai.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }

  Widget _setRow(
    SectionalExamGroup group,
    int setNum,
    bool isDark,
    Color textColor,
    bool isDone,
    bool isInProgress,
  ) {
    // Premium lock (Set 01 hamesha free)
    if (_isSetLocked(setNum)) {
      return _premiumLockedRow(group, setNum, isDark, textColor);
    }
    final data = _progress[group.launchTitle(setNum)];
    final String label = 'Set ${setNum.toString().padLeft(2, '0')}';

    String statusText;
    if (isDone) {
      statusText = '✓ Done • Score ${_fmtScore(data?['score'])} • ${data?['correct'] ?? 0}/${data?['total'] ?? 0} sahi';
    } else if (isInProgress) {
      statusText = '⏳ In-Progress • Q${(data?['currentIndex'] ?? 0) + 1} se resume hoga';
    } else {
      statusText = 'Not attempted • Full CBT mode';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF1F7)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 38,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(isDark ? 0.25 : 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'SET\n${setNum.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9.5, height: 1.15, fontWeight: FontWeight.w900, color: widget.color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textColor)),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDone
                          ? const Color(0xFF16A34A)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isDone)
              OutlinedButton(
                onPressed: () => _launch(group, setNum),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.color,
                  side: BorderSide(color: widget.color.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
                child: const Text('↻ Re-attempt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              )
            else
              ElevatedButton(
                onPressed: () => _launch(group, setNum),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInProgress ? const Color(0xFFD97706) : widget.color,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
                child: Text(isInProgress ? 'Resume →' : 'Start →', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _premiumLockedRow(SectionalExamGroup group, int setNum, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.45 : 0.55)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'SET\n${setNum.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 9.5, height: 1.15, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set ${setNum.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textColor),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '🔒 Premium • ₹49/month me saare Set khulenge',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _openPaywall,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
              child: const Text('Unlock 👑', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lockedRow(SectionalExamGroup group, int setNum, bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: () => widget.onShowUpcoming('Set $setNum', group.upcomingText),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'SET\n${setNum.toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9.5, height: 1.15, fontWeight: FontWeight.w900, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set ${setNum.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🔒 Locked • ${group.upcomingText}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(99)),
                child: const Text('🔒 Soon', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

