import { ServerValue } from "firebase-admin/database";
import { adminDb } from "@/lib/firebase-admin";
import { ApiError } from "@/lib/api-error";
import { buildIceServers, type IceServer } from "@/lib/turn-credentials";

type CallStatus = "calling" | "active" | "ended";
type EndReason = "rejected" | "cancelled" | "hangup";

type CallRecord = {
  groupId: string;
  caller: string;
  callee: string;
  status: CallStatus;
  endedReason: EndReason | null;
  endedBy: string | null;
  createdAt: number | object;
  answeredAt: number | object | null;
  endedAt: number | object | null;
};

export async function startCall(
  callerUid: string,
  calleeUid: string,
  groupId: string,
): Promise<{ roomId: string; iceServers: IceServer[] }> {
  if (callerUid === calleeUid) {
    throw new ApiError(400, "INVALID_REQUEST", "callerUid must differ from the authenticated user");
  }

  const membersSnapshot = await adminDb.ref(`groups/${groupId}/members`).get();
  const members = (membersSnapshot.val() ?? {}) as Record<string, boolean>;
  if (!members[callerUid] || !members[calleeUid]) {
    throw new ApiError(403, "NOT_GROUP_MEMBER", "caller and callee must both belong to the group");
  }

  // Realtime Databaseのtransaction()は単一refにしか効かないため、
  // caller/calleeそれぞれのstatusを個別にtransactionで押さえる。
  // calleeが busy だった場合は、先に busy にしたcallerを online へ補償する。
  const callerStatusRef = adminDb.ref(`users/${callerUid}/status`);
  const calleeStatusRef = adminDb.ref(`users/${calleeUid}/status`);

  const callerResult = await callerStatusRef.transaction((current) =>
    current === "busy" ? undefined : "busy",
  );
  if (!callerResult.committed) {
    throw new ApiError(409, "CALLER_BUSY", "caller is already in a call");
  }

  const calleeResult = await calleeStatusRef.transaction((current) =>
    current === "busy" ? undefined : "busy",
  );
  if (!calleeResult.committed) {
    await callerStatusRef.set("online");
    throw new ApiError(409, "CALLEE_BUSY", "callee is already in a call");
  }

  const roomRef = adminDb.ref("calls").push();
  const roomId = roomRef.key;
  if (!roomId) {
    throw new Error("failed to allocate roomId");
  }

  const call: CallRecord = {
    groupId,
    caller: callerUid,
    callee: calleeUid,
    status: "calling",
    endedReason: null,
    endedBy: null,
    createdAt: ServerValue.TIMESTAMP,
    answeredAt: null,
    endedAt: null,
  };

  await adminDb.ref().update({
    [`calls/${roomId}`]: call,
    [`users/${calleeUid}/incomingCall`]: {
      roomId,
      callerUid,
      groupId,
      createdAt: ServerValue.TIMESTAMP,
    },
  });

  return { roomId, iceServers: buildIceServers(callerUid) };
}

async function getCallOrThrow(roomId: string): Promise<CallRecord> {
  const snapshot = await adminDb.ref(`calls/${roomId}`).get();
  const call = snapshot.val() as CallRecord | null;
  if (!call) {
    throw new ApiError(404, "CALL_NOT_FOUND", `call ${roomId} does not exist`);
  }
  return call;
}

export async function acceptCall(
  uid: string,
  roomId: string,
): Promise<{ iceServers: IceServer[] }> {
  const call = await getCallOrThrow(roomId);
  if (call.callee !== uid) {
    throw new ApiError(403, "NOT_CALL_PARTICIPANT", "only the callee can accept a call");
  }

  const statusRef = adminDb.ref(`calls/${roomId}/status`);
  const result = await statusRef.transaction((current) =>
    current === "calling" ? "active" : undefined,
  );
  if (!result.committed) {
    throw new ApiError(409, "INVALID_CALL_STATE", `cannot accept a call in status "${call.status}"`);
  }

  await adminDb.ref().update({
    [`calls/${roomId}/answeredAt`]: ServerValue.TIMESTAMP,
    [`users/${uid}/incomingCall`]: null,
  });

  return { iceServers: buildIceServers(uid) };
}

export async function endCall(
  uid: string,
  roomId: string,
): Promise<{ status: "ended"; reason: EndReason }> {
  const call = await getCallOrThrow(roomId);
  if (call.caller !== uid && call.callee !== uid) {
    throw new ApiError(403, "NOT_CALL_PARTICIPANT", "uid is not a participant of this call");
  }

  if (call.status === "ended") {
    return { status: "ended", reason: call.endedReason ?? "hangup" };
  }

  const reason: EndReason =
    call.status === "calling" ? (uid === call.callee ? "rejected" : "cancelled") : "hangup";

  const statusRef = adminDb.ref(`calls/${roomId}/status`);
  const result = await statusRef.transaction((current) =>
    current === "ended" ? undefined : "ended",
  );

  if (!result.committed) {
    // 別リクエストが先にendedへ遷移させたレース: 現在値を読み直して冪等に返す
    const latest = await getCallOrThrow(roomId);
    return { status: "ended", reason: latest.endedReason ?? "hangup" };
  }

  await adminDb.ref().update({
    [`calls/${roomId}/endedReason`]: reason,
    [`calls/${roomId}/endedBy`]: uid,
    [`calls/${roomId}/endedAt`]: ServerValue.TIMESTAMP,
    [`users/${call.caller}/status`]: "online",
    [`users/${call.callee}/status`]: "online",
    [`users/${call.callee}/incomingCall`]: null,
  });

  return { status: "ended", reason };
}
