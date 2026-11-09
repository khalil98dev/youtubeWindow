import 'package:flutter/material.dart';
import '../controllers/unified_player_controller.dart';
import '../pages/downloads_view.dart';
import '../services/youtube_url_helper.dart';
import '../theme/app_theme.dart';
import 'account_status_badge.dart';
import 'download_dialog.dart';

class PremiumToolbar extends StatelessWidget {
  final UnifiedPlayerController controller;
  final bool isBackgroundPlayEnabled;
  final bool isAudioOnlyEnabled;
  final bool isAdBlockerEnabled;
  final bool isLoopEnabled;
  final double playbackSpeed;
  final String currentQuality;
  final YouTubeAccountInfo? accountInfo;
  final ValueChanged<bool> onToggleBackgroundPlay;
  final ValueChanged<bool> onToggleAudioOnly;
  final ValueChanged<bool> onToggleAdBlocker;
  final ValueChanged<bool> onToggleLoop;
  final ValueChanged<double> onSpeedSelected;
  final ValueChanged<String> onQualitySelected;
  final VoidCallback onTogglePiP;
  final ValueChanged<String> onNavigateUrl;

  const PremiumToolbar({
    super.key,
    required this.controller,
    required this.isBackgroundPlayEnabled,
    required this.isAudioOnlyEnabled,
    required this.isAdBlockerEnabled,
    required this.isLoopEnabled,
    required this.playbackSpeed,
    required this.currentQuality,
    this.accountInfo,
    required this.onToggleBackgroundPlay,
    required this.onToggleAudioOnly,
    required this.onToggleAdBlocker,
    required this.onToggleLoop,
    required this.onSpeedSelected,
    required this.onQualitySelected,
    required this.onTogglePiP,
    required this.onNavigateUrl,
  });

