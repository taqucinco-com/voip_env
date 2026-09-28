import { NextResponse } from "next/server";
import { requireUid } from "@/lib/auth";
import { submitIceCandidate } from "@/lib/calls";
import { ApiError, apiErrorResponse } from "@/lib/api-error";

export async function POST(
  request: Request,
  ctx: RouteContext<"/api/calls/[roomId]/ice-candidates">,
) {
  try {
    const uid = await requireUid(request);
    const { roomId } = await ctx.params;

    const body = await request.json().catch(() => null);
    const candidate = body?.candidate;
    const sdpMid = body?.sdpMid ?? null;
    const sdpMLineIndex = body?.sdpMLineIndex ?? null;
    if (typeof candidate !== "string") {
      throw new ApiError(400, "INVALID_REQUEST", "candidate is a required string");
    }
    if (sdpMid !== null && typeof sdpMid !== "string") {
      throw new ApiError(400, "INVALID_REQUEST", "sdpMid must be a string or null");
    }
    if (sdpMLineIndex !== null && typeof sdpMLineIndex !== "number") {
      throw new ApiError(400, "INVALID_REQUEST", "sdpMLineIndex must be a number or null");
    }

    await submitIceCandidate(uid, roomId, { candidate, sdpMid, sdpMLineIndex });
    return NextResponse.json({}, { status: 200 });
  } catch (error) {
    return apiErrorResponse(error);
  }
}
