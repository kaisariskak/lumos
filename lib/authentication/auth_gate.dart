import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';
import '../models/ibadat_profile.dart';
import '../models/invite_code.dart';
import '../repositories/profile_repository.dart';
import '../screens/authorization/ibadat_authorization.dart';
import '../screens/group_picker/group_picker_screen.dart';
import '../screens/invite_code/invite_code_screen.dart';
import '../screens/main_scaffold.dart';
import '../screens/pin/pin_screen.dart';
import '../services/pin_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authSub;
  bool _checkingBiometric = true;
  bool _showGroupPicker = false;
  bool _showInviteCode = false;
  bool _profileError = false;
  bool _pinRequired = false;

  IbadatProfile? _profile;

  @override
  void initState() {
    super.initState();

    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedIn) {
        setState(() => _checkingBiometric = false);
        _loadProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        setState(() {
          _checkingBiometric = false;
          _pinRequired = false;
          _profile = null;
          _showGroupPicker = false;
          _showInviteCode = false;
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

    final hasPin = await PinService.hasPin();
    if (hasPin) {
      setState(() {
        _pinRequired = true;
        _checkingBiometric = false;
      });
      return;
    }

    setState(() => _checkingBiometric = false);
    await _loadProfile();
  }

  void _onPinSuccess() {
    setState(() => _pinRequired = false);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final repo = ProfileRepository(Supabase.instance.client);
      IbadatProfile? profile = await repo.getProfile(user.id);
      final email = user.email ?? '';

      if (profile == null) {
        // Check legacy allowlist first (backward compat for existing users)
        final allowlistEntry = await repo.getAllowlistEntry(email);
        if (allowlistEntry != null) {
          final targetRole = allowlistEntry['target_role'] as String? ?? 'user';
          final createdBy = allowlistEntry['created_by'] as String?;
          final groupId = allowlistEntry['group_id'] as String?;

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

          if (groupId != null) {
            await repo.updateCurrentGroup(profile.id, groupId);
            profile = await repo.getProfile(user.id) ?? profile;
          }
        } else {
          // No allowlist entry → show invite code screen
          if (!mounted) return;
          setState(() => _showInviteCode = true);
          return;
        }
      } else if (profile.currentGroupId == null && profile.role == 'user') {
        // Profile exists but no group → try legacy allowlist first
        final groupId = await repo.getAllowlistGroupId(email);
        if (groupId != null) {
          await repo.updateCurrentGroup(profile.id, groupId);
          profile = await repo.getProfile(user.id) ?? profile;
        } else {
          // No allowlist group → show invite code screen to assign group
          if (!mounted) return;
          setState(() {
            _profile = profile;
            _showInviteCode = true;
          });
          return;
        }
      }

      if (!mounted) return;
      // Admins and super-admins always go straight to MainScaffold.
      // Admins create their first group from within the admin panel.
      setState(() {
        _profile = profile;
        _showGroupPicker = false;
        _showInviteCode = false;
      });
    } catch (e) {
      debugPrint('Profile load error: $e');
      if (!mounted) return;
      setState(() => _profileError = true);
    }
  }

  /// Called by InviteCodeScreen when the user enters a valid code.
  Future<void> _activateCode(InviteCode code) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profileRepo = ProfileRepository(Supabase.instance.client);
      final email = user.email ?? '';

      if (_profile == null) {
        // New user — create profile based on code role
        if (code.roleType == 'ADMIN') {
          await profileRepo.createProfile(
            id: user.id,
            displayName: user.userMetadata?['full_name'] as String? ??
                user.userMetadata?['name'] as String? ??
                email,
            email: email,
            avatarUrl: user.userMetadata?['avatar_url'] as String?,
            role: 'admin',
            superAdminId: code.createdBy,
          );
        } else {
          final profile = await profileRepo.createProfile(
            id: user.id,
            displayName: user.userMetadata?['full_name'] as String? ??
                user.userMetadata?['name'] as String? ??
                email,
            email: email,
            avatarUrl: user.userMetadata?['avatar_url'] as String?,
            role: 'user',
            createdByAdminId: code.createdBy,
          );
          if (code.groupId != null) {
            await profileRepo.updateCurrentGroup(profile.id, code.groupId);
          }
        }
      } else {
        // Profile exists but no group — assign group from USER code
        if (code.roleType == 'USER' && code.groupId != null) {
          await profileRepo.updateCurrentGroup(_profile!.id, code.groupId);
        }
      }

      // Reload profile to enter the app
      await _loadProfile();
    } catch (e) {
      debugPrint('Code activation error: $e');
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

    // PIN required
    if (_pinRequired) {
      return PinScreen(
        onSuccess: _onPinSuccess,
        onCancel: _logout,
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

    // Invite code screen (new user or existing user with no group)
    if (_showInviteCode) {
      return InviteCodeScreen(
        onCodeValidated: _activateCode,
        onLogout: _logout,
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
      onReloadProfile: _loadProfile,
    );
  }
}
