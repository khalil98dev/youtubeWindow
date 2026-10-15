import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/player_view.dart';
import 'pages/settings_view.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(500, 640),
      minimumSize: Size(440, 560),
      center: true,
      title: 'YouTube Viewer',
    ),
    () async {
      await windowManager.setResizable(true);
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const YouTubeWindowApp());
}

class YouTubeWindowApp extends StatelessWidget {
  const YouTubeWindowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Viewer',
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

  WebviewController? _webviewController;
  bool _isLoading = false;
  bool _isPlayerVisible = false;
  bool _isAlwaysOnTop = false;
  bool _isBorderlessMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkInitialAlwaysOnTop();
  }

  Future<void> _checkInitialAlwaysOnTop() async {
    try {
      final onTop = await windowManager.isAlwaysOnTop();
      if (mounted) {
        setState(() => _isAlwaysOnTop = onTop);
      }
    } catch (_) {}
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
    try {
      await windowManager.setAlwaysOnTop(value);
    } catch (e) {
      debugPrint('Error toggling alwaysOnTop: $e');
    }
  }

  Future<void> _toggleBorderless(bool borderless) async {
    setState(() => _isBorderlessMode = borderless);
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

  Future<void> _launchYouTube() async {
    final rawUrl = _urlController.text.trim();
    final width = int.tryParse(_widthController.text);
    final height = int.tryParse(_heightController.text);

    if (!_isValidYouTubeUrl(rawUrl)) {
      setState(() {
        _errorMessage = 'Please enter a valid YouTube URL (e.g. youtube.com or youtu.be).';
      });
      return;
    }

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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final controller = WebviewController();

      await controller.initialize();
      await controller.setDefaultContextMenusEnabled(true);
      await controller.loadUrl(_normalizeUrl(rawUrl));

      await windowManager.setSize(Size(width.toDouble(), height.toDouble()));
      await windowManager.setMinimumSize(const Size(320, 240));
      await windowManager.setTitle('YouTube Player');
      await windowManager.setAlwaysOnTop(_isAlwaysOnTop);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _webviewController = controller;
        _isPlayerVisible = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize YouTube Webview: $e';
      });
    }
  }

  Future<void> _resizeWindow(int width, int height) async {
    _widthController.text = width.toString();
    _heightController.text = height.toString();
    try {
      await windowManager.setSize(Size(width.toDouble(), height.toDouble()));
    } catch (e) {
      debugPrint('Error resizing window: $e');
    }
  }

  Future<void> _backToSettings() async {
    final controller = _webviewController;

    setState(() {
      _webviewController = null;
      _isPlayerVisible = false;
    });

    if (controller != null) {
      await controller.dispose();
    }

    if (_isBorderlessMode) {
      _isBorderlessMode = false;
      try {
        await windowManager.setTitleBarStyle(
          TitleBarStyle.normal,
          windowButtonVisibility: true,
        );
      } catch (_) {}
    }

    await windowManager.setSize(const Size(500, 640));
    await windowManager.setMinimumSize(const Size(440, 560));
    await windowManager.setTitle('YouTube Viewer');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _webviewController?.dispose();
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
      child: _isPlayerVisible && _webviewController != null
          ? PlayerView(
              key: const ValueKey('player_view'),
              controller: _webviewController!,
              isAlwaysOnTop: _isAlwaysOnTop,
              isBorderlessMode: _isBorderlessMode,
              onToggleAlwaysOnTop: _toggleAlwaysOnTop,
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
              isLoading: _isLoading,
              errorMessage: _errorMessage,
              onLaunch: _launchYouTube,
            ),
    );
  }
}