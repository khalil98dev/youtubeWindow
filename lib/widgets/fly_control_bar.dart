import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';
import 'glass_icon_button.dart';

class FlyControlBar extends StatefulWidget {
  final bool isAlwaysOnTop;
  final bool isFullDragMode;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleFullDrag;
  final VoidCallback onRestoreWindow;
  final VoidCallback? onBackToSettings;
  final VoidCallback? onReload;
  final ValueChanged<Offset>? onDragButton;

  const FlyControlBar({
    super.key,
    required this.isAlwaysOnTop,
    this.isFullDragMode = false,
    required this.onTogglePin,
    required this.onToggleFullDrag,
    required this.onRestoreWindow,
    this.onBackToSettings,
    this.onReload,
    this.onDragButton,
  });

  @override
  State<FlyControlBar> createState() => FlyControlBarState();
}

class FlyControlBarState extends State<FlyControlBar> {
  bool _isHovered = false;
  bool _isFadedOut = false;
  bool _isDragging = false;
  Timer? _collapseTimer;
  Timer? _fadeTimer;

  bool get _isExpanded => _isHovered || widget.isFullDragMode || _isDragging;

  @override
  void initState() {
    super.initState();
    // Fade out after initial 2.5s delay if not hovered
    _startFadeTimer(const Duration(milliseconds: 2500));
  }

  void _startFadeTimer(Duration delay) {
    _fadeTimer?.cancel();
    _fadeTimer = Timer(delay, () {
      if (mounted && !_isHovered && !widget.isFullDragMode && !_isDragging) {
        setState(() => _isFadedOut = true);
      }
    });
  }

  /// Wake up the button when mouse moves or interacts
  void wakeUp() {
    _fadeTimer?.cancel();
    if (_isFadedOut) {
      setState(() => _isFadedOut = false);
    }
    if (!_isHovered && !widget.isFullDragMode) {
      _startFadeTimer(const Duration(milliseconds: 2200));
    }
  }

  void _onHoverEnter() {
    _fadeTimer?.cancel();
    _collapseTimer?.cancel();
    setState(() {
      _isFadedOut = false;
      _isHovered = true;
    });
  }

  void _onHoverExit() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted && !widget.isFullDragMode && !_isDragging) {
        setState(() => _isHovered = false);
        // Start smooth fade out after mouse leaves
        _startFadeTimer(const Duration(milliseconds: 1800));
      }
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Opacity calculation:
    // When hovered or moving or dragging: 1.0
    // When faded out: 0.08 (ultra subtle ghost, non-intrusive)
    // When idle before fade: 0.45
    final double targetOpacity = (_isExpanded || _isDragging)
        ? 1.0
        : (_isFadedOut ? 0.08 : 0.45);

    return MouseRegion(
      onEnter: (_) => _onHoverEnter(),
      onExit: (_) => _onHoverExit(),
      child: AnimatedOpacity(
        opacity: targetOpacity,
        duration: Duration(milliseconds: _isFadedOut ? 600 : 150),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isFullDragMode
                      ? AppTheme.accentCyan.withValues(alpha: 0.8)
                      : (_isExpanded
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.14)),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                  if (widget.isFullDragMode)
                    BoxShadow(
                      color: AppTheme.accentCyan.withValues(alpha: 0.35),
                      blurRadius: 14,
                    )
                  else if (widget.isAlwaysOnTop)
                    BoxShadow(
                      color: AppTheme.pinActive.withValues(alpha: 0.28),
                      blurRadius: 12,
                    ),
                ],
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerRight,
                child: _isExpanded ? _buildExpandedDock() : _buildDraggableSettingOrb(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableSettingOrb() {
    return GestureDetector(
      onPanStart: (_) {
        _fadeTimer?.cancel();
        _collapseTimer?.cancel();
        setState(() {
          _isDragging = true;
          _isFadedOut = false;
        });
      },
      onPanUpdate: (details) {
        widget.onDragButton?.call(details.delta);
      },
      onPanEnd: (_) {
        setState(() => _isDragging = false);
        _startFadeTimer(const Duration(milliseconds: 2000));
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GlassIconButton(
          icon: widget.isFullDragMode
              ? Icons.open_with_rounded
              : (widget.isAlwaysOnTop ? Icons.push_pin_rounded : Icons.settings_rounded),
          size: 34,
          iconSize: 16,
          isActive: widget.isAlwaysOnTop || widget.isFullDragMode,
          activeColor: widget.isFullDragMode ? AppTheme.accentCyan : AppTheme.pinActive,
          tooltip: 'Hover to expand · Drag to reposition',
          onPressed: widget.onBackToSettings,
        ),
      ),
    );
  }

  Widget _buildExpandedDock() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Settings Icon (clickable to go to settings, also anchors hover)
        if (widget.onBackToSettings != null)
          GlassIconButton(
            icon: Icons.settings_rounded,
            size: 34,
            iconSize: 15,
            iconColor: Colors.white70,
            tooltip: 'Settings',
            onPressed: widget.onBackToSettings,
          ),
        const SizedBox(width: 5),

        // Draggable Grip handle (drags the native window)
        DragToMoveArea(
          child: Tooltip(
            message: 'Drag window',
            child: Container(
              width: 26,
              height: 34,
              alignment: Alignment.center,
              child: const Icon(
                Icons.drag_indicator_rounded,
                size: 16,
                color: Colors.white60,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),

        // Full Screen Move toggle
        GlassIconButton(
          icon: Icons.open_with_rounded,
          size: 34,
          iconSize: 15,
          isActive: widget.isFullDragMode,
          activeColor: AppTheme.accentCyan,
          tooltip: widget.isFullDragMode ? 'Exit Drag Mode' : 'Move Screen Anywhere',
          onPressed: widget.onToggleFullDrag,
        ),
        const SizedBox(width: 5),

        // Pin / Unpin (Always on Top)
        GlassIconButton(
          icon: widget.isAlwaysOnTop ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          size: 34,
          iconSize: 15,
          isActive: widget.isAlwaysOnTop,
          activeColor: AppTheme.pinActive,
          tooltip: widget.isAlwaysOnTop ? 'Unpin' : 'Pin Always on Top',
          onPressed: widget.onTogglePin,
        ),
        const SizedBox(width: 5),

        // Restore Window Controls & Borders
        GlassIconButton(
          icon: Icons.border_all_rounded,
          size: 34,
          iconSize: 15,
          iconColor: Colors.white,
          tooltip: 'Show Window Controls',
          onPressed: widget.onRestoreWindow,
        ),

        // Reload
        if (widget.onReload != null) ...[
          const SizedBox(width: 5),
          GlassIconButton(
            icon: Icons.refresh_rounded,
            size: 34,
            iconSize: 15,
            iconColor: Colors.white70,
            tooltip: 'Reload',
            onPressed: widget.onReload,
          ),
        ],
      ],
    );
  }
}
