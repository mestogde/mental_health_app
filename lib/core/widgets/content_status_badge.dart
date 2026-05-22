import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ContentStatusBadge extends StatelessWidget {
  const ContentStatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final baseBackground = const Color(0xFF1F1F1F).withValues(alpha: 0.42);
    final tintedBackground = Color.alphaBlend(
      backgroundColor.withValues(alpha: 0.08),
      baseBackground,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tintedBackground,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: foregroundColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class ContentStatusColors {
  const ContentStatusColors._();

  static const readBackground = AppColors.greenStatus;
  static const readForeground = Color(0xFF2E5D33);
  static const completedBackground = AppColors.greenStatus;
  static const completedForeground = Color(0xFF2E5D33);
}
