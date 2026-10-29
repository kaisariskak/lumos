import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_profile_wait.dart';
import '../cache/startup_cache.dart';
import '../l10n/app_strings.dart';
import '../models/ibadat_profile.dart';
import '../models/invite_code.dart';
import '../repositories/ibadat_group_repository.dart';
import '../repositories/profile_repository.dart';
import '../screens/authorization/ibadat_authorization.dart';
import '../screens/group_picker/group_picker_screen.dart';
import '../screens/invite_code/invite_code_screen.dart';
import '../screens/main_scaffold.dart';
import '../screens/registration/registration_screen.dart';
import '../screens/pin/pin_screen.dart';
import '../services/auth_logout_service.dart';
import '../services/pin_service.dart';
import '../utils/perf_log.dart';

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
  bool _showRegistration = false;
  bool _profileError = false;
  bool _pinRequired = false;
  bool _waitingForUsernameProfile = false;
  bool _usernameRegistrationInProgress = false;
  bool _hasPin = false;
  bool _pinVerified = false;

  IbadatProfile? _profile;

  @override
  void initState() {
    super.initState();

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedIn) {
        if (_usernameRegistrationInProgress) {
          return;
        }
        setState(() => _checkingBiometric = false);
        _loadProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _pinVerified = false;
        setState(() {
          _checkingBiometric = false;
          _pinRequired = false;
          _profileError = false;
          _waitingForUsernameProfile = false;
          _profile = null;
          _showGroupPicker = false;
          _showInviteCode = false;
          _showRegistration = false;
          _usernameRegistrationInProgress = false;
        });
      }
    });

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await traceAsync('AuthGate._checkAuth', () async {
      final user = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || user == null) {
        setState(() => _checkingBiometric = false);
        return;
      }

      _hasPin = await traceAsync('PinService.hasPin', PinService.hasPin);

      // Last-known profile: route immediately, then refresh in the background.
      final cached = _AuthData.tryFromJson(
        await StartupCache.read(user.id, _authCacheName),
      );
      final cachedProfile = cached?.profile;
      if (cached != null && cachedProfile != null) {
        if (!mounted) return;
        final pinNeeded =
            _hasPin && !_bypassesPin(cachedProfile, cached.ownsGroup);
        setState(() {
          _pinRequired = pinNeeded;
          _checkingBiometric = false;
        });
        if (!pinNeeded) {
          _applyProfile(_normalizeAdminProfile(cachedProfile, cached.ownsGroup));
          unawaited(_loadProfile(background: true));
        }
        return;
      }

      if (!_hasPin) {
        setState(() => _checkingBiometric = false);
        await _loadProfile();
        return;
      }

      _AuthData? data;
      try {
        data = await _fetchAuth(user.id);
      } catch (e) {
        debugPrint('PIN bypass check failed: $e');
      }
      final profile = data?.profile;
      if (!mounted) return;
      if (data != null &&
          profile != null &&
          _bypassesPin(profile, data.ownsGroup)) {
        setState(() {
          _pinRequired = false;
          _checkingBiometric = false;
        });
        await _loadProfile(prefetched: data);
        return;
      }

      setState(() {
        _pinRequired = true;
        _checkingBiometric = false;
      });
    });
  }

  /// Profile and group ownership depend only on the user id, so they are
  /// fetched in parallel.
  Future<_AuthData> _fetchAuth(String userId) async {
    final results = await Future.wait<Object?>([
      ProfileRepository(Supabase.instance.client).getProfile(userId),
      _ownsAnyGroup(userId),
    ]);
    return _AuthData(
      profile: results[0] as IbadatProfile?,
      ownsGroup: results[1] as bool,
    );
  }

  Future<bool> _ownsAnyGroup(String userId) async {
    try {
      final groups = await traceAsync(
        'AuthGate._ownsAnyGroup',
        () => IbadatGroupRepository(
          Supabase.instance.client,
        ).getGroupsByAdminIds([userId]),
        describeResult: (groups) => 'groups=${groups.length}',
      );
      return groups.isNotEmpty;
    } catch (e) {
      debugPrint('Admin ownership check failed: $e');
      return false;
    }
  }

  static bool _bypassesPin(IbadatProfile profile, bool ownsGroup) =>
      !profile.isSuperAdmin && ownsGroup;

  static IbadatProfile _normalizeAdminProfile(
    IbadatProfile profile,
    bool ownsGroup,
  ) {
    if (profile.isAdmin || profile.isSuperAdmin || !ownsGroup) return profile;
    return profile.copyWith(role: 'admin');
  }

  void _onPinSuccess() {
    _pinVerified = true;
    setState(() => _pinRequired = false);
    _loadProfile();
  }

  void _applyProfile(IbadatProfile profile) {
    if (!mounted) return;
    if (profile.currentGroupId == null && profile.role == 'user') {
      // Existing profile, no group → only need a USER invite code.
      setState(() {
        _profile = profile;
        _waitingForUsernameProfile = false;
        _showInviteCode = true;
        _showRegistration = false;
        _showGroupPicker = false;
      });
      return;
    }

    setState(() {
      _profile = profile;
      _waitingForUsernameProfile = false;
      _showGroupPicker = false;
      _showInviteCode = false;
      _showRegistration = false;
    });
  }

  Future<void> _loadProfile({
    int usernameProfileAttempts = 0,
    _AuthData? prefetched,
    bool background = false,
  }) async {
    await traceAsync(
      'AuthGate._loadProfile attempt=$usernameProfileAttempts',
      () async {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) return;
        try {
          final data = prefetched ?? await _fetchAuth(user.id);
          final profile = data.profile;

      if (profile == null) {
        if (AuthProfileWait.shouldWaitForUsernameProfile(user.userMetadata) &&
            usernameProfileAttempts < 12) {
          if (!mounted) return;
          setState(() {
            _profile = null;
            _waitingForUsernameProfile = true;
            _showRegistration = false;
            _showInviteCode = false;
            _showGroupPicker = false;
          });
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          return _loadProfile(
            usernameProfileAttempts: usernameProfileAttempts + 1,
          );
        }

        // No profile → must register (nickname + invite code).
        if (!mounted) return;
        setState(() {
          _profile = null;
          _waitingForUsernameProfile = false;
          _showRegistration = true;
          _showInviteCode = false;
          _showGroupPicker = false;
        });
        return;
      }

      unawaited(StartupCache.write(user.id, _authCacheName, data.toJson()));

      // A cached decision may have skipped the PIN; lock again if fresh data
      // says the PIN is required and it was not entered in this session.
      if (_hasPin && !_pinVerified && !_bypassesPin(profile, data.ownsGroup)) {
        if (!mounted) return;
        setState(() => _pinRequired = true);
        return;
      }

      _applyProfile(_normalizeAdminProfile(profile, data.ownsGroup));
        } catch (e) {
          debugPrint('Profile load error: $e');
          // Keep the cached screen when a background refresh fails.
          if (!mounted || (background && _profile != null)) return;
          setState(() => _profileError = true);
        }
      },
    );
  }

  /// Existing-user code activation: only ever called for USER codes
  /// (the case "profile exists, no current_group_id").
  Future<void> _activateCode(InviteCode code) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      if (_profile == null) {
        // Defensive: should be impossible — RegistrationScreen handles new users.
        debugPrint('_activateCode called without profile; reloading');
        await _loadProfile();
        return;
      }

      if (code.roleType == 'USER' && code.groupId != null) {
        final profileRepo = ProfileRepository(Supabase.instance.client);
        await profileRepo.updateCurrentGroup(_profile!.id, code.groupId!);
      }

      await _loadProfile();
    } catch (e) {
      debugPrint('Code activation error: $e');
      if (!mounted) return;
      setState(() => _profileError = true);
    }
  }

  Future<void> _onRegistered(IbadatProfile profile) async {
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _showRegistration = false;
      _showInviteCode = false;
      _showGroupPicker = false;
    });
    // Re-derive routing from canonical server state. Trusting the RPC
    // response shape risks landing in the wrong branch if a field that
    // affects routing (e.g. currentGroupId) wasn't populated in the
    // returned row.
    await _loadProfile();
  }

  Future<void> _logout() async {
    await AuthLogoutService.signOut();
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
    if (session == null || _usernameRegistrationInProgress) {
      return IbadatAuthorization(
        onUsernameRegistrationStarted: () {
          if (mounted) {
            setState(() => _usernameRegistrationInProgress = true);
          }
        },
        onUsernameRegistrationFinished: () {
          if (mounted) {
            setState(() => _usernameRegistrationInProgress = false);
          }
        },
        onUsernameRegistrationCompleted: () {
          if (mounted) {
            setState(() => _usernameRegistrationInProgress = false);
          }
          _loadProfile();
        },
      );
    }

    // PIN required
    if (_pinRequired) {
      return PinScreen(onSuccess: _onPinSuccess, onCancel: _logout);
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(s.retry),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _logout,
                child: Text(
                  s.logout,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Username/password sign-up creates auth first, then profile via RPC.
    if (_waitingForUsernameProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    // Registration: nickname + invite code (new users only)
    if (_showRegistration) {
      return RegistrationScreen(onRegistered: _onRegistered, onLogout: _logout);
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

const _authCacheName = 'auth';

/// Profile plus "admins at least one group" — everything routing needs.
class _AuthData {
  final IbadatProfile? profile;
  final bool ownsGroup;

  const _AuthData({required this.profile, required this.ownsGroup});

  Map<String, dynamic> toJson() => {
        'profile': profile?.toCacheJson(),
        'owns_group': ownsGroup,
      };

  static _AuthData? tryFromJson(Object? json) {
    try {
      final map = Map<String, dynamic>.from(json as Map);
      final profileJson = map['profile'];
      return _AuthData(
        profile: profileJson == null
            ? null
            : IbadatProfile.fromJson(Map<String, dynamic>.from(profileJson as Map)),
        ownsGroup: map['owns_group'] as bool,
      );
    } catch (_) {
      return null;
    }
  }
}
