import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bpsc_daily_card_model.dart';

class DayConfig {
  final List<String> filePool;
  final String cycleDay;
  final String domain;
  final int colorSeed;
  final String defaultWatermark;
  final String emoji;

  const DayConfig({
    required this.filePool,
    required this.cycleDay,
    required this.domain,
    required this.colorSeed,
    required this.defaultWatermark,
    required this.emoji,
  });
}

class BpscRotationService {
  static final Map<int, DayConfig> dayConfigurations = {
    DateTime.monday: const DayConfig(
      filePool: ["rivers.json", "waterfalls_and_springs.json"],
      cycleDay: "DAY 01",
      domain: "HYDROLOGY, RIVERS & WATERBODIES",
      colorSeed: 0xFF0284C7,
      defaultWatermark: "RIVERS",
      emoji: "🌊",
    ),
    DateTime.tuesday: const DayConfig(
      filePool: ["ancient.json", "freedomfighter.json", "triballeader.json"],
      cycleDay: "DAY 02",
      domain: "HISTORY, PERSONALITIES & REVOLT",
      colorSeed: 0xFFD97706,
      defaultWatermark: "HISTORY",
      emoji: "👑",
    ),
    DateTime.wednesday: const DayConfig(
      filePool: ["agroclimate.json", "crops.json", "soil.json"],
      cycleDay: "DAY 03",
      domain: "AGRICULTURE, SOILS & CROPS",
      colorSeed: 0xFF059669,
      defaultWatermark: "AGRI",
      emoji: "🌾",
    ),
    DateTime.thursday: const DayConfig(
      filePool: ["caves_and_stupas.json", "forts_and_tombs.json"],
      cycleDay: "DAY 04",
      domain: "HERITAGE, CAVES & ARCHITECTURE",
      colorSeed: 0xFFBE185D,
      defaultWatermark: "HERITAGE",
      emoji: "🏛️",
    ),
    DateTime.friday: const DayConfig(
      filePool: ["wildlife_and_bird_sanctuaries.json", "forest_profile_isfr.json"],
      cycleDay: "DAY 05",
      domain: "FORESTS, PARKS & ECO-SITES",
      colorSeed: 0xFF0D9488,
      defaultWatermark: "WILDLIFE",
      emoji: "🐅",
    ),
    DateTime.saturday: const DayConfig(
      filePool: ["minerals_of_bihar.json", "energy_and_power_plants.json"],
      cycleDay: "DAY 06",
      domain: "MINERALS, ENERGY & INFRA",
      colorSeed: 0xFFDC2626,
      defaultWatermark: "MINERALS",
      emoji: "⛰️",
    ),
    DateTime.sunday: const DayConfig(
      filePool: [
        "census_and_demographics.json",
        "moderngovernance.json",
        "gitag.json",
        "artist.json",
        "literature.json"
      ],
      cycleDay: "DAY 07",
      domain: "GOVERNANCE, CENSUS & ART CULTURE",
      colorSeed: 0xFF7C3AED,
      defaultWatermark: "CENSUS",
      emoji: "📊",
    ),
  };

  static int _getWeekOfYear(DateTime date) {
    DateTime startOfYear = DateTime(date.year, 1, 1);
    int firstDayOffset = startOfYear.weekday;
    int dayOfYear = date.difference(startOfYear).inDays;
    return ((dayOfYear + firstDayOffset) / 7).ceil();
  }

  // 🚀 Fast Multi-CDN Fetcher (Cloudflare Edge Primary + Failovers)
  static Future<dynamic> _fetchWithMirrors(String fileName) async {
    final int ts = DateTime.now().millisecondsSinceEpoch;
    final String cleanFile = fileName.trim();

    final List<String> mirrors = [
      // ⚡ Primary: Cloudflare Edge (Statically CDN)
      "https://cdn.statically.io/gh/zxcty54/content_base/main/knowyourbihar/$cleanFile?t=$ts",
      // 🔄 Fallback 1: Fastly CDN
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/knowyourbihar/$cleanFile?t=$ts",
      // 🔄 Fallback 2: jsDelivr Global
      "https://cdn.jsdelivr.net/gh/zxcty54/content_base@main/knowyourbihar/$cleanFile?t=$ts",
      // 🔄 Fallback 3: GitHack Cloudflare proxy
      "https://raw.githack.com/zxcty54/content_base/main/knowyourbihar/$cleanFile",
      // 🛡️ Fallback 4: Raw GitHub (Emergency backup)
      "https://raw.githubusercontent.com/zxcty54/content_base/main/knowyourbihar/$cleanFile?t=$ts",
    ];

    for (String url in mirrors) {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: const {
            'Accept': 'application/json, text/plain, */*',
            'Cache-Control': 'no-cache',
            'User-Agent': 'MockTesterApp-Flutter',
          },
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          String body = utf8.decode(res.bodyBytes).trim();
          if (body.startsWith('\uFEFF')) body = body.substring(1).trim();

          if (!body.startsWith('<') && !body.startsWith('<!DOCTYPE')) {
            final decoded = json.decode(body);
            if (decoded != null) {
              // Cache save karein
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('cached_kyb_$cleanFile', body);
              return decoded;
            }
          }
        }
      } catch (_) {
        continue;
      }
    }

    // 💾 Saare mirrors fail hone par local cache se fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_kyb_$cleanFile');
      if (cached != null && cached.isNotEmpty) {
        return json.decode(cached);
      }
    } catch (_) {}

    return null;
  }

  static Future<BpscDailyPayload> fetchTodayPayload() async {
    final now = DateTime.now();
    final config = dayConfigurations[now.weekday] ?? dayConfigurations[DateTime.monday]!;
    final weekNum = _getWeekOfYear(now);

    final String targetFile = config.filePool[weekNum % config.filePool.length];
    final decoded = await _fetchWithMirrors(targetFile);

    if (decoded == null) {
      throw Exception("Network unavailable. Please check your internet connection.");
    }

    List<dynamic> items = [];
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      for (var key in ['data', 'items', 'records', 'personalities', 'sites', 'districts']) {
        if (decoded[key] is List) {
          items = decoded[key];
          break;
        }
      }
      if (items.isEmpty) items = [decoded];
    }

    if (items.isEmpty) {
      throw Exception("Invalid File: Data format not recognized.");
    }

    final int activeIndex = (weekNum ~/ config.filePool.length) % items.length;
    final selectedRaw = Map<String, dynamic>.from(items[activeIndex]);

    final card = BpscDailyCardModel.fromUniversalJson(selectedRaw, config.defaultWatermark);
    return BpscDailyPayload(config: config, card: card);
  }
}

class BpscDailyPayload {
  final DayConfig config;
  final BpscDailyCardModel card;

  BpscDailyPayload({required this.config, required this.card});
}
