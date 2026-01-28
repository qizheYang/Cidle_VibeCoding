# Cidle - Chinese Wordle

A Chinese word guessing game inspired by Wordle, built with Flutter.

## Features

- **Pinyin-based matching**: Each tile shows both the Chinese character and its pinyin, split into initial (声母) and final (韵母)
- **Color-coded feedback**:
  - Green: Correct position
  - Yellow: Present but wrong position
  - Gray: Not in the word
- **Word types**: 2-character words and 4-character idioms (成语)
- **Polyphonic character support**: Tap characters with orange borders to select alternate pronunciations (多音字)
- **Progressive hints**: AI-generated hints that become more specific as you guess
- **Pinyin letter count**: Shows total pinyin letters as an additional hint

## How to Play

1. Enter Chinese characters to guess the hidden word
2. Each guess shows color feedback for both characters and pinyin components
3. Use the keyboard display to track which initials/finals have been used
4. Hints appear after 2 guesses, 4 guesses, and on request before the last guess

## Running Locally

```bash
# Run in debug mode
flutter run

# Build for web
flutter build web --release

# Serve locally
cd build/web && npx http-server -p 8080
```

## Public Hosting

The game can be hosted publicly using ngrok:

```bash
ngrok http 8080
```

## Tech Stack

- Flutter (Web)
- OpenAI API for pinyin lookup and hint generation
- Dart

## License

MIT
