// v1 source: flutter_app/lib/services/bpsc_rotation_service.dart

import 'package:flutter/foundation.dart';

import 'package:mocktester_v2/features/bihar_gk/domain/bpsc_daily_card_model.dart';
import 'package:mocktester_v2/core/network/json_fetcher.dart';

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

  /// Downloads one `knowyourbihar/*.json` file through the shared loader
  /// (longer timeout because these files are large).
  static Future<dynamic> _fetchWithMirrors(String fileName) {
    return JsonFetcher.instance.fetchRobust(
      'knowyourbihar/$fileName',
      timeout: const Duration(seconds: 12),
    );
  }

  static Future<BpscDailyPayload> fetchTodayPayload() async {
    final now = DateTime.now();
    final config = dayConfigurations[now.weekday] ?? dayConfigurations[DateTime.monday]!;
    final weekNum = _getWeekOfYear(now);

    final String targetFile = config.filePool[weekNum % config.filePool.length];
    debugPrint("Target file for today: $targetFile");

    final decoded = await _fetchWithMirrors(targetFile);

    if (decoded == null) {
      throw Exception("Network Timeout: $targetFile mirror URL se download nahi ho saka.");
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
      throw Exception("Invalid File: $targetFile ke andar koi valid items list nahi mili.");
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
