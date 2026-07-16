import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentUserRoleProvider = Provider<String?>((ref) {
  return null;
});

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/role-picker',
    redirect: (context, state) {
      final role = ref.read(currentUserRoleProvider);
      final isBuyerRoute = state.matchedLocation.startsWith('/buyer');
      final isFarmerRoute = state.matchedLocation.startsWith('/farmer');
      if (role == null) return '/role-picker';
      if (isBuyerRoute && role != 'buyer') return '/farmer';
      if (isFarmerRoute && role != 'farmer') return '/buyer';
      return null;
    },
    routes: [
      GoRoute(
        path: '/role-picker',
        builder: (context, state) =>
            const PlaceholderScreen(title: 'Role Picker'),
      ),
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          ...buyerRoutes,
          ...farmerRoutes,
        ],
      ),
    ],
  );
});

final buyerRoutes = <RouteBase>[
  GoRoute(
    path: '/buyer',
    builder: (context, state) =>
        const PlaceholderScreen(title: 'Buyer Home'),
  ),
];

final farmerRoutes = <RouteBase>[
  GoRoute(
    path: '/farmer',
    builder: (context, state) =>
        const PlaceholderScreen(title: 'Farmer Home'),
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
