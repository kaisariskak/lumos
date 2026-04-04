import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../models/ibadat_group.dart';
import '../../models/ibadat_profile.dart';
import '../../theme/accent_provider.dart';

class ProfileScreen extends StatefulWidget {
  final IbadatProfile profile;
  final IbadatGroup? group;
  final VoidCallback onSwitchGroup;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.profile,
    this.group,
    required this.onSwitchGroup,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    AccentProvider.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AccentProvider.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final currentLang = LocaleProvider.instance.value.languageCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 56, 16, 100),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AccentProvider.instance.current.accentDark, AccentProvider.instance.current.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(36),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x664F46E5),
                  blurRadius: 32,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.profile.displayName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.profile.displayName,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.profile.email,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '${s.groupLabel}: ${widget.group?.name ?? '—'}',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 32),

          // Color theme picker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🎨', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      s.colorTheme,
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<int>(
                  valueListenable: AccentProvider.instance,
                  builder: (_, selected, _) => Row(
                    children: List.generate(appAccents.length, (i) {
                      final theme = appAccents[i];
                      final isSelected = selected == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => AccentProvider.instance.setAccent(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: EdgeInsets.only(right: i < appAccents.length - 1 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: theme.accent.withValues(alpha: isSelected ? 0.2 : 0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.accent.withValues(alpha: isSelected ? 0.7 : 0.2),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: theme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  theme.name,
                                  style: TextStyle(
                                    color: isSelected ? theme.accentLight : const Color(0xFF64748B),
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Language switcher
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🌐', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      s.language,
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _LangBtn(
                        label: s.kazakh,
                        flag: '🇰🇿',
                        selected: currentLang == 'kk',
                        onTap: () => LocaleProvider.instance
                            .setLocale(const Locale('kk')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LangBtn(
                        label: s.russian,
                        flag: '🇷🇺',
                        selected: currentLang == 'ru',
                        onTap: () => LocaleProvider.instance
                            .setLocale(const Locale('ru')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: Text(s.logout),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  const _LangBtn({
    required this.label,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AccentProvider.instance.current.accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AccentProvider.instance.current.accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? AccentProvider.instance.current.accentLight
                    : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
