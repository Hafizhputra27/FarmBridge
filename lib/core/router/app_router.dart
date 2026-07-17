import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/role_picker_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/profile/screens/farmer_profile_screen.dart';
import '../../features/profile/screens/buyer_profile_screen.dart';
import '../../features/listing/screens/my_listings_screen.dart';
import '../../features/listing/screens/create_listing_screen.dart';
import '../../features/listing/screens/buyer_home_feed_screen.dart';
import '../../features/listing/screens/search_filter_screen.dart';
import '../../features/negotiation/screens/negotiation_chat_screen.dart';
import '../../features/negotiation/screens/chat_inbox_screen.dart';
import '../../features/listing/screens/listing_detail_screen.dart';
import '../../features/transaction/screens/transaction_detail_screen.dart';
import '../../features/recurring_order/screens/recurring_orders_screen.dart';
import '../../features/recurring_order/screens/recurring_order_detail_screen.dart';
import '../widgets/main_shell.dart';

// Pure — diextract dari redirect callback supaya bisa diunit-test tanpa
// device/emulator (lihat test/app_router_redirect_test.dart).
String? resolveRedirect(String? role, String matchedLocation) {
  final isOnboardingRoute =
      matchedLocation == '/role-picker' || matchedLocation == '/login';

  // Belum punya role (baru di-set setelah LoginScreen sukses) —
  // biarkan tetap di alur onboarding, jangan dipaksa balik ke
  // role-picker di tengah alurnya sendiri (dulu ini bikin loop).
  if (role == null) {
    return isOnboardingRoute ? null : '/role-picker';
  }

  // Role sudah ada (baru dipilih, atau di-restore dari session lama) —
  // jangan biarkan nyangkut di layar onboarding (initialLocation app
  // selalu '/role-picker', jadi restore session butuh redirect ini).
  if (isOnboardingRoute) {
    return role == 'farmer' ? '/farmer/listings' : '/buyer';
  }

  // Exact-or-slash, bukan raw prefix — '/farmer-profile/:id' tidak
  // boleh ke-anggap farmer-only route oleh startsWith('/farmer') mentah.
  final isBuyerRoute =
      matchedLocation == '/buyer' || matchedLocation.startsWith('/buyer/');
  final isFarmerRoute =
      matchedLocation == '/farmer' || matchedLocation.startsWith('/farmer/');
  if (isBuyerRoute && role != 'buyer') return '/farmer/listings';
  if (isFarmerRoute && role != 'farmer') return '/buyer';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/role-picker',
    redirect: (context, state) {
      final role = ref.read(currentUserRoleProvider);
      return resolveRedirect(role, state.matchedLocation);
    },
    routes: [
      GoRoute(
        path: '/role-picker',
        builder: (context, state) => const RolePickerScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final role = state.extra as String;
          return LoginScreen(role: role);
        },
      ),
      ShellRoute(
        builder: (context, state, child) =>
            MainShell(location: state.matchedLocation, child: child),
        routes: [
          ...buyerRoutes,
          ...farmerRoutes,
          GoRoute(
            path: '/farmer-profile/:id',
            builder: (context, state) =>
                FarmerProfileScreen(farmerId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/buyer-profile/:id',
            builder: (context, state) =>
                BuyerProfileScreen(buyerId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/percakapan',
            builder: (context, state) => const ChatInboxScreen(),
          ),
          GoRoute(
            path: '/listing/:id',
            builder: (context, state) =>
                ListingDetailScreen(listingId: state.pathParameters['id']!),
          ),
        ],
      ),
      // Full-screen, sengaja di luar shell — chat detail tidak butuh
      // bottom nav bar persisten.
      GoRoute(
        path: '/negosiasi/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return NegotiationChatScreen(negotiationId: id);
        },
      ),
      GoRoute(
        path: '/transaksi/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TransactionDetailScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/recurring-orders',
        builder: (context, state) => const RecurringOrdersScreen(),
      ),
      GoRoute(
        path: '/recurring-orders/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RecurringOrderDetailScreen(recurringOrderId: id);
        },
      ),
    ],
  );
});

final buyerRoutes = <RouteBase>[
  GoRoute(
    path: '/buyer',
    builder: (context, state) => const BuyerHomeFeedScreen(),
    routes: [
      GoRoute(
        path: 'search',
        builder: (context, state) => const SearchFilterScreen(),
      ),
    ],
  ),
];

final farmerRoutes = <RouteBase>[
  GoRoute(
    path: '/farmer',
    builder: (context, state) =>
        const PlaceholderScreen(title: 'Farmer Home'),
    routes: [
      GoRoute(
        path: 'listings',
        builder: (context, state) => const MyListingsScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateListingScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) {
              final listing = state.extra as Map<String, dynamic>;
              return CreateListingScreen(listing: listing);
            },
          ),
        ],
      ),
    ],
  ),
];

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — placeholder')),
    );
  }
}
