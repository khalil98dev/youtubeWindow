import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../controllers/unified_player_controller.dart';
import '../models/window_preset.dart';
import '../services/platform_helper.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fly_control_bar.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/premium_toolbar.dart';
import '../widgets/status_banner.dart';
import '../widgets/top_drag_bar.dart';

class PlayerView extends StatefulWidget {
  final UnifiedPlayerController controller;
  final bool isAlwaysOnTop;
  final bool isBorderlessMode;
  final bool isAdBlockerEnabled;
  final bool isBackgroundPlayEnabled;
  final bool isAudioOnlyEnabled;
  final ValueChanged<bool> onToggleAlwaysOnTop;
  final ValueChanged<bool>? onToggleAdBlocker;
  final ValueChanged<bool>? onToggleBackgroundPlay;
  final ValueChanged<bool>? onToggleAudioOnly;
  final Future<void> Function(bool borderless) onToggleBorderless;
  final VoidCallback onBackToSettings;
  final Future<void> Function(int width, int height) onResizeWindow;

  const PlayerView({
    super.key,
    required this.controller,
    required this.isAlwaysOnTop,
    required this.isBorderlessMode,
    this.isAdBlockerEnabled = true,
    this.isBackgroundPlayEnabled = true,
    this.isAudioOnlyEnabled = false,
    required this.onToggleAlwaysOnTop,
    this.onToggleAdBlocker,
    this.onToggleBackgroundPlay,
    this.onToggleAudioOnly,
    required this.onToggleBorderless,
    required this.onBackToSettings,
    required this.onResizeWindow,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, WindowListener {
  late final AnimationController _reloadAnimController;
  StreamSubscription<bool>? _loadingSubscription;
  StreamSubscription<YouTubeAccountInfo>? _accountSubscription;
  StreamSubscription<Map<String, dynamic>>? _shortcutSubscription;
  final FocusNode _focusNode = FocusNode();

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
  bool _isVideoHidden = false;

  // Premium feature states
  late bool _isBackgroundPlay;
  late bool _isAudioOnly;
  late bool _isAdBlocker;
  bool _isLoop = false;
  double _playbackSpeed = 1.0;
  String _currentQuality = 'hd1080';
  YouTubeAccountInfo? _accountInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (PlatformHelper.isDesktop) {
      windowManager.addListener(this);
    }

    _isBackgroundPlay = widget.isBackgroundPlayEnabled;
    _isAudioOnly = widget.isAudioOnlyEnabled;
    _isAdBlocker = widget.isAdBlockerEnabled;

    _reloadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _loadingSubscription = widget.controller.onLoadingChanged.listen((isLoading) {
      if (mounted) {
        setState(() => _isPageLoading = isLoading);
      }
    });

    _accountSubscription = widget.controller.onAccountChanged.listen((info) {
      if (mounted) {
        setState(() => _accountInfo = info);
      }
    });

    // Listen to shortcuts fired from inside the WebView (JS postMessage)
    _shortcutSubscription = widget.controller.onShortcutEvent.listen((event) {
      final action = event['action'] as String?;
      if (action == 'togglePin') {
        _handleTogglePin();
      } else if (action == 'toggleHide') {
        _handleToggleHideVideo();
      } else if (action == 'playPause') {
        final paused = event['paused'] as bool? ?? false;
        _showToast(
          paused ? 'Paused' : 'Playing',
          paused ? Icons.pause_rounded : Icons.play_arrow_rounded,
          paused ? AppTheme.textPrimary : AppTheme.accentGreen,
        );
      }
    });

    // Listen to physical keyboard events globally when Flutter has focus
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey);
  }

  @override
  void onWindowMinimize() {
    if (mounted) setState(() => _isVideoHidden = true);
  }

  @override
  void onWindowRestore() {
    if (mounted) setState(() => _isVideoHidden = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reset hidden flag when window is restored
    if (state == AppLifecycleState.resumed && _isVideoHidden) {
      setState(() => _isVideoHidden = false);
    }
    // When mobile app is minimized or phone screen is locked:
    if (_isBackgroundPlay) {
      // In background play mode, keep video/audio playing!
      widget.controller.setBackgroundPlay(true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (PlatformHelper.isDesktop) {
      windowManager.removeListener(this);
    }
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    _reloadAnimController.dispose();
    _loadingSubscription?.cancel();
    _accountSubscription?.cancel();
    _shortcutSubscription?.cancel();
    _toastTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Global Keyboard Shortcut Handler (when Flutter window has focus) ──
  bool _handleGlobalHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final key = event.logicalKey;

    // Ctrl+P or Alt+P → Pin / Unpin
    if ((isCtrl || isAlt) && key == LogicalKeyboardKey.keyP) {
      _handleTogglePin();
      return true;
    }

    // Ctrl+H or Alt+H → Hide / Minimize window
    if ((isCtrl || isAlt) && key == LogicalKeyboardKey.keyH) {
      _handleToggleHideVideo();
      return true;
    }

    // Ctrl+Space or Space → Play / Pause
    if ((isCtrl && key == LogicalKeyboardKey.space) ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _handleTogglePlayPause();
      return true;
    }

    return false;
  }

  // ── Keyboard Shortcut Handler for Focus widget ──
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_handleGlobalHardwareKey(event)) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleTogglePlayPause() async {
    await widget.controller.togglePlayPause();
    final paused = await widget.controller.isPaused();
    if (paused) {
      _showToast('Paused', Icons.pause_rounded, AppTheme.textPrimary);
    } else {
      _showToast('Playing', Icons.play_arrow_rounded, AppTheme.accentGreen);
    }
  }

  void _handleToggleHideVideo() {
    if (PlatformHelper.isDesktop) {
      if (_isVideoHidden) {
        // Restore from minimized
        windowManager.restore();
        windowManager.show();
        windowManager.focus();
        setState(() => _isVideoHidden = false);
        _showToast('Window restored', Icons.visibility_rounded, AppTheme.accentCyan);
      } else {
        // Minimize to taskbar (audio keeps playing via background play)
        windowManager.minimize();
        setState(() => _isVideoHidden = true);
        _showToast('Window hidden (Audio playing)', Icons.visibility_off_rounded, AppTheme.textSecondary);
      }
    }
  }

  void _showToast(String message, IconData icon, Color color) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _toastIcon = icon;
      _toastColor = color;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
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

  void _handleToggleAdBlocker(bool nextState) {
    setState(() => _isAdBlocker = nextState);
    widget.onToggleAdBlocker?.call(nextState);
    PreferencesService.saveAdBlocker(nextState);
    if (nextState) {
      _showToast('Ad Blocker active', Icons.shield_rounded, AppTheme.accentGreen);
    } else {
      _showToast('Ad Blocker disabled', Icons.shield_outlined, AppTheme.textSecondary);
    }
  }

  void _handleToggleBackgroundPlay(bool nextState) {
    setState(() => _isBackgroundPlay = nextState);
    widget.controller.setBackgroundPlay(nextState);
    widget.onToggleBackgroundPlay?.call(nextState);
    PreferencesService.saveBackgroundPlay(nextState);
    if (nextState) {
      _showToast('Background Play ON: Keeps playing in background', Icons.headphones_rounded, AppTheme.accentCyan);
    } else {
      _showToast('Background Play OFF', Icons.headphones_outlined, AppTheme.textSecondary);
    }
  }

  void _handleToggleAudioOnly(bool nextState) {
    setState(() => _isAudioOnly = nextState);
    widget.controller.setAudioOnly(nextState);
    widget.onToggleAudioOnly?.call(nextState);
    PreferencesService.saveAudioOnly(nextState);
    if (nextState) {
      _showToast('Audio Only Active: Saving 85% data & battery', Icons.music_note_rounded, AppTheme.youtubeRedLight);
    } else {
      _showToast('Video Mode Restored', Icons.videocam_rounded, AppTheme.textPrimary);
    }
  }

  void _handleToggleLoop(bool nextState) {
    setState(() => _isLoop = nextState);
    widget.controller.toggleLoop(nextState);
    _showToast(nextState ? 'Looping enabled' : 'Looping disabled', Icons.repeat_rounded, AppTheme.premiumGold);
  }

  void _handleSpeedSelected(double speed) {
    setState(() => _playbackSpeed = speed);
    widget.controller.setPlaybackSpeed(speed);
    PreferencesService.savePlaybackSpeed(speed);
    _showToast('Speed: ${speed}x', Icons.speed_rounded, AppTheme.textPrimary);
  }

  void _handleQualitySelected(String quality) {
    setState(() => _currentQuality = quality);
    widget.controller.setQuality(quality);
    PreferencesService.saveQuality(quality);
    _showToast('Quality set: $quality', Icons.hd_rounded, AppTheme.premiumGold);
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

    Widget body = Stack(
      children: [
        // Video Area + Top Navigation Bar + YouTube Premium Toolbar
        Column(
          children: [
            if (!borderless) ...[
              // Collapsible Top Toolbar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: _isToolbarCollapsed ? 6 : null,
                child: _isToolbarCollapsed
                    ? _buildCollapsedHandle()
                    : _buildExpandedToolbar(),
              ),

              // YouTube Premium Controls Bar (Speed, Quality, Audio-Only, Background, Download)
              if (!_isToolbarCollapsed)
                PremiumToolbar(
                  controller: widget.controller,
                  isBackgroundPlayEnabled: _isBackgroundPlay,
                  isAudioOnlyEnabled: _isAudioOnly,
                  isAdBlockerEnabled: _isAdBlocker,
                  isLoopEnabled: _isLoop,
                  playbackSpeed: _playbackSpeed,
                  currentQuality: _currentQuality,
                  accountInfo: _accountInfo,
                  onToggleBackgroundPlay: _handleToggleBackgroundPlay,
                  onToggleAudioOnly: _handleToggleAudioOnly,
                  onToggleAdBlocker: _handleToggleAdBlocker,
                  onToggleLoop: _handleToggleLoop,
                  onSpeedSelected: _handleSpeedSelected,
                  onQualitySelected: _handleQualitySelected,
                  onTogglePiP: () => widget.controller.togglePictureInPicture(),
                  onNavigateUrl: (url) => widget.controller.loadUrl(url),
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

            // Active Cross-Platform Webview
            Expanded(
              child: widget.controller.buildWidget(),
            ),
          ],
        ),

        // Top Drag Bar across the top of the pure view window (Desktop only)
        if (borderless && !_isFullDragMode && PlatformHelper.isDesktop)
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
              isAdBlockerEnabled: _isAdBlocker,
              onTogglePin: _handleTogglePin,
              onToggleFullDrag: () =>
                  setState(() => _isFullDragMode = !_isFullDragMode),
              onRestoreWindow: _handleRestoreWindow,
              onToggleAdBlocker: () => _handleToggleAdBlocker(!_isAdBlocker),
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

        // Full Screen Drag Overlay (Desktop pure view mode)
        if (borderless && _isFullDragMode && PlatformHelper.isDesktop)
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
    );

    if (PlatformHelper.isDesktop) {
      body = DragToResizeArea(
        resizeEdgeSize: 8,
        child: MouseRegion(
          onHover: (_) => _flyKey.currentState?.wakeUp(),
          child: body,
        ),
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: !borderless,
          bottom: !borderless,
          left: !borderless,
          right: !borderless,
          child: body,
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
    Widget toolbarContent = ClipRRect(
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
                    // Back to Settings Button
                    GlassIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 32,
                      iconSize: 13,
                      tooltip: 'Settings / Launcher',
                      onPressed: widget.onBackToSettings,
                    ),
                    const SizedBox(width: 4),

                    // Browser Back & Forward
                    GlassIconButton(
                      icon: Icons.chevron_left_rounded,
                      size: 30,
                      iconSize: 18,
                      tooltip: 'Back',
                      onPressed: () => widget.controller.goBack(),
                    ),
                    GlassIconButton(
                      icon: Icons.chevron_right_rounded,
                      size: 30,
                      iconSize: 18,
                      tooltip: 'Forward',
                      onPressed: () => widget.controller.goForward(),
                    ),
                    const SizedBox(width: 8),

                    // Draggable grip or title
                    Expanded(
                      child: Center(
                        child: PlatformHelper.isDesktop
                            ? Tooltip(
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
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.youtubeRed,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PREMIUM',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Pure View Glass Button (Desktop)
                    if (PlatformHelper.isDesktop) ...[
                      GlassIconButton(
                        icon: Icons.crop_free_rounded,
                        size: 32,
                        iconSize: 14,
                        activeColor: AppTheme.accentCyan,
                        tooltip: 'Pure View',
                        onPressed: _handleEnterBorderless,
                      ),
                      const SizedBox(width: 6),
                      _buildGlassSizeMenu(),
                      const SizedBox(width: 6),
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
                    ],

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

              // Sleek progress bar
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
    );

    if (PlatformHelper.isDesktop) {
      return DragToMoveArea(child: toolbarContent);
    }
    return toolbarContent;
  }

  Widget _buildGlassSizeMenu() {
    return PopupMenuButton<WindowPreset>(
      tooltip: 'Resize Window',
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
