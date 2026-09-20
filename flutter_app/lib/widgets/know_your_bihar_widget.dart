class ContentBlock {
  final String title;
  final List<String> bulletItems;
  final String? longDescription;

  ContentBlock({
    required this.title,
    required this.bulletItems,
    this.longDescription,
  });
}

class BpscDailyCardModel {
  final String title;
  final String category;
  final String summary;
  final String? district;
  final List<String> frontHighlights;
  final List<ContentBlock> allSections;
  final List<Map<String, String>> pyqFacts;
  final String watermark;

  BpscDailyCardModel({
    required this.title,
    required this.category,
    required this.summary,
    this.district,
    required this.frontHighlights,
    required this.allSections,
    required this.pyqFacts,
    required this.watermark,
  });

  factory BpscDailyCardModel.fromUniversalJson(
      Map<String, dynamic> json, String fallbackWatermark) {
    // 1. Primary Title
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

    // 2. Subtitle / Popular Tag
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

    // 3. District Finder
    String? district;
    if (json['location'] is Map) {
      district = json['location']['district']?.toString();
    } else if (json['birth_and_roots'] is Map &&
        json['birth_and_roots']['birth_place'] != null) {
      district = json['birth_and_roots']['birth_place']
          .toString()
          .split(',')
          .last
          .trim();
    } else if (json['districts_covered'] is List &&
        (json['districts_covered'] as List).isNotEmpty) {
      district = (json['districts_covered'] as List).first.toString();
    } else if (json['primary_districts'] is List &&
        (json['primary_districts'] as List).isNotEmpty) {
      district = (json['primary_districts'] as List).first.toString();
    } else if (json['core_districts'] is List &&
        (json['core_districts'] as List).isNotEmpty) {
      district = (json['core_districts'] as List).first.toString();
    } else if (json['top_producing_districts'] is List &&
        (json['top_producing_districts'] as List).isNotEmpty) {
      district = (json['top_producing_districts'] as List).first.toString();
    }

    // 4. Quick Summary / Benchmark
    String summary =
        'Exam-oriented high yield facts for BPSC & Bihar state examinations.';
    for (var entry in json.entries) {
      if (entry.value is Map &&
          entry.value['summary'] != null &&
          entry.value['summary'].toString().trim().isNotEmpty) {
        summary = entry.value['summary'].toString().trim();
        break;
      }
    }
    if (summary.startsWith('Exam-oriented') &&
        json['qualifying_benchmark'] != null) {
      summary = json['qualifying_benchmark'].toString();
    } else if (summary.startsWith('Exam-oriented') &&
        json['national_comparison'] != null) {
      summary = json['national_comparison'].toString();
    }

    // 5. Complete Dynamic Extraction (No data drop)
    List<ContentBlock> dynamicSections = [];
    List<String> frontCardFacts = [];

    final skipKeys = [
      'id', 'name', 'zone_name', 'site_name', 'indicator_name', 'crop_name',
      'plant_name', 'report_title', 'monument_name', 'product_name',
      'mineral_name', 'river_name', 'soil_name', 'waterbody_name',
      'sanctuary_name', 'title', 'popular_title', 'popular_tag', 'category',
      'era_category', 'energy_type', 'crop_type', 'official_status', 'nature',
      'regional_nickname', 'exam_facts_and_pyqs'
    ];

    String formatHeading(String raw) {
      return raw
          .replaceAll('_', ' ')
          .split(' ')
          .map((str) => str.isNotEmpty
              ? '${str[0].toUpperCase()}${str.substring(1)}'
              : '')
          .join(' ');
    }

    json.forEach((key, value) {
      if (skipKeys.contains(key) || value == null) return;

      String sectionTitle = formatHeading(key);
      List<String> items = [];
      String? desc;

      if (value is Map) {
        value.forEach((subKey, subVal) {
          if (subVal == null) return;
          String subTitle = formatHeading(subKey);

          if ([
            'explanation',
            'background_context',
            'detailed_role',
            'historical_narrative'
          ].contains(subKey)) {
            desc = subVal.toString().trim();
          } else if (subVal is List) {
            items.add('$subTitle: ${subVal.join(", ")}');
          } else if (subVal is Map) {
            subVal.forEach((k, v) => items.add('${formatHeading(k)}: $v'));
          } else {
            items.add('$subTitle: $subVal');
          }
        });
      } else if (value is List) {
        items.add(value.join(", "));
      } else {
        items.add(value.toString());
      }

      if (items.isNotEmpty || desc != null) {
        dynamicSections.add(ContentBlock(
          title: sectionTitle,
          bulletItems: items,
          longDescription: desc,
        ));
      }
    });

    for (var sec in dynamicSections) {
      for (var it in sec.bulletItems) {
        if (!it.toLowerCase().contains('summary') &&
            frontCardFacts.length < 2) {
          frontCardFacts.add(it);
        }
      }
    }

    // 6. PYQ Facts
    List<Map<String, String>> pyqs = [];
    if (json['exam_facts_and_pyqs'] is List) {
      for (var item in json['exam_facts_and_pyqs']) {
        if (item is Map) {
          pyqs.add({
            'topic': item['topic']?.toString() ?? 'Exam Trigger',
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
      frontHighlights: frontCardFacts,
      allSections: dynamicSections,
      pyqFacts: pyqs,
      watermark: json['popular_tag'] ?? fallbackWatermark,
    );
  }
}
