import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/auth/auth_provider.dart';
import 'package:voip_env/feature/call/call_negotiation.dart';
import 'package:voip_env/feature/call/call_record.dart';
import 'package:voip_env/feature/call/call_ui_state.dart';
import 'package:voip_env/feature/call/incoming_call.dart';
import 'package:voip_env/feature/call/signaling_client.dart';
import 'package:voip_env/feature/call/signaling_provider.dart';

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

    // 発信した/応答した通話のroomId。設定されている間はcalls/{roomId}を監視し、
    // 状態遷移（calling→active→ended）をUIへ反映する。
    final currentRoomId = useState<String?>(null);
    final isProcessing = useState(false);

    final incomingCall = ref.watch(incomingCallProvider).value;
    final callRecord = currentRoomId.value == null
        ? null
        : ref.watch(callRecordProvider(currentRoomId.value!)).value;

    // シグナリング配線の動作確認用。offer/answer/ICE候補の到達状況を画面に出す。
    final callOffer = currentRoomId.value == null
        ? null
        : ref.watch(callOfferProvider(currentRoomId.value!)).value;
    final callAnswer = currentRoomId.value == null
        ? null
        : ref.watch(callAnswerProvider(currentRoomId.value!)).value;
    final callerIceCandidates = currentRoomId.value == null
        ? const <IceCandidateEntry>[]
        : ref.watch(
                iceCandidatesProvider((
                  roomId: currentRoomId.value!,
                  side: 'caller',
                )),
              ).value ??
              const <IceCandidateEntry>[];
    final calleeIceCandidates = currentRoomId.value == null
        ? const <IceCandidateEntry>[]
        : ref.watch(
                iceCandidatesProvider((
                  roomId: currentRoomId.value!,
                  side: 'callee',
                )),
              ).value ??
              const <IceCandidateEntry>[];

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
      if (calleeUid == null) {
        return;
      }

      final result = await signalingClient.startCall(
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
      final result = await signalingClient.acceptCall(roomId: roomId);
      if (result.isSuccess) {
        currentRoomId.value = roomId;
      } else {
        showApiError(result);
      }
    });

    Future<void> handleEndCall(String roomId) => withProcessing(() async {
      final result = await signalingClient.endCall(roomId: roomId);
      if (!result.isSuccess) {
        showApiError(result);
      }
    });

    Future<void> handleSendTestOffer(String roomId) => withProcessing(() async {
      final result = await signalingClient.submitOffer(
        roomId: roomId,
        sdp: 'dummy-offer-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!result.isSuccess) {
        showApiError(result);
      }
    });

    Future<void> handleSendTestAnswer(String roomId) => withProcessing(() async {
      final result = await signalingClient.submitAnswer(
        roomId: roomId,
        sdp: 'dummy-answer-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!result.isSuccess) {
        showApiError(result);
      }
    });

    Future<void> handleSendTestIceCandidate(String roomId) =>
        withProcessing(() async {
          final result = await signalingClient.submitIceCandidate(
            roomId: roomId,
            candidate: 'dummy-candidate-${DateTime.now().millisecondsSinceEpoch}',
            sdpMid: '0',
            sdpMLineIndex: 0,
          );
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('user_id: ${user?.uid ?? '-'}'),
              const SizedBox(height: 8.0),
              Text(statusText, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24.0),
              Row(mainAxisSize: MainAxisSize.min, children: actions),
              if (callUiState case CallInProgress(:final roomId, :final isCaller)) ...[
                const SizedBox(height: 24.0),
                const Divider(),
                Text(
                  'シグナリング配線テスト（Offer/Answer/ICE候補）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8.0),
                Text('Offer: ${callOffer?.sdp ?? '未送信'}'),
                Text('Answer: ${callAnswer?.sdp ?? '未送信'}'),
                Text('ICE候補(caller): ${callerIceCandidates.length}件'),
                Text('ICE候補(callee): ${calleeIceCandidates.length}件'),
                const SizedBox(height: 8.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  alignment: WrapAlignment.center,
                  children: [
                    if (isCaller)
                      OutlinedButton(
                        onPressed: isProcessing.value
                            ? null
                            : () => handleSendTestOffer(roomId),
                        child: const Text('テストOfferを送る'),
                      )
                    else
                      OutlinedButton(
                        onPressed: isProcessing.value
                            ? null
                            : () => handleSendTestAnswer(roomId),
                        child: const Text('テストAnswerを送る'),
                      ),
                    OutlinedButton(
                      onPressed: isProcessing.value
                          ? null
                          : () => handleSendTestIceCandidate(roomId),
                      child: const Text('テストICE候補を送る'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
