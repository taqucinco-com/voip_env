import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/auth/auth_provider.dart';
import 'package:voip_env/feature/call/call_record.dart';
import 'package:voip_env/feature/call/call_ui_state.dart';
import 'package:voip_env/feature/call/incoming_call.dart';
import 'package:voip_env/feature/call/signaling_client.dart';

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

    // 発信した/応答した通話のroomId。設定されている間はcalls/{roomId}を監視し、
    // 状態遷移（calling→active→ended）をUIへ反映する。
    final currentRoomId = useState<String?>(null);
    final isProcessing = useState(false);

    final incomingCall = ref.watch(incomingCallProvider).value;
    final callRecord = currentRoomId.value == null
        ? null
        : ref.watch(callRecordProvider(currentRoomId.value!)).value;

    final callUiState = deriveCallUiState(
      myUid: user?.uid,
      currentRoomId: currentRoomId.value,
      incomingCall: incomingCall,
      callRecord: callRecord,
    );

    // 通話が終了したら追跡をやめる（次の発着信のためroomIdをリセットする）。
    useEffect(() {
      if (callRecord?.status == 'ended') {
        currentRoomId.value = null;
      }
      return null;
    }, [callRecord?.status]);

    useEffect(() {
      Future.microtask(() async {
        final idToken = await authorizer.getIdToken();
        debugPrint('ID Token: $idToken');
      });
      return null;
    }, [user]);

    Future<void> withProcessing(Future<void> Function() action) async {
      isProcessing.value = true;
      try {
        await action();
      } finally {
        if (context.mounted) {
          isProcessing.value = false;
        }
      }
    }

    void showApiError(SignalingApiResult result) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.statusCode}: ${result.body}')),
      );
    }

    Future<void> handleStartCall() => withProcessing(() async {
      final calleeUid = _testCalleeUidFor(user?.uid);
      final idToken = await authorizer.getIdToken();
      if (idToken == null || calleeUid == null) {
        return;
      }

      final result = await startCall(
        idToken: idToken,
        calleeUid: calleeUid,
        groupId: _testGroupId,
      );
      if (result.isSuccess) {
        currentRoomId.value = result.body['roomId'] as String;
      } else {
        showApiError(result);
      }
    });

    Future<void> handleAccept(String roomId) => withProcessing(() async {
      final idToken = await authorizer.getIdToken();
      if (idToken == null) {
        return;
      }

      final result = await acceptCall(idToken: idToken, roomId: roomId);
      if (result.isSuccess) {
        currentRoomId.value = roomId;
      } else {
        showApiError(result);
      }
    });

    Future<void> handleEndCall(String roomId) => withProcessing(() async {
      final idToken = await authorizer.getIdToken();
      if (idToken == null) {
        return;
      }

      final result = await endCall(idToken: idToken, roomId: roomId);
      if (!result.isSuccess) {
        showApiError(result);
      }
    });

    final (statusText, actions) = switch (callUiState) {
      CallIdle() => (
        'オンライン',
        [
          ElevatedButton(
            onPressed: isProcessing.value ? null : handleStartCall,
            child: const Text('テスト発信 (start call)'),
          ),
        ],
      ),
      CallConnecting() => ('接続中…', const <Widget>[]),
      CallOutgoingRinging(:final roomId, :final calleeUid) => (
        '発信中: $calleeUid',
        [
          OutlinedButton(
            onPressed: isProcessing.value ? null : () => handleEndCall(roomId),
            child: const Text('発信を取り消す'),
          ),
        ],
      ),
      CallIncomingRinging(:final roomId, :final callerUid) => (
        '着信中: $callerUid から',
        [
          ElevatedButton(
            onPressed: isProcessing.value ? null : () => handleAccept(roomId),
            child: const Text('応答'),
          ),
          const SizedBox(width: 16.0),
          OutlinedButton(
            onPressed: isProcessing.value ? null : () => handleEndCall(roomId),
            child: const Text('拒否'),
          ),
        ],
      ),
      CallInProgress(:final roomId, :final peerUid) => (
        '通話中: $peerUid',
        [
          OutlinedButton(
            onPressed: isProcessing.value ? null : () => handleEndCall(roomId),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('user_id: ${user?.uid ?? '-'}'),
            const SizedBox(height: 8.0),
            Text(statusText, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24.0),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ),
      ),
    );
  }
}
