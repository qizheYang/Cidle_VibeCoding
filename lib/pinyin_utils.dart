class PinyinSyllable {
  final String initial; // Consonant part (声母)
  final String finalPart; // Vowel part (韵母)

  const PinyinSyllable(this.initial, this.finalPart);

  /// Get the display version of the final part with proper ü character
  /// - V becomes Ü (e.g., LV -> LÜ, NV -> NÜ)
  /// - Y + U final displays U as Ü (e.g., YU -> YÜ)
  /// - J/Q/X + U final displays U as Ü (e.g., JU -> JÜ, QU -> QÜ, XU -> XÜ)
  String get displayFinal {
    String result = finalPart.toUpperCase();

    // Replace V with Ü
    result = result.replaceAll('V', 'Ü');

    // For Y, J, Q, X initials, U is actually Ü
    final upperInitial = initial.toUpperCase();
    if (['Y', 'J', 'Q', 'X'].contains(upperInitial)) {
      // U after these initials is ü, but UAN, UAI etc. are not
      // Only single U or U in UE, UN patterns
      if (result == 'U' || result == 'UE' || result == 'UN' || result == 'UAN') {
        if (result == 'U') {
          result = 'Ü';
        } else if (result == 'UE') {
          result = 'ÜE';
        } else if (result == 'UN') {
          result = 'ÜN';
        } else if (result == 'UAN') {
          result = 'ÜAN';
        }
      }
    }

    return result;
  }

  /// Get the display version of the initial
  String get displayInitial => initial.toUpperCase();

  @override
  String toString() => '$initial/$finalPart';

  @override
  bool operator ==(Object other) =>
      other is PinyinSyllable &&
      initial.toUpperCase() == other.initial.toUpperCase() &&
      finalPart.toUpperCase() == other.finalPart.toUpperCase();

  @override
  int get hashCode =>
      initial.toUpperCase().hashCode ^ finalPart.toUpperCase().hashCode;
}

class PinyinUtils {
  // All possible initials (声母) in pinyin
  static const List<String> initials = [
    'ZH',
    'CH',
    'SH', // These must come first (longer matches)
    'B',
    'P',
    'M',
    'F',
    'D',
    'T',
    'N',
    'L',
    'G',
    'K',
    'H',
    'J',
    'Q',
    'X',
    'R',
    'Z',
    'C',
    'S',
    'Y',
    'W',
  ];

  // All possible finals (韵母) in pinyin
  static const List<String> finals = [
    'IANG',
    'IONG',
    'UANG',
    'UENG',
    'ANG',
    'ENG',
    'ING',
    'ONG',
    'UNG',
    'IAO',
    'IAN',
    'UAN',
    'UEN',
    'UEI',
    'UAI',
    'IOU',
    'AI',
    'EI',
    'AO',
    'OU',
    'AN',
    'EN',
    'IN',
    'UN',
    'IA',
    'IE',
    'IU',
    'IO',
    'UA',
    'UO',
    'UE',
    'UI',
    'VE',
    'ER',
    'A',
    'O',
    'E',
    'I',
    'U',
    'V',
  ];

  /// Separates a pinyin syllable into initial and final
  /// e.g., "CI" -> PinyinSyllable("C", "I")
  /// e.g., "HUI" -> PinyinSyllable("H", "UI")
  /// e.g., "AN" -> PinyinSyllable("", "AN") (no initial)
  static PinyinSyllable separate(String pinyin) {
    String upper = pinyin.toUpperCase().trim();

    // Handle special case where pinyin has no initial (零声母)
    // Words starting with a, o, e, i, u, ü
    String foundInitial = '';

    // Try to match the longest initial first
    for (String initial in initials) {
      if (upper.startsWith(initial)) {
        foundInitial = initial;
        break;
      }
    }

    String remaining = upper.substring(foundInitial.length);

    // The remaining part is the final
    return PinyinSyllable(foundInitial, remaining);
  }

  /// Combines an initial and final back into pinyin
  static String combine(String initial, String finalPart) {
    return '$initial$finalPart'.toLowerCase();
  }
}
