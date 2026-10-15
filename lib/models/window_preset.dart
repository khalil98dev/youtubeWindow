class WindowPreset {
  final String id;
  final String label;
  final String subtitle;
  final int width;
  final int height;

  const WindowPreset({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.width,
    required this.height,
  });

  static const List<WindowPreset> presets = [
    WindowPreset(
      id: 'pip',
      label: 'PiP Mini',
      subtitle: '480 × 270',
      width: 480,
      height: 270,
    ),
    WindowPreset(
      id: 'compact',
      label: 'Compact',
      subtitle: '640 × 360',
      width: 640,
      height: 360,
    ),
    WindowPreset(
      id: 'standard',
      label: 'Standard',
      subtitle: '960 × 540',
      width: 960,
      height: 540,
    ),
    WindowPreset(
      id: 'hd',
      label: 'HD 720p',
      subtitle: '1280 × 720',
      width: 1280,
      height: 720,
    ),
    WindowPreset(
      id: 'fhd',
      label: 'FHD 1080p',
      subtitle: '1920 × 1080',
      width: 1920,
      height: 1080,
    ),
  ];
}
