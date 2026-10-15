import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBanner extends StatelessWidget {
  final String? message;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onDismiss;

  const StatusBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.iconColor = AppTheme.pinActive,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isVisible = message != null && message!.isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: isVisible
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                border: const Border(
                  bottom: BorderSide(color: AppTheme.border),
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onDismiss != null)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: onDismiss,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
