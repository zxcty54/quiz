import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../sectional_exam_screen.dart';
import '../sectional_family_screen.dart';

// --- Content Proxy (Private content_base ka darwaza: Cloudflare Worker) ---
const String _contentProxyBase =
    'https://content-proxy.nitesh-skyhigh.workers.dev';
const String _contentAppKey = 'mt_4bd7ba22c736af380d9d3905';


class SectionalTab extends StatefulWidget {
  final Map<String, dynamic> sectionalData;
  final bool isDarkMode;
  final Function(BuildContext, String, String) onLaunchCbtMock;

  const SectionalTab({
    super.key,
    required this.sectionalData,
    required this.isDarkMode,
    required this.onLaunchCbtMock,
  });

  @override
  State<SectionalTab> createState() => _SectionalTabState();
}

class _SectionalTabState extends State<SectionalTab> {
  Map<String, dynamic> _liveData = {};
  bool _isLoading = false;

  // CbtProgressService ka saved data: launchTitle -> {status, score, correct, total...}
  Map<String, Map<String, dynamic>> _progress = {};
  Timer? _refreshTimer;
  bool _refreshPending = false;

  @override
  void initState() {
    super.initState();
    _loadFromDiskAndFetch();
    _refreshProgress();
    // Test khatm karke wapas aane par grid/hero auto-refresh ho jaye
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      if (_refreshPending && (ModalRoute.of(context)?.isCurrent ?? false)) {
        _refreshPending = false;
        _refreshProgress();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SectionalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sectionalData.isNotEmpty && _liveData.isEmpty) {
      setState(() {
        _liveData = Map<String, dynamic>.from(widget.sectionalData);
      });
    }
  }

  // 1️⃣ Disk Storage load (0ms instant load), background live fetch
  Future<void> _loadFromDiskAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedJson = prefs.getString('persistent_sectional_data_json');

