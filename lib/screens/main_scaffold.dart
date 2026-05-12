import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';
import '../models/ibadat_group.dart';
import '../theme/accent_provider.dart';
import '../models/ibadat_profile.dart';
import '../repositories/ibadat_group_repository.dart';
import '../services/auth_logout_service.dart';
import 'admin/admin_screen.dart';
import 'home/home_screen.dart';
import 'payments/payments_screen.dart';
import 'profile/profile_screen.dart';
import 'report/report_editor_screen.dart';
import 'super_admin/super_admin_codes_screen.dart';

class MainScaffold extends StatefulWidget {
  final IbadatProfile profile;
  final VoidCallback onSwitchGroup;
  final VoidCallback onReloadProfile;

  const MainScaffold({
    super.key,
    required this.profile,
    required this.onSwitchGroup,
    required this.onReloadProfile,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  IbadatGroup? _group;
  bool _isLoading = true;
  int _paymentsReloadToken = 0;
  final Set<int> _builtTabs = {0};
  Timer? _tabWarmUpTimer;
  final _homeKey = GlobalKey<HomeScreenState>();
  final _reportKey = GlobalKey<ReportEditorScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGroup();
  }

  @override
  void didUpdateWidget(MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.currentGroupId != widget.profile.currentGroupId) {
      _loadGroup();
    }
  }

