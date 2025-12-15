import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/anki_status.dart';
import '../state/home_controller.dart';
import 'deck_select_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeController>().refreshStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeController>(
      builder: (context, controller, _) {
        final status = controller.status;

        return Scaffold(
          appBar: AppBar(
            title: const Text('오늘 새 카드 미리보기'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusPanel(
                  status: status,
                  loading: controller.loadingStatus,
                  requestingPermission: controller.requestingPermission,
                  errorCode: controller.lastErrorCode,
                  errorMessage: controller.lastErrorMessage,
                  onRetry: controller.refreshStatus,
                  onOpenAnki: controller.openAnkiDroid,
                  onInstall: controller.openPlayStore,
                  onRequestPermission: controller.requestAnkiPermission,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _StartButton(
                        enabled:
                            (status?.installed == true) &&
                            (status?.providerAccessible == true),
                        loading: controller.loadingCards,
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DeckSelectScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: (!enabled || loading) ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      ),
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text(
              '학습 시작',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.status,
    required this.loading,
    required this.requestingPermission,
    required this.errorCode,
    required this.errorMessage,
    required this.onRetry,
    required this.onOpenAnki,
    required this.onInstall,
    required this.onRequestPermission,
  });

  final AnkiStatus? status;
  final bool loading;
  final bool requestingPermission;
  final String? errorCode;
  final String? errorMessage;
  final Future<void> Function() onRetry;
  final Future<void> Function() onOpenAnki;
  final Future<void> Function() onInstall;
  final Future<bool> Function() onRequestPermission;

  @override
  Widget build(BuildContext context) {
    final s = status;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'AnkiDroid 연결 상태',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: loading ? null : onRetry,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: '새로고침',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: '설치',
                  ok: s?.installed == true,
                  unknown: s == null,
                ),
                _chip(
                  label: '패키지 가시성',
                  ok: s?.providerVisible == true,
                  unknown: s == null,
                ),
                _chip(
                  label: 'API 접근',
                  ok: s?.providerAccessible == true,
                  unknown: s == null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (s?.installed == false) ...[
              const Text('AnkiDroid 설치가 필요합니다.'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onInstall,
                    icon: const Icon(Icons.shop),
                    label: const Text('Play Store로 이동'),
                  ),
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('다시 확인'),
                  ),
                ],
              ),
            ] else if (s?.providerAccessible != true) ...[
              Text(
                _friendlyErrorMessage(errorCode, errorMessage),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '일부 환경에서는 AnkiDroid를 한 번 열고(가능하면 덱 화면까지 진입) 동기화 후 다시 시도해야 합니다.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (errorCode == 'ANKI_PERMISSION_DENIED') ...[
                    OutlinedButton.icon(
                      onPressed: (loading || requestingPermission)
                          ? null
                          : () async {
                              final granted = await onRequestPermission();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    granted ? '권한이 허용되었습니다.' : '권한이 거부되었습니다.',
                                  ),
                                ),
                              );
                            },
                      icon: requestingPermission
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_open),
                      label: const Text('권한 요청'),
                    ),
                  ],
                  FilledButton.icon(
                    onPressed: onOpenAnki,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('AnkiDroid 열기'),
                  ),
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ] else ...[
              const Text('준비 완료. “학습 시작”을 눌러 오늘의 새 카드(상위 N개)를 미리 봅니다.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip({required String label, required bool ok, required bool unknown}) {
    final color = unknown
        ? Colors.grey
        : ok
            ? Colors.green
            : Colors.red;
    final text = unknown
        ? '$label: 확인중'
        : ok
            ? '$label: OK'
            : '$label: 실패';
    return Chip(
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      label: Text(text),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

String _friendlyErrorMessage(String? code, String? message) {
  switch (code) {
    case 'ANKI_NOT_INSTALLED':
      return 'AnkiDroid가 설치되어 있지 않습니다.';
    case 'ANKI_PROVIDER_NOT_FOUND':
      return 'AnkiDroid ContentProvider를 찾지 못했습니다. (Android 11+ 패키지 가시성/queries 확인 필요)';
    case 'ANKI_PERMISSION_DENIED':
      return 'AnkiDroid API 접근 권한이 필요합니다. AnkiDroid를 열어 설정/API 권한을 확인한 뒤 다시 시도하세요.';
    case 'ANKI_QUERY_FAILED':
    case 'ANKI_NULL_CURSOR':
    case 'ANKI_SCHEMA_MISMATCH':
      return 'AnkiDroid 데이터 조회에 실패했습니다. AnkiDroid를 한 번 열고(동기화) 다시 시도하세요.\n(${message ?? code})';
    default:
      return message ?? '알 수 없는 오류가 발생했습니다.';
  }
}
