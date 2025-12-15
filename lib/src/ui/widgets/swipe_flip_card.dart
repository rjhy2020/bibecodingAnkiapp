import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/card_item.dart';
import '../../state/study_settings_controller.dart';
import 'study_card_faces.dart';

class SwipeFlipCard extends StatefulWidget {
  const SwipeFlipCard({
    super.key,
    required this.card,
    required this.onSpeak,
    required this.onSwiped,
  });

  final CardItem card;
  final Future<void> Function(String text) onSpeak;
  final VoidCallback onSwiped;

  @override
  State<SwipeFlipCard> createState() => _SwipeFlipCardState();
}

class _SwipeFlipCardState extends State<SwipeFlipCard>
    with TickerProviderStateMixin {
  late final AnimationController _flip;
  late final AnimationController _swipe;

  Offset _drag = Offset.zero;
  Offset _swipeStart = Offset.zero;
  Offset _swipeEnd = Offset.zero;
  bool _swipeOut = false;
  bool _isBack = false;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _swipe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _swipe.addListener(() {
      setState(() {
        _drag =
            Offset.lerp(_swipeStart, _swipeEnd, _swipe.value) ?? _swipeEnd;
      });
    });
    _swipe.addStatusListener((status) {
      if (status == AnimationStatus.completed && _swipeOut) {
        _swipeOut = false;
        widget.onSwiped();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SwipeFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.cardId != widget.card.cardId) {
      _drag = Offset.zero;
      _swipeStart = Offset.zero;
      _swipeEnd = Offset.zero;
      _swipeOut = false;
      _isBack = false;
      _flip.value = 0;
      _swipe.value = 0;
    }
  }

  @override
  void dispose() {
    _flip.dispose();
    _swipe.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_flip.isAnimating || _swipe.isAnimating) return;
    if (_isBack) {
      // On back: tap to go next (same as swiping right).
      _animateOut();
      return;
    }

    widget.onSpeak(widget.card.frontText);
    await _flip.forward(from: 0);
    if (!mounted) return;
    setState(() => _isBack = true);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final nextDx = math.max(0.0, _drag.dx + details.delta.dx);
    setState(() => _drag = Offset(nextDx, 0));
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final size = MediaQuery.sizeOf(context);
    final threshold = size.width * 0.22;
    if (_drag.dx >= threshold) {
      _animateOut();
    } else {
      _animateBack();
    }
  }

  void _animateBack() {
    _swipeStart = _drag;
    _swipeEnd = Offset.zero;
    _swipeOut = false;
    _swipe.forward(from: 0);
  }

  void _animateOut() {
    final size = MediaQuery.sizeOf(context);
    final end = Offset(size.width * 1.4, 0);
    _swipeStart = _drag;
    _swipeEnd = end;
    _swipeOut = true;
    _swipe.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context
        .watch<StudySettingsController>()
        .settingsForModel(widget.card.modelId);
    final front = StudyCardFrontFace(card: widget.card, settings: settings);
    final back = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi),
      child: StudyCardBackFace(card: widget.card, settings: settings),
    );

    final swipeRotation = (_drag.dx / 800).clamp(-0.12, 0.12);

    return GestureDetector(
      onTap: _handleTap,
      onLongPress: () => widget.onSpeak(widget.card.frontText),
      onHorizontalDragUpdate: _isBack ? _onHorizontalDragUpdate : null,
      onHorizontalDragEnd: _isBack ? _onHorizontalDragEnd : null,
      child: Transform.translate(
        offset: _drag,
        child: Transform.rotate(
          angle: swipeRotation,
          child: AnimatedBuilder(
            animation: _flip,
            builder: (context, _) {
              final t = _flip.value;
              final angle = math.pi * t;
              final showingFront = angle <= math.pi / 2;
              final face = showingFront ? front : back;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateY(angle),
                child: Material(
                  elevation: 6,
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 460,
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                    ),
                    child: face,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
