enum DownloadType { video, audio }

enum DownloadStatus { downloading, completed, failed, paused }

class DownloadItem {
  final String id;
  final String title;
  final String author;
  final String duration;
  final String thumbnailUrl;
  final String filePath;
  final DownloadType type;
  final String qualityLabel;
  final int totalBytes;
  int downloadedBytes;
  double progress;
  DownloadStatus status;
  String? error;
  final DateTime createdAt;

  DownloadItem({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.filePath,
    required this.type,
    required this.qualityLabel,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.progress = 0.0,
    this.status = DownloadStatus.downloading,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'duration': duration,
        'thumbnailUrl': thumbnailUrl,
        'filePath': filePath,
        'type': type.name,
        'qualityLabel': qualityLabel,
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'progress': progress,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        duration: json['duration'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String,
        filePath: json['filePath'] as String,
        type: json['type'] == 'audio' ? DownloadType.audio : DownloadType.video,
        qualityLabel: json['qualityLabel'] as String? ?? 'High',
        totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
        downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
        progress: (json['progress'] as num?)?.toDouble() ?? 1.0,
        status: DownloadStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => DownloadStatus.completed,
        ),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}
