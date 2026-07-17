import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

/// Tombol keluar (appbar) — konfirmasi dulu, lalu signOut + balik ke
/// role-picker. Dipakai di profil farmer & buyer (hanya saat profil sendiri).
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Keluar',
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Keluar?'),
            content: const Text('Anda akan keluar dari akun ini.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await ref.read(authProvider.notifier).signOut();
        // Role jadi null setelah signOut; router tidak re-evaluate tanpa
        // navigasi, jadi arahkan eksplisit ke role-picker.
        if (context.mounted) context.go('/role-picker');
      },
    );
  }
}
