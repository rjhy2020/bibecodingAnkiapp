class ModelStudySettings {
  final bool showFieldLabels;
  final Set<String> hiddenFieldKeys;
  final double frontFontSize;
  final double backTitleFontSize;
  final double backBodyFontSize;

  const ModelStudySettings({
    this.showFieldLabels = false,
    this.hiddenFieldKeys = const <String>{},
    this.frontFontSize = 44,
    this.backTitleFontSize = 28,
    this.backBodyFontSize = 16,
  });

  ModelStudySettings copyWith({
    bool? showFieldLabels,
    Set<String>? hiddenFieldKeys,
    double? frontFontSize,
    double? backTitleFontSize,
    double? backBodyFontSize,
  }) {
    return ModelStudySettings(
      showFieldLabels: showFieldLabels ?? this.showFieldLabels,
      hiddenFieldKeys: hiddenFieldKeys ?? this.hiddenFieldKeys,
      frontFontSize: frontFontSize ?? this.frontFontSize,
      backTitleFontSize: backTitleFontSize ?? this.backTitleFontSize,
      backBodyFontSize: backBodyFontSize ?? this.backBodyFontSize,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showFieldLabels': showFieldLabels,
      'hiddenFieldKeys': hiddenFieldKeys.toList()..sort(),
      'frontFontSize': frontFontSize,
      'backTitleFontSize': backTitleFontSize,
      'backBodyFontSize': backBodyFontSize,
    };
  }

  factory ModelStudySettings.fromJson(Map<String, dynamic> json) {
    final rawHidden = json['hiddenFieldKeys'];
    final hidden = <String>{};
    if (rawHidden is List) {
      for (final item in rawHidden) {
        if (item is String && item.trim().isNotEmpty) {
          hidden.add(item.trim().toLowerCase());
        }
      }
    }

    return ModelStudySettings(
      showFieldLabels: json['showFieldLabels'] == true,
      hiddenFieldKeys: hidden,
      frontFontSize: (json['frontFontSize'] as num?)?.toDouble() ?? 44,
      backTitleFontSize: (json['backTitleFontSize'] as num?)?.toDouble() ?? 28,
      backBodyFontSize: (json['backBodyFontSize'] as num?)?.toDouble() ?? 16,
    );
  }
}
