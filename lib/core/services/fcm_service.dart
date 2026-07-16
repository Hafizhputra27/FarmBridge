import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ponytail: sengaja kosong — FCM sudah menampilkan notifikasi system tray
  // otomatis untuk payload `notification` saat app di background/terminated,
  // tidak perlu handling manual untuk MVP.
}

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    await _messaging.requestPermission();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveDeviceToken(token);
    }
    _messaging.onTokenRefresh.listen(_saveDeviceToken);
  }

  Future<void> _saveDeviceToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      // Belum ada user login (role picker FG-11 baru Sprint 3) — token
      // akan tersimpan otomatis lewat onTokenRefresh atau initialize()
      // berikutnya begitu user sudah punya sesi.
      return;
    }
    await Supabase.instance.client
        .from('users')
        .update({'device_token': token}).eq('id', userId);
  }
}
