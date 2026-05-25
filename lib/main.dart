import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const DontTapBlueApp());
}

class DontTapBlueApp extends StatelessWidget {
  const DontTapBlueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Don't Tap Blue",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B4A),
          brightness: Brightness.dark,
        ),
        fontFamily: 'System',
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

enum GamePhase { ready, playing, gameOver }

enum TileKind { quiet, safe, trap, decoy }

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  static const int _boardSize = 4;
  static const int _tileCount = _boardSize * _boardSize;
  static const String _bestScoreKey = 'best_score';

  final Random _random = Random();

  GamePhase _phase = GamePhase.ready;
  Timer? _tickTimer;
  DateTime? _roundStartedAt;
  Duration _activeRoundDuration = const Duration(milliseconds: 1500);

  int _score = 0;
  int _bestScore = 0;
  int _streak = 0;
  int _maxStreak = 0;
  int _safeIndex = 0;
  double _timeLeft = 1;
  String _gameOverTitle = 'Blue got you';
  String _lastResult = 'Hit start. Tap orange. Never tap blue.';
  int _shakeTick = 0;
  int _safePulseTick = 0;
  int _flashTick = 0;
  Color _flashColor = Colors.transparent;

  final Set<int> _trapIndexes = <int>{};
  final Set<int> _decoyIndexes = <int>{};

  int get _level => 1 + (_score ~/ 6);

  int get _trapCount => (1 + (_score ~/ 8)).clamp(1, 3);

  int get _decoyCount {
    if (_score < 4) {
      return 0;
    }
    return (1 + ((_score - 4) ~/ 8)).clamp(1, 3);
  }

  @override
  void initState() {
    super.initState();
    _rollBoard();
    _loadBestScore();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _tickTimer?.cancel();
    setState(() {
      _phase = GamePhase.playing;
      _score = 0;
      _streak = 0;
      _maxStreak = 0;
      _timeLeft = 1;
      _gameOverTitle = 'Blue got you';
      _lastResult = 'Stay warm. Dodge blue.';
      _rollBoard();
    });
    HapticFeedback.mediumImpact();
    _startRoundClock();
  }

  void _handleTileTap(int index) {
    if (_phase != GamePhase.playing) {
      return;
    }

    if (_trapIndexes.contains(index)) {
      _endGame('Blue got you');
      return;
    }

    if (index == _safeIndex) {
      _scoreHit();
      return;
    }

    _miss(index);
  }

  void _scoreHit() {
    HapticFeedback.selectionClick();
    _triggerSuccessFeedback();
    setState(() {
      final int nextStreak = _streak + 1;
      final int bonus = nextStreak % 5 == 0 ? max(1, nextStreak ~/ 5) : 0;

      _streak = nextStreak;
      _maxStreak = max(_maxStreak, _streak);
      _score += 1 + bonus;
      _setBestScore(max(_bestScore, _score));
      _lastResult = bonus > 0 ? 'Combo +$bonus' : 'Good tap';
      _rollBoard();
    });
    _startRoundClock();
  }

  void _miss(int index) {
    HapticFeedback.lightImpact();
    _triggerMistakeFeedback();
    setState(() {
      _score = max(0, _score - 1);
      _streak = 0;
      _lastResult = _decoyIndexes.contains(index)
          ? 'Decoy. Combo broken.'
          : 'Cold tile. Combo broken.';
      _rollBoard();
    });
    _startRoundClock();
  }

  void _endGame(String title) {
    _tickTimer?.cancel();
    HapticFeedback.heavyImpact();
    _triggerMistakeFeedback();
    setState(() {
      _phase = GamePhase.gameOver;
      _gameOverTitle = title;
      _setBestScore(max(_bestScore, _score));
      _timeLeft = 0;
    });
  }

  Future<void> _loadBestScore() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _bestScore = preferences.getInt(_bestScoreKey) ?? 0;
    });
  }

  void _setBestScore(int value) {
    if (value <= _bestScore) {
      return;
    }
    _bestScore = value;
    SharedPreferences.getInstance().then((SharedPreferences preferences) {
      preferences.setInt(_bestScoreKey, value);
    });
  }

  void _triggerSuccessFeedback() {
    setState(() {
      _safePulseTick += 1;
      _flashTick += 1;
      _flashColor = const Color(0xFFFFB35C);
    });
  }

  void _triggerMistakeFeedback() {
    setState(() {
      _shakeTick += 1;
      _flashTick += 1;
      _flashColor = const Color(0xFFFF3158);
    });
  }

  void _startRoundClock() {
    _tickTimer?.cancel();
    _activeRoundDuration = _roundDuration;
    _roundStartedAt = DateTime.now();
    _timeLeft = 1;
    _tickTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _phase != GamePhase.playing || _roundStartedAt == null) {
        return;
      }

      final int elapsed = DateTime.now()
          .difference(_roundStartedAt!)
          .inMilliseconds;
      final double remaining =
          1 - (elapsed / _activeRoundDuration.inMilliseconds);

      if (remaining <= 0) {
        _endGame('Too slow');
        return;
      }

      setState(() {
        _timeLeft = remaining.clamp(0, 1);
      });
    });
  }

  Duration get _roundDuration {
    final int milliseconds = 1550 - (_score * 26) - (_streak * 9);
    return Duration(milliseconds: milliseconds.clamp(520, 1550));
  }

  void _rollBoard() {
    final Set<int> used = <int>{};

    _safeIndex = _random.nextInt(_tileCount);
    used.add(_safeIndex);

    _trapIndexes
      ..clear()
      ..addAll(_pickIndexes(_trapCount, used));
    used.addAll(_trapIndexes);

    _decoyIndexes
      ..clear()
      ..addAll(_pickIndexes(_decoyCount, used));
  }

  Set<int> _pickIndexes(int count, Set<int> blocked) {
    final Set<int> result = <int>{};
    while (result.length < count &&
        result.length + blocked.length < _tileCount) {
      final int index = _random.nextInt(_tileCount);
      if (!blocked.contains(index)) {
        result.add(index);
      }
    }
    return result;
  }

  TileKind _tileKindFor(int index) {
    if (index == _safeIndex) {
      return TileKind.safe;
    }
    if (_trapIndexes.contains(index)) {
      return TileKind.trap;
    }
    if (_decoyIndexes.contains(index)) {
      return TileKind.decoy;
    }
    return TileKind.quiet;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact =
            constraints.maxHeight < 760 || constraints.maxWidth < 430;
        final EdgeInsets pagePadding = EdgeInsets.fromLTRB(
          isCompact ? 12 : 16,
          isCompact ? 10 : 16,
          isCompact ? 12 : 16,
          isCompact ? 12 : 20,
        );
        final double sectionGap = isCompact ? 8 : 14;

        return Scaffold(
          backgroundColor: const Color(0xFF121318),
          body: _FeedbackFrame(
            shakeTick: _shakeTick,
            flashTick: _flashTick,
            flashColor: _flashColor,
            child: SafeArea(
              child: Padding(
                padding: pagePadding,
                child: Column(
                  children: [
                    _ScoreHeader(
                      score: _score,
                      bestScore: _bestScore,
                      streak: _streak,
                      level: _level,
                      isCompact: isCompact,
                    ),
                    SizedBox(height: sectionGap),
                    _PressureBar(
                      phase: _phase,
                      value: _timeLeft,
                      duration: _activeRoundDuration,
                      isCompact: isCompact,
                    ),
                    SizedBox(height: isCompact ? 10 : 16),
                    Expanded(
                      child: _GameStage(
                        boardSize: _boardSize,
                        phase: _phase,
                        score: _score,
                        bestScore: _bestScore,
                        streak: _streak,
                        maxStreak: _maxStreak,
                        level: _level,
                        gameOverTitle: _gameOverTitle,
                        lastResult: _lastResult,
                        safePulseTick: _safePulseTick,
                        tileKindFor: _tileKindFor,
                        onTileTap: _handleTileTap,
                        isCompact: isCompact,
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    _PrimaryAction(
                      phase: _phase,
                      onPressed: _startGame,
                      isCompact: isCompact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeedbackFrame extends StatelessWidget {
  const _FeedbackFrame({
    required this.shakeTick,
    required this.flashTick,
    required this.flashColor,
    required this.child,
  });

  final int shakeTick;
  final int flashTick;
  final Color flashColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey('shake-$shakeTick'),
          tween: Tween<double>(begin: shakeTick == 0 ? 0 : 1, end: 0),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            final double offset = sin(value * pi * 8) * 10 * value;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: ValueKey('flash-$flashTick'),
              tween: Tween<double>(begin: flashTick == 0 ? 0 : 0.24, end: 0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return ColoredBox(color: flashColor.withValues(alpha: value));
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _GameStage extends StatelessWidget {
  const _GameStage({
    required this.boardSize,
    required this.phase,
    required this.score,
    required this.bestScore,
    required this.streak,
    required this.maxStreak,
    required this.level,
    required this.gameOverTitle,
    required this.lastResult,
    required this.safePulseTick,
    required this.tileKindFor,
    required this.onTileTap,
    required this.isCompact,
  });

  final int boardSize;
  final GamePhase phase;
  final int score;
  final int bestScore;
  final int streak;
  final int maxStreak;
  final int level;
  final String gameOverTitle;
  final String lastResult;
  final int safePulseTick;
  final TileKind Function(int index) tileKindFor;
  final ValueChanged<int> onTileTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool hasResult = phase == GamePhase.gameOver;
        final double promptEstimate = isCompact ? 78 : 112;
        final double resultEstimate = hasResult ? (isCompact ? 128 : 176) : 0;
        final double verticalGaps = hasResult
            ? (isCompact ? 16 : 32)
            : (isCompact ? 8 : 16);
        final double availableBoardHeight =
            constraints.maxHeight -
            promptEstimate -
            resultEstimate -
            verticalGaps;
        final double boardExtent = min(
          min(constraints.maxWidth, 460),
          max(220, availableBoardHeight),
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PromptPanel(
                  phase: phase,
                  score: score,
                  streak: streak,
                  gameOverTitle: gameOverTitle,
                  lastResult: lastResult,
                  isCompact: isCompact,
                ),
                SizedBox(height: isCompact ? 8 : 16),
                if (hasResult) ...[
                  _ResultCard(
                    score: score,
                    bestScore: bestScore,
                    maxCombo: maxStreak,
                    level: level,
                    cause: gameOverTitle,
                    isCompact: isCompact,
                  ),
                  SizedBox(height: isCompact ? 8 : 16),
                ],
                SizedBox.square(
                  dimension: boardExtent,
                  child: _TargetGrid(
                    boardSize: boardSize,
                    phase: phase,
                    safePulseTick: safePulseTick,
                    tileKindFor: tileKindFor,
                    onTileTap: onTileTap,
                    isCompact: isCompact,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.score,
    required this.bestScore,
    required this.streak,
    required this.level,
    required this.isCompact,
  });

  final int score;
  final int bestScore;
  final int streak;
  final int level;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScorePill(
            label: 'Score',
            value: score,
            icon: Icons.bolt_rounded,
            color: const Color(0xFFFFD166),
            isCompact: isCompact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScorePill(
            label: 'Best',
            value: bestScore,
            icon: Icons.workspace_premium_rounded,
            color: const Color(0xFF7BD389),
            isCompact: isCompact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScorePill(
            label: 'Combo',
            value: streak,
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFFF8A5B),
            isCompact: isCompact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ScorePill(
            label: 'Level',
            value: level,
            icon: Icons.speed_rounded,
            color: const Color(0xFF65D6CE),
            isCompact: isCompact,
          ),
        ),
      ],
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isCompact,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF202228),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 10,
          vertical: isCompact ? 8 : 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: isCompact ? 18 : 20),
            SizedBox(height: isCompact ? 6 : 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$value',
              key: ValueKey('score-pill-$label'),
              style:
                  (isCompact
                          ? Theme.of(context).textTheme.titleLarge
                          : Theme.of(context).textTheme.headlineSmall)
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressureBar extends StatelessWidget {
  const _PressureBar({
    required this.phase,
    required this.value,
    required this.duration,
    required this.isCompact,
  });

  final GamePhase phase;
  final double value;
  final Duration duration;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final bool isPlaying = phase == GamePhase.playing;
    final Color barColor = value < 0.28
        ? const Color(0xFFFF4D6D)
        : const Color(0xFFFFB35C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.timer_rounded, color: barColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isPlaying
                    ? '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s window'
                    : 'Reaction window',
                style:
                    (isCompact
                            ? Theme.of(context).textTheme.labelMedium
                            : Theme.of(context).textTheme.labelLarge)
                        ?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w800,
                        ),
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 6 : 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            key: const ValueKey('pressure-bar'),
            value: isPlaying ? value : 1,
            minHeight: isCompact ? 8 : 10,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            color: isPlaying ? barColor : Colors.white.withValues(alpha: 0.28),
          ),
        ),
      ],
    );
  }
}

class _PromptPanel extends StatelessWidget {
  const _PromptPanel({
    required this.phase,
    required this.score,
    required this.streak,
    required this.gameOverTitle,
    required this.lastResult,
    required this.isCompact,
  });

  final GamePhase phase;
  final int score;
  final int streak;
  final String gameOverTitle;
  final String lastResult;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final String title = switch (phase) {
      GamePhase.ready => "Don't Tap Blue",
      GamePhase.playing => 'Find the warm tile',
      GamePhase.gameOver => gameOverTitle,
    };
    final String subtitle = switch (phase) {
      GamePhase.ready => 'Beat the timer. Decoys break combo. Blue ends it.',
      GamePhase.playing =>
        streak >= 5
            ? 'Combo $streak. Every fifth tap scores bonus.'
            : lastResult,
      GamePhase.gameOver => 'Score $score. Tap faster, trust less.',
    };

    return Semantics(
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style:
                (isCompact
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.headlineLarge)
                    ?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style:
                (isCompact
                        ? Theme.of(context).textTheme.bodyMedium
                        : Theme.of(context).textTheme.bodyLarge)
                    ?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.score,
    required this.bestScore,
    required this.maxCombo,
    required this.level,
    required this.cause,
    required this.isCompact,
  });

  final int score;
  final int bestScore;
  final int maxCombo;
  final int level;
  final String cause;
  final bool isCompact;

  String get _rank {
    if (score >= 80) {
      return 'S+';
    }
    if (score >= 55) {
      return 'S';
    }
    if (score >= 35) {
      return 'A';
    }
    if (score >= 20) {
      return 'B';
    }
    if (score >= 10) {
      return 'C';
    }
    return 'D';
  }

  Color get _rankColor {
    return switch (_rank) {
      'S+' => const Color(0xFFFFD166),
      'S' => const Color(0xFFFF8A5B),
      'A' => const Color(0xFF7BD389),
      'B' => const Color(0xFF65D6CE),
      'C' => const Color(0xFFB9A7FF),
      _ => const Color(0xFFFF6B6B),
    };
  }

  int? get _nextRankTarget {
    if (score < 10) {
      return 10;
    }
    if (score < 20) {
      return 20;
    }
    if (score < 35) {
      return 35;
    }
    if (score < 55) {
      return 55;
    }
    if (score < 80) {
      return 80;
    }
    return null;
  }

  String get _nextGoal {
    if (bestScore > score) {
      return '${bestScore - score} points to match your best';
    }

    final int? target = _nextRankTarget;
    if (target != null) {
      return '${target - score} points to rank up';
    }

    return 'Top rank. Chase a combo of 20.';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('result-card'),
      decoration: BoxDecoration(
        color: const Color(0xFF202228),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _rankColor.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(color: _rankColor.withValues(alpha: 0.14), blurRadius: 22),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _rankColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      _rank,
                      key: const ValueKey('result-rank'),
                      style:
                          (isCompact
                                  ? Theme.of(context).textTheme.titleLarge
                                  : Theme.of(context).textTheme.headlineMedium)
                              ?.copyWith(
                                color: _rankColor,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nextGoal,
                        style:
                            (isCompact
                                    ? Theme.of(context).textTheme.bodyMedium
                                    : Theme.of(context).textTheme.titleMedium)
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cause: $cause',
                        key: const ValueKey('result-cause'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.64),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isCompact ? 10 : 14),
            Row(
              children: [
                Expanded(
                  child: _ResultMetric(
                    label: 'Score',
                    value: '$score',
                    isCompact: isCompact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultMetric(
                    label: 'Best',
                    value: '$bestScore',
                    isCompact: isCompact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultMetric(
                    label: 'Max Combo',
                    value: '$maxCombo',
                    isCompact: isCompact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ResultMetric(
                    label: 'Level',
                    value: '$level',
                    isCompact: isCompact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    required this.isCompact,
  });

  final String label;
  final String value;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 6 : 8,
          vertical: isCompact ? 7 : 9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style:
                  (isCompact
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.titleLarge)
                      ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetGrid extends StatelessWidget {
  const _TargetGrid({
    required this.boardSize,
    required this.phase,
    required this.safePulseTick,
    required this.tileKindFor,
    required this.onTileTap,
    required this.isCompact,
  });

  final int boardSize;
  final GamePhase phase;
  final int safePulseTick;
  final TileKind Function(int index) tileKindFor;
  final ValueChanged<int> onTileTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: boardSize,
      mainAxisSpacing: isCompact ? 7 : 10,
      crossAxisSpacing: isCompact ? 7 : 10,
      children: List<Widget>.generate(boardSize * boardSize, (index) {
        final TileKind kind = tileKindFor(index);
        return _TargetTile(
          key: ValueKey('tile-$index-${kind.name}'),
          kind: kind,
          pulseTick: kind == TileKind.safe ? safePulseTick : 0,
          isDimmed: phase != GamePhase.playing,
          onTap: () => onTileTap(index),
        );
      }),
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    super.key,
    required this.kind,
    required this.pulseTick,
    required this.isDimmed,
    required this.onTap,
  });

  final TileKind kind;
  final int pulseTick;
  final bool isDimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _TileStyle style = _styleFor(kind);
    final double opacity = isDimmed ? 0.42 : 1;

    return Semantics(
      button: true,
      label: switch (kind) {
        TileKind.safe => 'safe tile',
        TileKind.trap => 'blue trap',
        TileKind.decoy => 'decoy tile',
        TileKind.quiet => 'quiet tile',
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: opacity,
        child: TweenAnimationBuilder<double>(
          key: ValueKey('pulse-${kind.name}-$pulseTick'),
          tween: Tween<double>(
            begin: kind == TileKind.safe && pulseTick > 0 ? 1.08 : 1,
            end: 1,
          ),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: style.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: style.glow,
                      blurRadius: kind == TileKind.quiet ? 0 : 18,
                      spreadRadius: kind == TileKind.safe ? 1 : 0,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(style.icon, color: style.iconColor, size: 31),
                    if (kind == TileKind.decoy)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(width: 8, height: 8),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _TileStyle _styleFor(TileKind kind) {
    return switch (kind) {
      TileKind.safe => _TileStyle(
        background: const Color(0xFFFF7448),
        border: const Color(0xFFFFC46F),
        glow: const Color(0xFFFF7448).withValues(alpha: 0.36),
        icon: Icons.touch_app_rounded,
        iconColor: const Color(0xFF24130C),
      ),
      TileKind.trap => _TileStyle(
        background: const Color(0xFF1779FF),
        border: const Color(0xFF8DC8FF),
        glow: const Color(0xFF1779FF).withValues(alpha: 0.34),
        icon: Icons.close_rounded,
        iconColor: Colors.white,
      ),
      TileKind.decoy => _TileStyle(
        background: const Color(0xFFFFC857),
        border: const Color(0xFFFFE5A1),
        glow: const Color(0xFFFFC857).withValues(alpha: 0.18),
        icon: Icons.touch_app_outlined,
        iconColor: const Color(0xFF33270A),
      ),
      TileKind.quiet => _TileStyle(
        background: const Color(0xFF242832),
        border: Colors.white.withValues(alpha: 0.08),
        glow: Colors.transparent,
        icon: Icons.circle_outlined,
        iconColor: Colors.white.withValues(alpha: 0.18),
      ),
    };
  }
}

class _TileStyle {
  const _TileStyle({
    required this.background,
    required this.border,
    required this.glow,
    required this.icon,
    required this.iconColor,
  });

  final Color background;
  final Color border;
  final Color glow;
  final IconData icon;
  final Color iconColor;
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.phase,
    required this.onPressed,
    required this.isCompact,
  });

  final GamePhase phase;
  final VoidCallback onPressed;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final String label = switch (phase) {
      GamePhase.ready => 'Start Run',
      GamePhase.playing => 'Restart',
      GamePhase.gameOver => 'Play Again',
    };

    return SizedBox(
      width: double.infinity,
      height: isCompact ? 50 : 56,
      child: FilledButton.icon(
        key: const ValueKey('primary-action'),
        onPressed: onPressed,
        icon: Icon(
          phase == GamePhase.playing
              ? Icons.refresh_rounded
              : Icons.play_arrow_rounded,
        ),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
