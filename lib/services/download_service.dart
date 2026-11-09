import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/download_item.dart';

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final List<DownloadItem> _items = [];
  List<DownloadItem> get items => List.unmodifiable(_items);

  bool _initialized = false;
  final YoutubeExplode _yt = YoutubeExplode();

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadPersistedDownloads();
  }

  Future<void> _loadPersistedDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList('yt_offline_downloads') ?? [];
      _items.clear();
      for (final str in listJson) {
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          final item = DownloadItem.fromJson(map);
          // Only add if file exists
          if (File(item.filePath).existsSync()) {
            _items.add(item);
          }
        } catch (_) {}
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  Future<void> _persistDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items
          .where((i) => i.status == DownloadStatus.completed)
          .map((i) => jsonEncode(i.toJson()))
          .toList();
      await prefs.setStringList('yt_offline_downloads', list);
    } catch (e) {
      debugPrint('Error persisting downloads: $e');
    }
  }

  /// Fetches video details and stream options for a given YouTube URL
  Future<Map<String, dynamic>?> getVideoInfo(String url) async {
    try {
      final video = await _yt.videos.get(url);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);

      final videoStreams = manifest.muxed.sortByVideoQuality();
      final audioStreams = manifest.audioOnly.sortByBitrate();

      return {
        'video': video,
        'manifest': manifest,
        'muxedStreams': videoStreams,
        'audioStreams': audioStreams,
      };
    } catch (e) {
      debugPrint('Error fetching video info for download: $e');
      return null;
    }
  }

  /// Starts downloading a stream (audio or video)
  Future<DownloadItem?> startDownload({
    required String videoUrl,
    required DownloadType type,
    String qualityLabel = 'Auto',
  }) async {
    try {
      final info = await getVideoInfo(videoUrl);
      if (info == null) return null;

      final Video video = info['video'] as Video;
      final StreamManifest manifest = info['manifest'] as StreamManifest;

      StreamInfo? selectedStream;
      String extension = 'mp4';

      if (type == DownloadType.audio) {
        final audioStreams = manifest.audioOnly.sortByBitrate();
        if (audioStreams.isNotEmpty) {
          selectedStream = audioStreams.last; // Highest bitrate
          extension = selectedStream.container.name;
        }
      } else {
        final muxed = manifest.muxed.sortByVideoQuality();
        if (muxed.isNotEmpty) {
          selectedStream = muxed.last; // Highest resolution with audio
          extension = selectedStream.container.name;
        } else {
          final audio = manifest.audioOnly.sortByBitrate();
          if (audio.isNotEmpty) {
            selectedStream = audio.last;
            extension = selectedStream.container.name;
          }
        }
      }

      if (selectedStream == null) {
        throw Exception('No playable stream found');
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = video.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final fileName = '${video.id}_${type.name}_$safeTitle.$extension';
      final file = File('${dir.path}/$fileName');

      final downloadItem = DownloadItem(
        id: '${video.id}_${DateTime.now().millisecondsSinceEpoch}',
        title: video.title,
        author: video.author,
        duration: video.duration != null
            ? '${video.duration!.inMinutes}:${(video.duration!.inSeconds % 60).toString().padLeft(2, '0')}'
            : 'Live',
        thumbnailUrl: video.thumbnails.highResUrl,
        filePath: file.path,
        type: type,
        qualityLabel: qualityLabel,
        totalBytes: selectedStream.size.totalBytes,
        progress: 0.0,
        status: DownloadStatus.downloading,
      );

      _items.insert(0, downloadItem);
      notifyListeners();

      // Background download task
      _executeDownload(selectedStream, file, downloadItem);

      return downloadItem;
    } catch (e) {
      debugPrint('Error starting download: $e');
      return null;
    }
  }

  Future<void> _executeDownload(
    StreamInfo streamInfo,
    File file,
    DownloadItem item,
  ) async {
    IOSink? output;
    try {
      final stream = _yt.videos.streamsClient.get(streamInfo);
      output = file.openWrite();

      int bytes = 0;
      final total = streamInfo.size.totalBytes;

      await for (final chunk in stream) {
        output.add(chunk);
        bytes += chunk.length;
        item.downloadedBytes = bytes;
        if (total > 0) {
          item.progress = (bytes / total).clamp(0.0, 1.0);
        }
        notifyListeners();
      }

      await output.flush();
      await output.close();
      output = null;

      item.status = DownloadStatus.completed;
      item.progress = 1.0;
      await _persistDownloads();
      notifyListeners();
    } catch (e) {
      debugPrint('Download error for ${item.title}: $e');
      item.status = DownloadStatus.failed;
      item.error = e.toString();
      try {
        await output?.close();
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> deleteDownload(DownloadItem item) async {
    try {
      final file = File(item.filePath);
      if (file.existsSync()) {
        file.deleteSync();
      }
      _items.removeWhere((i) => i.id == item.id);
      await _persistDownloads();
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting download: $e');
    }
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }
}
