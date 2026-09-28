import 'package:voip_env/feature/call/call_record.dart';
import 'package:voip_env/feature/call/incoming_call.dart';

sealed class CallUiState {
  const CallUiState();
}

// 通話に参加していない状態。
class CallIdle extends CallUiState {
  const CallIdle();
}

// roomIdは判明したがcalls/{roomId}の初回スナップショットをまだ受信していない状態。
// 発信直後の一瞬だけ通過するため、アイドル状態のボタンを誤って表示しないためにある。
class CallConnecting extends CallUiState {
  const CallConnecting({required this.roomId});
  final String roomId;
}

// 自分が発信し、相手の応答を待っている状態。
class CallOutgoingRinging extends CallUiState {
  const CallOutgoingRinging({required this.roomId, required this.calleeUid});
  final String roomId;
  final String calleeUid;
}

// 自分に着信があり、応答/拒否の判断を待っている状態。
class CallIncomingRinging extends CallUiState {
  const CallIncomingRinging({required this.roomId, required this.callerUid});
  final String roomId;
  final String callerUid;
}

// 通話が確立している状態。
class CallInProgress extends CallUiState {
  const CallInProgress({required this.roomId, required this.peerUid});
  final String roomId;
  final String peerUid;
}

// incomingCall・追跡中のroomId・calls/{roomId}のレコードから、
// 画面に表示すべき状態を1つに決定する。
//
// incomingCallは応答前のcallee側にしか存在せず、応答するとサーバーがnullに戻すため、
// 他の状態より先に判定してよい。
CallUiState deriveCallUiState({
  required String? myUid,
  required String? currentRoomId,
  required IncomingCall? incomingCall,
  required CallRecord? callRecord,
}) {
  if (incomingCall != null) {
    return CallIncomingRinging(
      roomId: incomingCall.roomId,
      callerUid: incomingCall.callerUid,
    );
  }

  if (currentRoomId == null) {
    return const CallIdle();
  }
  if (callRecord == null) {
    return CallConnecting(roomId: currentRoomId);
  }
  if (callRecord.status == 'ended') {
    return const CallIdle();
  }

  final isCaller = callRecord.caller == myUid;
  final peerUid = isCaller ? callRecord.callee : callRecord.caller;
  if (callRecord.status == 'active') {
    return CallInProgress(roomId: currentRoomId, peerUid: peerUid);
  }
  return CallOutgoingRinging(roomId: currentRoomId, calleeUid: peerUid);
}
