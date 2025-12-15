import 'package:flutter/material.dart';

import '../../models/card_item.dart';
import 'swipe_flip_card.dart';

class CardStack extends StatelessWidget {
  const CardStack({
    super.key,
    required this.topCard,
    required this.secondCard,
    required this.thirdCard,
    required this.onSpeak,
    required this.onSwiped,
  });

  final CardItem topCard;
  final CardItem? secondCard;
  final CardItem? thirdCard;
  final Future<void> Function(String text) onSpeak;
  final VoidCallback onSwiped;

  @override
  Widget build(BuildContext context) {
    final layers = <Widget>[
      if (thirdCard != null)
        _DeckLayer(
          key: const ValueKey('layer3'),
          depth: 2,
          child: _DecorativeCardPlaceholder(),
        ),
      if (secondCard != null)
        _DeckLayer(
          key: const ValueKey('layer2'),
          depth: 1,
          child: _DecorativeCardPlaceholder(),
        ),
      _DeckLayer(
        key: const ValueKey('layer1'),
        depth: 0,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return ScaleTransition(scale: scale, child: child);
          },
          child: SwipeFlipCard(
            key: ValueKey(topCard.cardId),
            card: topCard,
            onSpeak: onSpeak,
            onSwiped: onSwiped,
          ),
        ),
      ),
    ];

    return Stack(
      alignment: Alignment.center,
      children: layers,
    );
  }
}

class _DeckLayer extends StatelessWidget {
  const _DeckLayer({super.key, required this.depth, required this.child});

  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dy = 10.0 * depth;
    final scale = 1.0 - (0.03 * depth);
    final opacity = 1.0 - (0.10 * depth);

    return Transform.translate(
      offset: Offset(0, dy),
      child: Transform.scale(
        scale: scale,
        child: Opacity(opacity: opacity, child: child),
      ),
    );
  }
}

class _DecorativeCardPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 460,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
    );
  }
}