    if (savedJson != null && savedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedJson);
        if (decoded is Map && mounted) {
          setState(() {
            _liveData = Map<String, dynamic>.from(decoded);
          });
        }
      } catch (_) {}
    }

    if (_liveData.isEmpty && widget.sectionalData.isNotEmpty) {
      setState(() {
        _liveData = Map<String, dynamic>.from(widget.sectionalData);
      });
    }

    _fetchLiveGitHubData();
  }

  // 🚀 DIRECT GITHUB FETCHER (content_base) + PERMANENT DISK SAVE
  Future<void> _fetchLiveGitHubData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final int ts = DateTime.now().millisecondsSinceEpoch;
    final List<String> urls = [
      "$_contentProxyBase/sectional_data.json",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/sectional_data.json?t=$ts",
      "https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/sectional_data.json?t=$ts",
      "https://raw.githubusercontent.com/zxcty54/content_base/main/sectional_data.json?t=$ts",
    ];

    for (String url in urls) {
      try {
        final res = await http.get(Uri.parse(url), headers: {'X-App-Key': _contentAppKey}).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final dynamic parsed = jsonDecode(utf8.decode(res.bodyBytes));
          if (parsed is Map && mounted) {
            setState(() {
              _liveData = Map<String, dynamic>.from(parsed);
              _isLoading = false;
            });

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('persistent_sectional_data_json', jsonEncode(parsed));
            return;
          }
        }
      } catch (_) {
        continue;
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// JSON se rang: "0xFF7C3AED" ya "#7C3AED" dono chalega.
  Color? _jsonColor(dynamic data) => _colorField(data, 'color');

  Color? _colorField(dynamic data, String field) {
    if (data is! Map) return null;
    final dynamic raw = data[field];
    if (raw is! String || raw.trim().isEmpty) return null;
    String hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final int? value = int.tryParse(hex, radix: 16);
    return value == null ? null : Color(value);
  }

  Color _resolveColor(String key, int index) {
    final Color? fromJson = _jsonColor(_liveData[key]);
    if (fromJson != null) return fromJson;
    switch (key) {
      case 'bpsc':
        return const Color(0xFF9D174D);
      case 'ssc':
        return const Color(0xFF166534);
      case 'bssc_cgl':
        return const Color(0xFF6B21A8);
      case 'bssc_inter':
        return const Color(0xFF075985);
      case 'bssc_ldc':
        return const Color(0xFF4338CA);
      case 'bpsc_aedo':
        return const Color(0xFFBE123C);
      case 'btsc':
        return const Color(0xFF0D9488);
      case 'bihar_constable':
        return const Color(0xFFB45309);
      case 'ssc_cgl_ntpc':
        return const Color(0xFF166534);
      case 'bihar_si':
        return const Color(0xFFD97706);
      case 'bihar_amin':
        return const Color(0xFF059669);
      default:
        const List<Color> palette = [
          Color(0xFF2563EB),
          Color(0xFFDC2626),
          Color(0xFF7C3AED),
          Color(0xFF0D9488),
          Color(0xFFEA580C),
        ];
        return palette[index % palette.length];
    }
  }

  String _examIcon(String key) {
    final dynamic d = _liveData[key];
    if (d is Map && d['icon'] is String && (d['icon'] as String).isNotEmpty) {
      return d['icon'] as String;
    }
    switch (key) {
      case 'bpsc':
        return '🏛️';
      case 'ssc':
        return '🚂';
      case 'bssc_cgl':
        return '🎓';
      case 'bssc_inter':
        return '📗';
      case 'bssc_ldc':
        return '⌨️';
      case 'bpsc_aedo':
        return '📐';
      case 'btsc':
        return '🏨';
      case 'bihar_constable':
        return '🚓';
      case 'bihar_si':
        return '🚔';
      case 'bihar_amin':
        return '🗺️';
      default:
        return '🎯';
    }
  }

  String _formatExamTitle(String key, dynamic data) {
    if (data is Map && data['display_name'] != null) return data['display_name'];
    switch (key) {
      case 'bpsc':
        return 'BPSC PCS';
      case 'ssc':
        return 'SSC / NTPC';
      case 'bssc_cgl':
        return 'BSSC CGL';
      case 'bssc_inter':
        return 'BSSC 10+2';
      case 'bssc_ldc':
        return 'BSSC LDC';
      case 'bpsc_aedo':
        return 'BPSC AEO';
      case 'btsc':
        return 'BTSC';
      case 'bihar_constable':
        return 'BIHAR CONSTABLE';
      case 'bihar_si':
        return 'BIHAR SI';
      case 'bihar_amin':
        return 'BIHAR AMIN';
      default:
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatExamBadge(String key, dynamic data) {
    if (data is Map && data['badge'] != null) return data['badge'];
    switch (key) {
      case 'bpsc':
        return 'STATE PCS';
      case 'ssc':
        return 'TCS PATTERN';
      case 'bssc_cgl':
        return 'GRADUATE';
      case 'bssc_inter':
        return 'INTER LEVEL';
      case 'bssc_ldc':
        return 'CLERK / LDC';
      case 'bpsc_aedo':
        return 'AUDITING OFFICER';
      case 'btsc':
        return 'HOSTEL MANAGER';
      case 'bihar_constable':
        return 'POLICE';
      case 'bihar_si':
        return 'POLICE / DAROGA';
      case 'bihar_amin':
        return 'REVENUE DEPT';
      default:
        return 'EXAM ZONE';
    }
  }

  void _showUpcomingNotice(String setTitle, String notice) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_clock_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🔒 $setTitle jald hi live hoga!\n($notice)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------- Progress (CbtProgressService ke saved records) ----------

  Future<Map<String, Map<String, dynamic>>> _loadProgressMap() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, Map<String, dynamic>> out = {};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith('cbt_progress_')) continue;
      try {
        final raw = prefs.getString(k);
        if (raw == null) continue;
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          out[k.substring('cbt_progress_'.length)] = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return out;
  }

  Future<void> _refreshProgress() async {
    final data = await _loadProgressMap();
    if (!mounted) return;
    final List<SectionalExamGroup> all = <SectionalExamGroup>[
      for (final _ExamFamily f in _families()) ..._groupsForFamily(f),
    ];
    setState(() => _progress = withLegacyProgressAliases(data, all));
  }

  // ---------- JSON -> Groups ----------
  //
  // sectional_data.json ka contract (sab kuch optional, sab live chalta hai,
  // APK rebuild ki zaroorat nahi):
  //
  //   "<key>": {"title","total_sets","path_prefix","set_numbers",
  //             "upcoming_sets","upcoming_text"}          // map format
  //   "<key>": [ {"title","sets","folder","set_numbers",
  //               "upcoming_sets","upcoming_text"}, ... ]  // list format
  //   "<key>": {"display_name","badge","icon","color","family_title",
  //             "family_badge","sub_label","items":[ ... ]}
  //
  //   folder/path_prefix  -> "sectional_mock/<family>/..." ; ek hi family
  //                          wale saare keys apne aap EK card me jud jaate
  //                          hain (bpsc/cce + bpsc/aedo -> "BPSC").
  //   set_numbers         -> [1,2,3,10,14] jaise non-contiguous set live karo.
  //   display_name/badge  -> card ka naam aur pill (single-key family).
  //   family_title/badge  -> card ka naam aur pill (multi-key family).
  //   sub_label           -> multi-key family me section titles ka prefix.
  //   icon                -> koi bhi emoji.
  //   color               -> "0xFF7C3AED" ya "#7C3AED".
  //
  // Naya exam add karna = ek naya key + uska folder. Naya set add karna =
  // file upload karke sets/set_numbers badha dena. Dono bina rebuild ke.

  /// JSON ke "set_numbers" (ya "numbers") se explicit set list.
  List<int> _setNumbers(dynamic src) {
    if (src is! Map) return const <int>[];
    final dynamic raw = src['set_numbers'] ?? src['numbers'];
    if (raw is! List) return const <int>[];
    final List<int> out = <int>[];
    for (final dynamic v in raw) {
      final int? n = int.tryParse(v.toString());
      if (n != null && n > 0) out.add(n);
    }
    return out;
  }

  List<SectionalExamGroup> _groupsFor(String examKey) {
    final dynamic panelData = _liveData[examKey];
    if (panelData == null) return [];

    // Map Format (total_sets)
    if (panelData is Map && panelData.containsKey('total_sets')) {
      final List<int> nums = _setNumbers(panelData);
      return [
        SectionalExamGroup(
          title: _clean(panelData['title'] ?? '🏛️ Exam Special Zone'),
          sets: nums.isNotEmpty ? nums.length : (panelData['total_sets'] ?? 10),
          upcomingSets: panelData['upcoming_sets'] ?? 0,
          upcomingText: panelData['upcoming_text'] ?? "Coming Soon",
          pathPrefix: panelData['path_prefix'] ?? '$examKey/set',
          numbers: nums,
        ),
      ];
    }

    // List / Items Format
    List items = [];
    if (panelData is List) {
      items = panelData;
    } else if (panelData is Map && panelData['items'] is List) {
      items = panelData['items'];
    }

    return items.map<SectionalExamGroup>((item) {
      final String folder = item['folder'] ?? examKey;
      final List<int> nums = _setNumbers(item);
      return SectionalExamGroup(
        title: _clean(item['title'] ?? 'Sectional Mock'),
        sets: nums.isNotEmpty ? nums.length : (item['sets'] ?? 1),
        upcomingSets: item['upcoming_sets'] ?? 0,
        upcomingText: item['upcoming_text'] ?? "Live Tomorrow",
        pathPrefix: '$folder/set',
        numbers: nums,
      );
    }).toList();
  }

  // ---------- Exam families ----------
  // content_base me folder move hone par (jaise bpsc/cce + bpsc/aedo, ya
  // bssc/cgl + bssc/inter + bssc/ldc) app ko apne aap ek card bana dena
  // chahiye. Isliye family JSON ke folder/path_prefix se nikalti hai,
  // kisi hardcoded exam list se nahi.

  String _firstPath(dynamic data) {
    if (data is Map && data['path_prefix'] is String) {
      return data['path_prefix'] as String;
    }
    List<dynamic> items = const <dynamic>[];
    if (data is List) {
      items = data;
    } else if (data is Map && data['items'] is List) {
      items = data['items'] as List;
    }
    for (final dynamic it in items) {
      if (it is Map && it['folder'] is String) return it['folder'] as String;
    }
    return '';
  }

  String _familyOf(String key, dynamic data) {
    final Match? m = RegExp(r'sectional_mock/([^/]+)').firstMatch(_firstPath(data));
    return (m != null) ? m.group(1)! : key;
  }

  List<_ExamFamily> _families() {
    final Map<String, List<String>> byFamily = <String, List<String>>{};
    final List<String> order = <String>[];
    for (final String key in _liveData.keys) {
      final String fam = _familyOf(key, _liveData[key]);
      if (!byFamily.containsKey(fam)) {
        byFamily[fam] = <String>[];
        order.add(fam);
      }
      byFamily[fam]!.add(key);
    }
    return <_ExamFamily>[
      for (final String fam in order) _ExamFamily(fam, byFamily[fam]!),
    ];
  }

  static const Map<String, String> _subLabels = <String, String>{
    'bpsc': 'CCE',
    'bpsc_aedo': 'AEO',
    'bpsc_tre_primary': 'TRE PRIMARY',
    'bpsc_tre_middle': 'TRE MIDDLE',
    'bssc_cgl': 'CGL',
    'bssc_inter': 'INTER',
    'bssc_ldc': 'LDC',
  };

  String _subLabelFor(String key) {
    final dynamic d = _liveData[key];
    if (d is Map && d['sub_label'] is String && (d['sub_label'] as String).isNotEmpty) {
      return (d['sub_label'] as String).toUpperCase();
    }
    return _subLabels[key] ?? key.replaceAll('_', ' ').toUpperCase();
  }

  /// content_base ke JSON me kabhi HTML-escaped text chala jaata hai.
  String _clean(String text) =>
      text.replaceAll('&amp;', '&').replaceAll('&#39;', "'");

  // ---------- FOLDER TREE: content_base ke folder hi app ke level hain ----------
  //
  // Hub card -> folder -> sub-folder -> ... -> set files. Level kitne bhi hon,
  // structure JSON ke folder path se khud ban jaata hai:
  //
  //   sectional_mock/bpsc/aedo/aptitude/set1.json
  //     -> BPSC card -> AEO -> APTITUDE -> Set 1..5
  //   sectional_mock/bihar_si/set1.json
  //     -> BIHAR SI card -> seedha Set 1..5
  //
  // JSON se control (sab optional, kuch bhi na do to folder ke naam se default):
  //   key level  "folders": {
  //                  "aedo":            {"name":"AEO","badge":"...","icon":"🌾","color":"#BE123C"},
  //                  "aedo/aptitude":   {"name":"Quantitative Aptitude"}
  //                }
  //                -> path family ke folder ke relative, kitna bhi gehra ho.
  //   key level  "flatten": true   -> us family ke saare section ek hi list me
  //   item level "sub_exam", "sub_exam_badge", "sub_exam_icon", "sub_exam_color"
  //                -> family ke turant andar wale folder ka naam (chhota raasta)
  //
  // Ek suvidha rule: jis folder me sirf ek sub-folder ho aur apni koi set file
  // na ho, woh level skip ho jaata hai (btsc -> hostel_manager -> topics me se
  // beech wala level hat jaata hai, kyunki wahan choice hi nahi hai).

  /// Folder segment ke liye chhota display fallback. JSON hamesha jeetta hai.
  static const Map<String, String> _folderNames = <String, String>{
    'aedo': 'AEO',
    'cce': 'CCE',
    'cgl': 'CGL',
    'inter': 'INTER',
    'ldc': 'LDC',
  };

  static const List<Color> _folderPalette = <Color>[
    Color(0xFF7C3AED),
    Color(0xFF0D9488),
    Color(0xFFBE123C),
    Color(0xFF1D4ED8),
    Color(0xFFEA580C),
    Color(0xFF059669),
    Color(0xFF9333EA),
    Color(0xFFB45309),
  ];

  /// pathPrefix se family-relative folder path:
  /// "sectional_mock/bpsc/aedo/aptitude/set" -> "bpsc/aedo/aptitude".
  String _relFolderOf(String pathPrefix) {
    String p = pathPrefix;
    final int i = p.indexOf('sectional_mock/');
    if (i >= 0) p = p.substring(i + 'sectional_mock/'.length);
    final int slash = p.lastIndexOf('/'); // aakhri hissa set-file prefix hai
    if (slash > 0) p = p.substring(0, slash);
    return p.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  /// Ek JSON key ke item maps, usi order me jis order me _groupsFor groups deta hai.
  List<dynamic> _rawItemsFor(String key) {
    final dynamic d = _liveData[key];
    if (d is Map && d.containsKey('total_sets')) return <dynamic>[d];
    if (d is List) return d;
    if (d is Map && d['items'] is List) return d['items'] as List;
    return const <dynamic>[];
  }

  /// Pehle item par dhundo, warna key par (dict-format key ke liye).
  String _jsonStr(dynamic raw, dynamic keyData, String field) {
    for (final dynamic d in <dynamic>[raw, keyData]) {
      if (d is Map && d[field] is String && (d[field] as String).trim().isNotEmpty) {
        return (d[field] as String).trim();
      }
    }
    return '';
  }

  /// key level "folders" map me is path ka metadata (relative ya poora path).
  Map<String, dynamic> _folderMeta(_ExamFamily fam, String relPath, String fullPath) {
    for (final String key in fam.keys) {
      final dynamic d = _liveData[key];
      if (d is! Map || d['folders'] is! Map) continue;
      final Map<dynamic, dynamic> m = d['folders'] as Map;
      for (final String probe in <String>[relPath, fullPath]) {
        if (probe.isEmpty) continue;
        final dynamic hit = m[probe];
        if (hit is Map) return Map<String, dynamic>.from(hit);
      }
    }
    return const <String, dynamic>{};
  }

  String _metaStr(Map<String, dynamic> meta, String field) {
    final dynamic v = meta[field];
    return (v is String && v.trim().isNotEmpty) ? _clean(v.trim()) : '';
  }

  /// Title ke shuru ka emoji — leaf folder ke tile ka icon isi se banta hai.
  String _emojiOf(String title) {
    final List<String> parts = title.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    final String first = parts.first;
    if (first.runes.length > 3) return '';
    return first.runes.any((int r) => r > 0x2100) ? first : '';
  }

  /// Poora family folder tree. [colorIndex] hub card ki position hai.
  SectionalFolder _familyFolder(_ExamFamily fam, int colorIndex) {
    final Map<String, _NodeBuild> index = <String, _NodeBuild>{};

    _NodeBuild nodeFor(List<String> segs) {
      final String p = segs.join('/');
      final _NodeBuild? hit = index[p];
      if (hit != null) return hit;
      final _NodeBuild n = _NodeBuild(List<String>.from(segs));
      index[p] = n;
      if (segs.length > 1) {
        final _NodeBuild parent = nodeFor(segs.sublist(0, segs.length - 1));
        if (!parent.children.containsKey(segs.last)) {
          parent.children[segs.last] = n;
          parent.childOrder.add(segs.last);
        }
      }
      return n;
    }

    for (final String key in fam.keys) {
      final dynamic keyData = _liveData[key];
      final List<dynamic> raws = _rawItemsFor(key);
      final List<SectionalExamGroup> groups = _groupsFor(key);
      for (int i = 0; i < groups.length; i++) {
        final SectionalExamGroup g = groups[i];
        final dynamic raw = i < raws.length ? raws[i] : null;
        final String rel = _relFolderOf(g.pathPrefix);
        final List<String> segs = rel.isEmpty ? <String>[key] : rel.split('/');
        nodeFor(segs).groups.add(g);

        final String explicit = _clean(_jsonStr(raw, keyData, 'sub_exam'));
        if (explicit.isNotEmpty && segs.length >= 2) {
          final _NodeBuild first = nodeFor(segs.sublist(0, 2));
          if (first.overrideName.isEmpty) {
            first.overrideName = explicit.toUpperCase();
            first.overrideBadge = _clean(_jsonStr(raw, keyData, 'sub_exam_badge'));
            first.overrideIcon = _jsonStr(raw, keyData, 'sub_exam_icon');
            first.overrideColor = _colorField(raw, 'sub_exam_color') ??
                _jsonColor(raw) ??
                _colorField(keyData, 'sub_exam_color');
          }
        }
      }
    }

    if (index.isEmpty) {
      return SectionalFolder(
        path: fam.id,
        name: _familyTitle(fam),
        badge: '0 SETS',
        icon: _familyIcon(fam),
        color: _familyColor(fam, colorIndex),
        nameFromJson: true,
        groups: const <SectionalExamGroup>[],
        children: const <SectionalFolder>[],
      );
    }

    _NodeBuild root = index[fam.id] ?? index.values.first;
    for (final _NodeBuild n in index.values) {
      if (n.segs.length == 1) root = n;
    }

    // Ek hi section title do alag folder me ho to progress key takraati hai,
    // isliye sirf tab title me folder ka naam joda jaata hai. Screen par saaf
    // naam hi dikhta hai (displayTitle) aur purana record migrate ho jaata hai.
    final Map<String, Set<String>> parentsByTitle = <String, Set<String>>{};
    for (final _NodeBuild n in index.values) {
      final String parentPath = n.segs.length > 1 ? n.segs.sublist(0, n.segs.length - 1).join('/') : '';
      for (final SectionalExamGroup g in n.groups) {
        final Set<String> seen = parentsByTitle[g.title] ?? <String>{};
        seen.add(parentPath);
        parentsByTitle[g.title] = seen;
      }
    }
    final Set<String> clash = <String>{
      for (final MapEntry<String, Set<String>> e in parentsByTitle.entries)
        if (e.value.length > 1) e.key,
    };

    return _toFolder(fam, root, colorIndex, 0, '', true, clash);
  }

  SectionalFolder _toFolder(
    _ExamFamily fam,
    _NodeBuild n,
    int colorIndex,
    int childIndex,
    String parentName,
    bool isRoot,
    Set<String> clash,
  ) {
    final String fullPath = n.segs.join('/');
    final String relPath = n.segs.length > 1 ? n.segs.sublist(1).join('/') : '';
    final Map<String, dynamic> meta = isRoot ? const <String, dynamic>{} : _folderMeta(fam, relPath, fullPath);
    final String last = n.segs.last;

    String name;
    if (isRoot) {
      name = _familyTitle(fam);
    } else {
      name = _metaStr(meta, 'name');
      if (name.isEmpty) name = n.overrideName;
      if (name.isEmpty) name = _folderNames[last] ?? last.replaceAll('_', ' ').toUpperCase();
    }
    final bool nameFromJson = isRoot || _metaStr(meta, 'name').isNotEmpty || n.overrideName.isNotEmpty;

    List<SectionalFolder> kids = <SectionalFolder>[
      for (int i = 0; i < n.childOrder.length; i++)
        _toFolder(fam, n.children[n.childOrder[i]]!, colorIndex, i, name, false, clash),
    ];

    // "flatten": true -> is level ke neeche ka sab kuch ek hi list me.
    bool flatten = meta['flatten'] == true;
    if (isRoot) {
      for (final String key in fam.keys) {
        final dynamic d = _liveData[key];
        if (d is Map && d['flatten'] == true) flatten = true;
      }
    }

    final String prefix = (!isRoot && parentName.isNotEmpty) ? parentName : name;
    List<SectionalExamGroup> own = <SectionalExamGroup>[
      for (final SectionalExamGroup g in n.groups)
        (clash.contains(g.title) && !g.title.toUpperCase().contains(prefix))
            ? SectionalExamGroup(
                title: '$prefix · ${g.title}',
                displayTitle: g.title,
                sets: g.sets,
                upcomingSets: g.upcomingSets,
                upcomingText: g.upcomingText,
                pathPrefix: g.pathPrefix,
                numbers: g.numbers,
              )
            : SectionalExamGroup(
                title: g.title,
                displayTitle: g.title,
                sets: g.sets,
                upcomingSets: g.upcomingSets,
                upcomingText: g.upcomingText,
                pathPrefix: g.pathPrefix,
                numbers: g.numbers,
              ),
    ];

    if (flatten && kids.isNotEmpty) {
      own = <SectionalExamGroup>[
        ...own,
        for (final SectionalFolder k in kids) ...k.allGroups,
      ];
      kids = <SectionalFolder>[];
    }

    final int total = own.fold<int>(0, (int s, SectionalExamGroup g) => s + g.setNums.length) +
        kids.fold<int>(0, (int s, SectionalFolder k) => s + k.totalSets);

    String badge = _metaStr(meta, 'badge');
    if (badge.isEmpty && !isRoot) badge = n.overrideBadge;
    if (badge.isEmpty) badge = '$total SETS';

    String icon = _metaStr(meta, 'icon');
    if (icon.isEmpty && !isRoot) icon = n.overrideIcon;
    if (icon.isEmpty && own.isNotEmpty) {
      final SectionalExamGroup g0 = own.first;
      icon = _emojiOf(g0.displayTitle.isEmpty ? g0.title : g0.displayTitle);
    }
    if (icon.isEmpty) icon = isRoot ? _familyIcon(fam) : (kids.isNotEmpty ? '📁' : '📄');

    Color? color = _colorField(meta, 'color');
    if (color == null && !isRoot) color = n.overrideColor;
    if (color == null) {
      color = isRoot ? _familyColor(fam, colorIndex) : _folderPalette[childIndex % _folderPalette.length];
    }

    // Sirf ek sub-folder aur apni koi set file nahi -> beech ka level skip.
    if (kids.length == 1 && own.isEmpty) return kids.first;

    return SectionalFolder(
      path: fullPath,
      name: name,
      badge: badge,
      icon: icon,
      color: color,
      nameFromJson: nameFromJson,
      groups: own,
      children: kids,
    );
  }

  /// Family ke saare section groups (folder tree ke order me).
  List<SectionalExamGroup> _groupsForFamily(_ExamFamily fam) => _familyFolder(fam, 0).allGroups;

  String _familyTitle(_ExamFamily fam) {
    for (final String key in fam.keys) {
      final dynamic d = _liveData[key];
      if (d is Map && d['family_title'] is String && (d['family_title'] as String).isNotEmpty) {
        return _clean(d['family_title'] as String);
      }
    }
    if (fam.keys.length == 1) {
      return _clean(_formatExamTitle(fam.keys.first, _liveData[fam.keys.first]));
    }
    switch (fam.id) {
      case 'bpsc':
        return 'BPSC';
      case 'bssc':
        return 'BSSC';
      case 'btsc':
        return 'BTSC';
      case 'bpsc_tre':
        return 'BPSC TRE';
    }
    return fam.id.replaceAll('_', ' ').toUpperCase();
  }

  String _familyBadge(_ExamFamily fam) {
    for (final String key in fam.keys) {
      final dynamic d = _liveData[key];
      if (d is Map && d['family_badge'] is String && (d['family_badge'] as String).isNotEmpty) {
        return _clean(d['family_badge'] as String);
      }
    }
    if (fam.keys.length == 1) {
      return _clean(_formatExamBadge(fam.keys.first, _liveData[fam.keys.first]));
    }
    // Kai key ek hi folder me: card ke pill par folder ke naam dikha do.
    final List<SectionalFolder> kids = _familyFolder(fam, 0).children;
    if (kids.length > 1) {
      final String joined = kids.map((SectionalFolder k) => k.name).join(' • ');
      return joined.length <= 24 ? joined : '${kids.length} FOLDERS';
    }
    return fam.keys.map(_subLabelFor).join(' • ');
  }

  String _familyIcon(_ExamFamily fam) {
    for (final String key in fam.keys) {
      final dynamic d = _liveData[key];
      if (d is Map && d['icon'] is String && (d['icon'] as String).isNotEmpty) {
        return d['icon'] as String;
      }
    }
    if (fam.keys.length == 1) return _examIcon(fam.keys.first);
    switch (fam.id) {
      case 'bpsc':
        return '🏛️';
      case 'bssc':
        return '🎓';
      case 'btsc':
        return '🏨';
    }
    return '🎯';
  }

  Color _familyColor(_ExamFamily fam, int index) {
    for (final String key in fam.keys) {
      final Color? c = _jsonColor(_liveData[key]);
      if (c != null) return c;
    }
    if (fam.keys.length == 1) return _resolveColor(fam.keys.first, index);
    switch (fam.id) {
      case 'bpsc':
        return const Color(0xFF9D174D);
      case 'bssc':
        return const Color(0xFF6B21A8);
      case 'btsc':
        return const Color(0xFF0D9488);
    }
    return _resolveColor(fam.keys.first, index);
  }

  ({int done, int total}) _familyCounts(_ExamFamily fam) {
    int done = 0;
    int total = 0;
    for (final SectionalExamGroup g in _groupsForFamily(fam)) {
      total += g.setNums.length;
      for (final int n in g.setNums) {
        if (_progress[g.launchTitle(n)]?['status'] == 'COMPLETED') done++;
      }
    }
    return (done: done, total: total);
  }

  /// Next suggested set: pehle koi In-Progress, warna pehla bacha hua set.
  Map<String, dynamic>? _nextCandidate(List<_ExamFamily> families) {
    Map<String, dynamic>? firstLeft;
    for (final _ExamFamily fam in families) {
      final counts = _familyCounts(fam);
      for (final SectionalExamGroup g in _groupsForFamily(fam)) {
        for (final int n in g.setNums) {
          final String title = g.launchTitle(n);
          final String? status = _progress[title]?['status']?.toString();
          if (status == 'IN_PROGRESS') {
            return {
              'title': title,
              'path': g.launchPath(n),
              'examTitle': _familyTitle(fam),
              'setNum': n,
              'inProgress': true,
              'done': counts.done,
              'total': counts.total,
            };
          }
          if (status != 'COMPLETED' && firstLeft == null) {
            firstLeft = {
              'title': title,
              'path': g.launchPath(n),
              'examTitle': _familyTitle(fam),
              'setNum': n,
              'inProgress': false,
              'done': counts.done,
              'total': counts.total,
            };
          }
        }
      }
    }
    return firstLeft;
  }

  void _launch(BuildContext context, String title, String path) {
    _refreshPending = true;
    widget.onLaunchCbtMock(context, title, path);
  }

  void _openExam(BuildContext context, _ExamFamily fam, int index) {
    final SectionalFolder root = _familyFolder(fam, index);

    // Jitne folder hain utne level: sub-folder ho to folder screen, warna
    // seedha set files ki list.
    if (root.children.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SectionalFolderScreen(
            folder: root,
            crumb: _familyTitle(fam),
            isDarkMode: widget.isDarkMode,
            progressLoader: _loadProgressMap,
            onLaunchCbtMock: widget.onLaunchCbtMock,
            onShowUpcoming: _showUpcomingNotice,
          ),
        ),
      ).then((_) => _refreshProgress());
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SectionalExamScreen(
          examTitle: _familyTitle(fam),
          badge: _familyBadge(fam),
          icon: _familyIcon(fam),
          color: _familyColor(fam, index),
          isDarkMode: widget.isDarkMode,
          groups: root.allGroups,
          progressLoader: _loadProgressMap,
          onLaunchCbtMock: widget.onLaunchCbtMock,
          onShowUpcoming: _showUpcomingNotice,
        ),
      ),
    ).then((_) => _refreshProgress());
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    if (_liveData.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isDark = widget.isDarkMode;
    final Color textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE8EDF7);

    final List<_ExamFamily> families = _families();
    final candidate = families.isEmpty ? null : _nextCandidate(families);
    final bool anyProgress = _progress.values.any((p) => p['status'] == 'COMPLETED' || p['status'] == 'IN_PROGRESS');

    return RefreshIndicator(
      color: const Color(0xFF2563EB),
      onRefresh: () async {
        await _fetchLiveGitHubData();
        await _refreshProgress();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎯 Sectional Mocks', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.3)),
                    const SizedBox(height: 3),
                    Text(
                      'Apna target exam chuno aur real CBT pattern par set lagao',
                      style: TextStyle(color: subTextColor, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF2563EB)),
                ),
            ],
          ),

          if (families.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'Abhi koi exam data available nahi hai.\nInternet on karke pull-down refresh karo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: subTextColor, height: 1.6),
              ),
            )
          else ...[
            // Next Set hero
            if (candidate != null) ...[
              const SizedBox(height: 20),
              _sectionHead(
                candidate['inProgress'] == true ? '⏯️ Aadha Ruka Set' : '⏭️ Tumhara Next Set',
                candidate['inProgress'] == true ? 'RESUME' : 'AUTO SUGGEST',
                textColor,
              ),
              const SizedBox(height: 10),
              _nextHero(context, candidate),
            ] else if (anyProgress) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF14532D), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🎉 Badhai Ho!', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text(
                      'Saare available sets complete ho gaye hain. Kisi bhi set ko Re-attempt karke apna score aur improve karo!',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],

            // Exams grid
            const SizedBox(height: 20),
            _sectionHead('🏛️ Target Exams', '${families.length} EXAMS', textColor),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.98,
              ),
              itemCount: families.length,
              itemBuilder: (ctx, i) {
                final _ExamFamily fam = families[i];
                final Color color = _familyColor(fam, i);
                final counts = _familyCounts(fam);
                final double pct = counts.total == 0 ? 0 : counts.done / counts.total;
                return Material(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(19),
                  child: InkWell(
                    onTap: () => _openExam(ctx, fam, i),
                    borderRadius: BorderRadius.circular(19),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.25 : 0.10), borderRadius: BorderRadius.circular(13)),
                            child: Center(child: Text(_familyIcon(fam), style: const TextStyle(fontSize: 20))),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _familyTitle(fam),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.25 : 0.10), borderRadius: BorderRadius.circular(99)),
                            child: Text(
                              _familyBadge(fam),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.6),
                            ),
                          ),
                          const SizedBox(height: 11),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F7),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '${counts.done} / ${counts.total} sets done',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: subTextColor),
                              ),
                              const Spacer(),
                              Text(
                                '${counts.total} SETS ›',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: color),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            Text(
              'Exams aur sets live content se auto-update hote hain — naya set add hote hi resumable yahi dikhega, bina app update ke.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: subTextColor, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHead(String title, String tag, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.2)),
        Text(tag, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF2563EB), letterSpacing: 0.6)),
      ],
    );
  }

  Widget _nextHero(BuildContext context, Map<String, dynamic> candidate) {
    final int done = candidate['done'] as int;
    final int total = candidate['total'] as int;
    final bool inProgress = candidate['inProgress'] == true;
    final String examTitle = candidate['examTitle'] as String;
    // Every available set is unlocked for this Google Play release.
    return InkWell(
      onTap: () => _launch(
        context,
        candidate['title'] as String,
        candidate['path'] as String,
      ),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF172554), Color(0xFF1E40AF), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E40AF).withValues(alpha: 0.32),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(99)),
              child: Text(
                inProgress ? '✦ SET BEECH ME RUKA HAI' : '✦ NEXT SET READY HAI',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF451A03), letterSpacing: 0.8),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              candidate['title'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 17.5, fontWeight: FontWeight.w900, height: 1.25),
            ),
            const SizedBox(height: 4),
            Text(
              inProgress
                  ? 'Ye set aadha attempt hua hai — wahi se resume karo!'
                  : 'Yahi se apni practice aage badhao — $examTitle ka agla set.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  '$examTitle • $done / $total sets complete',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    inProgress ? 'Resume Karo →' : 'Set Start Karo →',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF451A03)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Folder tree banate waqt ka mutable node (baad me SectionalFolder banta hai).
class _NodeBuild {
  final List<String> segs;
  final List<String> childOrder = <String>[];
  final Map<String, _NodeBuild> children = <String, _NodeBuild>{};
  final List<SectionalExamGroup> groups = <SectionalExamGroup>[];
  String overrideName = '';
  String overrideBadge = '';
  String overrideIcon = '';
  Color? overrideColor;

  _NodeBuild(this.segs);
}

/// Ek exam family = sectional_mock ke ek hi folder ke saare JSON keys.
/// Example: bpsc/cce + bpsc/aedo -> ek "BPSC" card.
class _ExamFamily {
  final String id;
  final List<String> keys;

  const _ExamFamily(this.id, this.keys);
}
