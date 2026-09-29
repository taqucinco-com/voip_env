import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

// 非同期処理の実行中フラグを管理するhook。実行完了時、ウィジェットが既に
// unmountされていればsetStateを避けるためcontext.mountedを確認する。
typedef AsyncAction = ({
  bool isRunning,
  Future<void> Function(Future<void> Function() action) run,
});

AsyncAction useAsyncAction(BuildContext context) {
  final isRunning = useState(false);

  Future<void> run(Future<void> Function() action) async {
    isRunning.value = true;
    try {
      await action();
    } finally {
      if (context.mounted) {
        isRunning.value = false;
      }
    }
  }

  return (isRunning: isRunning.value, run: run);
}