  @override
  void dispose() {
    _tabWarmUpTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadGroup();
    }
  }

  Future<void> _loadGroup() async {
    if (widget.profile.currentGroupId == null) {
      setState(() {
        _group = null;
        _isLoading = false;
      });
      if (widget.profile.isAdmin) {
        _scheduleTabWarmUp(3);
      }
      return;
    }
    try {
      final repo = IbadatGroupRepository(Supabase.instance.client);
      final group = await repo.getGroupById(widget.profile.currentGroupId!);
      if (!mounted) return;
      final isFinancier =
          group != null && group.financierId == widget.profile.id;
      final isAdmin = _isEffectiveAdmin(group);
      final showPayments = group != null && (isFinancier || isAdmin);
      final tabCount = 2 + (showPayments ? 1 : 0) + 1;
      setState(() {
        _group = group;
        _isLoading = false;
        if (_tabIndex >= tabCount) {
          _tabIndex = tabCount - 1;
          _builtTabs.add(_tabIndex);
        }
      });
      _scheduleTabWarmUp(tabCount);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scheduleTabWarmUp(int tabCount) {
    _tabWarmUpTimer?.cancel();
    if (tabCount <= 1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      var nextIndex = 1;

      void buildNextTab() {
        if (!mounted) return;
        while (nextIndex < tabCount && _builtTabs.contains(nextIndex)) {
          nextIndex++;
        }
        if (nextIndex >= tabCount) return;

        setState(() => _builtTabs.add(nextIndex));
        nextIndex++;
        _tabWarmUpTimer = Timer(
          const Duration(milliseconds: 220),
          buildNextTab,
        );
      }

      _tabWarmUpTimer = Timer(const Duration(milliseconds: 450), buildNextTab);
    });
  }

  Future<void> _logout() async {
    await AuthLogoutService.signOut();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Super-admin sees only the codes screen — no groups, no tabs
    if (widget.profile.isSuperAdmin) {
      return SuperAdminCodesScreen(profile: widget.profile, onLogout: _logout);
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(
            color: AccentProvider.instance.current.accent,
          ),
        ),
      );
    }

    final group = _group;
    final effectiveProfile = _effectiveProfileFor(group);
    final isAdmin = effectiveProfile.isAdmin;
    final isFinancier = group != null && group.financierId == widget.profile.id;
    final showPayments = group != null && (isFinancier || isAdmin);
    final noGroupForUser = group == null && !isAdmin;
    final tabs = noGroupForUser
        ? const <Widget>[]
        : _buildTabViews(
            group: group,
            profile: effectiveProfile,
            isAdmin: isAdmin,
            showPayments: showPayments,
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0F172A),
                AccentProvider.instance.current.gradientMid,
                const Color(0xFF0F172A),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: noGroupForUser
              ? _NoGroupPlaceholder(onSwitch: widget.onSwitchGroup)
              : IndexedStack(index: _tabIndex, children: tabs),
        ),
      ),
      bottomNavigationBar: noGroupForUser
          ? null
          : _BottomNav(
              currentIndex: _tabIndex,
              isAdmin: isAdmin,
              showPayments: showPayments,
              groupName: widget.profile.isSuperAdmin
                  ? 'Барлық топтар'
                  : (group?.name ?? ''),
              onTap: (i) {
                _dismissKeyboard();
                setState(() {
                  _tabIndex = i;
                  _builtTabs.add(i);
                  if (showPayments && i == 2) {
                    _paymentsReloadToken++;
                  }
                });
                if (i == 0) {
                  _homeKey.currentState?.reload();
                } else if (i == 1) {
                  _reportKey.currentState?.reloadPeriods();
                }
              },
            ),
    );
  }

  List<Widget> _buildTabViews({
    required IbadatGroup? group,
    required IbadatProfile profile,
    required bool isAdmin,
    required bool showPayments,
  }) {
    final views = <Widget>[
      HomeScreen(
        key: _homeKey,
        profile: profile,
        group: group,
        onSwitchGroup: widget.onSwitchGroup,
      ),
      ReportEditorScreen(
        key: _reportKey,
        profile: profile,
        group: group,
        onSaved: () => _homeKey.currentState?.reload(),
        onBack: () => setState(() {
          _tabIndex = 0;
          _builtTabs.add(0);
        }),
      ),
      if (showPayments)
        PaymentsScreen(
          profile: profile,
          group: group!,
          reloadToken: _paymentsReloadToken,
        ),
      if (isAdmin)
        AdminScreen(
          profile: profile,
          group: group,
          onSwitchGroup: widget.onSwitchGroup,
          onLogout: _logout,
          onGroupChanged: group == null
              ? widget.onReloadProfile
              : () {
                  _loadGroup();
                  _homeKey.currentState?.reload();
                },
        )
      else
        ProfileScreen(
          profile: profile,
          group: group!,
          onSwitchGroup: widget.onSwitchGroup,
          onLogout: _logout,
        ),
    ];

    return [
      for (var i = 0; i < views.length; i++)
        _builtTabs.contains(i) ? views[i] : const SizedBox.shrink(),
    ];
  }

  bool _isEffectiveAdmin(IbadatGroup? group) {
    return widget.profile.isAdmin || group?.adminId == widget.profile.id;
  }

  IbadatProfile _effectiveProfileFor(IbadatGroup? group) {
    if (_isEffectiveAdmin(group) && !widget.profile.isAdmin) {
      return widget.profile.copyWith(role: 'admin');
    }
    return widget.profile;
  }
}

class _NoGroupPlaceholder extends StatelessWidget {
  final VoidCallback onSwitch;

  const _NoGroupPlaceholder({required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👥', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            s.noGroupSelected,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onSwitch,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              s.selectGroupBtn,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isAdmin;
  final bool showPayments;
  final String groupName;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.isAdmin,
    required this.showPayments,
    required this.groupName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tabs = [
      _NavTab(icon: '👥', label: s.tabList),
      _NavTab(icon: '📝', label: s.tabReport),
      if (showPayments) _NavTab(icon: '💰', label: s.tabPayments),
      _NavTab(
        icon: isAdmin ? '👑' : '⚙️',
        label: isAdmin ? s.tabAdmin : s.tabProfile,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: tabs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final tab = entry.value;
                  final isActive = currentIndex == i;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tab.icon, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AccentProvider.instance.current.accentLight
                                  : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 4 : 0,
                            height: isActive ? 4 : 0,
                            decoration: BoxDecoration(
                              color: AccentProvider.instance.current.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab {
  final String icon;
  final String label;

  const _NavTab({required this.icon, required this.label});
}
