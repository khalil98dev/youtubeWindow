import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/window_preset.dart';
import '../theme/app_theme.dart';
import '../widgets/bouncy_button.dart';

class SettingsView extends StatefulWidget {
  final TextEditingController urlController;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final bool isAlwaysOnTop;
  final ValueChanged<bool> onToggleAlwaysOnTop;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onLaunch;

  const SettingsView({
    super.key,
    required this.urlController,
    required this.widthController,
    required this.heightController,
    required this.isAlwaysOnTop,
    required this.onToggleAlwaysOnTop,
    required this.isLoading,
    this.errorMessage,
    required this.onLaunch,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _selectedPresetId = 'hd';

  final List<Map<String, String>> _quickLinks = [
    {'name': 'YouTube Home', 'url': 'https://www.youtube.com'},
    {'name': 'Trending', 'url': 'https://www.youtube.com/feed/trending'},
    {'name': 'Music', 'url': 'https://music.youtube.com'},
    {'name': 'Lofi Chill ☕', 'url': 'https://www.youtube.com/watch?v=jfKfPfyJRdk'},
  ];

  @override
  void initState() {
    super.initState();
    _syncPresetFromInputs();
    widget.widthController.addListener(_onDimensionChanged);
    widget.heightController.addListener(_onDimensionChanged);
  }

  @override
  void dispose() {
    widget.widthController.removeListener(_onDimensionChanged);
    widget.heightController.removeListener(_onDimensionChanged);
    super.dispose();
  }

  void _onDimensionChanged() {
    _syncPresetFromInputs();
  }

  void _syncPresetFromInputs() {
    final w = int.tryParse(widget.widthController.text);
    final h = int.tryParse(widget.heightController.text);
    if (w == null || h == null) return;

    for (final preset in WindowPreset.presets) {
      if (preset.width == w && preset.height == h) {
        if (_selectedPresetId != preset.id) {
          setState(() => _selectedPresetId = preset.id);
        }
        return;
      }
    }
    if (_selectedPresetId != 'custom') {
      setState(() => _selectedPresetId = 'custom');
    }
  }

  void _selectPreset(WindowPreset preset) {
    setState(() {
      _selectedPresetId = preset.id;
      widget.widthController.text = preset.width.toString();
      widget.heightController.text = preset.height.toString();
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    if (data?.text != null && data!.text!.isNotEmpty) {
      widget.urlController.text = data.text!.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pasted from clipboard: ${data.text}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surfaceElevated,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 20),

                  // URL Input Card
                  _buildUrlSection(),
                  const SizedBox(height: 18),

                  // Window Presets Card
                  _buildDimensionsSection(),
                  const SizedBox(height: 18),

                  // Always on Top Card
                  _buildAlwaysOnTopCard(),
                  const SizedBox(height: 24),

                  // Error Display
                  if (widget.errorMessage != null) ...[
                    _buildErrorBox(widget.errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // Launch Button CTA
                  _buildLaunchButton(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.youtubeRed.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'YouTube Viewer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.4,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Desktop floating player & PiP controller',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUrlSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Video or Channel URL',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              BouncyButton(
                onPressed: _pasteFromClipboard,
                tooltip: 'Paste from clipboard',
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.content_paste_rounded, size: 13, color: AppTheme.textSecondary),
                    SizedBox(width: 4),
                    Text(
                      'Paste',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.urlController,
            style: const TextStyle(fontSize: 13.5, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppTheme.surfaceElevated,
              hintText: 'https://www.youtube.com/watch?v=...',
              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              prefixIcon: const Icon(
                Icons.link_rounded,
                size: 18,
                color: AppTheme.youtubeRed,
              ),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.urlController,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16, color: AppTheme.textMuted),
                    onPressed: () => widget.urlController.clear(),
                    splashRadius: 16,
                  );
                },
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderActive, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Quick suggestions
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickLinks.map((item) {
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    widget.urlController.text = item['url']!;
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Text(
                      item['name']!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Window Dimensions (16:9)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${widget.widthController.text} × ${widget.heightController.text} px',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppTheme.accentCyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Presets pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: WindowPreset.presets.map((preset) {
                final isSelected = _selectedPresetId == preset.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: BouncyButton(
                    onPressed: () => _selectPreset(preset),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.youtubeRed.withValues(alpha: 0.18)
                          : AppTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppTheme.youtubeRed : AppTheme.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preset.subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? AppTheme.youtubeRedLight : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          // Custom Width and Height Inputs
          Row(
            children: [
              Expanded(
                child: _buildDimensionInput(
                  controller: widget.widthController,
                  label: 'Width',
                  icon: Icons.width_normal_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDimensionInput(
                  controller: widget.heightController,
                  label: 'Height',
                  icon: Icons.height_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppTheme.surfaceElevated,
        prefixIcon: Icon(icon, size: 16, color: AppTheme.textSecondary),
        suffixText: 'px',
        suffixStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.borderActive),
        ),
      ),
    );
  }

  Widget _buildAlwaysOnTopCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isAlwaysOnTop ? AppTheme.pinActiveSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isAlwaysOnTop
              ? AppTheme.pinActive.withValues(alpha: 0.5)
              : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isAlwaysOnTop
                  ? AppTheme.pinActive.withValues(alpha: 0.2)
                  : AppTheme.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: AnimatedRotation(
              turns: widget.isAlwaysOnTop ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                widget.isAlwaysOnTop
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                size: 20,
                color: widget.isAlwaysOnTop ? AppTheme.pinActive : AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Always on Top (Pin)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (widget.isAlwaysOnTop) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.pinActive.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PINNED',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.pinActive,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Keep the player floating above all other windows',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: widget.isAlwaysOnTop,
            activeThumbColor: AppTheme.pinActive,
            activeTrackColor: AppTheme.pinActive.withValues(alpha: 0.3),
            inactiveThumbColor: AppTheme.textSecondary,
            inactiveTrackColor: AppTheme.surfaceElevated,
            onChanged: widget.onToggleAlwaysOnTop,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x2BFF3B5C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x66FF3B5C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppTheme.youtubeRedLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.youtubeRedLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunchButton() {
    return BouncyButton(
      onPressed: widget.isLoading ? null : widget.onLaunch,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.youtubeRed.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        child: widget.isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Launching Player...',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Launch YouTube Player',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
