import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:voip_env/feature/auth/auth_provider.dart';
import 'package:voip_env/feature/call/call_record_provider.dart';
import 'package:voip_env/feature/call/call_ui_state.dart';
import 'package:voip_env/feature/call/incoming_call_provider.dart';

// 発信/応答した通話のroomIdを保持するだけの状態。リセットのタイミングは
// callUiStateProviderが管理する。
class CurrentRoomIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void track(String roomId) => state = roomId;

  void clear() => state = null;
}

final currentRoomIdProvider =
    NotifierProvider.autoDispose<CurrentRoomIdNotifier, String?>(
      CurrentRoomIdNotifier.new,
    );

// incomingCall・追跡中のroomId・calls/{roomId}のレコードを合成し、
// 画面に表示すべきCallUiStateへ畳み込む。
//
// 併せて、通話がendedになったら追跡中のroomIdをリセットする（ref.listen）。
// ended検知はCallUiStateの畳み込みと同じ関心事のため、この中に同居させている。
// roomIdが変わるたびlisten先が張り替わるが、古いbuildのlisten登録はRiverpodが
// Provider再評価時に自動で破棄する。
final callUiStateProvider = Provider.autoDispose<CallUiState>((ref) {
  final myUid = ref.watch(authStateChangesProvider).value?.uid;
  final incomingCall = ref.watch(incomingCallProvider).value;
  final roomId = ref.watch(currentRoomIdProvider);
  final callRecord = roomId == null
      ? null
      : ref.watch(callRecordProvider(roomId)).value;

  if (roomId != null) {
    ref.listen(callRecordProvider(roomId), (previous, next) {
      if (next.value?.status == 'ended') {
        ref.read(currentRoomIdProvider.notifier).clear();
      }
    });
  }

  return deriveCallUiState(
    myUid: myUid,
    currentRoomId: roomId,
    incomingCall: incomingCall,
    callRecord: callRecord,
  );
});
