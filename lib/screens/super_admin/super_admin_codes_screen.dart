import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../models/ibadat_profile.dart';
import '../../models/invite_code.dart';
import '../../repositories/invite_code_repository.dart';

/// The one and only screen for super_admin.
/// Shows all previously generated ADMIN codes + button to create a new one.
class SuperAdminCodesScreen extends StatefulWidget {
  final IbadatProfile profile;
  final VoidCallback onLogout;

  const SuperAdminCodesScreen({
    super.key,
    required this.profile,
    required this.onLogout,
  });

  @override
  State<SuperAdminCodesScreen> createState() => _SuperAdminCodesScreenState();
}

class _SuperAdminCodesScreenState extends State<SuperAdminCodesScreen> {
  late final InviteCodeRepository _repo;
  List<InviteCode> _codes = [];
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _repo = InviteCodeRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final codes = await _repo.getAdminCodes(widget.profile.id);
      if (!mounted) return;
      setState(() {
        _codes = codes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      await _repo.generateAdminCode(createdBy: widget.profile.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.of(context).error}: $e')),
      );
      setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final currentLang = LocaleProvider.instance.value.languageCode;

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
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🌟', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(
                            '${widget.profile.displayName} · ${s.superAdminLabel}',
                            style: const TextStyle(
                              color: Color(0xFFFCD34D),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Language switcher
                    GestureDetector(
                      onTap: () => LocaleProvider.instance.setLocale(
                        Locale(currentLang == 'kk' ? 'ru' : 'kk'),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          currentLang == 'kk' ? 'RU' : 'KZ',
                          style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: widget.onLogout,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout,
                            color: Color(0xFF64748B), size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Title ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    const Text('🔑', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                      ).createShader(b),
                      child: Text(
                        s.tabCodes,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Generate button ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add, size: 18),
                    label: Text(s.generateAdminCode,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          const Color(0xFFF59E0B).withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),

              // ── Codes list ──────────────────────────────────────────
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF6366F1)))
                    : _codes.isEmpty
                        ? Center(
                            child: Text(
                              s.noActiveCode,
                              style: const TextStyle(
                                  color: Color(0xFF475569), fontSize: 14),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: const Color(0xFF6366F1),
                            backgroundColor: const Color(0xFF1E293B),
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              itemCount: _codes.length,
                              itemBuilder: (_, i) =>
                                  _CodeTile(code: _codes[i], strings: s),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Code tile ──────────────────────────────────────────────────────────────

class _CodeTile extends StatelessWidget {
  final InviteCode code;
  final AppStrings strings;

  const _CodeTile({required this.code, required this.strings});

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final isActive = code.isValid;
    final isUsed = code.isUsed;
    final isExpired = code.isExpired && !isUsed;

    Color borderColor;
    Color labelColor;
    String statusLabel;

    if (isUsed) {
      borderColor = const Color(0xFF059669).withValues(alpha: 0.4);
      labelColor = const Color(0xFF34D399);
      statusLabel = '✅ Использован';
    } else if (isExpired) {
      borderColor = const Color(0xFF374151);
      labelColor = const Color(0xFF6B7280);
      statusLabel = '⏰ Истёк';
    } else {
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.4);
      labelColor = const Color(0xFFFCD34D);
      statusLabel = '🟡 Активен';
    }

    final exp = code.expiresAt;
    final expiresLabel =
        '${exp.day.toString().padLeft(2, '0')}.${exp.month.toString().padLeft(2, '0')}.${exp.year}  '
        '${exp.hour.toString().padLeft(2, '0')}:${exp.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code.code,
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF475569),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(statusLabel,
                        style: TextStyle(color: labelColor, fontSize: 11)),
                    const SizedBox(width: 8),
                    Text(
                      '${s.codeExpiresIn}: $expiresLabel',
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isActive)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.codeCopied)),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.copy,
                    color: Color(0xFFFCD34D), size: 18),
              ),
            ),
        ],
      ),
    );
  }
}
