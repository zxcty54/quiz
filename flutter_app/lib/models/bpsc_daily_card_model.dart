class BpscDailyCardModel {
  final String title;
  final String category;
  final String summary;
  final String? district;
  final List<String> bulletPoints;
  final List<Map<String, String>> pyqFacts;
  final Map<String, dynamic> rawJson;
  final String watermark;

  BpscDailyCardModel({
    required this.title,
    required this.category,
    required this.summary,
    this.district,
    required this.bulletPoints,
    required this.pyqFacts,
    required this.rawJson,
    required this.watermark,
  });

  factory BpscDailyCardModel.fromUniversalJson(
      Map<String, dynamic> json, String fallbackWatermark) {
    // 1. Title Extraction
    String title = json['name'] ??
        json['zone_name'] ??
        json['site_name'] ??
        json['indicator_name'] ??
        json['crop_name'] ??
        json['plant_name'] ??
        json['report_title'] ??
        json['monument_name'] ??
        json['product_name'] ??
        json['mineral_name'] ??
        json['river_name'] ??
        json['soil_name'] ??
        json['waterbody_name'] ??
        json['sanctuary_name'] ??
        json['title'] ??
        'Bihar Special Focus';

    // 2. Category / Subtitle
    String category = json['popular_title'] ??
        json['popular_tag'] ??
        json['category'] ??
        json['era_category'] ??
        json['energy_type'] ??
        json['crop_type'] ??
        json['official_status'] ??
        json['nature'] ??
        json['regional_nickname'] ??
        json['total_districts'] ??
        'Static GK Profile';

    // 3. District / Location Finder
    String? district;
    if (json['location'] is Map) {
      district = json['location']['district']?.toString();
    } else if (json['birth_and_roots'] is Map &&
        json['birth_and_roots']['birth_place'] != null) {
      district = json['birth_and_roots']['birth_place'].toString().split(',').last.trim();
    } else if (json['districts_covered'] is List && (json['districts_covered'] as List).isNotEmpty) {
      district = (json['districts_covered'] as List).first.toString();
    } else if (json['primary_districts'] is List && (json['primary_districts'] as List).isNotEmpty) {
      district = (json['primary_districts'] as List).first.toString();
    } else if (json['core_districts'] is List && (json['core_districts'] as List).isNotEmpty) {
      district = (json['core_districts'] as List).first.toString();
    } else if (json['top_producing_districts'] is List && (json['top_producing_districts'] as List).isNotEmpty) {
      district = (json['top_producing_districts'] as List).first.toString();
    }

    // 4. One-Liner Summary
    String summary = 'Exam-oriented high yield facts for BPSC & Bihar state examinations.';
    for (var entry in json.entries) {
      if (entry.value is Map && entry.value['summary'] != null && entry.value['summary'].toString().trim().isNotEmpty) {
        summary = entry.value['summary'].toString().trim();
        break;
      }
    }
    if (summary.startsWith('Exam-oriented') && json['qualifying_benchmark'] != null) {
      summary = json['qualifying_benchmark'].toString();
    } else if (summary.startsWith('Exam-oriented') && json['national_comparison'] != null) {
      summary = json['national_comparison'].toString();
    }

    // 5. Structure-Aware Bullet Points
    List<String> bullets = [];

    // History / Leaders / Literature
    if (json['birth_and_roots'] is Map && json['birth_and_roots']['birth_place'] != null) {
      bullets.add('Birth / Roots: ${json['birth_and_roots']['birth_place']}');
    }
    if (json['major_contributions_and_role'] is Map && json['major_contributions_and_role']['key_areas'] != null) {
      bullets.add('Key Contributions: ${json['major_contributions_and_role']['key_areas']}');
    }
    if (json['organizations_and_literary_works'] is Map) {
      final org = json['organizations_and_literary_works'] as Map;
      if (org['famous_works_or_edicts'] is List) {
        bullets.add('Works / Literature: ${(org['famous_works_or_edicts'] as List).join(", ")}');
      } else if (org['institutions_or_initiatives'] is List) {
        bullets.add('Initiatives: ${(org['institutions_or_initiatives'] as List).join(", ")}');
      }
    }

    // Geography / Rivers / Waterfalls / Caves
    if (json['geographical_metrics'] is Map) {
      final geo = json['geographical_metrics'] as Map;
      if (geo['bihar_entry_point'] != null) bullets.add('Entry in Bihar: ${geo['bihar_entry_point']}');
      if (geo['confluence_point'] != null) bullets.add('Confluence: ${geo['confluence_point']}');
      if (geo['tributaries'] is List) bullets.add('Tributaries: ${(geo['tributaries'] as List).join(", ")}');
    }
    if (json['physical_features_and_climate'] is Map && json['physical_features_and_climate']['temperature_or_height'] != null) {
      bullets.add('Height / Features: ${json['physical_features_and_climate']['temperature_or_height']}');
    }
    if (json['architectural_and_structural_features'] is Map && json['architectural_and_structural_features']['materials_used'] is List) {
      bullets.add('Architecture / Material: ${(json['architectural_and_structural_features']['materials_used'] as List).join(", ")}');
    }

    // Agriculture / Crops / Power / Minerals / Census / Forest
    if (json['cropping_profile_and_economy'] is Map && json['cropping_profile_and_economy']['key_crops_grown'] is List) {
      bullets.add('Key Crops: ${(json['cropping_profile_and_economy']['key_crops_grown'] as List).join(", ")}');
    }
    if (json['economic_and_crop_dynamics'] is Map && json['economic_and_crop_dynamics']['key_crops'] is List) {
      bullets.add('Key Crops: ${(json['economic_and_crop_dynamics']['key_crops'] as List).join(", ")}');
    }
    if (json['technical_metrics'] is Map && json['technical_metrics']['installed_capacity_mw'] != null) {
      bullets.add('Installed Capacity: ${json['technical_metrics']['installed_capacity_mw']}');
    }
    if (json['reserves_and_economic_impact'] is Map && json['reserves_and_economic_impact']['national_share'] != null) {
      bullets.add('National Reserve Share: ${json['reserves_and_economic_impact']['national_share']}');
    }
    if (json['state_totals'] is Map) {
      final st = json['state_totals'] as Map;
      if (st['total_forest_cover_sq_km'] != null) bullets.add('Forest Cover: ${st['total_forest_cover_sq_km']} (${st['forest_cover_percentage'] ?? ''})');
      if (st['total_green_cover'] != null) bullets.add('Total Green Cover: ${st['total_green_cover']}');
    }
    if (json['state_average_metric'] != null) {
      bullets.add('Census Metric: ${json['state_average_metric']}');
    }

    // 6. PYQ Facts Extractor
    List<Map<String, String>> pyqs = [];
    if (json['exam_facts_and_pyqs'] is List) {
      for (var item in json['exam_facts_and_pyqs']) {
        if (item is Map) {
          pyqs.add({
            'topic': item['topic']?.toString() ?? 'Important Exam Trigger',
            'detail': item['detail']?.toString() ?? '',
          });
        }
      }
    }

    return BpscDailyCardModel(
      title: title,
      category: category,
      summary: summary,
      district: district,
      bulletPoints: bullets,
      pyqFacts: pyqs,
      rawJson: json,
      watermark: json['popular_tag'] ?? fallbackWatermark,
    );
  }
}
