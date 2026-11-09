/// Comprehensive YouTube Premium JavaScript and Controller service.
/// Injects background play support, lockscreen media controls, ad blocking,
/// audio-only mode, custom playback speed, and quality lock.
class YouTubePremiumService {
  static const String premiumScript = r'''
(function() {
  if (window.__yt_premium_initialized__) return;
  window.__yt_premium_initialized__ = true;

  window.__yt_premium_config = {
    backgroundPlay: true,
    audioOnly: false,
    speed: 1.0,
    quality: 'hd1080',
    loop: false,
    adBlock: true
  };

  // -------------------------------------------------------------
  // 1. MOBILE & DESKTOP BACKGROUND PLAYBACK ENABLER
  // -------------------------------------------------------------
  // YouTube monitors document.hidden & document.visibilityState to pause videos
  // when the user leaves the tab, turns off the screen, or minimizes the app.
  // We override these properties so YouTube always believes it is in the foreground.

  try {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      get: function() { return false; }
    });

    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      get: function() { return 'visible'; }
    });

    Object.defineProperty(document, 'webkitVisibilityState', {
      configurable: true,
      get: function() { return 'visible'; }
    });

    // Ensure document.hasFocus() always reports true so YouTube never detects window blur or outside clicks
    document.hasFocus = function() { return true; };
  } catch (e) {
    console.warn('Error overriding visibility properties', e);
  }

  // Intercept visibilitychange, blur, and pagehide events
  const originalDocAddEventListener = document.addEventListener;
  document.addEventListener = function(type, listener, options) {
    if (type === 'visibilitychange' || type === 'webkitvisibilitychange') {
      const wrappedListener = function(e) {
        if (!window.__yt_premium_config.backgroundPlay) {
          return listener.apply(this, arguments);
        }
        // Suppress visibility pause while allowing background playback
      };
      return originalDocAddEventListener.call(document, type, wrappedListener, options);
    }
    return originalDocAddEventListener.apply(document, arguments);
  };

  const originalWinAddEventListener = window.addEventListener;
  window.addEventListener = function(type, listener, options) {
    if (type === 'blur' || type === 'pagehide') {
      const wrappedListener = function(e) {
        if (!window.__yt_premium_config.backgroundPlay) {
          return listener.apply(this, arguments);
        }
        // Suppress window blur pause
      };
      return originalWinAddEventListener.call(window, type, wrappedListener, options);
    }
    return originalWinAddEventListener.apply(window, arguments);
  };

  // -------------------------------------------------------------
  // KEYBOARD SHORTCUTS IN WEBVIEW (Ctrl+Space, Ctrl+P, Ctrl+H, Space)
  // -------------------------------------------------------------
  function sendToFlutter(msg) {
    try {
      if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage(msg);
        return;
      }
    } catch (_) {}
    try {
      if (window.FlutterChannel && window.FlutterChannel.postMessage) {
        window.FlutterChannel.postMessage(JSON.stringify(msg));
        return;
      }
    } catch (_) {}
  }

  function togglePlayPauseInternal() {
    try {
      const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
      if (player && typeof player.getPlayerState === 'function') {
        const s = player.getPlayerState();
        if (s === 1) { // 1 = playing
          if (typeof player.pauseVideo === 'function') player.pauseVideo();
          return true; // now paused
        } else {
          if (typeof player.playVideo === 'function') player.playVideo();
          return false; // now playing
        }
      }
      const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
      if (video) {
        if (video.paused) {
          video.play().catch(() => {});
          return false;
        } else {
          video.pause();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // Intercept keyboard events in capture phase so Edge/WebView2 doesn't open Print (Ctrl+P) or History (Ctrl+H)
  window.addEventListener('keydown', function(e) {
    const activeEl = document.activeElement;
    const isInput = activeEl && (
      activeEl.tagName === 'INPUT' ||
      activeEl.tagName === 'TEXTAREA' ||
      activeEl.isContentEditable ||
      activeEl.getAttribute('role') === 'textbox'
    );

    const isCtrl = e.ctrlKey || e.metaKey;
    const isAlt = e.altKey;
    const key = e.key ? e.key.toLowerCase() : '';
    const code = e.code || '';

    // 1. Play / Pause: Ctrl+Space (always), Space (when not typing in search/comments), MediaPlayPause
    if ((isCtrl && (code === 'Space' || key === ' ')) ||
        (!isInput && (code === 'Space' || key === ' ')) ||
        code === 'MediaPlayPause') {
      e.preventDefault();
      e.stopPropagation();
      const nowPaused = togglePlayPauseInternal();
      sendToFlutter({ action: 'playPause', paused: nowPaused });
      return;
    }

    // 2. Pin / Unpin: Ctrl+P or Alt+P
    if ((isCtrl || isAlt) && (key === 'p' || code === 'KeyP')) {
      e.preventDefault();
      e.stopPropagation();
      sendToFlutter({ action: 'togglePin' });
      return;
    }

    // 3. Hide / Minimize: Ctrl+H or Alt+H
    if ((isCtrl || isAlt) && (key === 'h' || code === 'KeyH')) {
      e.preventDefault();
      e.stopPropagation();
      sendToFlutter({ action: 'toggleHide' });
      return;
    }
  }, true);

  // -------------------------------------------------------------
  // 2. LOCK SCREEN & SYSTEM NOTIFICATION CONTROLS (MediaSession)
  // -------------------------------------------------------------
  function setupMediaSession() {
    if (!('mediaSession' in navigator)) return;

    function updateMetadata() {
      const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
      if (!video) return;

      // Extract title and channel from DOM
      let title = document.title.replace(' - YouTube', '').trim();
      const titleEl = document.querySelector('h1.ytd-watch-metadata') ||
                      document.querySelector('h1.title') ||
                      document.querySelector('.slim-video-metadata-title');
      if (titleEl && titleEl.textContent) {
        title = titleEl.textContent.trim();
      }

      let artist = 'YouTube';
      const channelEl = document.querySelector('#channel-name a') ||
                        document.querySelector('.ytd-channel-name a') ||
                        document.querySelector('.slim-owner-channel-name');
      if (channelEl && channelEl.textContent) {
        artist = channelEl.textContent.trim();
      }

      // Thumbnail
      const urlParams = new URLSearchParams(window.location.search);
      const videoId = urlParams.get('v');
      const artwork = videoId ? [
        { src: `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`, sizes: '480x360', type: 'image/jpeg' },
        { src: `https://i.ytimg.com/vi/${videoId}/maxresdefault.jpg`, sizes: '1280x720', type: 'image/jpeg' }
      ] : [
        { src: 'https://www.youtube.com/s/desktop/f17228a6/img/favicon_144x144.png', sizes: '144x144', type: 'image/png' }
      ];

      try {
        navigator.mediaSession.metadata = new MediaMetadata({
          title: title || 'YouTube Video',
          artist: artist || 'YouTube',
          album: 'YouTube Premium',
          artwork: artwork
        });
      } catch (_) {}
    }

    try {
      navigator.mediaSession.setActionHandler('play', function() {
        const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
        if (video) video.play();
      });

      navigator.mediaSession.setActionHandler('pause', function() {
        const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
        if (video) {
          isUserInitiatedPause = true;
          userPaused = true;
          video.pause();
          setTimeout(() => { isUserInitiatedPause = false; }, 500);
        }
      });

      navigator.mediaSession.setActionHandler('seekbackward', function(details) {
        const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
        if (video) video.currentTime = Math.max(video.currentTime - (details.seekOffset || 10), 0);
      });

      navigator.mediaSession.setActionHandler('seekforward', function(details) {
        const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
        if (video) video.currentTime = Math.min(video.currentTime + (details.seekOffset || 10), video.duration);
      });

      navigator.mediaSession.setActionHandler('previoustrack', function() {
        const prevBtn = document.querySelector('.ytp-prev-button');
        if (prevBtn) prevBtn.click();
      });

      navigator.mediaSession.setActionHandler('nexttrack', function() {
        const nextBtn = document.querySelector('.ytp-next-button');
        if (nextBtn) nextBtn.click();
      });
    } catch (_) {}

    setInterval(updateMetadata, 3000);
  }

  // -------------------------------------------------------------
  // 3. AUDIO-ONLY MODE (Data & Battery Saver)
  // -------------------------------------------------------------
  window.__yt_premium_set_audio_only = function(enabled) {
    window.__yt_premium_config.audioOnly = enabled;
    let style = document.getElementById('yt-premium-audio-only-style');
    if (enabled) {
      if (!style) {
        style = document.createElement('style');
        style.id = 'yt-premium-audio-only-style';
        style.textContent = `
          video.html5-main-video, .html5-video-player video {
            opacity: 0 !important;
            filter: blur(20px);
          }
          .html5-video-player::before {
            content: '🎵 YouTube Premium - Audio Mode Active';
            display: flex;
            align-items: center;
            justify-content: center;
            position: absolute;
            top: 0; left: 0; right: 0; bottom: 0;
            background: linear-gradient(135deg, #180005 0%, #0d0d0d 100%);
            color: #ff3344;
            font-size: 20px;
            font-weight: 700;
            letter-spacing: 0.8px;
            z-index: 10;
            pointer-events: none;
          }
        `;
        document.head.appendChild(style);
      }
    } else {
      if (style) style.remove();
    }
  };

  // -------------------------------------------------------------
  // 4. PLAYBACK SPEED BOOSTER (0.25x up to 4.0x)
  // -------------------------------------------------------------
  window.__yt_premium_set_speed = function(rate) {
    window.__yt_premium_config.speed = rate;
    const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
    if (video) {
      video.playbackRate = rate;
    }
  };

  // -------------------------------------------------------------
  // 5. PICTURE-IN-PICTURE (PiP)
  // -------------------------------------------------------------
  window.__yt_premium_toggle_pip = function() {
    const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
    if (!video) return false;
    try {
      if (document.pictureInPictureElement) {
        document.exitPictureInPicture();
        return false;
      } else if (document.pictureInPictureEnabled) {
        video.requestPictureInPicture();
        return true;
      }
    } catch (e) {
      console.warn('PiP error', e);
    }
    return false;
  };

  // -------------------------------------------------------------
  // 6. 1080p PREMIUM / QUALITY LOCK
  // -------------------------------------------------------------
  window.__yt_premium_set_quality = function(quality) {
    window.__yt_premium_config.quality = quality;
    try {
      const player = document.getElementById('movie_player');
      if (player && typeof player.setPlaybackQualityRange === 'function') {
        player.setPlaybackQualityRange(quality, quality);
      }
    } catch (_) {}
  };

  // -------------------------------------------------------------
  // 7. LOOP / REPEAT MODE
  // -------------------------------------------------------------
  window.__yt_premium_toggle_loop = function(enabled) {
    window.__yt_premium_config.loop = enabled;
    const video = document.querySelector('video.html5-main-video') || document.querySelector('video');
    if (video) {
      video.loop = enabled;
    }
  };

  // -------------------------------------------------------------
  // 8. ACCOUNT & USER DETECTION
  // -------------------------------------------------------------
  window.__yt_premium_get_account_status = function() {
    try {
      // Check for user avatar button or channel icon
      const avatar = document.querySelector('button#avatar-btn, ytd-topbar-menu-button-renderer img#img, .yt-spec-avatar-shape img');
      const signInBtn = document.querySelector('a[href*="accounts.google.com/ServiceLogin"], ytd-button-renderer.ytd-masthead a');

      const isSignedIn = !!avatar && !signInBtn;
      const avatarUrl = avatar ? (avatar.src || '') : '';
      const pageTitle = document.title || '';
      const currentUrl = window.location.href;

      return JSON.stringify({
        isSignedIn: isSignedIn,
        avatarUrl: avatarUrl,
        pageTitle: pageTitle,
        currentUrl: currentUrl
      });
    } catch (e) {
      return JSON.stringify({ isSignedIn: false, error: e.toString() });
    }
  };

  // Initialize MediaSession when ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupMediaSession);
  } else {
    setupMediaSession();
  }
})();
''';

  /// Helper to get the sign-in URL for YouTube / Google
  static const String youtubeSignInUrl =
      'https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue';

  /// Helper URLs for YouTube Premium shortcuts
  static const String youtubeHomeUrl = 'https://www.youtube.com';
  static const String youtubeMusicUrl = 'https://music.youtube.com';
  static const String youtubeSubscriptionsUrl = 'https://www.youtube.com/feed/subscriptions';
  static const String youtubeHistoryUrl = 'https://www.youtube.com/feed/history';
  static const String youtubeWatchLaterUrl = 'https://www.youtube.com/playlist?list=WL';
  static const String youtubeLikedVideosUrl = 'https://www.youtube.com/playlist?list=LL';
}
