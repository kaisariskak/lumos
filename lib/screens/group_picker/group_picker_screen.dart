import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../models/ibadat_group.dart';
import '../../models/ibadat_profile.dart';
import '../../repositories/ibadat_group_repository.dart';
import '../../repositories/profile_repository.dart';

class GroupPickerScreen extends StatefulWidget {
  final IbadatProfile profile;
  final VoidCallback onGroupSelected;
  final VoidCallback? onBack;

  const GroupPickerScreen({
    super.key,
    required this.profile,
    required this.onGroupSelected,
    this.onBack,
  });

  @override
  State<GroupPickerScreen> createState() => _GroupPickerScreenState();
}

class _GroupPickerScreenState extends State<GroupPickerScreen> {
  late final IbadatGroupRepository _groupRepo;
  late final ProfileRepository _profileRepo;

  List<IbadatGroup> _groups = [];
  bool _isLoading = true;
  bool _isSaving = false;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _groupRepo = IbadatGroupRepository(client);
    _profileRepo = ProfileRepository(client);
    _loadGroups();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _groupRepo.getAllGroups();
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup(IbadatGroup group) async {
    setState(() => _isSaving = true);
    try {
      await _profileRepo.updateCurrentGroup(widget.profile.id, group.id);
      widget.onGroupSelected();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Қосылу қатесі: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _createGroup() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final group = await _groupRepo.createGroup(name, widget.profile.id);
      // Update admin role then join
      await _profileRepo.updateRole(widget.profile.id, 'admin');
      await _profileRepo.updateCurrentGroup(widget.profile.id, group.id);
      widget.onGroupSelected();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Топ құру қатесі: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF0F172A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      if (widget.onBack != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: widget.onBack,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.chevron_left, color: Color(0xFF94A3B8), size: 20),
                                  Text(s.back, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (widget.onBack != null) const SizedBox(height: 16),

                      // Header
                      Center(
                        child: Column(
                          children: [
                            const Text('👥', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              s.selectGroup,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.groupSubtitle,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Groups list
                      if (_groups.isEmpty)
                        Center(
                          child: Text(
                            s.noGroupsHint,
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      else ...[
                        Text(
                          s.availableGroups,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...(_groups.map((g) => _GroupCard(
                              group: g,
                              isCurrent: widget.profile.currentGroupId == g.id,
                              isSaving: _isSaving,
                              onJoin: () => _joinGroup(g),
                            ))),
                        const SizedBox(height: 24),
                      ],

                      // Create new group
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.createNewGroup,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _nameCtrl,
                              style: const TextStyle(color: Color(0xFFE2E8F0)),
                              decoration: InputDecoration(
                                hintText: s.groupNameHint,
                                hintStyle: const TextStyle(color: Color(0xFF475569)),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _createGroup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        s.create,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final IbadatGroup group;
  final bool isCurrent;
  final bool isSaving;
  final VoidCallback onJoin;

  const _GroupCard({
    required this.group,
    required this.isCurrent,
    required this.isSaving,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF6366F1).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6366F1).withValues(alpha: 0.2),
                const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(child: Text('👥', style: TextStyle(fontSize: 22))),
        ),
        title: Text(
          group.name,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          '${S.of(context).codeLabel}: ${group.code}',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        trailing: isCurrent
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  S.of(context).currentLabel,
                  style: const TextStyle(
                    color: Color(0xFFA5B4FC),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : IconButton(
                onPressed: isSaving ? null : onJoin,
                icon: const Icon(Icons.arrow_forward_ios,
                    color: Color(0xFF6366F1), size: 18),
              ),
      ),
    );
  }
}
