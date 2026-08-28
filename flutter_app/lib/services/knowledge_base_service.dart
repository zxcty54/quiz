import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:archive/archive.dart';

class KnowledgeBaseService {
  static final KnowledgeBaseService instance = KnowledgeBaseService._init();
  static Database? _database;

  KnowledgeBaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bpsc_database.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final docDirectory = await getApplicationDocumentsDirectory();
    final dbPath = join(docDirectory.path, fileName);

    if (!await File(dbPath).exists()) {
      await _extractGzAssetToDisk(dbPath);
    }

    return await openDatabase(dbPath, readOnly: true);
  }

  Future<void> _extractGzAssetToDisk(String targetPath) async {
    ByteData data = await rootBundle.load('assets/data/database/bpsc_database.db.gz');
    List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    List<int> decompressedBytes = GZipDecoder().decodeBytes(bytes);

    File targetFile = File(targetPath);
    await targetFile.writeAsBytes(decompressedBytes, flush: true);
  }

  // 🧠 Smart Multi-Word & Prefix Search Engine (Hinglish/Natural Language Friendly)
  Future<List<String>> searchRelevantChunks(String rawQuery, {int limit = 3}) async {
    final db = await database;
    if (db == null) return [];

    // 1. Common Stopwords & Conversational Hinglish Noise Filter
    final stopWords = {
      'kya', 'hai', 'h', 'he', 'ka', 'ki', 'ke', 'ko', 'me', 'mein', 'se', 'par',
      'batao', 'samjhao', 'karein', 'karta', 'hota', 'hoti', 'hote', 'what', 'is',
      'the', 'about', 'explain', 'tell', 'sir', 'please', 'details', 'kaise'
    };

    // 2. Clean punctuation, lowercase, and tokenize into core search terms
    final cleanWords = rawQuery
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]+'), ' ')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.length > 1 && !stopWords.contains(w))
        .toList();

    // If all words were filtered out (e.g. user typed single small keyword), keep original tokens
    if (cleanWords.isEmpty) {
      cleanWords.addAll(
        rawQuery
            .toLowerCase()
            .replaceAll(RegExp(r'[^\w\s]+'), ' ')
            .split(RegExp(r'\s+'))
            .where((w) => w.trim().isNotEmpty),
      );
    }

    if (cleanWords.isEmpty) return [];

    // 3. Construct FTS5 Query with Prefix Wildcard (e.g. "ribosomes* OR ribosome*")
    final ftsQuery = cleanWords.map((w) => '$w*').join(' OR ');

    try {
      // ⚡ Try FTS5 Match with Ranking
      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT content FROM fts_knowledge 
        WHERE fts_knowledge MATCH ? 
        ORDER BY rank 
        LIMIT ?
        ''',
        [ftsQuery, limit],
      );

      if (results.isNotEmpty) {
        return results.map((row) => row['content'] as String).toList();
      }
    } catch (_) {}

    // 4. Robust Substring Fallback (standard table / LIKE search)
    try {
      final String searchKey = cleanWords.first;
      final List<Map<String, dynamic>> fallbackResults = await db.rawQuery(
        '''
        SELECT content FROM fts_knowledge 
        WHERE content LIKE ? 
        LIMIT ?
        ''',
        ['%$searchKey%', limit],
      );

      return fallbackResults.map((row) => row['content'] as String).toList();
    } catch (_) {
      return [];
    }
  }
}
