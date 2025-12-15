import 'package:flutter/material.dart';

import '../../models/card_item.dart';
import '../../models/model_study_settings.dart';
import '../../state/study_settings_controller.dart';
import '../../utils/html_sanitizer.dart';

class StudyCardFrontFace extends StatelessWidget {
  const StudyCardFrontFace({
    super.key,
    required this.card,
    required this.settings,
    this.showDeckName = true,
    this.showHint = true,
  });

  final CardItem card;
  final ModelStudySettings settings;
  final bool showDeckName;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final front = stripHtmlToPlainText(card.frontText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDeckName)
          Text(
            card.deckName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54),
          ),
        if (showDeckName) const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: Text(
              front,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: settings.frontFontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (showHint) const SizedBox(height: 8),
        if (showHint)
          const Text(
            '탭해서 뒤집기',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45),
          ),
      ],
    );
  }
}

class StudyCardBackFace extends StatelessWidget {
  const StudyCardBackFace({
    super.key,
    required this.card,
    required this.settings,
    this.showDeckName = true,
    this.showHint = true,
  });

  final CardItem card;
  final ModelStudySettings settings;
  final bool showDeckName;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final front = stripHtmlToPlainText(card.frontText);
    final hidden = settings.hiddenFieldKeys;

    final rows = <Widget>[];
    for (var i = 0; i < card.backFields.length; i++) {
      final field = card.backFields[i];
      final key = StudySettingsController.normalizeFieldKey(field.name);
      if (hidden.contains(key)) continue;

      final clean = stripHtmlToPlainText(field.value);
      if (clean.trim().isEmpty) continue;
      if (i == 0 && clean == front) continue;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _FieldRow(
            name: field.name,
            value: clean,
            showLabel: settings.showFieldLabels,
            fontSize: settings.backBodyFontSize,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDeckName)
          Text(
            card.deckName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54),
          ),
        if (showDeckName) const SizedBox(height: 8),
        Text(
          front,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: settings.backTitleFontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
        if (showHint) const SizedBox(height: 8),
        if (showHint)
          const Text(
            '탭(또는 오른쪽 스와이프)으로 다음 카드',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45),
          ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.name,
    required this.value,
    required this.showLabel,
    required this.fontSize,
  });

  final String name;
  final String value;
  final bool showLabel;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
        ],
        SelectableText(
          value,
          style: TextStyle(fontSize: fontSize),
        ),
      ],
    );
  }
}
