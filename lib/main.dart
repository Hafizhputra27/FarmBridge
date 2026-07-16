import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await Supabase.initialize(
      url: 'https://rwxnjxmzkcfoddnzjosi.supabase.co',
      publishableKey: 'sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX',
    );
  } catch (e) {
    debugPrint('Supabase init skipped: $e');
  }

  await FcmService().initialize();

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
