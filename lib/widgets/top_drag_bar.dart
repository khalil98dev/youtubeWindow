import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';

class TopDragBar extends StatefulWidget {
  final bool isAlwaysOnTop;

  const TopDragBar({
    super.key,
    this.isAlwaysOnTop = false,
  });

  @override
  State<TopDragBar> createState() => _TopDragBarState();
}

class _TopDragBarState extends State<TopDragBar> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: DragToMoveArea(
        child: Container(
          height: 38,
          color: Colors.transparent,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: AnimatedOpacity(
            opacity: _isHovered ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Tooltip(
              message: 'Drag window',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.drag_handle_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        if (widget.isAlwaysOnTop) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.push_pin_rounded,
                            size: 13,
                            color: AppTheme.pinActive,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
