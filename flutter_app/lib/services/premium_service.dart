import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_stats_service.dart';

/// 👑 Premium (Monthly ₹49) — free UPI manual system.
/// Student QR/UPI se pay karta hai, screenshot lagata hai,
/// admin Admin Hub se Approve karta hai -> premium_until set.
/// Lock/unlock isi premium_until date se chalta hai.
class PremiumService {
  static const String _configUrl =
      'https://raw.githubusercontent.com/zxcty54/content_base/refs/heads/main/app_config.json';
  static const String _configCacheKey = 'premium_payment_config_cache';
  static const String _untilCacheKey = 'premium_until_cache';

  static SupabaseClient get _client => Supabase.instance.client;

  // ---------- Payment Config (live app_config.json se) ----------
  // app_config.json me aisa block ho:
  // "payment": {"upi_id": "name@okhdfc", "upi_name": "MockTester", "price": 49, "days": 30}
  static Future<Map<String, dynamic>> getPaymentConfig() async {
    Map<String, dynamic> config = {
      'upi_id': '',
      'upi_name': 'MockTester',
      'price': 49,
      'days': 30,
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_configCacheKey);
      if (cached != null) {
        final decoded = jsonDecode(cached);
        if (decoded is Map) {
          config = {...config, ...Map<String, dynamic>.from(decoded)};
        }
      }
      final res =
          await http.get(Uri.parse(_configUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final root = jsonDecode(utf8.decode(res.bodyBytes));
        if (root is Map && root['payment'] is Map) {
          final payment = Map<String, dynamic>.from(root['payment'] as Map);
          config = {...config, ...payment};
          await prefs.setString(_configCacheKey, jsonEncode(config));
        }
      }
    } catch (e) {
      debugPrint('Premium config error: $e');
    }
    return config;
  }

  static Future<String> currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ?? 'usr_guest';
  }

  // ---------- Premium Status ----------
  static Future<DateTime?> fetchPremiumUntil() async {
    try {
      final userId = await currentUserId();
      final row = await _client
          .from('user_premium')
          .select('premium_until')
          .eq('user_id', userId)
          .maybeSingle();
      final prefs = await SharedPreferences.getInstance();
      if (row != null && row['premium_until'] != null) {
        final until = DateTime.tryParse(row['premium_until'].toString());
        if (until != null) {
          await prefs.setString(_untilCacheKey, until.toIso8601String());
          return until;
        }
      }
      await prefs.remove(_untilCacheKey);
      return null;
    } catch (e) {
      debugPrint('Premium status error (cache se jawab): $e');
      final prefs = await SharedPreferences.getInstance();
      return DateTime.tryParse(prefs.getString(_untilCacheKey) ?? '');
    }
  }

  static Future<bool> isPremiumActive() async {
    final until = await fetchPremiumUntil();
    return until != null && until.isAfter(DateTime.now());
  }

  // ---------- Owner Mode (app malik ke liye sab unlock) ----------
  static const String _ownerKey = 'owner_full_access';

  static Future<bool> isOwnerMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ownerKey) ?? false;
  }

  static Future<void> setOwnerMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ownerKey, value);
  }

  /// Admin Hub wala Master PIN hi chalega (admin_config table se check)
  static Future<bool> verifyOwnerPin(String pin) async {
    try {
      final res = await _client
          .from('admin_config')
          .select('master_pin')
          .eq('master_pin', pin.trim())
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('Owner PIN verify error: $e');
      return false;
    }
  }

  // ---------- Requests ----------
  static Future<Map<String, dynamic>?> fetchMyLatestRequest() async {
    try {
      final userId = await currentUserId();
      final rows = await _client
          .from('premium_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first);
    } catch (e) {
      debugPrint('My premium request error: $e');
    }
    return null;
  }

  static Future<String> uploadScreenshot(File file, String userId) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
    final name =
        'premium_${userId}_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    await _client.storage.from('premium_proofs').uploadBinary(name, bytes);
    return _client.storage.from('premium_proofs').getPublicUrl(name);
  }

  /// Request bhejo. return: {'ok': true} ya {'ok': false, 'error': '...'}
  static Future<Map<String, dynamic>> submitRequest({
    required String screenshotUrl,
    String? upiRef,
    required int amount,
  }) async {
    try {
      final userId = await currentUserId();
      final ref = (upiRef ?? '').trim();

      // Wahi UPI Ref dobara? turant rok do
      if (ref.isNotEmpty) {
        final dup = await _client
            .from('premium_requests')
            .select('id')
            .eq('upi_ref', ref)
            .inFilter('status', ['pending', 'approved'])
            .limit(1);
        if (dup.isNotEmpty) {
          return {
            'ok': false,
            'error': 'duplicate',
            'message': 'Ye UPI Ref No. pehle hi use ho chuka hai. '
                'Apne sahi payment ka screenshot lagao.',
          };
        }
      }

      // Ek pending pehle se hai to dusri mat bhejo
      final pending = await _client
          .from('premium_requests')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'pending')
          .limit(1);
      if (pending.isNotEmpty) {
        return {
          'ok': false,
          'error': 'already_pending',
          'message': 'Tumhari ek request pehle se pending hai. '
              'Admin ke check karne ka intezaar karo.',
        };
      }

      final stats = await UserStatsService.getStats();
      final row = await _client
          .from('premium_requests')
          .insert({
            'user_id': userId,
            'user_name': (stats['student_name'] ?? 'Aspirant').toString(),
            'user_contact': (stats['student_contact'] ?? '').toString(),
            'amount': amount,
            'upi_ref': ref.isEmpty ? null : ref,
            'screenshot_url': screenshotUrl,
            'status': 'pending',
          })
          .select()
          .single();
      return {'ok': true, 'request': Map<String, dynamic>.from(row)};
    } catch (e) {
      debugPrint('Premium submit error: $e');
      return {
        'ok': false,
        'error': 'failed',
        'message': 'Request nahi gayi. Internet check karke phir try karo.',
      };
    }
  }
}
