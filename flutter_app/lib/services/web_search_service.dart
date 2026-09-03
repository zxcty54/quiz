import 'dart:convert';
import 'package:http/http.dart' as http;

class WebSearchService {
  static final WebSearchService instance = WebSearchService._internal();
  WebSearchService._internal();

  /// Multiple sources scan karke 2-3 lines context nikalna
  Future<String> searchWebContext(String query) async {
    try {
      final clean = Uri.encodeComponent(query.trim());
      // DuckDuckGo instant summary API (Completely free, no API key needed)
      final url = Uri.parse('https://api.duckduckgo.com/?q=$clean&format=json&no_html=1&skip_disambig=1');
      
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String abstractText = data['AbstractText'] ?? '';
        
        if (abstractText.trim().isNotEmpty) {
          return "LIVE WEB SOURCE: $abstractText";
        }
      }
    } catch (_) {
      // Net slow ya fail hone par safe exit
    }
    return "";
  }
}
