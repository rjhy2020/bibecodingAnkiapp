import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/card_item.dart';
import '../models/model_study_settings.dart';
import '../state/study_settings_controller.dart';
import '../utils/html_sanitizer.dart';

class StudySettingsSheet extends StatefulWidget {
  const StudySettingsSheet({super.key, required this.card});

  final CardItem card;

  static Future<void> show(BuildContext context, CardItem card) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StudySettingsSheet(card: card),
    );
  }

  @override
  State<StudySettingsSheet> createState() => _StudySettingsSheetState();
}

class _StudySettingsSheetState extends State<StudySettingsSheet> {
  late ModelStudySettings _settings;
  late final List<_FieldPreview> _fields;

  @override
  void initState() {
    super.initState();
    final controller = context.read<StudySettingsController>();
    _settings = controller.settingsForModel(widget.card.modelId);
    _fields = _buildFieldPreviews(widget.card);
  }

  List<_FieldPreview> _buildFieldPreviews(CardItem card) {
    final seen = <String>{};
    final result = <_FieldPreview>[];
    for (final f in card.backFields) {
      final name = f.name.trim();
      if (name.isEmpty) continue;
      final key = StudySettingsController.normalizeFieldKey(name);
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(
        _FieldPreview(
          name: name,
          keyName: key,
          valuePreview: stripHtmlToPlainText(f.value),
        ),
      );
    }
    return result;
  }

  bool _isFieldVisible(_FieldPreview field) {
    return !_settings.hiddenFieldKeys.contains(field.keyName);
  }

  void _setFieldVisible(_FieldPreview field, bool visible) {
    final next = {..._settings.hiddenFieldKeys};
    if (visible) {
      next.remove(field.keyName);
    } else {
      next.add(field.keyName);
    }
    setState(() => _settings = _settings.copyWith(hiddenFieldKeys: next));
  }

  Future<void> _apply() async {
    final controller = context.read<StudySettingsController>();
    await controller.saveModelSettings(widget.card.modelId, _settings);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    final controller = context.read<StudySettingsController>();
    await controller.resetModelSettings(widget.card.modelId);
    if (!mounted) return;
    setState(() => _settings = const ModelStudySettings());
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '카드 표시 설정',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: _reset,
                        child: const Text('초기화'),
                      ),
                    ],
                  ),
                  Text(
                    '노트 타입(modelId): ${widget.card.modelId}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),

                  _PreviewSection(card: widget.card, settings: _settings),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('필드명(카테고리) 표시'),
                    subtitle: const Text('예: “뜻”, “예문”, “pronunciation” 등'),
                    value: _settings.showFieldLabels,
                    onChanged: (v) =>
                        setState(() => _settings = _settings.copyWith(showFieldLabels: v)),
                  ),
                  const Divider(),
                  _SliderRow(
                    label: '앞면 단어 크기',
                    value: _settings.frontFontSize,
                    min: 24,
                    max: 64,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(frontFontSize: v),
                    ),
                  ),
                  _SliderRow(
                    label: '뒷면 단어 크기',
                    value: _settings.backTitleFontSize,
                    min: 18,
                    max: 42,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(backTitleFontSize: v),
                    ),
                  ),
                  _SliderRow(
                    label: '뒷면 내용 크기',
                    value: _settings.backBodyFontSize,
                    min: 12,
                    max: 26,
                    onChanged: (v) => setState(
                      () => _settings = _settings.copyWith(backBodyFontSize: v),
                    ),
                  ),
                  const Divider(),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('필드 숨김/표시'),
                    children: [
                      if (_fields.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text('이 카드에서 필드를 찾지 못했습니다.'),
                        ),
                      for (final f in _fields)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _isFieldVisible(f),
                          onChanged: (v) => _setFieldVisible(f, v == true),
                          title: Text(f.name),
                          subtitle: Text(
                            f.valuePreview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('적용'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.card, required this.settings});

  final CardItem card;
  final ModelStudySettings settings;

  @override
  Widget build(BuildContext context) {
    final front = stripHtmlToPlainText(card.frontText);
    final hidden = settings.hiddenFieldKeys;

    final visibleFields = <FieldItem>[];
    for (var i = 0; i < card.backFields.length; i++) {
      final field = card.backFields[i];
      final key = StudySettingsController.normalizeFieldKey(field.name);
      if (hidden.contains(key)) continue;

      final clean = stripHtmlToPlainText(field.value);
      if (clean.trim().isEmpty) continue;
      if (i == 0 && clean == front) continue;

      visibleFields.add(FieldItem(name: field.name, value: clean));
    }

    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '미리보기',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            for (final f in visibleFields.take(3)) ...[
              if (settings.showFieldLabels) ...[
                Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
              ],
              Text(
                f.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: settings.backBodyFontSize),
              ),
              const SizedBox(height: 10),
            ],
            if (visibleFields.length > 3)
              Text(
                '… +${visibleFields.length - 3}개',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$label: ${value.toStringAsFixed(0)}'),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _FieldPreview {
  const _FieldPreview({
    required this.name,
    required this.keyName,
    required this.valuePreview,
  });

  final String name;
  final String keyName;
  final String valuePreview;
}

