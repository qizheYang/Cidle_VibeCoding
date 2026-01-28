import 'pinyin_utils.dart';
import 'dictionary_service.dart';

enum MatchStatus {
  correct, // Green - exact match in position
  present, // Yellow - exists but wrong position
  absent, // Gray - not in the word
}

class SyllableMatch {
  final PinyinSyllable syllable;
  final MatchStatus initialStatus;
  final MatchStatus finalStatus;
  final MatchStatus characterStatus; // Character-level match status
  final String character;

  SyllableMatch({
    required this.syllable,
    required this.initialStatus,
    required this.finalStatus,
    required this.characterStatus,
    required this.character,
  });

  /// Check if this is a 多音字 case: character matches but pinyin differs
  bool get isPolyphonicMismatch =>
      characterStatus == MatchStatus.present &&
      (initialStatus != MatchStatus.correct ||
          finalStatus != MatchStatus.correct);
}

class GuessResult {
  final ChineseWord guessedWord;
  final List<SyllableMatch> matches;
  final bool isCorrect;

  GuessResult({
    required this.guessedWord,
    required this.matches,
    required this.isCorrect,
  });
}

class GameState {
  final ChineseWord targetWord;
  final List<GuessResult> guesses = [];
  final int maxGuesses;
  bool _isGameOver = false;
  bool _isWon = false;

  GameState({required this.targetWord, this.maxGuesses = 6});

  factory GameState.random({int wordLength = 2, int maxGuesses = 6}) {
    final word = DictionaryService().getRandomWord(length: wordLength);
    return GameState(targetWord: word, maxGuesses: maxGuesses);
  }

  bool get isGameOver => _isGameOver;
  bool get isWon => _isWon;
  int get remainingGuesses => maxGuesses - guesses.length;
  int get wordLength => targetWord.length;

  GuessResult? submitGuess(ChineseWord guess) {
    if (_isGameOver) return null;
    if (guess.length != targetWord.length) return null;

    final targetSyllables = targetWord.syllables;
    final guessSyllables = guess.syllables;

    // Track which target components have been matched
    final unmatchedTargetInitials = <int, String>{};
    final unmatchedTargetFinals = <int, String>{};
    final unmatchedTargetChars = <int, String>{};

    for (int i = 0; i < targetSyllables.length; i++) {
      unmatchedTargetInitials[i] = targetSyllables[i].initial.toUpperCase();
      unmatchedTargetFinals[i] = targetSyllables[i].finalPart.toUpperCase();
      unmatchedTargetChars[i] = targetWord.characters[i];
    }

    final initialStatuses = List<MatchStatus?>.filled(guess.length, null);
    final finalStatuses = List<MatchStatus?>.filled(guess.length, null);
    final charStatuses = List<MatchStatus?>.filled(guess.length, null);

    // First pass: find exact matches (green)
    for (int i = 0; i < guessSyllables.length; i++) {
      final guessInitial = guessSyllables[i].initial.toUpperCase();
      final guessFinal = guessSyllables[i].finalPart.toUpperCase();
      final guessChar = guess.characters[i];
      final targetInitial = targetSyllables[i].initial.toUpperCase();
      final targetFinal = targetSyllables[i].finalPart.toUpperCase();
      final targetChar = targetWord.characters[i];

      // Check character - only green if BOTH character AND pinyin match
      if (guessChar == targetChar &&
          guessInitial == targetInitial &&
          guessFinal == targetFinal) {
        charStatuses[i] = MatchStatus.correct;
        unmatchedTargetChars.remove(i);
      }

      // Check initial
      if (guessInitial == targetInitial) {
        initialStatuses[i] = MatchStatus.correct;
        unmatchedTargetInitials.remove(i);
      }

      // Check final
      if (guessFinal == targetFinal) {
        finalStatuses[i] = MatchStatus.correct;
        unmatchedTargetFinals.remove(i);
      }
    }

    // Second pass: find present matches (yellow)
    for (int i = 0; i < guessSyllables.length; i++) {
      final guessInitial = guessSyllables[i].initial.toUpperCase();
      final guessFinal = guessSyllables[i].finalPart.toUpperCase();
      final guessChar = guess.characters[i];

      // Check character if not already exact match
      if (charStatuses[i] == null) {
        bool found = false;
        for (var entry in unmatchedTargetChars.entries) {
          if (entry.value == guessChar) {
            charStatuses[i] = MatchStatus.present;
            unmatchedTargetChars.remove(entry.key);
            found = true;
            break;
          }
        }
        if (!found) {
          // Also check if same char exists in target but with different pinyin (多音字)
          if (targetWord.characters.contains(guessChar)) {
            charStatuses[i] = MatchStatus.present;
          } else {
            charStatuses[i] = MatchStatus.absent;
          }
        }
      }

      // Check initial if not already matched
      if (initialStatuses[i] == null) {
        bool found = false;
        for (var entry in unmatchedTargetInitials.entries) {
          if (entry.value == guessInitial) {
            initialStatuses[i] = MatchStatus.present;
            unmatchedTargetInitials.remove(entry.key);
            found = true;
            break;
          }
        }
        if (!found) {
          initialStatuses[i] = MatchStatus.absent;
        }
      }

      // Check final if not already matched
      if (finalStatuses[i] == null) {
        bool found = false;
        for (var entry in unmatchedTargetFinals.entries) {
          if (entry.value == guessFinal) {
            finalStatuses[i] = MatchStatus.present;
            unmatchedTargetFinals.remove(entry.key);
            found = true;
            break;
          }
        }
        if (!found) {
          finalStatuses[i] = MatchStatus.absent;
        }
      }
    }

    // Build matches
    final matches = <SyllableMatch>[];
    for (int i = 0; i < guessSyllables.length; i++) {
      matches.add(SyllableMatch(
        syllable: guessSyllables[i],
        initialStatus: initialStatuses[i]!,
        finalStatus: finalStatuses[i]!,
        characterStatus: charStatuses[i]!,
        character: guess.characters[i],
      ));
    }

    // Win only if all characters AND pinyins match exactly
    final isCorrect = matches.every(
      (m) =>
          m.characterStatus == MatchStatus.correct &&
          m.initialStatus == MatchStatus.correct &&
          m.finalStatus == MatchStatus.correct,
    );

    final result = GuessResult(
      guessedWord: guess,
      matches: matches,
      isCorrect: isCorrect,
    );

    guesses.add(result);

    if (isCorrect) {
      _isWon = true;
      _isGameOver = true;
    } else if (guesses.length >= maxGuesses) {
      _isGameOver = true;
    }

    return result;
  }
}
