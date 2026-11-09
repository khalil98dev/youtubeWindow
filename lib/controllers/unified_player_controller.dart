import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' as mobile_wv;
import 'package:webview_flutter_android/webview_flutter_android.dart' as mobile_android;
import 'package:webview_flutter_windows/webview_flutter_windows.dart' as win_wv;
import '../services/ad_blocker_service.dart';
import '../services/platform_helper.dart';
import '../services/youtube_premium_service.dart';
import '../services/youtube_url_helper.dart';

/// Account status parsed from YouTube web view
class YouTubeAccountInfo {
  final bool isSignedIn;
  final String avatarUrl;
  final String pageTitle;
  final String currentUrl;

  YouTubeAccountInfo({
    this.isSignedIn = false,
    this.avatarUrl = '',
    this.pageTitle = '',
    this.currentUrl = '',
  });

  factory YouTubeAccountInfo.fromJson(Map<String, dynamic> json) {
    return YouTubeAccountInfo(
      isSignedIn: json['isSignedIn'] == true,
      avatarUrl: json['avatarUrl'] as String? ?? '',
      pageTitle: json['pageTitle'] as String? ?? '',
      currentUrl: json['currentUrl'] as String? ?? '',
    );
  }
}

/// Unified Player Controller providing an identical cross-platform API for
/// YouTube playback across Windows Desktop, Android, and iOS.
class UnifiedPlayerController {
  final bool isAdBlockerEnabled;
  final bool isBackgroundPlayEnabled;

  win_wv.WebviewController? _winController;
  mobile_wv.WebViewController? _mobileController;

  final StreamController<bool> _loadingStateController = StreamController<bool>.broadcast();
  Stream<bool> get onLoadingChanged => _loadingStateController.stream;

  final StreamController<YouTubeAccountInfo> _accountStateController = StreamController<YouTubeAccountInfo>.broadcast();
  Stream<YouTubeAccountInfo> get onAccountChanged => _accountStateController.stream;

  final StreamController<Map<String, dynamic>> _shortcutEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onShortcutEvent => _shortcutEventController.stream;

  StreamSubscription? _winLoadingSub;
  StreamSubscription? _winWebMessageSub;
  Timer? _accountPollingTimer;
  String _currentUrl = 'https://www.youtube.com';

  UnifiedPlayerController({
    this.isAdBlockerEnabled = true,
    this.isBackgroundPlayEnabled = true,
  });

  win_wv.WebviewController? get windowsController => _winController;
  mobile_wv.WebViewController? get mobileController => _mobileController;
  String get currentUrl => _currentUrl;

  /// Initializes the appropriate controller based on current running platform
  Future<void> initialize(String initialUrl) async {
    _currentUrl = initialUrl;

    if (PlatformHelper.isWindows) {
      await _initWindows(initialUrl);
    } else {
      await _initMobile(initialUrl);
    }

    // Start background account and status detection
    _startAccountPolling();
  }

  Future<void> _initWindows(String initialUrl) async {
    final controller = win_wv.WebviewController();
    await controller.initialize();
    await controller.setDefaultContextMenusEnabled(true);

    if (isAdBlockerEnabled) {
      await AdBlockerService.install(controller);
    }

    // Install YouTube Premium background and enhancements script
    try {
      await controller.addScriptToExecuteOnDocumentCreated(
        YouTubePremiumService.premiumScript,
      );
      await controller.executeScript(YouTubePremiumService.premiumScript);
    } catch (e) {
      debugPrint('Error installing Premium script on Windows: $e');
    }

    _winLoadingSub = controller.loadingState.listen((state) {
      final isLoading = state == win_wv.LoadingState.loading;
      _loadingStateController.add(isLoading);
      if (state == win_wv.LoadingState.navigationCompleted) {
        if (isAdBlockerEnabled) {
          AdBlockerService.reapply(controller);
        }
        controller.executeScript(YouTubePremiumService.premiumScript);
      }
    });

    _winWebMessageSub = controller.webMessage.listen((dynamic raw) {
      try {
        dynamic parsed = raw;
        if (parsed is String) {
          try {
            parsed = jsonDecode(parsed);
          } catch (_) {}
        }
        if (parsed is Map) {
          _shortcutEventController.add(Map<String, dynamic>.from(parsed));
        }
      } catch (e) {
        debugPrint('Error parsing webMessage: $e');
      }
    });

    await controller.loadUrl(initialUrl);
    _winController = controller;
  }

