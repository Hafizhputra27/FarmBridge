import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/providers/auth_provider.dart';

/// buyer_profiles.id milik user yang sedang login — dipakai tab "Profil"
/// (route /buyer-profile/:id expect buyer_profiles.id, bukan users.id).
final myBuyerProfileIdProvider =
    FutureProvider.family<String?, String>((ref, userId) async {
  final row = await Supabase.instance.client
      .from('buyer_profiles')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle();
  return row?['id'] as String?;
});

// Pure — supaya bisa diunit-test tanpa widget tree.
int buyerTabIndexFor(String location) {
  if (location.startsWith('/buyer/search')) return 1;
  if (location == '/percakapan') return 2;
  if (location.startsWith('/buyer-profile/')) return 3;
  return 0;
}

int farmerTabIndexFor(String location) {
  if (location == '/percakapan') return 1;
  if (location.startsWith('/farmer-profile/')) return 2;
  // /farmer/dashboard dan /farmer/listings (diakses via tombol appbar)
  // sama-sama "home" petani — highlight tab Dashboard.
  return 0;
}

class MainShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const MainShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    final userId = ref.watch(authProvider.select((s) => s.userId));

    if (role == 'farmer') {
      return _FarmerShell(userId: userId, location: location, child: child);
    }
    return _BuyerShell(userId: userId, location: location, child: child);
  }
}

class _BuyerShell extends ConsumerWidget {
  final String? userId;
  final String location;
  final Widget child;

  const _BuyerShell({
    required this.userId,
    required this.location,
    required this.child,
  });

  Future<void> _onTap(BuildContext context, WidgetRef ref, int index) async {
    switch (index) {
      case 0:
        context.go('/buyer');
      case 1:
        context.go('/buyer/search');
      case 2:
        context.go('/percakapan');
      case 3:
        final uid = userId;
        if (uid == null) return;
        final buyerProfileId =
            await ref.read(myBuyerProfileIdProvider(uid).future);
        if (buyerProfileId != null && context.mounted) {
          context.go('/buyer-profile/$buyerProfileId');
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _FloatingNav(
        child: BottomNavigationBar(
          currentIndex: buyerTabIndexFor(location),
          onTap: (index) => _onTap(context, ref, index),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Percakapan',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}

/// Pembungkus visual: bikin BottomNavigationBar tampil sebagai pill mengambang
/// (margin + rounded + shadow) sesuai desain, tanpa mengubah behavior tab.
class _FloatingNav extends StatelessWidget {
  final Widget child;
  const _FloatingNav({required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: child,
        ),
      ),
    );
  }
}

class _FarmerShell extends StatelessWidget {
  final String? userId;
  final String location;
  final Widget child;

  const _FarmerShell({
    required this.userId,
    required this.location,
    required this.child,
  });

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/farmer/dashboard');
      case 1:
        context.go('/percakapan');
      case 2:
        final uid = userId;
        if (uid != null) context.go('/farmer-profile/$uid');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _FloatingNav(
        child: BottomNavigationBar(
          currentIndex: farmerTabIndexFor(location),
          onTap: (index) => _onTap(context, index),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.space_dashboard_outlined),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Percakapan',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
