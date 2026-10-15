import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';
import 'package:window_manager/window_manager.dart';
import '../models/window_preset.dart';
import '../theme/app_theme.dart';
import '../widgets/fly_control_bar.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/status_banner.dart';
import '../widgets/top_drag_bar.dart';

class PlayerView extends StatefulWidget {
  final WebviewController controller;
  final bool isAlwaysOnTop;
  final bool isBorderlessMode;
  final ValueChanged<bool> onToggleAlwaysOnTop;
  final Future<void> Function(bool borderless) onToggleBorderless;
  final VoidCallback onBackToSettings;
  final Future<void> Function(int width, int height) onResizeWindow;

  const PlayerView({
    super.key,
    required this.controller,
    required this.isAlwaysOnTop,
    required this.isBorderlessMode,
    required this.onToggleAlwaysOnTop,
    required this.onToggleBorderless,
    required this.onBackToSettings,
    required this.onResizeWindow,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reloadAnimController;
  StreamSubscription<LoadingState>? _loadingSubscription;

  bool _isPageLoading = false;
  String? _toastMessage;
  IconData _toastIcon = Icons.info_outline_rounded;
  Color _toastColor = AppTheme.pinActive;
  Timer? _toastTimer;
  bool _isToolbarCollapsed = false;
  bool _isFullDragMode = false;
  final GlobalKey<FlyControlBarState> _flyKey = GlobalKey<FlyControlBarState>();
  double _flyRight = 14;
  double _flyTop = 14;

  @override
  void initState() {
    super.initState();
    _reloadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _loadingSubscription = widget.controller.loadingState.listen((state) {
      if (mounted) {
        setState(() => _isPageLoading = state == LoadingState.loading);
      }
    });
  }

  @override
  void dispose() {
    _reloadAnimController.dispose();
    _loadingSubscription?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast(String message, IconData icon, Color color) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastIcon = icon;
      _toastColor = color;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() => _toastMessage = null);
      }
    });
  }

  void _handleTogglePin() {
    final nextState = !widget.isAlwaysOnTop;
    widget.onToggleAlwaysOnTop(nextState);
    if (nextState) {
      _showToast('Pinned on top', Icons.push_pin_rounded, AppTheme.pinActive);
    } else {
      _showToast('Unpinned', Icons.push_pin_outlined, AppTheme.textSecondary);
    }
  }

  Future<void> _handleEnterBorderless() async {
    await widget.onToggleBorderless(true);
    _showToast('Pure View active', Icons.crop_free_rounded, AppTheme.accentCyan);
  }

  Future<void> _handleRestoreWindow() async {
    setState(() => _isFullDragMode = false);
    await widget.onToggleBorderless(false);
    _showToast('Controls restored', Icons.border_all_rounded, AppTheme.accentGreen);
  }

  Future<void> _handleReload() async {
    _reloadAnimController.forward(from: 0.0);
    await widget.controller.reload();
  }

  void _handleResize(WindowPreset preset) {
    widget.onResizeWindow(preset.width, preset.height);
  }

  @override
  Widget build(BuildContext context) {
    final borderless = widget.isBorderlessMode;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: !borderless,
        bottom: !borderless,
        left: !borderless,
        right: !borderless,
        child: DragToResizeArea(
          resizeEdgeSize: 8,
          child: MouseRegion(
            onHover: (_) => _flyKey.currentState?.wakeUp(),
            child: Stack(
              children: [
                // Video Area + Top Bar (when in standard mode)
                Column(
                  children: [
                    if (!borderless) ...[
                      // Draggable Top Navigation Bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        height: _isToolbarCollapsed ? 6 : null,
                        child: _isToolbarCollapsed
                            ? _buildCollapsedHandle()
                            : _buildExpandedToolbar(),
                      ),

                      // Dropdown notification banner
                      if (!_isToolbarCollapsed)
                        StatusBanner(
                          message: _toastMessage,
                          icon: _toastIcon,
                          iconColor: _toastColor,
                          onDismiss: () => setState(() => _toastMessage = null),
                        ),
                    ],

                    // Webview Video Area
                    Expanded(
                      child: Webview(widget.controller),
                    ),
                  ],
                ),

                // Top Drag Bar across the top of the pure view window
                if (borderless && !_isFullDragMode)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: TopDragBar(isAlwaysOnTop: widget.isAlwaysOnTop),
                  ),

                // Floating Fly Button Overlay (visible in borderless mode)
                if (borderless)
                  Positioned(
                    top: _flyTop,
                    right: _flyRight,
                    child: FlyControlBar(
                      key: _flyKey,
                      isAlwaysOnTop: widget.isAlwaysOnTop,
                      isFullDragMode: _isFullDragMode,
                      onTogglePin: _handleTogglePin,
                      onToggleFullDrag: () =>
                          setState(() => _isFullDragMode = !_isFullDragMode),
                      onRestoreWindow: _handleRestoreWindow,
                      onBackToSettings: () {
                        setState(() => _isFullDragMode = false);
                        widget.onBackToSettings();
                      },
                      onReload: _handleReload,
                      onDragButton: (delta) {
                        setState(() {
                          _flyRight = (_flyRight - delta.dx).clamp(8.0, 1400.0);
                          _flyTop = (_flyTop + delta.dy).clamp(8.0, 1400.0);
                        });
                      },
                    ),
                  ),

              // Full Screen Drag Overlay (when full drag mode is toggled)
              if (borderless && _isFullDragMode)
                Positioned.fill(
                  child: DragToMoveArea(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppTheme.accentCyan.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentCyan.withValues(alpha: 0.25),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.open_with_rounded,
                                    size: 20,
                                    color: AppTheme.accentCyan,
                                  ),
                                  const SizedBox(width: 12),
                                  GlassIconButton(
                                    icon: Icons.check_rounded,
                                    size: 32,
                                    iconSize: 16,
                                    isActive: true,
                                    activeColor: AppTheme.accentCyan,
                                    tooltip: 'Done Moving',
                                    onPressed: () =>
                                        setState(() => _isFullDragMode = false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Minimalist Drop-down toast in borderless mode
              if (borderless && _toastMessage != null)
                Positioned(
                  top: 58,
                  right: 14,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_toastIcon, size: 13, color: _toastColor),
                            const SizedBox(width: 6),
                            Text(
                              _toastMessage!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildCollapsedHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isToolbarCollapsed = false),
      child: GestureDetector(
        onTap: () => setState(() => _isToolbarCollapsed = false),
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedToolbar() {
    return DragToMoveArea(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      // Back to Settings Glass Icon Button
                      GlassIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 32,
                        iconSize: 13,
                        tooltip: 'Settings',
                        onPressed: widget.onBackToSettings,
                      ),
                      const SizedBox(width: 8),

                      // Draggable grip in center
                      Expanded(
                        child: Center(
                          child: Tooltip(
                            message: 'Drag window',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: const Icon(
                                Icons.drag_handle_rounded,
                                size: 16,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Pure View Glass Button
                      GlassIconButton(
                        icon: Icons.crop_free_rounded,
                        size: 32,
                        iconSize: 14,
                        activeColor: AppTheme.accentCyan,
                        tooltip: 'Pure View',
                        onPressed: _handleEnterBorderless,
                      ),
                      const SizedBox(width: 6),

                      // Window Size Menu
                      _buildGlassSizeMenu(),
                      const SizedBox(width: 6),

                      // Pin / Always On Top Button
                      GlassIconButton(
                        icon: widget.isAlwaysOnTop
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        size: 32,
                        iconSize: 14,
                        isActive: widget.isAlwaysOnTop,
                        activeColor: AppTheme.pinActive,
                        tooltip: widget.isAlwaysOnTop ? 'Unpin' : 'Pin Always on Top',
                        onPressed: _handleTogglePin,
                      ),
                      const SizedBox(width: 6),

                      // Reload Button
                      GlassIconButton(
                        icon: Icons.refresh_rounded,
                        size: 32,
                        iconSize: 15,
                        customIcon: RotationTransition(
                          turns: _reloadAnimController,
                          child: const Icon(
                            Icons.refresh_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                        tooltip: 'Reload',
                        onPressed: _handleReload,
                      ),
                      const SizedBox(width: 6),

                      // Collapse Header Button
                      GlassIconButton(
                        icon: Icons.keyboard_arrow_up_rounded,
                        size: 32,
                        iconSize: 16,
                        tooltip: 'Collapse',
                        onPressed: () => setState(() => _isToolbarCollapsed = true),
                      ),
                    ],
                  ),
                ),

                // Sleek 2px progress bar
                if (_isPageLoading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.youtubeRed),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSizeMenu() {
    return PopupMenuButton<WindowPreset>(
      tooltip: 'Resize',
      color: const Color(0xF0181A24),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      offset: const Offset(0, 36),
      onSelected: _handleResize,
      itemBuilder: (context) {
        return WindowPreset.presets.map((preset) {
          return PopupMenuItem<WindowPreset>(
            value: preset,
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  preset.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  preset.subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: GlassIconButton(
        icon: Icons.aspect_ratio_rounded,
        size: 32,
        iconSize: 14,
        tooltip: 'Resize Window',
      ),
    );
  }
}
