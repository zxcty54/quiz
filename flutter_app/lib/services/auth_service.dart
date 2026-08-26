import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  static final SupabaseClient _supabase = Supabase.instance.client;

  // 1-Tap Google Sign-In & Supabase Sync
  static Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      // 1. Purani cache clear karein taaki hamesha fresh account picker popup khule
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("⚠️ Google Sign-In: User closed account picker without selecting.");
        return null; // User cancelled
      }

      final String name = googleUser.displayName ?? "MockTester Aspirant";
      final String email = googleUser.email;
      final String photoUrl = googleUser.photoUrl ?? "";
      final String uid = googleUser.id; // Unique Google User ID

      // 2. Local Storage Sync (Guest flag false karein)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', false);
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);
      await prefs.setString('user_photo', photoUrl);

      // 3. Supabase Cloud Sync (Try-catch wrapped taaki network issue par login block na ho)
      try {
        await _syncUserToSupabase(
          uid: uid,
          name: name,
          email: email,
          photoUrl: photoUrl,
        );
      } catch (dbError) {
        debugPrint("⚠️ Supabase Sync skipped: $dbError");
      }

      return googleUser;
    } catch (e) {
      debugPrint("❌ GOOGLE SIGN-IN ROOT ERROR: $e");
      rethrow; // UI ko actual exception forward karega taaki screen par error dikhe
    }
  }

  // Supabase Database Sync Helper
  static Future<void> _syncUserToSupabase({
    required String uid,
    required String name,
    required String email,
    required String photoUrl,
  }) async {
    try {
      await _supabase.from('app_users').upsert({
        'uid': uid,
        'name': name,
        'email': email,
        'photo_url': photoUrl,
        'last_active': DateTime.now().toIso8601String(),
      }, onConflict: 'uid');
      debugPrint("✅ User details synced to Supabase successfully!");
    } catch (e) {
      debugPrint("❌ Supabase Sync Failed: $e");
    }
  }

  // Logout
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('is_guest');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_photo');
    await prefs.remove('user_mobile');
  }
}
