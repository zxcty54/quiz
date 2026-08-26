import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final SupabaseClient _supabase = Supabase.instance.client;

  // 1-Tap Google Sign-In + Auto Local & Supabase Sync
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Step A: Trigger Google Account Selector
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      // Step B: Obtain Auth Details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step C: Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final String name = user.displayName ?? "MockTester Aspirant";
        final String email = user.email ?? "";
        final String photoUrl = user.photoURL ?? "";
        final String mobile = user.phoneNumber ?? "";

        // Step D: Local Storage (SharedPreferences) Sync
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_name', name);
        await prefs.setString('user_email', email);
        await prefs.setString('user_photo', photoUrl);
        await prefs.setString('user_mobile', mobile);

        // Step E: Cloud Supabase Table Sync
        await _syncUserToSupabase(
          uid: user.uid,
          name: name,
          email: email,
          photoUrl: photoUrl,
          mobile: mobile,
        );
      }

      return userCredential;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      return null;
    }
  }

  // Supabase Database Sync Helper
  static Future<void> _syncUserToSupabase({
    required String uid,
    required String name,
    required String email,
    required String photoUrl,
    required String mobile,
  }) async {
    try {
      await _supabase.from('app_users').upsert({
        'uid': uid,
        'name': name,
        'email': email,
        'photo_url': photoUrl,
        'mobile': mobile,
        'last_active': DateTime.now().toIso8601String(),
      }, onConflict: 'uid');
      debugPrint("✅ User details synced to Supabase successfully!");
    } catch (e) {
      debugPrint("❌ Supabase Sync Failed: $e");
    }
  }

  // Logout (Google, Firebase & Local Storage clear)
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_photo');
    await prefs.remove('user_mobile');
  }
}
