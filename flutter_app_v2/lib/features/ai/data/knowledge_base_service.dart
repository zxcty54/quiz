// v1 source: flutter_app/lib/services/knowledge_base_service.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Lightweight on-device retrieval for the AI Doubt flow.
///
/// **Status:** `ai_doubt_screen.dart` imported `knowledge_base_service.dart` in
/// v1, but the file was never committed, so the screen never compiled. This
/// implementation restores the used API
/// (`KnowledgeBaseService.instance.searchRelevantChunks`) with a real, dependency
/// free retrieval engine: the bundled `learn_data.json` corpus is flattened into
/// chunks and scored with token-overlap (a poor-man's BM25) so answers are
/// grounded in actual app content instead of model hallucination.
///
/// Extra material can be pushed in at runtime with [addDocuments] — e.g. the
/// JSON of the question currently on screen — and it will be searchable
/// immediately.
class KnowledgeBaseService {
  KnowledgeBaseService._();

  static final KnowledgeBaseService instance = KnowledgeBaseService._();

  static const String _assetPath = 'assets/data/learn_data.json';
  static const int _maxChunkChars = 480;

  final List<String> _chunks = <String>[];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  int get chunkCount => _chunks.length;

  /// Loads the bundled corpus once. Safe to call repeatedly.
  Future<void> ensureLoaded() async {
    if (_isLoaded) return;
    _isLoaded = true;
    try {
      final String raw = await rootBundle.loadString(_assetPath);
      final dynamic decoded = jsonDecode(raw);
      _indexDocument(decoded);
      debugPrint('KnowledgeBaseService: indexed ${_chunks.length} chunks');
    } catch (e) {
      debugPrint('KnowledgeBaseService: asset load failed: $e');
    }
  }

  /// Adds arbitrary JSON/text to the index (question banks, notes, …).
  void addDocuments(Iterable<String> documents) {
    for (final String doc in documents) {
      _pushChunk(doc);
    }
  }

  /// Returns the [limit] most relevant chunks for [query].
  ///
  /// Returns an empty list when nothing matches — callers show
  /// "no direct textbook match found" in that case (same UX as v1 intended).
  Future<List<String>> searchRelevantChunks(
    String query, {
    int limit = 2,
  }) async {
    await ensureLoaded();
    final String needle = query.trim();
    if (needle.isEmpty || _chunks.isEmpty) return <String>[];

    final Set<String> terms = _tokenize(needle);
    if (terms.isEmpty) return <String>[];

    final List<_ScoredChunk> scored = <_ScoredChunk>[];
    for (final String chunk in _chunks) {
      final Set<String> chunkTerms = _tokenize(chunk);
      if (chunkTerms.isEmpty) continue;

      int hits = 0;
      for (final String term in terms) {
        if (chunkTerms.contains(term)) hits++;
      }
      if (hits == 0) continue;

      final double coverage = hits / terms.length;
      final double density = hits / chunkTerms.length;
      scored.add(_ScoredChunk(chunk, coverage * 0.75 + density * 0.25));
    }

    if (scored.isEmpty) return <String>[];
    scored.sort((_ScoredChunk a, _ScoredChunk b) => b.score.compareTo(a.score));
    return scored
        .take(limit.clamp(1, 10))
        .map((_ScoredChunk entry) => entry.text)
        .toList();
  }

  // ------------------------------------------------------------- internals --

  void _indexDocument(dynamic node) {
    if (node == null) return;
    if (node is String) {
      _pushChunk(node);
      return;
    }
    if (node is List) {
      for (final dynamic item in node) {
        _indexDocument(item);
      }
      return;
    }
    if (node is Map) {
      final StringBuffer buffer = StringBuffer();
      node.forEach((dynamic key, dynamic value) {
        if (value is String || value is num) {
          final String text = value.toString().trim();
          if (text.isNotEmpty) {
            buffer.writeln('${_humanize(key.toString())}: $text');
          }
        }
      });
      final String chunk = buffer.toString().trim();
      if (chunk.isNotEmpty) {
        _pushChunk(chunk);
      }
      node.forEach((dynamic key, dynamic value) {
        if (value is List || value is Map) {
          _indexDocument(value);
        }
      });
    }
  }

  void _pushChunk(String text) {
    final String clean = text
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.length < 25) return;
    _chunks.add(
      clean.length <= _maxChunkChars
          ? clean
          : '${clean.substring(0, _maxChunkChars)}…',
    );
  }

  static String _humanize(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .where((String part) => part.isNotEmpty)
      .map((String part) =>
          '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  static final RegExp _wordSplit = RegExp(r'[^a-z0-9]+');

  static const Set<String> _stopWords = <String>{
    'the', 'is', 'are', 'a', 'an', 'of', 'and', 'or', 'to', 'in', 'on', 'for',
    'with', 'what', 'why', 'how', 'kya', 'hai', 'ka', 'ki', 'ke', 'me', 'mein',
    'se', 'ko', 'batao', 'samasya',
  };

  static Set<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .split(_wordSplit)
        .where((String token) =>
            token.length > 2 && !_stopWords.contains(token))
        .toSet();
  }
}

class _ScoredChunk {
  const _ScoredChunk(this.text, this.score);

  final String text;
  final double score;
}
