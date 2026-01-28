import 'package:flutter/material.dart';
import 'game_state.dart';
import 'dictionary_service.dart';
import 'pinyin_utils.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameState? _gameState;
  final DictionaryService _dictService = DictionaryService();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _currentInput = '';
  List<String>? _currentPinyin;
  bool _isLoading = false;
  bool _isLoadingWord = true;
  String? _errorMessage;
  int _selectedWordLength = 2;
  List<String>? _allHints;
  int _hintsToShow = 0;
  bool _isLoadingHints = false;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _startNewGame() async {
    setState(() {
      _isLoadingWord = true;
      _currentInput = '';
      _currentPinyin = null;
      _isLoading = false;
      _errorMessage = null;
      _allHints = null;
      _hintsToShow = 0;
      _isLoadingHints = false;
      _inputController.clear();
    });

    final word = await _dictService.fetchRandomWord(length: _selectedWordLength);

    setState(() {
      _gameState = GameState(targetWord: word!, maxGuesses: 6);
      _isLoadingWord = false;
    });

    _fetchAllHints();
    _focusNode.requestFocus();
  }

  Future<void> _fetchAllHints() async {
    if (_gameState == null) return;

    setState(() => _isLoadingHints = true);

    final isIdiom = _gameState!.wordLength == 4;
    final hints = await _dictService.getAllHints(
      _gameState!.targetWord.characters,
      isIdiom: isIdiom,
    );

    if (hints != null && mounted) {
      setState(() {
        _allHints = hints;
        _hintsToShow = 0;
        _isLoadingHints = false;
      });
    } else {
      setState(() => _isLoadingHints = false);
    }
  }

  void _showNextHint() {
    if (_allHints != null && _hintsToShow < _allHints!.length) {
      setState(() => _hintsToShow++);
    }
  }

  int get _targetPinyinLetterCount {
    if (_gameState == null) return 0;
    return _dictService.getPinyinLetterCount(_gameState!.targetWord.pinyinList);
  }

  Map<String, MatchStatus> get _initialStatusMap {
    final map = <String, MatchStatus>{};
    if (_gameState == null) return map;

    for (var guess in _gameState!.guesses) {
      for (var match in guess.matches) {
        final initial = match.syllable.initial.toUpperCase();
        if (initial.isEmpty) continue;
        final current = map[initial];
        if (match.initialStatus == MatchStatus.correct) {
          map[initial] = MatchStatus.correct;
        } else if (match.initialStatus == MatchStatus.present && current != MatchStatus.correct) {
          map[initial] = MatchStatus.present;
        } else if (current == null) {
          map[initial] = match.initialStatus;
        }
      }
    }
    return map;
  }

  Map<String, MatchStatus> get _finalStatusMap {
    final map = <String, MatchStatus>{};
    if (_gameState == null) return map;

    for (var guess in _gameState!.guesses) {
      for (var match in guess.matches) {
        final finalPart = match.syllable.finalPart.toUpperCase();
        if (finalPart.isEmpty) continue;
        final current = map[finalPart];
        if (match.finalStatus == MatchStatus.correct) {
          map[finalPart] = MatchStatus.correct;
        } else if (match.finalStatus == MatchStatus.present && current != MatchStatus.correct) {
          map[finalPart] = MatchStatus.present;
        } else if (current == null) {
          map[finalPart] = match.finalStatus;
        }
      }
    }
    return map;
  }

  void _changeWordLength(int length) {
    setState(() => _selectedWordLength = length);
    _startNewGame();
  }

  Future<void> _onInputChanged(String value) async {
    if (_gameState == null) return;

    final chineseOnly = value.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
    final limited = chineseOnly.length > _gameState!.wordLength
        ? chineseOnly.substring(0, _gameState!.wordLength)
        : chineseOnly;

    if (limited != _currentInput) {
      setState(() {
        _currentInput = limited;
        _currentPinyin = null;
        _errorMessage = null;
      });

      if (limited.length == _gameState!.wordLength) {
        setState(() => _isLoading = true);
        final pinyin = await _dictService.lookupPinyin(limited);
        setState(() {
          _isLoading = false;
          if (pinyin != null) {
            _currentPinyin = pinyin;
          } else {
            _errorMessage = '无法获取拼音';
          }
        });
      }
    }
  }

  void _showPinyinOptionsDialog(int charIndex) {
    if (_currentInput.length <= charIndex) return;

    final char = _currentInput[charIndex];
    final options = _dictService.getPinyinOptions(char);

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$char 不是多音字'), duration: const Duration(seconds: 1)),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a1b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('选择「$char」的读音', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: options.map((pinyin) {
                final syllable = PinyinUtils.separate(pinyin);
                final isSelected = _currentPinyin != null && _currentPinyin![charIndex] == pinyin;
                return GestureDetector(
                  onTap: () {
                    if (_currentPinyin != null) {
                      setState(() {
                        _currentPinyin = List.from(_currentPinyin!);
                        _currentPinyin![charIndex] = pinyin;
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF538d4e) : const Color(0xFF3a3a3c),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${syllable.displayInitial}/${syllable.displayFinal}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _onSubmit() async {
    if (_gameState == null || _gameState!.isGameOver) return;

    if (_currentInput.length != _gameState!.wordLength) {
      setState(() => _errorMessage = '请输入${_gameState!.wordLength}个汉字');
      return;
    }

    if (_currentPinyin == null) {
      setState(() => _isLoading = true);
      final pinyin = await _dictService.lookupPinyin(_currentInput);
      setState(() => _isLoading = false);
      if (pinyin == null) {
        setState(() => _errorMessage = '无法获取拼音');
        return;
      }
      _currentPinyin = pinyin;
    }

    final word = ChineseWord(_currentInput, _currentPinyin!);
    final result = _gameState!.submitGuess(word);

    if (result != null) {
      setState(() {
        _currentInput = '';
        _currentPinyin = null;
        _errorMessage = null;
        _inputController.clear();
      });

      final guessCount = _gameState!.guesses.length;
      if (guessCount == 2 && _hintsToShow < 1) {
        _showNextHint();
      } else if (guessCount == 4 && _hintsToShow < 2) {
        _showNextHint();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121213),
      body: SafeArea(
        child: _isLoadingWord || _gameState == null
            ? _buildLoading()
            : Column(
                children: [
                  _buildHeader(),
                  _buildInfoBar(),
                  Expanded(child: _buildGameArea()),
                  if (_gameState!.isGameOver) _buildGameOverBanner(),
                  if (!_gameState!.isGameOver) _buildInputSection(),
                  _buildKeyboard(),
                ],
              ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          SizedBox(height: 16),
          Text('加载中...', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white54, size: 22),
            onPressed: _showHelpDialog,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const Expanded(
            child: Text(
              '汉字 Wordle',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 22),
            onPressed: _startNewGame,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    final canRequestHint = _gameState != null &&
        _gameState!.remainingGuesses == 1 &&
        _allHints != null &&
        _hintsToShow < 3 &&
        !_gameState!.isGameOver;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          // Top row: word length + pinyin count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Word length chips
              ..._dictService.getAvailableWordLengths().map((len) {
                final selected = _selectedWordLength == len;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => _changeWordLength(len),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF538d4e) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: selected ? const Color(0xFF538d4e) : Colors.grey[700]!),
                      ),
                      child: Text(
                        len == 4 ? '成语' : '$len字',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 16),
              // Pinyin letter count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2d4a7c),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$_targetPinyinLetterCount 字母',
                  style: const TextStyle(color: Color(0xFF8bb4f0), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          // Hints section
          if (_allHints != null && _hintsToShow > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2a2a2a),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < _hintsToShow && i < _allHints!.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i < _hintsToShow - 1 ? 4 : 0),
                      child: Text(
                        '${i + 1}. ${_allHints![i]}',
                        style: TextStyle(color: Colors.orange[300], fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (canRequestHint) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showNextHint,
              child: Text('点击获取最后提示', style: TextStyle(color: Colors.orange[400], fontSize: 11, decoration: TextDecoration.underline)),
            ),
          ],
          if (_isLoadingHints) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.orange[300])),
                const SizedBox(width: 6),
                Text('加载提示...', style: TextStyle(color: Colors.orange[300], fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth > 500 ? 400.0 : screenWidth - 32;
    final tileSize = (maxWidth - (_gameState!.wordLength - 1) * 6) / _gameState!.wordLength;
    final clampedSize = tileSize.clamp(50.0, 100.0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous guesses
            for (var guess in _gameState!.guesses)
              _buildGuessRow(guess, clampedSize),
            // Current input
            if (!_gameState!.isGameOver)
              _buildCurrentRow(clampedSize),
            // Empty rows
            for (int i = 0; i < (_gameState!.remainingGuesses - 1).clamp(0, 5); i++)
              _buildEmptyRow(clampedSize),
          ],
        ),
      ),
    );
  }

  Widget _buildGuessRow(GuessResult guess, double size) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var match in guess.matches)
            _buildTile(
              match.character,
              match.syllable,
              match.characterStatus,
              match.initialStatus,
              match.finalStatus,
              size,
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentRow(double size) {
    final chars = _currentInput.split('');
    final syllables = _currentPinyin?.map((p) => PinyinUtils.separate(p)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _gameState!.wordLength; i++)
            _buildInputTile(
              i < chars.length ? chars[i] : '',
              syllables != null && i < syllables.length ? syllables[i] : null,
              i,
              size,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyRow(double size) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _gameState!.wordLength; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: size,
              height: size * 1.4,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF3a3a3c), width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTile(String char, PinyinSyllable syllable, MatchStatus charStatus, MatchStatus initialStatus, MatchStatus finalStatus, double size) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: size,
      height: size * 1.4,
      child: Column(
        children: [
          // Pinyin section (top 40%)
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getColor(initialStatus),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(4)),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Text(
                          syllable.displayInitial.isEmpty ? '∅' : syllable.displayInitial,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: syllable.displayInitial.isEmpty ? 0.5 : 1),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, color: Colors.black26),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getColor(finalStatus),
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(4)),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Text(
                          syllable.displayFinal,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Character section (bottom 60%)
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                color: _getColor(charStatus),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                char,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputTile(String char, PinyinSyllable? syllable, int index, double size) {
    final isPolyphonic = char.isNotEmpty && _dictService.isPolyphonic(char);

    return GestureDetector(
      onTap: isPolyphonic && syllable != null ? () => _showPinyinOptionsDialog(index) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: size,
        height: size * 1.4,
        decoration: BoxDecoration(
          border: Border.all(
            color: char.isNotEmpty ? (isPolyphonic ? Colors.orange : const Color(0xFF565758)) : const Color(0xFF3a3a3c),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            // Pinyin section
            Expanded(
              flex: 4,
              child: syllable != null
                  ? Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(right: BorderSide(color: Color(0xFF3a3a3c))),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                syllable.displayInitial.isEmpty ? '∅' : syllable.displayInitial,
                                style: TextStyle(color: Colors.white.withValues(alpha: syllable.displayInitial.isEmpty ? 0.5 : 1), fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(syllable.displayFinal, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: _isLoading && index < _currentInput.length
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38))
                          : Text('声/韵', style: TextStyle(color: Colors.grey[700], fontSize: 9)),
                    ),
            ),
            // Character section
            Expanded(
              flex: 6,
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF3a3a3c))),
                ),
                alignment: Alignment.center,
                child: char.isNotEmpty
                    ? Text(char, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.35))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFf44336), fontSize: 12)),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _focusNode,
                  onChanged: _onInputChanged,
                  onSubmitted: (_) => _onSubmit(),
                  style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '输入汉字',
                    hintStyle: TextStyle(color: Colors.grey[700], fontSize: 16, letterSpacing: 2),
                    filled: true,
                    fillColor: const Color(0xFF2a2a2a),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF538d4e),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('确定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboard() {
    final initialStatus = _initialStatusMap;
    final finalStatus = _finalStatusMap;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        border: Border(top: BorderSide(color: Colors.grey[850]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Consonants (声母)
          Expanded(
            flex: 5,
            child: _buildKeyboardPanel('声母', [
              ['B', 'P', 'M', 'F'],
              ['D', 'T', 'N', 'L'],
              ['G', 'K', 'H'],
              ['J', 'Q', 'X'],
              ['ZH', 'CH', 'SH', 'R'],
              ['Z', 'C', 'S'],
              ['Y', 'W'],
            ], initialStatus, isVowel: false),
          ),
          Container(
            width: 1,
            height: 140,
            color: Colors.grey[800],
            margin: const EdgeInsets.symmetric(horizontal: 6),
          ),
          // Right: Vowels (韵母)
          Expanded(
            flex: 6,
            child: _buildKeyboardPanel('韵母', [
              ['A', 'O', 'E', 'I', 'U', 'Ü'],
              ['AI', 'EI', 'AO', 'OU'],
              ['AN', 'EN', 'ANG', 'ENG', 'ER'],
              ['IA', 'IE', 'IU', 'IN', 'ING'],
              ['UA', 'UO', 'UI', 'UN', 'ONG'],
              ['IAO', 'IAN', 'UAN', 'UEN'],
              ['IANG', 'IONG', 'UANG'],
            ], finalStatus, isVowel: true),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardPanel(String label, List<List<String>> rows, Map<String, MatchStatus> statusMap, {required bool isVowel}) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        for (var row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var key in row)
                  _buildKey(key, statusMap[isVowel ? key.replaceAll('Ü', 'V') : key]),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildKey(String key, MatchStatus? status) {
    Color bg;
    Color fg = Colors.white;

    if (status == null) {
      bg = const Color(0xFF818384);
    } else {
      switch (status) {
        case MatchStatus.correct:
          bg = const Color(0xFF538d4e);
        case MatchStatus.present:
          bg = const Color(0xFFb59f3b);
        case MatchStatus.absent:
          bg = const Color(0xFF3a3a3c);
          fg = Colors.white54;
      }
    }

    final width = key.length > 2 ? 32.0 : (key.length > 1 ? 26.0 : 22.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      width: width,
      height: 28,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.center,
      child: Text(
        key,
        style: TextStyle(color: fg, fontSize: key.length > 2 ? 8 : (key.length > 1 ? 9 : 10), fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildGameOverBanner() {
    final won = _gameState!.isWon;
    final target = _gameState!.targetWord;
    final syllables = target.syllables;

    return Container(
      padding: const EdgeInsets.all(20),
      color: won ? const Color(0xFF538d4e) : const Color(0xFFc9413b),
      child: Column(
        children: [
          Text(won ? '太棒了!' : '再接再厉', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${target.characters}  (${syllables.map((s) => '${s.displayInitial}/${s.displayFinal}').join(' ')})',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _startNewGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: won ? const Color(0xFF538d4e) : const Color(0xFFc9413b),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('再来一局', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('游戏规则', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('猜出目标词语，每次猜测后会显示颜色提示。', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              _buildHelpRow(const Color(0xFF538d4e), '绿色 = 正确位置'),
              _buildHelpRow(const Color(0xFFb59f3b), '黄色 = 存在但位置错'),
              _buildHelpRow(const Color(0xFF3a3a3c), '灰色 = 不存在'),
              const SizedBox(height: 16),
              const Text('每个格子分为上下两部分：\n上方：拼音（声母/韵母）\n下方：汉字', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              Text('多音字会以橙色边框标记，点击可选择读音。', style: TextStyle(color: Colors.orange[300], fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了', style: TextStyle(color: Color(0xFF538d4e))),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpRow(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 20, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Color _getColor(MatchStatus status) {
    switch (status) {
      case MatchStatus.correct:
        return const Color(0xFF538d4e);
      case MatchStatus.present:
        return const Color(0xFFb59f3b);
      case MatchStatus.absent:
        return const Color(0xFF3a3a3c);
    }
  }
}
