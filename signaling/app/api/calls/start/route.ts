import { NextResponse } from "next/server";
import { requireUid } from "@/lib/auth";
import { startCall } from "@/lib/calls";
import { ApiError, apiErrorResponse } from "@/lib/api-error";

export async function POST(request: Request) {
  try {
    const callerUid = await requireUid(request);

    const body = await request.json().catch(() => null);
    const calleeUid = body?.calleeUid;
    const groupId = body?.groupId;
    if (typeof calleeUid !== "string" || typeof groupId !== "string") {
      throw new ApiError(400, "INVALID_REQUEST", "calleeUid and groupId are required strings");
    }

    const result = await startCall(callerUid, calleeUid, groupId);
    return NextResponse.json(result, { status: 201 });
  } catch (error) {
    return apiErrorResponse(error);
  }
}
