class AnkiStatus {
  final bool installed;
  final bool providerVisible;
  final bool providerAccessible;
  final String? lastErrorCode;
  final String? lastErrorMessage;

  const AnkiStatus({
    required this.installed,
    required this.providerVisible,
    required this.providerAccessible,
    this.lastErrorCode,
    this.lastErrorMessage,
  });

  factory AnkiStatus.fromMap(Map<dynamic, dynamic> map) {
    return AnkiStatus(
      installed: map['installed'] == true,
      providerVisible: map['providerVisible'] == true,
      providerAccessible: map['providerAccessible'] == true,
      lastErrorCode: map['lastErrorCode'] as String?,
      lastErrorMessage: map['lastErrorMessage'] as String?,
    );
  }
}

