import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';
import '../models/ibadat_group.dart';
import '../models/ibadat_profile.dart';
import '../repositories/ibadat_group_repository.dart';
import 'admin/admin_screen.dart';
import 'home/home_screen.dart';
import 'payments/payments_screen.dart';
import 'profile/profile_screen.dart';
import 'report/report_editor_screen.dart';
import 'super_admin/super_admin_codes_screen.dart';

class MainScaffold extends StatefulWidget {
  final IbadatProfile profile;
  final VoidCallback onSwitchGroup;

  const MainScaffold({
    super.key,
    required this.profile,
    required this.onSwitchGroup,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with WidgetsBindingObserver {
  int _tabIndex = 0;
  IbadatGroup? _group;
  bool _isLoading = true;
  final _homeKey = GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGroup();
  }

  @override
  void dispose() {
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
      setState(() => _isLoading = false);
      return;
    }
    try {
      final repo = IbadatGroupRepository(Supabase.instance.client);
      final group = await repo.getGroupById(widget.profile.currentGroupId!);
      if (!mounted) return;
      final isFinancier =
          group != null && group.financierId == widget.profile.id;
      final tabCount = 2 + (isFinancier ? 1 : 0) + 1;
      setState(() {
        _group = group;
        _isLoading = false;
        if (_tabIndex >= tabCount) _tabIndex = tabCount - 1;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    // Super-admin sees only the codes screen — no groups, no tabs
    if (widget.profile.isSuperAdmin) {
      return SuperAdminCodesScreen(
        profile: widget.profile,
        onLogout: _logout,
      );
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    final isAdmin = widget.profile.isAdmin;
    final group = _group;
    final isFinancier = group != null && group.financierId == widget.profile.id;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: group == null
            ? _NoGroupPlaceholder(onSwitch: widget.onSwitchGroup)
            : IndexedStack(
                index: _tabIndex,
                children: [
                  HomeScreen(
                    key: _homeKey,
                    profile: widget.profile,
                    group: group,
                    onSwitchGroup: widget.onSwitchGroup,
                  ),
                  ReportEditorScreen(
                    profile: widget.profile,
                    group: group,
                    onSaved: () => _homeKey.currentState?.reload(),
                    onBack: () => setState(() => _tabIndex = 0),
                  ),
                  if (isFinancier)
                    PaymentsScreen(
                      profile: widget.profile,
                      group: group,
                    ),
                  if (isAdmin)
                    AdminScreen(
                      profile: widget.profile,
                      group: group,
                      onSwitchGroup: widget.onSwitchGroup,
                      onLogout: _logout,
                      onGroupChanged: _loadGroup,
                    )
                  else
                    ProfileScreen(
                      profile: widget.profile,
                      group: group,
                      onSwitchGroup: widget.onSwitchGroup,
                      onLogout: _logout,
                    ),
                ],
              ),
      ),
      bottomNavigationBar: group == null
          ? null
          : _BottomNav(
              currentIndex: _tabIndex,
              isAdmin: isAdmin,
              isFinancier: isFinancier,
              groupName: widget.profile.isSuperAdmin ? 'Барлық топтар' : group.name,
              onTap: (i) {
                setState(() => _tabIndex = i);
                if (i == 0) _homeKey.currentState?.reload();
                _loadGroup();
              },
            ),
    );
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
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(s.selectGroupBtn,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isAdmin;
  final bool isFinancier;
  final String groupName;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.isAdmin,
    required this.isFinancier,
    required this.groupName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tabs = [
      _NavTab(icon: '👥', label: s.tabList),
      _NavTab(icon: '📝', label: s.tabReport),
      if (isFinancier) _NavTab(icon: '💰', label: s.tabPayments),
      _NavTab(icon: isAdmin ? '👑' : '⚙️', label: isAdmin ? s.tabAdmin : s.tabProfile),
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
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👥', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      groupName,
                      style: const TextStyle(
                        color: Color(0xFFA5B4FC),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                                  ? const Color(0xFFA5B4FC)
                                  : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 4 : 0,
                            height: isActive ? 4 : 0,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
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
