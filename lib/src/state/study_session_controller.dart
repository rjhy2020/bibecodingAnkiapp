import 'package:flutter/foundation.dart';

import '../models/card_item.dart';

class StudySessionController extends ChangeNotifier {
  StudySessionController(this.cards);

  final List<CardItem> cards;
  int index = 0;

  int get total => cards.length;
  int get remaining => (cards.length - index).clamp(0, cards.length);

  bool get isComplete => index >= cards.length;

  CardItem? get currentCard => isComplete ? null : cards[index];
  CardItem? peek(int offset) {
    final i = index + offset;
    if (i < 0 || i >= cards.length) return null;
    return cards[i];
  }

  void swipeNext() {
    if (isComplete) return;
    index++;
    notifyListeners();
  }

  void restart() {
    index = 0;
    notifyListeners();
  }
}

