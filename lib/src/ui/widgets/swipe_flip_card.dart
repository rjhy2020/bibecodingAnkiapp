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

  late final ValueNotifier<Offset> _drag;
  Offset _swipeStart = Offset.zero;
  Offset _swipeEnd = Offset.zero;
  Curve _swipeCurve = Curves.easeOutCubic;
  bool _swipeOut = false;
  bool _isBack = false;
  bool _buildBackContent = false;

  @override
  void initState() {
    super.initState();
    _drag = ValueNotifier(Offset.zero);
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _swipe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _swipe.addListener(() {
      final t = _swipeCurve.transform(_swipe.value);
      _drag.value = Offset.lerp(_swipeStart, _swipeEnd, t) ?? _swipeEnd;
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
      _drag.value = Offset.zero;
      _swipeStart = Offset.zero;
      _swipeEnd = Offset.zero;
      _swipeOut = false;
      _isBack = false;
      _buildBackContent = false;
      _flip.value = 0;
      _swipe.value = 0;
    }
  }

  @override
  void dispose() {
    _drag.dispose();
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
    if (!_buildBackContent) {
      setState(() => _buildBackContent = true);
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
    }
    await _flip.forward(from: 0);
    if (!mounted) return;
    setState(() => _isBack = true);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final current = _drag.value;
    final nextDx = math.max(0.0, current.dx + details.delta.dx);
    _drag.value = Offset(nextDx, 0);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final size = MediaQuery.sizeOf(context);
    final threshold = size.width * 0.22;
    if (_drag.value.dx >= threshold) {
      _animateOut();
    } else {
      _animateBack();
    }
  }

  void _animateBack() {
    _swipeCurve = Curves.easeOutCubic;
    _swipeStart = _drag.value;
    _swipeEnd = Offset.zero;
    _swipeOut = false;
    _swipe.forward(from: 0);
  }

  void _animateOut() {
    final size = MediaQuery.sizeOf(context);
    final end = Offset(size.width * 1.4, 0);
    _swipeCurve = Curves.easeInCubic;
    _swipeStart = _drag.value;
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
      child: StudyCardBackFace(
        card: widget.card,
        settings: settings,
        showFields: _buildBackContent,
      ),
    );

    final cardBody = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_flip.value);
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
    );

    return GestureDetector(
      onTap: _handleTap,
      onLongPress: () => widget.onSpeak(widget.card.frontText),
      onHorizontalDragUpdate: _isBack ? _onHorizontalDragUpdate : null,
      onHorizontalDragEnd: _isBack ? _onHorizontalDragEnd : null,
      child: ValueListenableBuilder<Offset>(
        valueListenable: _drag,
        child: cardBody,
        builder: (context, drag, child) {
          final swipeRotation = (drag.dx / 900).clamp(-0.10, 0.10);
          return Transform.translate(
            offset: drag,
            child: Transform.rotate(angle: swipeRotation, child: child),
          );
        },
      ),
    );
  }
}
