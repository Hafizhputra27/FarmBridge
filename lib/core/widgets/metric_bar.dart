import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Bar metrik trust-score — dipakai profil petani (Pengiriman Tepat Waktu,
/// Tingkat Penolakan, Konsistensi Pemenuhan) & profil pembeli (Reliability).
/// Sekali di sini, dua layar konsisten.
class MetricBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final num percent; // 0..100
  final bool isLast;

  const MetricBar({
    super.key,
    required this.icon,
    required this.label,
    required this.percent,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Text('${percent.toStringAsFixed(percent % 1 == 0 ? 0 : 1)}%',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percent.clamp(0, 100)) / 100,
              minHeight: 7,
              backgroundColor: AppTheme.sage,
              valueColor:
                  const AlwaysStoppedAnimation(AppTheme.brandGreen),
            ),
          ),
        ],
      ),
    );
  }
}
