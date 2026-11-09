import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';
import '../services/youtube_url_helper.dart';
import '../theme/app_theme.dart';

class DownloadDialog extends StatefulWidget {
  final String? initialUrl;
  final Future<String?> Function()? onGetActiveVideoUrl;

  const DownloadDialog({
    super.key,
    this.initialUrl,
    this.onGetActiveVideoUrl,
  });

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  final TextEditingController _urlInputController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  Video? _video;
  List<MuxedStreamInfo> _muxedStreams = [];

  DownloadType _selectedType = DownloadType.video;
  String _selectedQuality = 'Best Available';

  bool _isAutoBound = false;
  String? _autoBoundSource;

  @override
  void initState() {
    super.initState();
    _checkAndBindInitialUrl();
  }

  @override
  void dispose() {
    _urlInputController.dispose();
    super.dispose();
  }

  /// Two-stage validation and auto-bind:
  /// Check 1: Is user's input valid?
  /// Check 2: If invalid, check if a video is running in player and auto-bind it!
  Future<void> _checkAndBindInitialUrl() async {
    final raw = widget.initialUrl?.trim() ?? '';
    await _processUrl(raw, isManualInput: false);
  }

  Future<void> _processUrl(String input, {required bool isManualInput}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final trimmed = input.trim();

    // -------------------------------------------------------------
    // CHECK 1: Verify if the user's inserted URL is a valid video
    // -------------------------------------------------------------
    if (YouTubeUrlHelper.isValidVideoUrl(trimmed)) {
      final normalized = YouTubeUrlHelper.normalizeToWatchUrl(trimmed);
      _urlInputController.text = normalized;
      setState(() {
        _isAutoBound = false;
        _autoBoundSource = null;
      });
      await _fetchStreamsForUrl(normalized);
      return;
    }

    // -------------------------------------------------------------
    // CHECK 2: Inserted URL is invalid! Check if a video is running
    // in the player and auto-bind its URL.
    // -------------------------------------------------------------
    String? runningVideoUrl;
    if (widget.onGetActiveVideoUrl != null) {
      try {
        runningVideoUrl = await widget.onGetActiveVideoUrl!();
      } catch (_) {}
    }

    if (runningVideoUrl != null && YouTubeUrlHelper.isValidVideoUrl(runningVideoUrl)) {
      final normalizedRunning = YouTubeUrlHelper.normalizeToWatchUrl(runningVideoUrl);
      _urlInputController.text = normalizedRunning;
      if (mounted) {
        setState(() {
          _isAutoBound = true;
          _autoBoundSource = isManualInput
              ? 'Input was invalid → Auto-bound from running video'
              : 'Auto-bound from currently playing video';
        });
      }
      await _fetchStreamsForUrl(normalizedRunning);
      return;
    }

    // Fallback for Check 2: Check system clipboard for a valid video URL
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final clipText = clip?.text?.trim();
      if (clipText != null && YouTubeUrlHelper.isValidVideoUrl(clipText)) {
        final normalizedClip = YouTubeUrlHelper.normalizeToWatchUrl(clipText);
        _urlInputController.text = normalizedClip;
        if (mounted) {
          setState(() {
            _isAutoBound = true;
            _autoBoundSource = isManualInput
                ? 'Input was invalid → Auto-bound from link in clipboard'
                : 'Auto-bound from YouTube link in clipboard';
          });
        }
        await _fetchStreamsForUrl(normalizedClip);
        return;
      }
    } catch (_) {}

