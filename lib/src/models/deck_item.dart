class DeckItem {
  final int deckId;
  final String deckName;
  final int? newCount;
  final int? learnCount;
  final int? reviewCount;

  const DeckItem({
    required this.deckId,
    required this.deckName,
    this.newCount,
    this.learnCount,
    this.reviewCount,
  });

  factory DeckItem.fromMap(Map<dynamic, dynamic> map) {
    return DeckItem(
      deckId: (map['deckId'] as int?) ?? 0,
      deckName: (map['deckName'] as String?) ?? '',
      newCount: map['newCount'] as int?,
      learnCount: map['learnCount'] as int?,
      reviewCount: map['reviewCount'] as int?,
    );
  }
}

