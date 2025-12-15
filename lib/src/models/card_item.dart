class FieldItem {
  final String name;
  final String value;

  const FieldItem({required this.name, required this.value});

  factory FieldItem.fromMap(Map<dynamic, dynamic> map) {
    return FieldItem(
      name: (map['name'] as String?) ?? '',
      value: (map['value'] as String?) ?? '',
    );
  }
}

class CardItem {
  final String cardId;
  final int modelId;
  final String deckName;
  final String frontText;
  final List<FieldItem> backFields;

  const CardItem({
    required this.cardId,
    required this.modelId,
    required this.deckName,
    required this.frontText,
    required this.backFields,
  });

  factory CardItem.fromMap(Map<dynamic, dynamic> map) {
    final rawBackFields = map['backFields'];
    final backFields = <FieldItem>[];
    if (rawBackFields is List) {
      for (final item in rawBackFields) {
        if (item is Map) backFields.add(FieldItem.fromMap(item));
      }
    }

    return CardItem(
      cardId: (map['cardId'] as String?) ?? '',
      modelId: (map['modelId'] as num?)?.toInt() ?? 0,
      deckName: (map['deckName'] as String?) ?? 'Unknown Deck',
      frontText: (map['frontText'] as String?) ?? '',
      backFields: backFields,
    );
  }
}