    // If both checks failed:
    if (mounted) {
      setState(() {
        _isLoading = false;
        _urlInputController.text = trimmed;
        _error = 'Invalid YouTube video URL. Please enter a valid watch link or play a video in the player to auto-bind.';
      });
    }
  }

  Future<void> _fetchStreamsForUrl(String url) async {
    try {
      final info = await DownloadService().getVideoInfo(url);
      if (!mounted) return;

      if (info == null) {
        setState(() {
          _isLoading = false;
          _error = 'Could not retrieve video streams. Ensure this video is public and accessible.';
        });
        return;
      }

      setState(() {
        _video = info['video'] as Video;
        final muxed = info['muxedStreams'] as List<MuxedStreamInfo>;
        _muxedStreams = muxed;
        _isLoading = false;
        if (muxed.isNotEmpty) {
          _selectedQuality = muxed.last.videoQuality.name;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error loading video: $e';
        });
      }
    }
  }

  Future<void> _manuallyTriggerAutoBind() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    String? active;
    if (widget.onGetActiveVideoUrl != null) {
      active = await widget.onGetActiveVideoUrl!();
    }

    if (active != null && YouTubeUrlHelper.isValidVideoUrl(active)) {
      final normalized = YouTubeUrlHelper.normalizeToWatchUrl(active);
      _urlInputController.text = normalized;
      setState(() {
        _isAutoBound = true;
        _autoBoundSource = 'Auto-bound from running video in player';
      });
      await _fetchStreamsForUrl(normalized);
      return;
    }

    // Try clipboard
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final clipText = clip?.text?.trim();
    if (clipText != null && YouTubeUrlHelper.isValidVideoUrl(clipText)) {
      final normalized = YouTubeUrlHelper.normalizeToWatchUrl(clipText);
      _urlInputController.text = normalized;
      setState(() {
        _isAutoBound = true;
        _autoBoundSource = 'Auto-bound from clipboard';
      });
      await _fetchStreamsForUrl(normalized);
      return;
    }

    setState(() {
      _isLoading = false;
      _error = 'No running video detected in the player. Please play a video first or paste a watch link.';
    });
  }

  Future<void> _pasteFromClipboard() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.isNotEmpty) {
      _urlInputController.text = clip.text!.trim();
      await _processUrl(clip.text!.trim(), isManualInput: true);
    }
  }

  void _startDownload() {
    final targetUrl = _urlInputController.text.trim();
    if (!YouTubeUrlHelper.isValidVideoUrl(targetUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot download: Invalid video URL.'),
          backgroundColor: AppTheme.youtubeRed,
        ),
      );
      return;
    }

    DownloadService().startDownload(
      videoUrl: targetUrl,
      type: _selectedType,
      qualityLabel: _selectedQuality,
    );

    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting offline download: ${_video?.title ?? "Video"}'),
        backgroundColor: AppTheme.surfaceElevated,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.youtubeRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.download_rounded, color: AppTheme.youtubeRed, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YouTube Premium Download',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Save for offline playback without ads',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // URL Input Bar with Auto-Bind and Paste buttons
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isAutoBound
                          ? AppTheme.accentCyan.withValues(alpha: 0.6)
                          : AppTheme.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.link_rounded, size: 18, color: AppTheme.youtubeRed),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _urlInputController,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Enter YouTube video link...',
                            hintStyle: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (val) => _processUrl(val, isManualInput: true),
                        ),
                      ),
                      // Auto-bind Running Video Button
                      Tooltip(
                        message: 'Auto-bind from currently running video',
                        child: IconButton(
                          icon: const Icon(Icons.sync_rounded, size: 18, color: AppTheme.accentCyan),
                          onPressed: _manuallyTriggerAutoBind,
                        ),
                      ),
                      // Paste Button
                      Tooltip(
                        message: 'Paste link from clipboard',
                        child: IconButton(
                          icon: const Icon(Icons.paste_rounded, size: 17, color: AppTheme.textSecondary),
                          onPressed: _pasteFromClipboard,
                        ),
                      ),
                    ],
                  ),
                ),

                // Auto-bound Pill Badge
                if (_isAutoBound && _autoBoundSource != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 14, color: AppTheme.accentCyan),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _autoBoundSource!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppTheme.youtubeRed),
                        SizedBox(height: 14),
                        Text(
                          'Validating URL & extracting streams...',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.youtubeRed, size: 36),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _manuallyTriggerAutoBind,
                              icon: const Icon(Icons.sync_rounded, size: 16),
                              label: const Text('Auto-Bind Running Video'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.surfaceElevated,
                                foregroundColor: AppTheme.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Video Card Preview
                  if (_video != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _video!.thumbnails.mediumResUrl,
                              width: 80,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 80,
                                height: 50,
                                color: Colors.black26,
                                child: const Icon(Icons.video_library, color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _video!.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _video!.author,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Format Selector: Video vs Audio
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormatButton(
                          type: DownloadType.video,
                          icon: Icons.videocam_rounded,
                          label: 'Video & Audio',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormatButton(
                          type: DownloadType.audio,
                          icon: Icons.music_note_rounded,
                          label: 'Audio Only',
                        ),
                      ),
                    ],
                  ),

                  // Quality selector for video
                  if (_selectedType == DownloadType.video && _muxedStreams.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _muxedStreams.any((s) => s.videoQuality.name == _selectedQuality)
                              ? _selectedQuality
                              : _muxedStreams.last.videoQuality.name,
                          isExpanded: true,
                          dropdownColor: AppTheme.surfaceElevated,
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                          items: _muxedStreams.map((stream) {
                            return DropdownMenuItem<String>(
                              value: stream.videoQuality.name,
                              child: Row(
                                children: [
                                  const Icon(Icons.hd_rounded, size: 16, color: AppTheme.premiumGold),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${stream.videoQuality.name} (${stream.container.name.toUpperCase()})',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedQuality = val);
                          },
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                            side: const BorderSide(color: AppTheme.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _startDownload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.youtubeRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'Download',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatButton({
    required DownloadType type,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedType == type;
    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.youtubeRed.withValues(alpha: 0.15) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.youtubeRed : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.youtubeRed : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
