import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/common/hooks/use_async_action.dart';
import 'package:voip_env/feature/auth/auth_provider.dart';
import 'package:voip_env/feature/call/call_session_provider.dart';
import 'package:voip_env/feature/call/call_ui_state.dart';
import 'package:voip_env/feature/call/signaling_client.dart';
import 'package:voip_env/feature/call/signaling_client_provider.dart';
import 'package:voip_env/widget/call_signaling_debug_panel.dart';

// 疎通確認用の固定値。groupIdの選択UIは未実装。
// group_test1に所属する2つのuidのうち、ログイン中でない方を相手として扱う。
const _testGroupMemberUids = [
  'suyMIoEvFOVy2bBYvWhw4KZSQ753',
  'yWo72LEq7TRiHRsPbfhzDh9Bzd13',
];
const _testGroupId = 'group_test1';

String? _testCalleeUidFor(String? myUid) {
  return _testGroupMemberUids.where((uid) => uid != myUid).firstOrNull;
}

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateChangesProvider).value;
    final authorizer = ref.watch(authFacadeProvider);
    final signalingClient = ref.watch(signalingClientProvider);
    final callUiState = ref.watch(callUiStateProvider);
    final asyncAction = useAsyncAction(context);

    useEffect(() {
      Future.microtask(() async {
        final idToken = await authorizer.getIdToken();
        debugPrint('ID Token: $idToken');
      });
      return null;
    }, [user]);

    void showApiError(SignalingApiResult result) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.statusCode}: ${result.body}')),
      );
    }

    Future<void> handleStartCall() => asyncAction.run(() async {
      final calleeUid = _testCalleeUidFor(user?.uid);
      if (calleeUid == null) {
        return;
      }

      final result = await signalingClient.startCall(
        calleeUid: calleeUid,
        groupId: _testGroupId,
      );
      if (result.isSuccess) {
        ref
            .read(currentRoomIdProvider.notifier)
            .track(result.body['roomId'] as String);
      } else {
        showApiError(result);
      }
    });

    Future<void> handleAccept(String roomId) => asyncAction.run(() async {
      final result = await signalingClient.acceptCall(roomId: roomId);
      if (result.isSuccess) {
        ref.read(currentRoomIdProvider.notifier).track(roomId);
      } else {
        showApiError(result);
      }
    });

    Future<void> handleEndCall(String roomId) => asyncAction.run(() async {
      final result = await signalingClient.endCall(roomId: roomId);
      if (!result.isSuccess) {
        showApiError(result);
      }
    });

    final (statusText, actions) = switch (callUiState) {
      CallIdle() => (
        'オンライン',
        [
          ElevatedButton(
            onPressed: asyncAction.isRunning ? null : handleStartCall,
            child: const Text('テスト発信 (start call)'),
          ),
        ],
      ),
      CallConnecting() => ('接続中…', const <Widget>[]),
      CallOutgoingRinging(:final roomId, :final calleeUid) => (
        '発信中: $calleeUid',
        [
          OutlinedButton(
            onPressed: asyncAction.isRunning
                ? null
                : () => handleEndCall(roomId),
            child: const Text('発信を取り消す'),
          ),
        ],
      ),
      CallIncomingRinging(:final roomId, :final callerUid) => (
        '着信中: $callerUid から',
        [
          ElevatedButton(
            onPressed: asyncAction.isRunning
                ? null
                : () => handleAccept(roomId),
            child: const Text('応答'),
          ),
          const SizedBox(width: 16.0),
          OutlinedButton(
            onPressed: asyncAction.isRunning
                ? null
                : () => handleEndCall(roomId),
            child: const Text('拒否'),
          ),
        ],
      ),
      CallInProgress(:final roomId, :final peerUid) => (
        '通話中: $peerUid',
        [
          OutlinedButton(
            onPressed: asyncAction.isRunning
                ? null
                : () => handleEndCall(roomId),
            child: const Text('終了'),
          ),
        ],
      ),
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async => await ref.read(authFacadeProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('user_id: ${user?.uid ?? '-'}'),
              const SizedBox(height: 8.0),
              Text(statusText, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24.0),
              Row(mainAxisSize: MainAxisSize.min, children: actions),
              if (callUiState case CallInProgress(
                :final roomId,
                :final isCaller,
              ))
                CallSignalingDebugPanel(roomId: roomId, isCaller: isCaller),
            ],
          ),
        ),
      ),
    );
  }
}
