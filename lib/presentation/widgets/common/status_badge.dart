import 'package:flutter/material.dart';
import '../../../app/theme.dart';

enum BadgeStatus { active, inactive, completed, failed, pending, warning }

class StatusBadge extends StatelessWidget {
  final BadgeStatus status;
  final String? customLabel;

  const StatusBadge({super.key, required this.status, this.customLabel});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.iconColor),
          const SizedBox(width: 4),
          Text(
            customLabel ?? config.label,
            style: TextStyle(
              color: config.textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getConfig() {
    switch (status) {
      case BadgeStatus.active:
        return _BadgeConfig(
          label: 'ACTIVO',
          icon: Icons.check_circle,
          backgroundColor: AppTheme.success.withValues(alpha: 0.1),
          borderColor: AppTheme.success,
          iconColor: AppTheme.success,
          textColor: AppTheme.success,
        );
      case BadgeStatus.inactive:
        return _BadgeConfig(
          label: 'INACTIVO',
          icon: Icons.pause_circle,
          backgroundColor: Colors.grey.withValues(alpha: 0.1),
          borderColor: Colors.grey,
          iconColor: Colors.grey,
          textColor: Colors.grey,
        );
      case BadgeStatus.completed:
        return _BadgeConfig(
          label: 'COMPLETADO',
          icon: Icons.check_circle,
          backgroundColor: AppTheme.success.withValues(alpha: 0.1),
          borderColor: AppTheme.success,
          iconColor: AppTheme.success,
          textColor: AppTheme.success,
        );
      case BadgeStatus.failed:
        return _BadgeConfig(
          label: 'FALLIDO',
          icon: Icons.cancel,
          backgroundColor: AppTheme.error.withValues(alpha: 0.1),
          borderColor: AppTheme.error,
          iconColor: AppTheme.error,
          textColor: AppTheme.error,
        );
      case BadgeStatus.pending:
        return _BadgeConfig(
          label: 'PENDIENTE',
          icon: Icons.schedule,
          backgroundColor: AppTheme.warning.withValues(alpha: 0.1),
          borderColor: AppTheme.warning,
          iconColor: AppTheme.warning,
          textColor: AppTheme.warning,
        );
      case BadgeStatus.warning:
        return _BadgeConfig(
          label: 'ADVERTENCIA',
          icon: Icons.warning_amber,
          backgroundColor: AppTheme.warning.withValues(alpha: 0.1),
          borderColor: AppTheme.warning,
          iconColor: AppTheme.warning,
          textColor: AppTheme.warning,
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;

  _BadgeConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
  });
}
