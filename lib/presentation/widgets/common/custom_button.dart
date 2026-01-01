import 'package:flutter/material.dart';
import '../../../app/theme.dart';

enum CustomButtonVariant { primary, secondary, outline, ghost, danger }

enum CustomButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final CustomButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = CustomButtonVariant.primary,
    this.size = CustomButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle();
    final textStyle = _getTextStyle();
    final padding = _getPadding();

    Widget buttonChild = isLoading
        ? SizedBox(
            height: _getIconSize(),
            width: _getIconSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
            ),
          )
        : Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _getIconSize(), color: _getTextColor()),
                const SizedBox(width: 8),
              ],
              Text(text, style: textStyle),
            ],
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: buttonStyle.copyWith(padding: WidgetStateProperty.all(padding)),
        child: buttonChild,
      ),
    );
  }

  ButtonStyle _getButtonStyle() {
    switch (variant) {
      case CustomButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: AppTheme.textPrincipal,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      case CustomButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: AppTheme.bgMedio,
          foregroundColor: AppTheme.textPrincipal,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      case CustomButtonVariant.outline:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.textPrincipal,
          elevation: 0,
          side: const BorderSide(color: AppTheme.bgMedio, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      case CustomButtonVariant.ghost:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppTheme.textPrincipal,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
      case CustomButtonVariant.danger:
        return ElevatedButton.styleFrom(
          backgroundColor: AppTheme.error,
          foregroundColor: AppTheme.textPrincipal,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        );
    }
  }

  TextStyle _getTextStyle() {
    final fontSize = size == CustomButtonSize.small
        ? 12.0
        : size == CustomButtonSize.medium
        ? 14.0
        : 16.0;

    return TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: _getTextColor(),
    );
  }

  Color _getTextColor() {
    if (variant == CustomButtonVariant.outline ||
        variant == CustomButtonVariant.ghost) {
      return AppTheme.textPrincipal;
    }
    return AppTheme.textPrincipal;
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case CustomButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case CustomButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case CustomButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  double _getIconSize() {
    switch (size) {
      case CustomButtonSize.small:
        return 16;
      case CustomButtonSize.medium:
        return 20;
      case CustomButtonSize.large:
        return 24;
    }
  }
}
