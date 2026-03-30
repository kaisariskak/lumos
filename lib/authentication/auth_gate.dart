import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';
import '../models/ibadat_profile.dart';
import '../repositories/profile_repository.dart';
import '../screens/authorization/ibadat_authorization.dart';
import '../screens/group_picker/group_picker_screen.dart';
import '../screens/main_scaffold.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSub;
  final _localAuth = LocalAuthentication();

  bool _biometricPassed = false;
  bool _checkingBiometric = true;
  bool _showGroupPicker = false;
  bool _profileError = false;
  bool _notAllowed = false;

  IbadatProfile? _profile;

  @override
  void initState() {
    super.initState();

    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedIn) {
        // After Google Sign-In skip biometric — go straight in
        setState(() {
          _biometricPassed = true;
          _checkingBiometric = false;
        });
        _loadProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        setState(() {
          _biometricPassed = false;
          _checkingBiometric = false;
          _profile = null;
          _showGroupPicker = false;
        });
      }
    });

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() => _checkingBiometric = false);
      return;
    }
    // Session exists → biometric check
    await _authenticate();
    if (_biometricPassed) await _loadProfile();
  }

  Future<void> _authenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();

      if (!canCheck) {
        setState(() {
          _biometricPassed = true;
          _checkingBiometric = false;
        });
        return;
      }

      final ok = await _localAuth.authenticate(
        localizedReason: 'Қолданбаға кіруді растаңыз',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      setState(() {
        _biometricPassed = ok;
        _checkingBiometric = false;
      });
    } catch (_) {
      setState(() {
        _biometricPassed = true;
        _checkingBiometric = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final repo = ProfileRepository(Supabase.instance.client);
      IbadatProfile? profile = await repo.getProfile(user.id);

      final email = user.email ?? '';

      if (profile == null) {
        // Profile not yet created — check allowlist
        final allowlistEntry = await repo.getAllowlistEntry(email);
        if (allowlistEntry == null) {
          if (!mounted) return;
          setState(() => _notAllowed = true);
          return;
        }

        final targetRole = allowlistEntry['target_role'] as String? ?? 'user';
        final createdBy = allowlistEntry['created_by'] as String?;
        final groupId = allowlistEntry['group_id'] as String?;

        // For admin target_role: super_admin_id = createdBy; for users: created_by_admin_id = createdBy
        profile = await repo.createProfile(
          id: user.id,
          displayName: user.userMetadata?['full_name'] as String? ??
              user.userMetadata?['name'] as String? ??
              email,
          email: email,
          avatarUrl: user.userMetadata?['avatar_url'] as String?,
          role: targetRole,
          superAdminId: targetRole == 'admin' ? createdBy : null,
          createdByAdminId: targetRole == 'user' ? createdBy : null,
        );

        // Auto-assign group from allowlist
        if (groupId != null) {
          await repo.updateCurrentGroup(profile.id, groupId);
          profile = await repo.getProfile(user.id) ?? profile;
        }
      } else if (profile.currentGroupId == null && profile.role == 'user') {
        // Existing profile with no group — auto-assign from allowlist if available
        final groupId = await repo.getAllowlistGroupId(email);
        if (groupId != null) {
          await repo.updateCurrentGroup(profile.id, groupId);
          profile = await repo.getProfile(user.id) ?? profile;
        }
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _showGroupPicker = profile?.currentGroupId == null && (profile?.isAdmin ?? false);
      });
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (!mounted) return;
      setState(() => _profileError = true);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Loading
    if (_checkingBiometric) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    final session = Supabase.instance.client.auth.currentSession;

    // No session → sign in
    if (session == null) return const IbadatAuthorization();

    // Session but biometric not passed
    if (!_biometricPassed) {
      final s = S.of(context);
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔒', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 20),
              Text(
                s.appLocked,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: Text(s.unlock),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _logout,
                child: Text(s.switchAccount,
                    style: const TextStyle(color: Color(0xFF64748B))),
              ),
            ],
          ),
        ),
      );
    }

    // Not in allowlist
    if (_notAllowed) {
      final s = S.of(context);
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🚫', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 20),
                Text(
                  s.accessDenied,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  s.notAllowedDesc,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextButton(
                  onPressed: () {
                    setState(() => _notAllowed = false);
                    _logout();
                  },
                  child: Text(
                    s.logout,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Profile load error
    if (_profileError) {
      final s = S.of(context);
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                s.profileNotLoaded,
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() => _profileError = false);
                  _loadProfile();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(s.retry),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _logout,
                child: Text(s.logout, style: const TextStyle(color: Color(0xFF64748B))),
              ),
            ],
          ),
        ),
      );
    }

    // Profile still loading
    if (_profile == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    // Regular user with no group — wait for admin to assign
    if (_profile!.currentGroupId == null && !_profile!.isAdmin) {
      return _WaitingForGroupScreen(onLogout: _logout);
    }

    // Admin with no group → pick a group
    if (_showGroupPicker) {
      return GroupPickerScreen(
        profile: _profile!,
        onGroupSelected: () async {
          await _loadProfile();
          if (mounted) setState(() => _showGroupPicker = false);
        },
        onBack: _profile!.currentGroupId != null
            ? () => setState(() => _showGroupPicker = false)
            : null,
      );
    }

    // Main app
    return MainScaffold(
      profile: _profile!,
      onSwitchGroup: () => setState(() => _showGroupPicker = true),
    );
  }
}

class _WaitingForGroupScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const _WaitingForGroupScreen({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⏳', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 20),
              Text(
                s.waitingForGroup,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                s.waitingDesc,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: onLogout,
                child: Text(
                  s.logout,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
