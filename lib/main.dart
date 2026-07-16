import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://xxxxxxxxxx.supabase.co',
      publishableKey: 'xxxxxxxxxx',
    );
  } catch (e) {
    debugPrint('Supabase init skipped: $e');
  }

  runApp(const ProviderScope(child: FarmBridgeApp()));
}

class FarmBridgeApp extends ConsumerWidget {
  const FarmBridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FarmBridge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
