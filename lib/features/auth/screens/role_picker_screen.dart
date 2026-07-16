import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class RolePickerScreen extends ConsumerWidget {
  const RolePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      authProvider.select((s) => s.isLoading),
    );
    final error = ref.watch(
      authProvider.select((s) => s.error),
    );

    return Scaffold(
      backgroundColor: Colors.green.shade800,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.agriculture, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'FarmBridge',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Pilih peran Anda',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 40),
                  _RoleCard(
                    icon: Icons.agriculture,
                    label: 'Saya Petani',
                    role: 'farmer',
                    isLoading: isLoading,
                    onTap: () => _handleRoleSelect(context, 'farmer'),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.storefront,
                    label: 'Saya Pembeli',
                    role: 'buyer',
                    isLoading: isLoading,
                    onTap: () => _handleRoleSelect(context, 'buyer'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      error,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _handleRoleSelect(BuildContext context, String role) {
    context.push('/login', extra: role);
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String role;
  final bool isLoading;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.role,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 36, color: Colors.white),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
