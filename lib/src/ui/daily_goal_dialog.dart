import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

Future<int> askDailyGoalRounds({
  required BuildContext context,
  required String deckName,
  required int initialGoal,
}) async {
  final original = (initialGoal <= 0 ? 1 : initialGoal).clamp(1, 99);
  final result = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _DailyGoalDialog(deckName: deckName, initialGoal: original);
    },
  );
  return result ?? original;
}

class _DailyGoalDialog extends StatefulWidget {
  const _DailyGoalDialog({required this.deckName, required this.initialGoal});

  final String deckName;
  final int initialGoal;

  @override
  State<_DailyGoalDialog> createState() => _DailyGoalDialogState();
}

class _DailyGoalDialogState extends State<_DailyGoalDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _errorText;
  bool _closing = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialGoal.toString());
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_closing) return;

    final raw = _controller.text.trim();
    final value = int.tryParse(raw);
    if (value == null || value < 1 || value > 99) {
      setState(() => _errorText = '1~99 숫자를 입력하세요');
      return;
    }

    setState(() {
      _closing = true;
      _allowPop = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    // Wait for text input / selection overlays to detach before route pop.
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  Future<void> _cancel() async {
    if (_closing) return;
    setState(() {
      _closing = true;
      _allowPop = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<int>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Intercept system back (and any other pop attempts) so we can safely
        // detach text input overlays before closing.
        _cancel();
      },
      child: AlertDialog(
        title: const Text('목표 회독 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('“${widget.deckName}”\n몇회독이 목표입니까?'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              enableInteractiveSelection: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: InputDecoration(
                labelText: '목표 회독(1~99)',
                errorText: _errorText,
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _closing ? null : _cancel,
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: _closing ? null : _confirm,
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
