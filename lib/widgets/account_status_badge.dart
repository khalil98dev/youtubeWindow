import 'package:flutter/material.dart';
import '../controllers/unified_player_controller.dart';
import '../services/youtube_premium_service.dart';
import '../theme/app_theme.dart';

class AccountStatusBadge extends StatelessWidget {
  final YouTubeAccountInfo? accountInfo;
  final VoidCallback onSignIn;
  final ValueChanged<String>? onNavigateUrl;

  const AccountStatusBadge({
    super.key,
    this.accountInfo,
    required this.onSignIn,
    this.onNavigateUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isSignedIn = accountInfo?.isSignedIn ?? false;
    final avatarUrl = accountInfo?.avatarUrl ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSignedIn ? AppTheme.premiumGold.withValues(alpha: 0.4) : AppTheme.border,
        ),
      ),
      child: PopupMenuButton<String>(
        color: AppTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.border),
        ),
        offset: const Offset(0, 44),
        onSelected: (url) {
          if (url == 'signin') {
            onSignIn();
          } else if (onNavigateUrl != null) {
            onNavigateUrl!(url);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Row(
              children: [
                Icon(
                  isSignedIn ? Icons.check_circle_rounded : Icons.account_circle_outlined,
                  size: 18,
                  color: isSignedIn ? AppTheme.premiumGold : AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  isSignedIn ? 'Connected to Google' : 'Guest Account',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSignedIn ? AppTheme.premiumGold : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          if (!isSignedIn)
            const PopupMenuItem<String>(
              value: 'signin',
              child: Row(
                children: [
                  Icon(Icons.login_rounded, size: 18, color: AppTheme.youtubeRed),
                  SizedBox(width: 10),
                  Text('Sign in to YouTube / Google', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          const PopupMenuItem<String>(
            value: YouTubePremiumService.youtubeSubscriptionsUrl,
            child: Row(
              children: [
                Icon(Icons.subscriptions_outlined, size: 18, color: AppTheme.textPrimary),
                SizedBox(width: 10),
                Text('Subscriptions', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: YouTubePremiumService.youtubeHistoryUrl,
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 18, color: AppTheme.textPrimary),
                SizedBox(width: 10),
                Text('History', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: YouTubePremiumService.youtubeWatchLaterUrl,
            child: Row(
              children: [
                Icon(Icons.watch_later_outlined, size: 18, color: AppTheme.textPrimary),
                SizedBox(width: 10),
                Text('Watch Later', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: YouTubePremiumService.youtubeLikedVideosUrl,
            child: Row(
              children: [
                Icon(Icons.thumb_up_alt_outlined, size: 18, color: AppTheme.textPrimary),
                SizedBox(width: 10),
                Text('Liked Videos', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: YouTubePremiumService.youtubeMusicUrl,
            child: Row(
              children: [
                Icon(Icons.music_note_rounded, size: 18, color: AppTheme.youtubeRedLight),
                SizedBox(width: 10),
                Text('YouTube Music', style: TextStyle(fontSize: 13, color: AppTheme.youtubeRedLight)),
              ],
            ),
          ),
          if (isSignedIn) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'signin',
              child: Row(
                children: [
                  Icon(Icons.switch_account_rounded, size: 18, color: AppTheme.textSecondary),
                  SizedBox(width: 10),
                  Text('Switch Account', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSignedIn && avatarUrl.isNotEmpty)
                ClipOval(
                  child: Image.network(
                    avatarUrl,
                    width: 22,
                    height: 22,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.account_circle_rounded,
                      size: 22,
                      color: AppTheme.premiumGold,
                    ),
                  ),
                )
              else
                Icon(
                  isSignedIn ? Icons.account_circle_rounded : Icons.login_rounded,
                  size: 18,
                  color: isSignedIn ? AppTheme.premiumGold : AppTheme.textSecondary,
                ),
              const SizedBox(width: 6),
              Text(
                isSignedIn ? 'Account' : 'Sign In',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSignedIn ? AppTheme.premiumGold : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: isSignedIn ? AppTheme.premiumGold : AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
