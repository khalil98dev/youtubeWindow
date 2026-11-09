import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'controllers/unified_player_controller.dart';
import 'pages/player_view.dart';
import 'pages/settings_view.dart';
import 'services/download_service.dart';
import 'services/platform_helper.dart';
import 'services/preferences_service.dart';
import 'services/youtube_premium_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop specific window manager initialization
  if (PlatformHelper.isDesktop) {
    try {
      await windowManager.ensureInitialized();
      await windowManager.waitUntilReadyToShow(
        const WindowOptions(
          size: Size(540, 680),
          minimumSize: Size(440, 560),
          center: true,
          title: 'YouTube Premium Viewer',
        ),
        () async {
          await windowManager.setResizable(true);
          await windowManager.show();
          await windowManager.focus();
        },
      );
    } catch (e) {
      debugPrint('WindowManager init ignored: $e');
    }
  }

  // Pre-load offline downloads
  DownloadService().initialize();

  runApp(const YouTubeWindowApp());
}

class YouTubeWindowApp extends StatelessWidget {
  const YouTubeWindowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Premium Viewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const YouTubeWindowHost(),
    );
  }
}

class YouTubeWindowHost extends StatefulWidget {
  const YouTubeWindowHost({super.key});

  @override
  State<YouTubeWindowHost> createState() => _YouTubeWindowHostState();
}

class _YouTubeWindowHostState extends State<YouTubeWindowHost> {
  final _urlController = TextEditingController(text: 'https://www.youtube.com');
  final _widthController = TextEditingController(text: '1280');
  final _heightController = TextEditingController(text: '720');

  UnifiedPlayerController? _playerController;
  bool _isLoading = false;
  bool _isPlayerVisible = false;
  bool _isAlwaysOnTop = false;
  bool _isBorderlessMode = false;
  bool _isAdBlockerEnabled = true;
  bool _isBackgroundPlayEnabled = true;
  bool _isAudioOnlyEnabled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await PreferencesService.loadPreferences();
    if (mounted) {
      setState(() {
        _isAdBlockerEnabled = prefs['adBlocker'] as bool;
        _isBackgroundPlayEnabled = prefs['backgroundPlay'] as bool;
        _isAudioOnlyEnabled = prefs['audioOnly'] as bool;
        _isAlwaysOnTop = prefs['alwaysOnTop'] as bool;
        _urlController.text = prefs['lastUrl'] as String;
        _widthController.text = (prefs['width'] as int).toString();
        _heightController.text = (prefs['height'] as int).toString();
      });
    }

