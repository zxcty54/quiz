import 'package:flutter_test/flutter_test.dart';
import 'package:mocktester_v2/core/network/json_fetcher.dart';

void main() {
  group('JsonFetcher.extractList', () {
    test('passes a plain list through', () {
      final List<dynamic>? result =
          JsonFetcher.extractList(<dynamic>[1, 2, 3]);
      expect(result, <dynamic>[1, 2, 3]);
    });

    test('unwraps the questions / data / items envelopes', () {
      expect(JsonFetcher.extractList(<String, dynamic>{
        'questions': <dynamic>['q'],
      }), <dynamic>['q']);
      expect(JsonFetcher.extractList(<String, dynamic>{
        'data': <dynamic>['d'],
      }), <dynamic>['d']);
      expect(JsonFetcher.extractList(<String, dynamic>{
        'items': <dynamic>['i'],
      }), <dynamic>['i']);
    });

    test('returns null for unusable payloads', () {
      expect(JsonFetcher.extractList(null), isNull);
      expect(JsonFetcher.extractList(<String, dynamic>{'x': 1}), isNull);
      expect(JsonFetcher.extractList('text'), isNull);
    });
  });

  group('JsonFetcher.cleanPath', () {
    test('strips every known mirror prefix and cache-buster', () {
      const List<String> urls = <String>[
        'https://raw.githubusercontent.com/zxcty54/content_base/main/static/physics/light.json',
        'https://fastly.jsdelivr.net/gh/zxcty54/content_base@main/static/physics/light.json',
        'https://cdn.statically.io/gh/zxcty54/quiz/main/aptitude/set1.json',
        'https://raw.githack.com/zxcty54/quiz/main/aptitude/set1.json',
      ];
      expect(JsonFetcher.cleanPath(urls[0]), 'static/physics/light.json');
      expect(JsonFetcher.cleanPath(urls[1]), 'static/physics/light.json');
      expect(JsonFetcher.cleanPath(urls[2]), 'aptitude/set1.json');
      expect(JsonFetcher.cleanPath(urls[3]), 'aptitude/set1.json');
    });

    test('removes query strings and leading slashes', () {
      expect(
        JsonFetcher.cleanPath('/subject_mapping.json?t=1699999999'),
        'subject_mapping.json',
      );
    });

    test('is idempotent for already clean paths', () {
      expect(JsonFetcher.cleanPath('sectional_data.json'), 'sectional_data.json');
    });
  });
}
