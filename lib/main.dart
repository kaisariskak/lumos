import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ibadat_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sydskxivdjickwwyjeqb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5ZHNreGl2ZGppY2t3d3lqZXFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0OTI3NzcsImV4cCI6MjA4NzA2ODc3N30.RwXnyKxRHGsf2wbRP9elCSeZtqFjW7MY7Lx91z4kQkw',
  );

  // Handle OAuth deep link redirect (Google Sign-In callback)
  final appLinks = AppLinks();

  // Handle deep link when app is launched from cold start via OAuth redirect
  final initialUri = await appLinks.getInitialLink();
  if (initialUri != null) {
    await Supabase.instance.client.auth.getSessionFromUrl(initialUri);
  }

  // Handle deep link when app is already running (warm start)
  appLinks.uriLinkStream.listen((uri) {
    Supabase.instance.client.auth.getSessionFromUrl(uri);
  });

  runApp(const IbadatApp());
}
