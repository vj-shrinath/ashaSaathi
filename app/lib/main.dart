import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final supabaseUrl = const String.fromEnvironment(
    'SUPABASE_URL',
  ).ifEmpty(dotenv.env['SUPABASE_URL']);
  final supabasePublishableKey = const String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  ).ifEmpty(dotenv.env['SUPABASE_PUBLISHABLE_KEY']);
  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    throw StateError(
      'Missing Supabase configuration. Provide SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const ProviderScope(child: AshaSaathiApp()));
}

extension on String {
  String ifEmpty(String? fallback) => isEmpty ? fallback ?? '' : this;
}

class AshaSaathiApp extends ConsumerWidget {
  const AshaSaathiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'ASHA Saathi AI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
