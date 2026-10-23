class AppConstants {
  static const String appName = 'TetangGo';
  static const String appTagline = 'Tetangga Kompak, Lingkungan Terjaga';
  static const String appVersion = '0.1.0';
  static const String appDescription =
      'Platform digitalisasi lingkungan perumahan/cluster yang mengedepankan kekompakan warga, transparansi kas RT, dan keamanan lingkungan terpadu.';

  /// Dynamic maintainable copyright notice.
  /// Sourced with base year 2026.
  static String get copyrightNotice {
    final currentYear = DateTime.now().year;
    final yearStr = currentYear <= 2026 ? '2026' : '2026-$currentYear';
    return '© $yearStr $appName. All rights reserved.';
  }

  static const String licenseType = 'PolyForm Noncommercial License 1.0.0';
  static const String licenseUrl =
      'https://polyformproject.org/licenses/noncommercial/1.0.0';
  static const String repositoryUrl = 'https://github.com/zahidinf/TetangGo';
}
