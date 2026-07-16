import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/role_picker_screen.dart';
import '../../features/auth/screens/name_input_screen.dart';

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
        builder: (context, state) => const RolePickerScreen(),
      ),
      GoRoute(
        path: '/name-input',
        builder: (context, state) {
          final role = state.extra as String;
          return NameInputScreen(role: role);
        },
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
