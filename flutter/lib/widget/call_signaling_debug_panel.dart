import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/common/hooks/use_async_action.dart';
import 'package:voip_env/feature/call/call_negotiation_provider.dart';
import 'package:voip_env/feature/call/signaling_client.dart';
import 'package:voip_env/feature/call/signaling_client_provider.dart';

// シグナリング配線の動作確認用パネル。offer/answer/ICE候補の到達状況を表示し、
// テスト送信ボタンを提供する。本番の通話UIとは別関心のため独立したウィジェットにしている。
class CallSignalingDebugPanel extends HookConsumerWidget {
  const CallSignalingDebugPanel({
    super.key,
    required this.roomId,
    required this.isCaller,
  });

  final String roomId;
  final bool isCaller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalingClient = ref.watch(signalingClientProvider);
    final callNegotiation = ref.watch(callNegotiationProvider(roomId));
    final asyncAction = useAsyncAction(context);

    void showApiError(SignalingApiResult result) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.statusCode}: ${result.body}')),
      );
    }

    Future<void> handleSendTestOffer() => asyncAction.run(() async {
      final result = await signalingClient.submitOffer(
        roomId: roomId,
        sdp: 'dummy-offer-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!result.isSuccess) {
        showApiError(result);
      }
    });

    Future<void> handleSendTestAnswer() => asyncAction.run(() async {
      final result = await signalingClient.submitAnswer(
        roomId: roomId,
        sdp: 'dummy-answer-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!result.isSuccess) {
        showApiError(result);
      }
    });

    Future<void> handleSendTestIceCandidate() => asyncAction.run(() async {
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24.0),
        const Divider(),
        Text(
          'シグナリング配線テスト（Offer/Answer/ICE候補）',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8.0),
        Text('Offer: ${callNegotiation.offer?.sdp ?? '未送信'}'),
        Text('Answer: ${callNegotiation.answer?.sdp ?? '未送信'}'),
        Text('ICE候補(caller): ${callNegotiation.callerIceCandidates.length}件'),
        Text('ICE候補(callee): ${callNegotiation.calleeIceCandidates.length}件'),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          alignment: WrapAlignment.center,
          children: [
            if (isCaller)
              OutlinedButton(
                onPressed: asyncAction.isRunning ? null : handleSendTestOffer,
                child: const Text('テストOfferを送る'),
              )
            else
              OutlinedButton(
                onPressed: asyncAction.isRunning ? null : handleSendTestAnswer,
                child: const Text('テストAnswerを送る'),
              ),
            OutlinedButton(
              onPressed: asyncAction.isRunning
                  ? null
                  : handleSendTestIceCandidate,
              child: const Text('テストICE候補を送る'),
            ),
          ],
        ),
      ],
    );
  }
}
