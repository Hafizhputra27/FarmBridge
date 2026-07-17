import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

/// Header identitas profil (avatar + nama + lokasi + bio + badge verified),
/// dipakai farmer & buyer profile. Sesuai desain FarmBridge (Sprint 2 ke-6).
class ProfileHeader extends StatelessWidget {
  final String name;
  final String? location;
  final String? bio;
  final bool verified;

  const ProfileHeader({
    super.key,
    required this.name,
    this.location,
    this.bio,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: AppTheme.sage,
              child: Text(
                initial,
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.brandGreen),
              ),
            ),
            if (verified)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified,
                      size: 22, color: AppTheme.brandGreen),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (location != null && location!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined,
                  size: 15, color: Colors.grey.shade600),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  location!,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
        if (bio != null && bio!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            bio!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.35),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}