    if (PlatformHelper.isDesktop) {
      try {
        final onTop = await windowManager.isAlwaysOnTop();
        if (mounted) {
          setState(() => _isAlwaysOnTop = onTop);
        }
      } catch (_) {}
    }
  }

  bool _isValidYouTubeUrl(String input) {
    String cleanUrl = input.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }

    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || !uri.hasAuthority) {
      return false;
    }

    const validHosts = {
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'youtu.be',
      'www.youtu.be',
      'music.youtube.com',
      'accounts.google.com',
    };

    return validHosts.contains(uri.host.toLowerCase());
  }

  String _normalizeUrl(String input) {
    String cleanUrl = input.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    return cleanUrl;
  }

  Future<void> _toggleAlwaysOnTop(bool value) async {
    setState(() => _isAlwaysOnTop = value);
    PreferencesService.saveAlwaysOnTop(value);
    if (PlatformHelper.isDesktop) {
      try {
        await windowManager.setAlwaysOnTop(value);
      } catch (e) {
        debugPrint('Error toggling alwaysOnTop: $e');
      }
    }
  }

  void _toggleAdBlocker(bool value) {
    setState(() => _isAdBlockerEnabled = value);
    PreferencesService.saveAdBlocker(value);
  }

  void _toggleBackgroundPlay(bool value) {
    setState(() => _isBackgroundPlayEnabled = value);
    PreferencesService.saveBackgroundPlay(value);
    _playerController?.setBackgroundPlay(value);
  }

  void _toggleAudioOnly(bool value) {
    setState(() => _isAudioOnlyEnabled = value);
    PreferencesService.saveAudioOnly(value);
    _playerController?.setAudioOnly(value);
  }

  Future<void> _toggleBorderless(bool borderless) async {
    setState(() => _isBorderlessMode = borderless);
    if (PlatformHelper.isDesktop) {
      try {
        if (borderless) {
          await windowManager.setTitleBarStyle(
            TitleBarStyle.hidden,
            windowButtonVisibility: false,
          );
        } else {
          await windowManager.setTitleBarStyle(
            TitleBarStyle.normal,
            windowButtonVisibility: true,
          );
        }
      } catch (e) {
        debugPrint('Error toggling borderless: $e');
      }
    }
  }

  Future<void> _launchYouTube({String? targetUrl}) async {
    final rawUrl = targetUrl ?? _urlController.text.trim();
    final width = int.tryParse(_widthController.text);
    final height = int.tryParse(_heightController.text);

    if (!_isValidYouTubeUrl(rawUrl)) {
      setState(() {
        _errorMessage = 'Please enter a valid YouTube or Google URL.';
      });
      return;
    }

    if (PlatformHelper.isDesktop) {
      if (width == null ||
          height == null ||
          width < 320 ||
          height < 240 ||
          width > 7680 ||
          height > 4320) {
        setState(() {
          _errorMessage = 'Please enter valid dimensions (min 320x240, max 7680x4320).';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final normalized = _normalizeUrl(rawUrl);
      PreferencesService.saveLastUrl(normalized);

      final controller = UnifiedPlayerController(
        isAdBlockerEnabled: _isAdBlockerEnabled,
        isBackgroundPlayEnabled: _isBackgroundPlayEnabled,
      );

      await controller.initialize(normalized);

      if (PlatformHelper.isDesktop && width != null && height != null) {
        try {
          await windowManager.setSize(Size(width.toDouble(), height.toDouble()));
          await windowManager.setMinimumSize(const Size(320, 240));
          await windowManager.setTitle('YouTube Premium Player');
          await windowManager.setAlwaysOnTop(_isAlwaysOnTop);
        } catch (_) {}
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _playerController = controller;
        _isPlayerVisible = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize YouTube: $e';
      });
    }
  }

  Future<void> _openSignIn() async {
    await _launchYouTube(targetUrl: YouTubePremiumService.youtubeSignInUrl);
  }

  Future<void> _resizeWindow(int width, int height) async {
    _widthController.text = width.toString();
    _heightController.text = height.toString();
    PreferencesService.saveDimensions(width, height);
    if (PlatformHelper.isDesktop) {
      try {
        await windowManager.setSize(Size(width.toDouble(), height.toDouble()));
      } catch (e) {
        debugPrint('Error resizing window: $e');
      }
    }
  }

  Future<void> _backToSettings() async {
    final controller = _playerController;

    setState(() {
      _playerController = null;
      _isPlayerVisible = false;
    });

    if (controller != null) {
      await controller.dispose();
    }

    if (PlatformHelper.isDesktop) {
      if (_isBorderlessMode) {
        _isBorderlessMode = false;
        try {
          await windowManager.setTitleBarStyle(
            TitleBarStyle.normal,
            windowButtonVisibility: true,
          );
        } catch (_) {}
      }

      try {
        await windowManager.setSize(const Size(540, 680));
        await windowManager.setMinimumSize(const Size(440, 560));
        await windowManager.setTitle('YouTube Premium Viewer');
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: _isPlayerVisible && _playerController != null
          ? PlayerView(
              key: const ValueKey('player_view'),
              controller: _playerController!,
              isAlwaysOnTop: _isAlwaysOnTop,
              isBorderlessMode: _isBorderlessMode,
              isAdBlockerEnabled: _isAdBlockerEnabled,
              isBackgroundPlayEnabled: _isBackgroundPlayEnabled,
              isAudioOnlyEnabled: _isAudioOnlyEnabled,
              onToggleAlwaysOnTop: _toggleAlwaysOnTop,
              onToggleAdBlocker: _toggleAdBlocker,
              onToggleBackgroundPlay: _toggleBackgroundPlay,
              onToggleAudioOnly: _toggleAudioOnly,
              onToggleBorderless: _toggleBorderless,
              onBackToSettings: _backToSettings,
              onResizeWindow: _resizeWindow,
            )
          : SettingsView(
              key: const ValueKey('settings_view'),
              urlController: _urlController,
              widthController: _widthController,
              heightController: _heightController,
              isAlwaysOnTop: _isAlwaysOnTop,
              onToggleAlwaysOnTop: _toggleAlwaysOnTop,
              isAdBlockerEnabled: _isAdBlockerEnabled,
              onToggleAdBlocker: _toggleAdBlocker,
              isBackgroundPlayEnabled: _isBackgroundPlayEnabled,
              onToggleBackgroundPlay: _toggleBackgroundPlay,
              isAudioOnlyEnabled: _isAudioOnlyEnabled,
              onToggleAudioOnly: _toggleAudioOnly,
              onOpenSignIn: _openSignIn,
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              onLaunch: () => _launchYouTube(),
            ),
    );
  }
}
