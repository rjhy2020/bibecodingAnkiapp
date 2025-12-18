import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../models/card_item.dart';
import '../state/daily_deck_progress_controller.dart';
import '../state/study_session_controller.dart';
import '../utils/html_sanitizer.dart';
import 'daily_goal_dialog.dart';
import 'study_settings_sheet.dart';
import 'widgets/card_stack.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, required this.deckId, required this.deckName});

  final int deckId;
  final String deckName;

  static Route<void> route({
    required int deckId,
    required String deckName,
    required List<CardItem> cards,
  }) {
    return MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => StudySessionController(cards),
        child: StudyScreen(deckId: deckId, deckName: deckName),
      ),
    );
  }

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late final FlutterTts _tts;
  bool _ttsReady = false;
  StudySessionController? _session;
  String _lastAutoSpokenCardId = '';
  bool _wasComplete = false;
  Timer? _autoSpeakTimer;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachSessionListener());
  }

  void _attachSessionListener() {
    if (!mounted) return;
    if (_session != null) return;
    final session = context.read<StudySessionController>();
    _session = session;
    session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  void _onSessionChanged() {
    final session = _session;
    if (session == null) return;

    if (session.isComplete) {
      if (!_wasComplete) {
        _wasComplete = true;
        final progress = context.read<DailyDeckProgressController>();
        unawaited(progress.incrementCompletedRounds(widget.deckId));
      }
      return;
    }

    _wasComplete = false;

    final card = session.currentCard;
    if (card == null) return;
    if (_lastAutoSpokenCardId == card.cardId) return;
    _lastAutoSpokenCardId = card.cardId;

    _autoSpeakTimer?.cancel();
    final cardId = card.cardId;
    final text = card.frontText;
    _autoSpeakTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      final current = _session?.currentCard;
      if (current == null || current.cardId != cardId) return;
      _speak(text);
    });
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      if (!mounted) return;
      setState(() => _ttsReady = true);
      _onSessionChanged();
    } catch (_) {
      if (!mounted) return;
      setState(() => _ttsReady = false);
    }
  }

  Future<void> _speak(String raw) async {
    if (!_ttsReady) return;
    final text = stripHtmlToPlainText(raw);
    if (text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _speakManual(String raw) async {
    _autoSpeakTimer?.cancel();
    await _speak(raw);
  }

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
    _autoSpeakTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudySessionController>(
      builder: (context, session, _) {
        final daily = context
            .watch<DailyDeckProgressController>()
            .progressForDeck(widget.deckId);

        if (session.isComplete) {
          return _CompleteScreen(
            onRestart: session.restart,
            onHome: () => Navigator.of(context).pop(),
            deckName: widget.deckName,
            roundsCompleted: daily.roundsCompleted,
            goalRounds: daily.goalRounds,
          );
        }

        final currentRound = daily.roundsCompleted + 1;

        return Scaffold(
          appBar: AppBar(
            title: Text('학습 • ${widget.deckName}'),
            actions: [
              IconButton(
                onPressed: () {
                  final card = session.currentCard;
                  if (card == null) return;
                  StudySettingsSheet.show(context, card);
                },
                icon: const Icon(Icons.tune),
                tooltip: '표시 설정',
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Header(
                    total: session.total,
                    remaining: session.remaining,
                    currentRound: currentRound,
                    goalRounds: daily.goalRounds,
                    onEditGoal: () async {
                      final goal = await askDailyGoalRounds(
                        context: context,
                        deckName: widget.deckName,
                        initialGoal: daily.goalRounds,
                      );
                      if (!context.mounted) return;
                      await context
                          .read<DailyDeckProgressController>()
                          .setGoalForDeck(widget.deckId, goal);
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: CardStack(
                          topCard: session.currentCard!,
                          secondCard: session.peek(1),
                          thirdCard: session.peek(2),
                          onSpeak: _speakManual,
                          onSwiped: session.swipeNext,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '앞면 탭: 플립 / 뒷면 탭(또는 오른쪽 스와이프): 다음 카드',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.remaining,
    required this.currentRound,
    required this.goalRounds,
    required this.onEditGoal,
  });

  final int total;
  final int remaining;
  final int currentRound;
  final int goalRounds;
  final VoidCallback onEditGoal;

  @override
  Widget build(BuildContext context) {
    final roundText = goalRounds > 0 ? '$currentRound/$goalRounds' : '$currentRound';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill('Total', '$total'),
        _pill('Remaining', '$remaining'),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onEditGoal,
          child: _pill('회독/목표', roundText),
        ),
      ],
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class _CompleteScreen extends StatelessWidget {
  const _CompleteScreen({
    required this.onRestart,
    required this.onHome,
    required this.deckName,
    required this.roundsCompleted,
    required this.goalRounds,
  });

  final VoidCallback onRestart;
  final VoidCallback onHome;
  final String deckName;
  final int roundsCompleted;
  final int goalRounds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('완료')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '오늘 미리보기 완료',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '$deckName\n오늘 $roundsCompleted회독'
                '${goalRounds > 0 ? ' / 목표 $goalRounds회독' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton(
                    onPressed: onRestart,
                    child: const Text('다시 시작'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onHome,
                    child: const Text('홈으로'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
