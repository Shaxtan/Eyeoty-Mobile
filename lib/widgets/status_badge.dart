import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color _color() {
    switch (status.toLowerCase()) {
      case 'running':
      case 'moving':
      case 'online':
        return AppColors.statusMoving;
      case 'idle':
        return AppColors.statusIdle;
      case 'stopped':
        return AppColors.statusStopped;
      default:
        return AppColors.statusInactive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      // decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
            decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
