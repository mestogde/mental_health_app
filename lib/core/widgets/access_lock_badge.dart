import 'package:flutter/material.dart';

class AccessLockBadge extends StatelessWidget {
  const AccessLockBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F).withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.lock_outline, color: Colors.white, size: 12),
    );
  }
}
