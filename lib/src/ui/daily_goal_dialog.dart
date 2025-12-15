import 'package:flutter/material.dart';

Future<int> askDailyGoalRounds({
  required BuildContext context,
  required String deckName,
  required int initialGoal,
}) async {
  final controller = TextEditingController(
    text: (initialGoal <= 0 ? 1 : initialGoal).toString(),
  );
  String? errorText;

  final result = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('목표 회독 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('“$deckName”\n몇회독이 목표입니까?'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '목표 회독(1~99)',
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) setState(() => errorText = null);
                },
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                final raw = controller.text.trim();
                final value = int.tryParse(raw);
                if (value == null || value < 1 || value > 99) {
                  setState(() => errorText = '1~99 숫자를 입력하세요');
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    },
  );

  controller.dispose();
  return result ?? (initialGoal <= 0 ? 1 : initialGoal);
}

