import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _signup = true;
  bool _busy = false;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  List<Json> _communities = [];
  Json? _community;

  @override
  void initState() {
    super.initState();
    _loadCommunities();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _loadCommunities() async {
    try {
      final r = await supabase.from('communities').select().order('name');
      if (!mounted) return;
      final list = List<Json>.from(r);
      setState(() {
        _communities = list;
        _community = list.isEmpty
            ? null
            : list.firstWhere((c) => c['name'] == 'UTM Kuala Lumpur',
            orElse: () => list.first);
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pw = _pw.text;
    if (email.isEmpty || pw.length < 6) {
      toast(context, 'Enter your email and a password of 6+ characters');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_signup) {
        final res = await supabase.auth
            .signUp(email: email, password: pw, data: {'name': _name.text.trim()});
        if (res.session != null) {
          if (_community != null) {
            await supabase.from('profiles').update({
              'community_id': _community!['id'],
              'location_latitude': _community!['latitude'],
              'location_longitude': _community!['longitude'],
            }).eq('id', res.user!.id);
          }
          await Me.load();
          Me.version.value++;
        } else if (mounted) {
          toast(context, 'Account created. Confirm your email, then log in.');
        }
      } else {
        await supabase.auth.signInWithPassword(email: email, password: pw);
      }
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e) {
      if (mounted) toast(context, 'Something went wrong: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/logo.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),            const SizedBox(height: 28),
            const Text('Borrow more.\nBuy less.',
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1.05)),
            const SizedBox(height: 12),
            const Text(
              'Useful things are already around you. Find them nearby, borrow them, return them.',
              style: TextStyle(fontSize: 16, color: AppColors.grey, height: 1.4),
            ),
            const SizedBox(height: 32),
            if (_signup) ...[
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Your name'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pw,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password (6+ characters)'),
            ),
            if (_signup && _communities.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _community?['id'] as String?,
                decoration: const InputDecoration(hintText: 'Where do you want to borrow?'),
                items: [
                  for (final c in _communities)
                    DropdownMenuItem(
                        value: c['id'] as String, child: Text(c['name'] as String)),
                ],
                onChanged: (id) => setState(() =>
                _community = _communities.firstWhere((c) => c['id'] == id)),
              ),
            ],
            const SizedBox(height: 24),
            PillButton(
              label: _signup ? 'Create account' : 'Log in',
              onPressed: _submit,
              loading: _busy,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _signup = !_signup),
              child: Text(
                _signup ? 'Already have an account? Log in' : 'New to Lendly? Create an account',
                style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