  Future<void> _initMobile(String initialUrl) async {
    final controller = mobile_wv.WebViewController();

    await controller.setJavaScriptMode(mobile_wv.JavaScriptMode.unrestricted);
    // Custom user agent ensures Google Sign-In won't fail with disallowed_useragent
    await controller.setUserAgent(PlatformHelper.mobileUserAgent);

    await controller.addJavaScriptChannel(
      'FlutterChannel',
      onMessageReceived: (mobile_wv.JavaScriptMessage message) {
        try {
          final decoded = jsonDecode(message.message);
          if (decoded is Map) {
            _shortcutEventController.add(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      },
    );

    if (PlatformHelper.isAndroid) {
      try {
        final android = controller.platform;
        if (android is mobile_android.AndroidWebViewController) {
          android.setMediaPlaybackRequiresUserGesture(false);
        }
      } catch (e) {
        debugPrint('Error configuring Android webview settings: $e');
      }
    }

    controller.setNavigationDelegate(
      mobile_wv.NavigationDelegate(
        onPageStarted: (url) {
          _currentUrl = url;
          _loadingStateController.add(true);
          _injectScriptsMobile(controller);
        },
        onPageFinished: (url) {
          _currentUrl = url;
          _loadingStateController.add(false);
          _injectScriptsMobile(controller);
          _checkAccountStatus();
        },
        onWebResourceError: (error) {
          debugPrint('Mobile WebView error: ${error.description}');
        },
      ),
    );

    await controller.loadRequest(Uri.parse(initialUrl));
    _mobileController = controller;
  }

  Future<void> _injectScriptsMobile(mobile_wv.WebViewController controller) async {
    try {
      if (isAdBlockerEnabled) {
        await controller.runJavaScript(AdBlockerService.youTubeAdBlockerScript);
      }
      await controller.runJavaScript(YouTubePremiumService.premiumScript);
    } catch (_) {}
  }

  void _startAccountPolling() {
    _accountPollingTimer?.cancel();
    _accountPollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkAccountStatus();
    });
  }

  Future<void> _checkAccountStatus() async {
    try {
      final res = await executeScript(
        'window.__yt_premium_get_account_status ? window.__yt_premium_get_account_status() : "{}"',
      );
      if (res != null && res.isNotEmpty) {
        // Strip escaped quotes if returned as a JSON-encoded string
        String raw = res;
        if (raw.startsWith('"') && raw.endsWith('"')) {
          try {
            raw = jsonDecode(raw) as String;
          } catch (_) {}
        }
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _accountStateController.add(YouTubeAccountInfo.fromJson(map));
      }
    } catch (_) {}
  }

  /// Executes JavaScript on the active platform
  Future<String?> executeScript(String script) async {
    if (PlatformHelper.isWindows && _winController != null) {
      try {
        return await _winController!.executeScript(script);
      } catch (e) {
        debugPrint('Windows executeScript error: $e');
        return null;
      }
    } else if (_mobileController != null) {
      try {
        final result = await _mobileController!.runJavaScriptReturningResult(script);
        return result.toString();
      } catch (e) {
        debugPrint('Mobile executeScript error: $e');
        return null;
      }
    }
    return null;
  }

  /// Loads a URL across platforms
  Future<void> loadUrl(String url) async {
    _currentUrl = url;
    if (PlatformHelper.isWindows && _winController != null) {
      await _winController!.loadUrl(url);
    } else if (_mobileController != null) {
      await _mobileController!.loadRequest(Uri.parse(url));
    }
  }

  /// Reloads active webview
  Future<void> reload() async {
    if (PlatformHelper.isWindows && _winController != null) {
      await _winController!.reload();
      if (isAdBlockerEnabled) {
        await AdBlockerService.reapply(_winController!);
      }
      await _winController!.executeScript(YouTubePremiumService.premiumScript);
    } else if (_mobileController != null) {
      await _mobileController!.reload();
    }
  }

  /// Navigates back
  Future<void> goBack() async {
    if (PlatformHelper.isWindows && _winController != null) {
      await _winController!.goBack();
    } else if (_mobileController != null && await _mobileController!.canGoBack()) {
      await _mobileController!.goBack();
    }
  }

  /// Navigates forward
  Future<void> goForward() async {
    if (PlatformHelper.isWindows && _winController != null) {
      await _winController!.goForward();
    } else if (_mobileController != null && await _mobileController!.canGoForward()) {
      await _mobileController!.goForward();
    }
  }

  /// Retrieves the currently active/running video URL from the WebView.
  /// Inspects the YouTube player API, video element, canonical link, and window.location.
  Future<String?> getActiveVideoUrl() async {
    const js = r'''
(function() {
  try {
    const player = document.getElementById('movie_player');
    if (player && typeof player.getVideoUrl === 'function') {
      const pUrl = player.getVideoUrl();
      if (pUrl && pUrl.includes('v=')) return pUrl;
    }

    const href = window.location.href;
    if (href && (href.includes('watch?v=') || href.includes('youtu.be/') || href.includes('/shorts/'))) {
      return href;
    }

    const urlParams = new URLSearchParams(window.location.search);
    const videoId = urlParams.get('v');
    if (videoId && videoId.length >= 8) {
      return 'https://www.youtube.com/watch?v=' + videoId;
    }

    const canonical = document.querySelector('link[rel="canonical"]');
    if (canonical && canonical.href && canonical.href.includes('watch?v=')) {
      return canonical.href;
    }
  } catch (_) {}
  return window.location.href || '';
})();
''';

    try {
      final res = await executeScript(js);
      if (res != null && res.isNotEmpty) {
        String clean = res.trim();
        if ((clean.startsWith('"') && clean.endsWith('"')) ||
            (clean.startsWith("'") && clean.endsWith("'"))) {
          clean = clean.substring(1, clean.length - 1);
        }
        if (clean.isNotEmpty && clean != 'null' && clean != 'undefined') {
          if (YouTubeUrlHelper.isValidVideoUrl(clean)) {
            _currentUrl = YouTubeUrlHelper.normalizeToWatchUrl(clean);
            return _currentUrl;
          }
          return clean;
        }
      }
    } catch (e) {
      debugPrint('Error getting active video URL: $e');
    }

    return _currentUrl;
  }

  /// Opens Google/YouTube Sign-In
  Future<void> openSignIn() async {
    await loadUrl(YouTubePremiumService.youtubeSignInUrl);
  }

  /// Sets video playback speed (e.g. 0.25x to 4.0x)
  Future<void> setPlaybackSpeed(double speed) async {
    await executeScript('window.__yt_premium_set_speed && window.__yt_premium_set_speed($speed);');
  }

  /// Sets video quality lock (e.g. 'hd1080', 'hd720', 'highres')
  Future<void> setQuality(String quality) async {
    await executeScript("window.__yt_premium_set_quality && window.__yt_premium_set_quality('$quality');");
  }

  /// Toggles Audio-Only mode (saves up to 85% bandwidth & battery)
  Future<void> setAudioOnly(bool enabled) async {
    await executeScript('window.__yt_premium_set_audio_only && window.__yt_premium_set_audio_only($enabled);');
  }

  /// Toggles Background Play mode
  Future<void> setBackgroundPlay(bool enabled) async {
    await executeScript('if (window.__yt_premium_config) window.__yt_premium_config.backgroundPlay = $enabled;');
  }

  /// Toggles play/pause on the active video
  Future<void> togglePlayPause() async {
    await executeScript(r'''
(function() {
  const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
  if (player && typeof player.getPlayerState === 'function') {
    const s = player.getPlayerState();
    if (s === 1) { // playing -> pause
      if (typeof player.pauseVideo === 'function') player.pauseVideo();
    } else { // paused/ended -> play
      if (typeof player.playVideo === 'function') player.playVideo();
    }
    return;
  }
  const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
  if (video) {
    if (video.paused) {
      video.play().catch(() => {});
    } else {
      video.pause();
    }
  }
})();
''');
  }

  /// Returns true if the video is currently paused
  Future<bool> isPaused() async {
    final result = await executeScript(r'''
(function() {
  const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
  if (player && typeof player.getPlayerState === 'function') {
    return player.getPlayerState() !== 1;
  }
  const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
  return video ? video.paused : true;
})();
''');
    if (result == null) return false;
    final clean = result.replaceAll('"', '').trim();
    return clean == 'true';
  }

  /// Triggers Picture-in-Picture (PiP)
  Future<void> togglePictureInPicture() async {
    await executeScript('window.__yt_premium_toggle_pip && window.__yt_premium_toggle_pip();');
  }

  /// Toggles Loop mode
  Future<void> toggleLoop(bool enabled) async {
    await executeScript('window.__yt_premium_toggle_loop && window.__yt_premium_toggle_loop($enabled);');
  }

  /// Builds the proper native WebView widget for the current platform
  Widget buildWidget() {
    if (PlatformHelper.isWindows) {
      if (_winController == null) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFFFF0033)));
      }
      return win_wv.Webview(_winController!);
    } else {
      if (_mobileController == null) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFFFF0033)));
      }
      return mobile_wv.WebViewWidget(controller: _mobileController!);
    }
  }

  Future<void> dispose() async {
    _accountPollingTimer?.cancel();
    _winLoadingSub?.cancel();
    _winWebMessageSub?.cancel();
    await _loadingStateController.close();
    await _accountStateController.close();
    await _shortcutEventController.close();
    if (PlatformHelper.isWindows && _winController != null) {
      await _winController!.dispose();
      _winController = null;
    }
    _mobileController = null;
  }
}
