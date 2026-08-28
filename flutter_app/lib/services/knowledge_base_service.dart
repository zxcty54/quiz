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

  // Fast Search with FTS5 and standard table fallback
  Future<List<String>> searchRelevantChunks(String query, {int limit = 2}) async {
    final db = await instance.database;
    final cleanQuery = query.replaceAll(RegExp(r'[^\w\s]+'), ' ').trim();
    if (cleanQuery.isEmpty) return [];

    try {
      // 1. Try Native FTS5 Fast Search
      final results = await db.rawQuery('''
        SELECT content FROM fts_knowledge 
        WHERE fts_knowledge MATCH ? 
        LIMIT ?
      ''', [cleanQuery, limit]);

      return results.map((row) => row['content'] as String).toList();
    } catch (e) {
      // 2. Fallback to standard SQL table search if FTS5 is compiling
      final fallbackResults = await db.rawQuery('''
        SELECT content FROM knowledge_chunks 
        WHERE content LIKE ? 
        LIMIT ?
      ''', ['%$cleanQuery%', limit]);

      return fallbackResults.map((row) => row['content'] as String).toList();
    }
  }
}
