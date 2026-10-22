/// Helper utility for normalizing and formatting resident honorifics (sapaan).
/// Strictly supports only two canonical honorifics: 'Bapak' and 'Ibu'.
class HonorificHelper {
  static const String bapak = 'Bapak';
  static const String ibu = 'Ibu';

  /// Exactly two canonical options permitted for selection.
  static const List<String> canonicalOptions = [bapak, ibu];

  /// Normalizes any raw honorific string according to strict TetangGo rules:
  /// - Rule A: Maps Mba, Mbak, Mama, Mamah (case-insensitive, trimmed) to 'Ibu'.
  /// - Rule B: Maps all other values (Pak, Bp, Mas, Kak, empty, null, unknown) to 'Bapak'.
  static String normalize(String? raw) {
    if (raw == null) return bapak;
    final trimmed = raw.trim().toUpperCase();
    switch (trimmed) {
      case 'IBU':
      case 'MBA':
      case 'MBAK':
      case 'MAMA':
      case 'MAMAH':
        return ibu;
      default:
        return bapak;
    }
  }

  /// Formats the display name with standardized honorific: "<Honorific> <Name>".
  /// Ensures 'Pak' or legacy honorifics never appear in the UI.
  static String formatDisplayName(String? salutation, String name) {
    final s = normalize(salutation);
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return s;
    return '$s $trimmedName';
  }
}
