import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? iconColor;
  final Color? activeColor;
  final bool isActive;
  final double size;
  final double iconSize;
  final Widget? customIcon;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.iconColor,
    this.activeColor,
    this.isActive = false,
    this.size = 36,
    this.iconSize = 16,
    this.customIcon,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = widget.activeColor ?? AppTheme.accentCyan;
    final effectiveIconColor = widget.isActive
        ? effectiveActiveColor
        : (widget.iconColor ?? (_isHovered ? Colors.white : AppTheme.textPrimary));

    Widget button = MouseRegion(
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : (_isHovered ? 1.06 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.size / 2),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isActive
                      ? effectiveActiveColor.withValues(alpha: 0.22)
                      : (_isHovered
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.08)),
                  border: Border.all(
                    color: widget.isActive
                        ? effectiveActiveColor.withValues(alpha: 0.6)
                        : (_isHovered
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.12)),
                    width: widget.isActive ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    if (widget.isActive)
                      BoxShadow(
                        color: effectiveActiveColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                      )
                    else if (_isHovered)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                  ],
                ),
                child: widget.customIcon ??
                    Icon(
                      widget.icon,
                      size: widget.iconSize,
                      color: effectiveIconColor,
                    ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}
