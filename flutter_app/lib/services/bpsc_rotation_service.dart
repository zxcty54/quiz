import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bpsc_daily_card_model.dart';

class DayConfig {
  final List<String> filePool; // Multiple files rotate per day
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
  // 7-Day Cycle mapping covering all your uploaded JSON files
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
      filePool: ["census_and_demographics.json", "moderngovernance.json", "gitag.json", "artist.json", "literature.json"],
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

  static Future<dynamic> _fetchWithMirrors(String fileName) async {
    final List<String> mirrors = [
      "https://raw.githubusercontent.com/zxcty54/content_base/main/knowyourbihar/$fileName",
      "https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/knowyourbihar/$fileName",
      "https://raw.githack.com/zxcty54/content_base/main/knowyourbihar/$fileName",
    ];

    for (String url in mirrors) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          String body = utf8.decode(res.bodyBytes).trim();
          if (body.startsWith('\uFEFF')) body = body.substring(1).trim();
          return json.decode(body);
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static Future<BpscDailyPayload> fetchTodayPayload() async {
    final now = DateTime.now();
    final config = dayConfigurations[now.weekday] ?? dayConfigurations[DateTime.monday]!;
    final weekNum = _getWeekOfYear(now);

    // Pick target file based on week offset
    final String targetFile = config.filePool[weekNum % config.filePool.length];
    final decoded = await _fetchWithMirrors(targetFile);

    if (decoded == null) {
      throw Exception("Unable to load daily data from mirrors for $targetFile");
    }

    List<dynamic> items = [];
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      items = decoded['data'] ??
          decoded['items'] ??
          decoded['records'] ??
          [decoded];
    }

    if (items.isEmpty) {
      throw Exception("Empty items found in $targetFile");
    }

    // Weekly sequential index rotation
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
