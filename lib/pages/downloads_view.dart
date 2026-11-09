import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import '../widgets/download_dialog.dart';

class DownloadsView extends StatefulWidget {
  final Future<String?> Function()? onGetActiveVideoUrl;
  final String? currentUrl;

  const DownloadsView({
    super.key,
    this.onGetActiveVideoUrl,
    this.currentUrl,
  });

  @override
  State<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends State<DownloadsView> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    DownloadService().initialize();
    DownloadService().addListener(_onDownloadsChanged);

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  void _onDownloadsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DownloadService().removeListener(_onDownloadsChanged);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(DownloadItem item) async {
    try {
      if (_currentlyPlayingId == item.id && _playerState == PlayerState.playing) {
        await _audioPlayer.pause();
      } else if (_currentlyPlayingId == item.id && _playerState == PlayerState.paused) {
        await _audioPlayer.resume();
      } else {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingId = item.id);
        await _audioPlayer.play(DeviceFileSource(item.filePath));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _openDownloadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => DownloadDialog(
        initialUrl: widget.currentUrl,
        onGetActiveVideoUrl: widget.onGetActiveVideoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = DownloadService().items;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.download_done_rounded, color: AppTheme.youtubeRed, size: 22),
            SizedBox(width: 10),
            Text(
              'Offline Downloads',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openDownloadDialog,
            tooltip: 'Download from URL or Running Video',
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.accentCyan, size: 22),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.youtubeRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.youtubeRed.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16, color: AppTheme.premiumGold),
                const SizedBox(width: 6),
                Text(
                  '${items.length} Saved',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.premiumGold),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_download_outlined,
                            size: 64,
                            color: AppTheme.textMuted.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Offline Videos or Songs Yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Use the Download button in the player or launch screen to save YouTube videos and audio for ad-free offline listening.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _openDownloadDialog,
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Download from URL or Running Video', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.youtubeRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildDownloadItemCard(item);
                    },
                  ),
          ),

          // Mini Player bar if audio is currently loaded
          if (_currentlyPlayingId != null) _buildMiniPlayer(),
        ],
      ),
      floatingActionButton: items.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openDownloadDialog,
              backgroundColor: AppTheme.youtubeRed,
              icon: const Icon(Icons.download_rounded, color: Colors.white),
              label: const Text(
                'Download',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildDownloadItemCard(DownloadItem item) {
    final isPlaying = _currentlyPlayingId == item.id && _playerState == PlayerState.playing;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlaying ? AppTheme.youtubeRed : AppTheme.borderSubtle,
          width: isPlaying ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.thumbnailUrl,
                  width: 90,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 90,
                    height: 56,
                    color: Colors.black38,
                    child: Icon(
                      item.type == DownloadType.audio ? Icons.music_note : Icons.videocam,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.type == DownloadType.audio
                                ? Colors.deepPurple.withValues(alpha: 0.3)
                                : AppTheme.youtubeRed.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.type == DownloadType.audio ? 'AUDIO' : 'VIDEO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.type == DownloadType.audio ? Colors.purpleAccent : AppTheme.youtubeRedLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatBytes(item.totalBytes > 0 ? item.totalBytes : item.downloadedBytes),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textSecondary),
                color: AppTheme.surfaceElevated,
                onSelected: (action) {
                  if (action == 'delete') {
                    if (_currentlyPlayingId == item.id) {
                      _audioPlayer.stop();
                      setState(() => _currentlyPlayingId = null);
                    }
                    DownloadService().deleteDownload(item);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: AppTheme.youtubeRed, size: 18),
                        SizedBox(width: 8),
                        Text('Delete File', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Download Progress bar (if still downloading)
          if (item.status == DownloadStatus.downloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.progress > 0 ? item.progress : null,
                backgroundColor: Colors.white10,
                color: AppTheme.youtubeRed,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Downloading ${(item.progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Text(
                  '${_formatBytes(item.downloadedBytes)} / ${_formatBytes(item.totalBytes)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ] else if (item.status == DownloadStatus.completed) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.type == DownloadType.audio || File(item.filePath).existsSync())
                  TextButton.icon(
                    onPressed: () => _playAudio(item),
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: AppTheme.youtubeRed,
                      size: 20,
                    ),
                    label: Text(
                      isPlaying ? 'Pause' : 'Play Offline',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    final items = DownloadService().items;
    final item = items.firstWhere(
      (i) => i.id == _currentlyPlayingId,
      orElse: () => items.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceElevated,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.thumbnailUrl,
                  width: 44,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.music_note, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _playerState == PlayerState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppTheme.youtubeRed,
                ),
                onPressed: () => _playAudio(item),
              ),
              IconButton(
                icon: const Icon(Icons.stop_rounded, color: AppTheme.textSecondary),
                onPressed: () async {
                  await _audioPlayer.stop();
                  setState(() => _currentlyPlayingId = null);
                },
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: AppTheme.youtubeRed,
              inactiveTrackColor: Colors.white12,
              thumbColor: AppTheme.youtubeRed,
            ),
            child: Slider(
              value: _duration.inMilliseconds > 0
                  ? _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble()
                  : 0.0,
              max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
              onChanged: (val) {
                _audioPlayer.seek(Duration(milliseconds: val.toInt()));
              },
            ),
          ),
        ],
      ),
    );
  }
}
