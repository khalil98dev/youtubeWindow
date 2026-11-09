import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

class AdBlockerService {
  static const String youTubeAdBlockerScript = r'''
(function() {
  if (window.__yt_adblock_installed__) return;
  window.__yt_adblock_installed__ = true;

  // 1. Inject Styles to hide banners, promoted cards, and ad overlays
  function injectStyles() {
    if (document.getElementById('yt-adblock-styles')) return;
    const style = document.createElement('style');
    style.id = 'yt-adblock-styles';
    style.textContent = `
      .video-ads,
      .ytp-ad-module,
      .ytp-ad-overlay-container,
      .ytp-ad-overlay-slot,
      .ytp-ad-message-container,
      .ytp-ad-player-overlay,
      .ytp-ad-player-overlay-flyout-cta,
      .ytp-ad-action-interstitial,
      .ytp-ad-image-overlay,
      .ytp-ad-text,
      #player-ads,
      #masthead-ad,
      ytd-promoted-video-renderer,
      ytd-promoted-sparkles-web-renderer,
      ytd-in-feed-ad-layout-renderer,
      ytd-ad-slot-renderer,
      ytd-banner-promo-renderer,
      ytd-statement-banner-renderer,
      ytd-mealbar-promo-renderer,
      ytd-engagement-panel-section-list-renderer[target-id="engagement-panel-ads"],
      .ytd-merch-shelf-renderer,
      ytd-player-legacy-desktop-watch-ads-renderer,
      ytd-action-companion-ad-renderer,
      ytd-brand-video-singleton-renderer,
      ytd-compact-promoted-video-renderer,
      #panels ytd-ads-engagement-panel-content-renderer,
      #related ytd-ad-slot-renderer,
      ytd-display-ad-renderer,
      tp-yt-paper-dialog:has(ytd-enforcement-message-view-model),
      ytd-enforcement-message-view-model,
      tp-yt-iron-overlay-backdrop {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
        height: 0 !important;
        width: 0 !important;
      }
    `;
    const target = document.head || document.documentElement;
    if (target) target.appendChild(style);
  }

  // 2. Clean JSON data in YouTube player responses to prevent ad scheduling
  function cleanPlayerData(obj) {
    if (!obj || typeof obj !== 'object') return obj;
    try {
      delete obj.adPlacements;
      delete obj.adSlots;
      delete obj.playerAds;
      delete obj.adBreakHeartbeatParams;
      if (obj.playbackTracking) {
        delete obj.playbackTracking.videostatsPlaybackUrl;
        delete obj.playbackTracking.videostatsDelayplayUrl;
        delete obj.playbackTracking.videostatsWatchtimeUrl;
        delete obj.playbackTracking.videostatsPtrackingUrl;
        delete obj.playbackTracking.qoeUrl;
        delete obj.playbackTracking.atrUrl;
      }
    } catch (_) {}
    return obj;
  }

  // Intercept window.ytInitialPlayerResponse
  let _rawPlayerResponse = window.ytInitialPlayerResponse;
  if (_rawPlayerResponse) cleanPlayerData(_rawPlayerResponse);
  try {
    Object.defineProperty(window, 'ytInitialPlayerResponse', {
      configurable: true,
      enumerable: true,
      get() { return _rawPlayerResponse; },
      set(val) { _rawPlayerResponse = cleanPlayerData(val); }
    });
  } catch (_) {}

  // 3. Network-level interception: Filter ad URLs & sanitize /youtubei/v1/player JSON
  const adUrlPatterns = [
    '/pagead/',
    '/api/stats/ads',
    'doubleclick.net',
    'googleads',
    '/youtubei/v1/player/ad_break',
    '/youtubei/v1/log_event',
    'ad.doubleclick.net'
  ];

  function isAdUrl(url) {
    if (!url || typeof url !== 'string') return false;
    return adUrlPatterns.some(pattern => url.includes(pattern));
  }

  if (window.fetch) {
    const originalFetch = window.fetch;
    window.fetch = async function(...args) {
      let url = '';
      if (typeof args[0] === 'string') {
        url = args[0];
      } else if (args[0] && args[0].url) {
        url = args[0].url;
      }

      if (isAdUrl(url)) {
        return new Response('{}', {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }

      const res = await originalFetch.apply(this, args);

      if (url.includes('/youtubei/v1/player')) {
        try {
          const clone = res.clone();
          const json = await clone.json();
          cleanPlayerData(json);
          return new Response(JSON.stringify(json), {
            status: res.status,
            statusText: res.statusText,
            headers: res.headers
          });
        } catch (_) {
          return res;
        }
      }

      return res;
    };
  }

  if (window.XMLHttpRequest) {
    const originalOpen = XMLHttpRequest.prototype.open;
    const originalSend = XMLHttpRequest.prototype.send;

    XMLHttpRequest.prototype.open = function(method, url, ...rest) {
      this._ytUrl = typeof url === 'string' ? url : (url ? url.toString() : '');
      return originalOpen.call(this, method, url, ...rest);
    };

    XMLHttpRequest.prototype.send = function(body) {
      if (isAdUrl(this._ytUrl)) {
        Object.defineProperty(this, 'status', { writable: true, value: 200 });
        Object.defineProperty(this, 'readyState', { writable: true, value: 4 });
        Object.defineProperty(this, 'responseText', { writable: true, value: '{}' });
        Object.defineProperty(this, 'response', { writable: true, value: '{}' });
        setTimeout(() => {
          if (typeof this.onreadystatechange === 'function') this.onreadystatechange();
          if (typeof this.onload === 'function') this.onload();
        }, 0);
        return;
      }

      if (this._ytUrl && this._ytUrl.includes('/youtubei/v1/player')) {
        this.addEventListener('readystatechange', function() {
          if (this.readyState === 4 && this.status === 200) {
            try {
              const data = JSON.parse(this.responseText);
              cleanPlayerData(data);
              const sanitized = JSON.stringify(data);
              Object.defineProperty(this, 'responseText', { get: () => sanitized });
              Object.defineProperty(this, 'response', { get: () => sanitized });
            } catch (_) {}
          }
        });
      }

      return originalSend.call(this, body);
    };
  }

  // 4. Video ad detector & immediate skipper (auto-skip + 16x speedup + mute during ad)
  function handleVideoAds() {
    const player = document.getElementById('movie_player') || document.querySelector('.html5-video-player');
    const isAd = player && (
      player.classList.contains('ad-showing') ||
      player.classList.contains('ad-interrupting')
    );

    const video = document.querySelector('video.html5-main-video') || document.querySelector('video');

    if (isAd && video) {
      video.muted = true;
      if (Number.isFinite(video.duration) && video.duration > 0) {
        video.currentTime = video.duration;
      }
      video.playbackRate = 16.0;
    }

    // Auto click skip buttons
    const skipSelectors = [
      '.ytp-ad-skip-button',
      '.ytp-ad-skip-button-modern',
      '.ytp-skip-ad-button',
      '.ytp-ad-skip-button-container button',
      'button.ytp-ad-skip-button-text',
      '.ytp-ad-overlay-close-button',
      '[id^="skip-button"] button',
      '.ytp-ad-preview-container button'
    ];

    for (const sel of skipSelectors) {
      const el = document.querySelector(sel);
      if (el && typeof el.click === 'function') {
        el.click();
      }
    }

    // Dismiss adblock enforcement dialogs if YouTube attempts to show them
    const enforcement = document.querySelector('ytd-enforcement-message-view-model') ||
                        document.querySelector('tp-yt-paper-dialog:has(ytd-enforcement-message-view-model)');
    if (enforcement) {
      const dismiss = enforcement.querySelector('#dismiss-button, button[aria-label="Dismiss"]');
      if (dismiss) {
        dismiss.click();
      } else {
        enforcement.remove();
      }
      document.querySelectorAll('tp-yt-iron-overlay-backdrop').forEach(b => b.remove());
      if (video && video.paused) {
        video.play();
      }
    }
  }

  // Run skip loop every 120ms
  setInterval(handleVideoAds, 120);

  // MutationObserver for instant DOM reaction & style persistence
  function setupObserver() {
    injectStyles();
    handleVideoAds();
    const obs = new MutationObserver(() => {
      injectStyles();
      handleVideoAds();
    });
    obs.observe(document.documentElement || document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['class']
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupObserver);
  } else {
    setupObserver();
  }
})();
''';

  /// Injects and activates the YouTube ad blocker script in the webview.
  /// Registers the script to execute on document creation, and also immediately
  /// executes it in the current page context if already created.
  static Future<ScriptID?> install(WebviewController controller) async {
    try {
      final scriptId = await controller.addScriptToExecuteOnDocumentCreated(
        youTubeAdBlockerScript,
      );
      // Also execute immediately in case document is already created
      await controller.executeScript(youTubeAdBlockerScript);
      return scriptId;
    } catch (e) {
      debugPrint('AdBlockerService install error: $e');
      return null;
    }
  }

  /// Re-applies the ad blocker script (e.g. after page reloads or navigations).
  static Future<void> reapply(WebviewController controller) async {
    try {
      await controller.executeScript(youTubeAdBlockerScript);
    } catch (e) {
      debugPrint('AdBlockerService reapply error: $e');
    }
  }
}
