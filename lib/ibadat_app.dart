import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'authentication/auth_gate.dart';
import 'l10n/locale_provider.dart';
import 'theme/theme.dart';

class IbadatApp extends StatefulWidget {
  const IbadatApp({super.key});

  @override
  State<IbadatApp> createState() => _IbadatAppState();
}

class _IbadatAppState extends State<IbadatApp> {
  @override
  void initState() {
    super.initState();
    LocaleProvider.instance.init().then((_) {
      if (mounted) setState(() {});
    });
    LocaleProvider.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleProvider.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ибадат Трекер',
      theme: darkTheme,
      locale: LocaleProvider.instance.value,
      supportedLocales: const [
        Locale('kk'),
        Locale('ru'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}
