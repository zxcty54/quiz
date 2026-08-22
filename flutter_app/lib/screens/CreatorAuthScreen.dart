import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'creator_mock_builder_screen.dart';

class CreatorAuthScreen extends StatefulWidget {
  final bool isDarkMode;
  const CreatorAuthScreen({super.key, required this.isDarkMode});

  @override
  State<CreatorAuthScreen> createState() => _CreatorAuthScreenState();
}

class _CreatorAuthScreenState extends State<CreatorAuthScreen> {
  bool isLoginMode = true;
  final _handleCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _handleAuth() async {
    final handle = _handleCtrl.text.trim().toLowerCase();
    final pin = _pinCtrl.text.trim();

    if (handle.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Handle and PIN are required!')));
      return;
    }

    setState(() => _loading = true);
    final client = Supabase.instance.client;

    try {
      if (isLoginMode) {
        // LOGIN CHECK
        final res = await client
            .from('creator_profiles')
            .select()
            .eq('handle_id', handle)
            .eq('secret_pin', pin)
            .maybeSingle();

        if (res == null) {
          throw 'Invalid Handle ID or PIN!';
        }
        if (res['is_blocked'] == true) {
          throw 'This creator account is suspended.';
        }

        await _saveSession(handle, res['name']);
      } else {
        // REGISTER NEW CREATOR
        if (_nameCtrl.text.trim().isEmpty) {
          throw 'Please enter your Full Name';
        }

        await client.from('creator_profiles').insert({
          'handle_id': handle,
          'name': _nameCtrl.text.trim(),
          'secret_pin': pin,
          'subject_specialty': _subjectCtrl.text.trim(),
          'telegram_handle': _telegramCtrl.text.trim(),
        });

        await _saveSession(handle, _nameCtrl.text.trim());
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CreatorMockBuilderScreen(
              creatorHandle: handle,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSession(String handle, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_creator_handle', handle);
    await prefs.setString('saved_creator_name', name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLoginMode ? 'Creator Studio Login' : 'Become a Creator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _handleCtrl,
              decoration: const InputDecoration(labelText: 'Unique Handle ID (e.g. rakesh_maths)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: '4-Digit Secret PIN', border: OutlineInputBorder()),
            ),
            if (!isLoginMode) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Display Name (e.g. Rakesh Sir)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(labelText: 'Specialty (e.g. Science / Maths)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _telegramCtrl,
                decoration: const InputDecoration(labelText: 'Telegram Handle / Channel Link', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleAuth,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isLoginMode ? 'Enter Creator Studio' : 'Register & Start Creating', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => isLoginMode = !isLoginMode),
              child: Text(isLoginMode ? "New teacher? Create Creator Profile" : "Already have PIN? Login here"),
            ),
          ],
        ),
      ),
    );
  }
}
