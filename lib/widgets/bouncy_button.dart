import 'package:flutter/material.dart';

class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final EdgeInsetsGeometry padding;
  final BoxDecoration? decoration;
  final BoxDecoration? hoverDecoration;
  final double scaleFactor;
  final Duration duration;

  const BouncyButton({
    super.key,
    required this.child,
    this.onPressed,
    this.tooltip,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.decoration,
    this.hoverDecoration,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 140),
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    final currentDecoration = (_isHovered && widget.hoverDecoration != null)
        ? widget.hoverDecoration
        : widget.decoration;

    Widget button = MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isEnabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (isEnabled) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (isEnabled) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (isEnabled) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (isEnabled) setState(() => _isPressed = false);
        },
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? widget.scaleFactor : (_isHovered ? 1.02 : 1.0),
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: widget.duration,
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            decoration: currentDecoration,
            child: widget.child,
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

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.45,
      child: button,
    );
  }
}
