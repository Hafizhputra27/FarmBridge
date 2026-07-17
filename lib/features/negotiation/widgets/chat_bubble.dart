import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/format.dart';

class ChatBubble extends StatelessWidget {
  final bool isMine;
  final String? text;
  final double? offerPrice;
  final double? recommendedPrice;
  final String actionType;
  final DateTime createdAt;

  const ChatBubble({
    super.key,
    required this.isMine,
    this.text,
    this.offerPrice,
    this.recommendedPrice,
    required this.actionType,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    if (actionType == 'accept') {
      return _systemBubble('Diterima', AppTheme.brandGreen);
    }
    if (actionType == 'decline') {
      return _systemBubble('Ditolak', Colors.red.shade600);
    }

    final bubbleColor = isMine ? AppTheme.brandGreen : Colors.white;
    final textColor = isMine ? Colors.white : AppTheme.ink;
    final subColor = isMine ? Colors.white70 : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                border: isMine
                    ? null
                    : Border.all(color: Colors.black.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (actionType == 'counter')
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.18)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Counter Offer',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMine ? Colors.white : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  if (offerPrice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        formatRupiah(offerPrice!),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  if (recommendedPrice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 12, color: subColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Rekomendasi: ${formatRupiah(recommendedPrice!)}',
                              style: TextStyle(fontSize: 12, color: subColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (text != null && text!.isNotEmpty)
                    Text(text!,
                        style: TextStyle(fontSize: 14, color: textColor)),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(fontSize: 10, color: subColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemBubble(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