  Future<void> _openDownloadDialog(BuildContext context) async {
    String current = controller.currentUrl;

    // Check twice: if user's current URL is invalid, query the active video running in webview and auto-bind!
    if (!YouTubeUrlHelper.isValidVideoUrl(current)) {
      final active = await controller.getActiveVideoUrl();
      if (active != null && YouTubeUrlHelper.isValidVideoUrl(active)) {
        current = active;
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => DownloadDialog(
        initialUrl: current,
        onGetActiveVideoUrl: () => controller.getActiveVideoUrl(),
      ),
    );
  }

  void _openDownloadsLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DownloadsView(
          onGetActiveVideoUrl: () => controller.getActiveVideoUrl(),
          currentUrl: controller.currentUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: AppTheme.borderSubtle),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // Account / Sign-In Button
            AccountStatusBadge(
              accountInfo: accountInfo,
              onSignIn: () => controller.openSignIn(),
              onNavigateUrl: onNavigateUrl,
            ),
            const SizedBox(width: 8),

            const VerticalDivider(width: 1, indent: 10, endIndent: 10, color: AppTheme.border),
            const SizedBox(width: 8),

            // Background Play indicator / toggle
            _buildToggleChip(
              icon: isBackgroundPlayEnabled ? Icons.headphones_rounded : Icons.headphones_outlined,
              label: 'Background',
              isActive: isBackgroundPlayEnabled,
              activeColor: AppTheme.accentCyan,
              onTap: () => onToggleBackgroundPlay(!isBackgroundPlayEnabled),
              tooltip: 'Background Play: Keep playing audio when minimized or screen locked',
            ),
            const SizedBox(width: 6),

            // Audio-Only Mode toggle
            _buildToggleChip(
              icon: isAudioOnlyEnabled ? Icons.music_note_rounded : Icons.music_off_outlined,
              label: 'Audio Only',
              isActive: isAudioOnlyEnabled,
              activeColor: AppTheme.youtubeRedLight,
              onTap: () => onToggleAudioOnly(!isAudioOnlyEnabled),
              tooltip: 'Audio Only: Save up to 85% battery & network bandwidth',
            ),
            const SizedBox(width: 6),

            // Ad Blocker toggle
            _buildToggleChip(
              icon: isAdBlockerEnabled ? Icons.shield_rounded : Icons.shield_outlined,
              label: 'Ad-Free',
              isActive: isAdBlockerEnabled,
              activeColor: AppTheme.accentGreen,
              onTap: () => onToggleAdBlocker(!isAdBlockerEnabled),
              tooltip: 'Ad Blocker: Auto-skip video & banner ads',
            ),
            const SizedBox(width: 6),

            // Picture-in-Picture
            _buildActionChip(
              icon: Icons.picture_in_picture_alt_rounded,
              label: 'PiP',
              onTap: onTogglePiP,
              tooltip: 'Picture-in-Picture mode',
            ),
            const SizedBox(width: 6),

            // Speed Selector
            PopupMenuButton<double>(
              color: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.border),
              ),
              offset: const Offset(0, 36),
              tooltip: 'Playback Speed',
              onSelected: onSpeedSelected,
              itemBuilder: (context) => [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
                  .map(
                    (speed) => PopupMenuItem<double>(
                      value: speed,
                      child: Row(
                        children: [
                          if (playbackSpeed == speed)
                            const Icon(Icons.check_rounded, size: 16, color: AppTheme.youtubeRed)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text('${speed}x', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: _buildBadge(
                icon: Icons.speed_rounded,
                text: '${playbackSpeed}x',
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 6),

            // Quality Lock Selector
            PopupMenuButton<String>(
              color: AppTheme.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.border),
              ),
              offset: const Offset(0, 36),
              tooltip: 'Force Quality',
              onSelected: onQualitySelected,
              itemBuilder: (context) => [
                {'label': '1080p Premium', 'value': 'hd1080'},
                {'label': '720p HD', 'value': 'hd720'},
                {'label': '480p SD', 'value': 'large'},
                {'label': '360p Data Saver', 'value': 'medium'},
                {'label': 'Auto', 'value': 'auto'},
              ]
                  .map(
                    (item) => PopupMenuItem<String>(
                      value: item['value']!,
                      child: Row(
                        children: [
                          if (currentQuality == item['value'])
                            const Icon(Icons.check_rounded, size: 16, color: AppTheme.premiumGold)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(item['label']!, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: _buildBadge(
                icon: Icons.hd_rounded,
                text: currentQuality == 'hd1080'
                    ? '1080p'
                    : currentQuality.toUpperCase(),
                color: AppTheme.premiumGold,
              ),
            ),
            const SizedBox(width: 6),

            // Loop Toggle
            _buildToggleChip(
              icon: isLoopEnabled ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              label: 'Loop',
              isActive: isLoopEnabled,
              activeColor: AppTheme.premiumGold,
              onTap: () => onToggleLoop(!isLoopEnabled),
              tooltip: 'Loop current video',
            ),
            const SizedBox(width: 6),

            const VerticalDivider(width: 1, indent: 10, endIndent: 10, color: AppTheme.border),
            const SizedBox(width: 8),

            // Download Button (YouTube Premium offline download)
            _buildActionChip(
              icon: Icons.download_rounded,
              label: 'Download',
              color: AppTheme.youtubeRed,
              textColor: Colors.white,
              onTap: () => _openDownloadDialog(context),
              tooltip: 'Download video/audio for offline playback',
            ),
            const SizedBox(width: 6),

            // Offline Library Button
            _buildActionChip(
              icon: Icons.folder_special_rounded,
              label: 'Saved',
              color: AppTheme.surfaceElevated,
              textColor: AppTheme.textPrimary,
              onTap: () => _openDownloadsLibrary(context),
              tooltip: 'View downloaded offline media',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? activeColor.withValues(alpha: 0.5) : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isActive ? activeColor : AppTheme.textSecondary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? activeColor : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    Color? color,
    Color? textColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color ?? AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: textColor ?? AppTheme.textPrimary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
          const Icon(Icons.arrow_drop_down, size: 14, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}
