import 'package:flutter/material.dart';

class NegotiationActions extends StatelessWidget {
  final bool isReceiver;
  final String status;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final void Function(double offerPrice, String message) onCounter;

  const NegotiationActions({
    super.key,
    required this.isReceiver,
    required this.status,
    required this.onAccept,
    required this.onDecline,
    required this.onCounter,
  });

  bool get _canAct =>
      isReceiver && (status == 'open' || status == 'countered');

  @override
  Widget build(BuildContext context) {
    if (!_canAct) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onDecline,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade400),
                shape: const StadiumBorder(),
              ),
              child: const Text('Tolak', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _showCounterDialog(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: const Color(0xFF14532D),
                side: const BorderSide(color: Color(0xFF14532D)),
                shape: const StadiumBorder(),
              ),
              child: const Text('Tawar', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: const Color(0xFF14532D),
                shape: const StadiumBorder(),
              ),
              child: const Text('Terima', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCounterDialog(BuildContext context) {
    final priceController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tawar Harga'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga tawaran (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Pesan (opsional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final price =
                  double.tryParse(priceController.text);
              if (price != null && price > 0) {
                Navigator.pop(ctx);
                onCounter(price, messageController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            child: const Text('Kirim Tawaran'),
          ),
        ],
      ),
    );
  }
}
