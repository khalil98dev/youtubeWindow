class YouTubeUrlHelper {
  /// Regular expression to match standard YouTube video IDs (11 alphanumeric, hyphen, underscore characters)
  static final RegExp _videoIdRegex = RegExp(
    r'(?:https?:\/\/)?(?:www\.|m\.|music\.)?(?:youtube\.com\/(?:watch\?.*?v=|shorts\/|live\/|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );

  /// Checks if the input string can be resolved to a valid YouTube Video
  static bool isValidVideoUrl(String? url) {
    if (url == null) return false;
    final clean = url.trim();
    if (clean.isEmpty) return false;

    // Check if raw 11-char ID
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean)) {
      return true;
    }

    // Check standard match
    return _videoIdRegex.hasMatch(clean);
  }

  /// Extracts the 11-character video ID from any YouTube URL or raw ID
  static String? extractVideoId(String? input) {
    if (input == null) return null;
    final clean = input.trim();
    if (clean.isEmpty) return null;

    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean)) {
      return clean;
    }

    final match = _videoIdRegex.firstMatch(clean);
    return match?.group(1);
  }

  /// Normalizes any valid YouTube video URL or ID into a standard watch URL:
  /// https://www.youtube.com/watch?v=VIDEO_ID
  static String normalizeToWatchUrl(String input) {
    final id = extractVideoId(input);
    if (id != null) {
      return 'https://www.youtube.com/watch?v=$id';
    }
    String clean = input.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'https://$clean';
    }
    return clean;
  }
}
