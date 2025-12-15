import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/deck_item.dart';
import '../state/daily_deck_progress_controller.dart';
import '../state/home_controller.dart';
import 'daily_goal_dialog.dart';
import 'study_screen.dart';

class DeckSelectScreen extends StatefulWidget {
  const DeckSelectScreen({super.key});

  @override
  State<DeckSelectScreen> createState() => _DeckSelectScreenState();
}

class _DeckSelectScreenState extends State<DeckSelectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<HomeController>();
      if (controller.decks.isEmpty && !controller.loadingDecks) {
        controller.refreshDecks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressController = context.watch<DailyDeckProgressController>();
    return Consumer<HomeController>(
      builder: (context, controller, _) {
        final decks = controller.decks;
        final selectedId = controller.selectedDeckId;
        final selectedDeck = controller.selectedDeck;

        return Scaffold(
          appBar: AppBar(
            title: const Text('덱 선택'),
            actions: [
              IconButton(
                onPressed: controller.loadingDecks ? null : controller.refreshDecks,
                icon: controller.loadingDecks
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: '덱 새로고침',
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: decks.isEmpty
                    ? _EmptyDecksState(
                        loading: controller.loadingDecks,
                        errorCode: controller.lastErrorCode,
                        errorMessage: controller.lastErrorMessage,
                        onRetry: controller.refreshDecks,
                        onOpenAnki: controller.openAnkiDroid,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: decks.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final d = decks[index];
                          return _DeckTile(
                            deck: d,
                            selected: d.deckId == selectedId,
                            onTap: () => controller.selectDeck(d.deckId),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                  child: FilledButton(
                      onPressed:
                          (selectedDeck == null ||
                                  controller.loadingCards ||
                                  !progressController.loaded)
                              ? null
                              : () async {
                                  try {
                                    final cards = await controller.loadTodayCards(
                                      deckId: selectedDeck.deckId,
                                    );
                                    if (!context.mounted) return;

                                    if (cards.isEmpty) {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => _EmptyCardsScreen(
                                            deckName: selectedDeck.deckName,
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    if (!progressController.hasGoalForDeck(
                                      selectedDeck.deckId,
                                    )) {
                                      final goal = await askDailyGoalRounds(
                                        context: context,
                                        deckName: selectedDeck.deckName,
                                        initialGoal: 1,
                                      );
                                      if (!context.mounted) return;
                                      await progressController.setGoalForDeck(
                                        selectedDeck.deckId,
                                        goal,
                                      );
                                    }

                                    if (!context.mounted) return;
                                    await Navigator.of(context).push(
                                      StudyScreen.route(
                                        deckId: selectedDeck.deckId,
                                        deckName: selectedDeck.deckName,
                                        cards: cards,
                                      ),
                                    );
                                  } on PlatformException catch (e) {
                                    if (!context.mounted) return;
                                    final details = e.details?.toString();
                                    final message = e.message;
                                    final combined =
                                        (details == null || details.isEmpty)
                                            ? message
                                            : '${message ?? ''}\n$details';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          combined ?? 'AnkiDroid 데이터 조회 실패',
                                        ),
                                      ),
                                    );
                                  }
                                },
                      child: controller.loadingCards
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              selectedDeck == null
                                  ? '덱을 선택하세요'
                                  : '이 덱으로 시작 (${selectedDeck.deckName})',
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({
    required this.deck,
    required this.selected,
    required this.onTap,
  });

  final DeckItem deck;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = <String>[
      if (deck.newCount != null) 'New ${deck.newCount}',
      if (deck.learnCount != null) 'Learn ${deck.learnCount}',
      if (deck.reviewCount != null) 'Review ${deck.reviewCount}',
    ].join(' • ');

    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.08) : scheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? scheme.primary : Colors.black54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      deck.deckName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDecksState extends StatelessWidget {
  const _EmptyDecksState({
    required this.loading,
    required this.errorCode,
    required this.errorMessage,
    required this.onRetry,
    required this.onOpenAnki,
  });

  final bool loading;
  final String? errorCode;
  final String? errorMessage;
  final Future<void> Function() onRetry;
  final Future<void> Function() onOpenAnki;

  @override
  Widget build(BuildContext context) {
    final msg = loading
        ? '덱 목록 불러오는 중...'
        : errorMessage ?? errorCode ?? '덱 목록을 불러오지 못했습니다.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '덱을 선택하세요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: loading ? null : onOpenAnki,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('AnkiDroid 열기'),
                ),
                OutlinedButton(
                  onPressed: loading ? null : onRetry,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCardsScreen extends StatelessWidget {
  const _EmptyCardsScreen({required this.deckName});

  final String deckName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘 새 카드')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '선택한 덱에 오늘 보여줄 새 카드가 없음\n($deckName)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
